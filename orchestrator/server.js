/**
 * One-command orchestrator for the Mini Ride-Dispatch Simulator.
 *
 * Instead of opening five terminals by hand, this script:
 *   1. Spawns dispatch_core, eta_service, fare_service, and
 *      analytics_service as child processes, logging each one's
 *      output to this single terminal with a colored prefix.
 *   2. Serves the Elm dashboard as static files.
 *   3. Reverse-proxies the dashboard's API/WebSocket calls to the
 *      right backend port, so the whole system is reachable from one
 *      host:port instead of four.
 *
 * This does NOT replace each service's own toolchain (Elixir, Stack,
 * Scala, Clojure still need to be installed) - it just replaces having
 * to juggle five terminal windows once they are.
 */

const http = require("http");
const fs = require("fs");
const path = require("path");
const { spawn } = require("child_process");
const httpProxy = require("http-proxy");

const ROOT = path.resolve(__dirname, "..");
const PORT = process.env.PORT || 8080;
const IS_WINDOWS = process.platform === "win32";

const RESET = "\x1b[0m";

// Each service's actual run command - the same one you'd type by hand
// in that service's own README. `shell: true` is needed so Windows can
// resolve .bat/.cmd shims (mix.bat, stack.exe wrappers, scala.bat, etc.)
// the same way a real terminal would.
const SERVICES = [
  {
    name: "dispatch_core",
    color: "\x1b[36m", // cyan
    cwd: path.join(ROOT, "dispatch_core"),
    command: "mix",
    args: ["run", "--no-halt"]
  },
  {
    name: "eta_service",
    color: "\x1b[33m", // yellow
    cwd: path.join(ROOT, "eta_service"),
    command: "stack",
    args: ["exec", "eta-service-exe"]
  },
  {
    name: "fare_service",
    color: "\x1b[35m", // magenta
    cwd: path.join(ROOT, "fare_service"),
    command: "scala",
    args: ["run", "src/main/scala/fareservice"]
  },
  {
    name: "analytics_service",
    color: "\x1b[32m", // green
    cwd: path.join(ROOT, "analytics_service"),
    command: "clojure",
    args: ["-M", "-m", "rideanalytics.main"]
  }
];

const children = [];

function startService(service) {
  log(service, `starting: ${service.command} ${service.args.join(" ")}`);

  const child = spawn(service.command, service.args, {
    cwd: service.cwd,
    shell: true,
    // On POSIX, this makes the child the leader of a new process
    // group, so shutdown() can kill the whole group (shell + the real
    // process it launched) in one signal instead of orphaning the
    // real process when the shell wrapper exits.
    detached: !IS_WINDOWS
  });

  child.stdout.on("data", (data) => logLines(service, data));
  child.stderr.on("data", (data) => logLines(service, data));
  child.on("exit", (code) => {
    log(service, `exited with code ${code}`);
  });
  child.on("error", (err) => {
    log(service, `failed to start: ${err.message}`);
  });

  children.push(child);
}

function log(service, message) {
  console.log(`${service.color}[${service.name}]${RESET} ${message}`);
}

function logLines(service, data) {
  const lines = data.toString().split(/\r?\n/);
  for (const line of lines) {
    if (line.trim().length > 0) {
      log(service, line);
    }
  }
}

// ---- Reverse proxy + static dashboard ----

const proxy = httpProxy.createProxyServer({});
proxy.on("error", (err, _req, res) => {
  console.error(`[orchestrator] proxy error: ${err.message}`);
  if (res && res.writeHead && !res.headersSent) {
    res.writeHead(502, { "Content-Type": "application/json" });
    res.end(JSON.stringify({ error: "upstream service unavailable", detail: err.message }));
  }
});

// Maps a public path prefix to the real service port and the path that
// service actually expects. The dashboard calls /api/eta, /api/fare,
// /api/analytics - none of it needs to know the real ports.
const API_ROUTES = [
  { prefix: "/api/eta", target: "http://localhost:4001", realPath: "/eta" },
  { prefix: "/api/fare", target: "http://localhost:4002", realPath: "/fare" },
  { prefix: "/api/analytics", target: "http://localhost:4003", realPath: "/analytics" }
];

const DASHBOARD_DIR = path.join(ROOT, "dashboard");
const MIME_TYPES = {
  ".html": "text/html",
  ".js": "application/javascript",
  ".css": "text/css"
};

function serveStatic(req, res) {
  const urlPath = req.url === "/" ? "/index.html" : req.url;
  const filePath = path.join(DASHBOARD_DIR, urlPath);

  // Guard against escaping the dashboard directory via ../ in the URL.
  if (!filePath.startsWith(DASHBOARD_DIR)) {
    res.writeHead(400);
    res.end("Bad request");
    return;
  }

  fs.readFile(filePath, (err, content) => {
    if (err) {
      res.writeHead(404, { "Content-Type": "text/plain" });
      res.end("Not found");
      return;
    }
    const ext = path.extname(filePath);
    res.writeHead(200, { "Content-Type": MIME_TYPES[ext] || "application/octet-stream" });
    res.end(content);
  });
}

function safeJsonParse(text) {
  try {
    return JSON.parse(text);
  } catch {
    return text;
  }
}

function checkHealth(name, url) {
  return new Promise((resolve) => {
    const req = http.get(url, { timeout: 2000 }, (r) => {
      let body = "";
      r.on("data", (chunk) => (body += chunk));
      r.on("end", () => resolve([name, { status: r.statusCode, body: safeJsonParse(body) }]));
    });
    req.on("timeout", () => {
      req.destroy();
      resolve([name, { status: null, error: "timeout" }]);
    });
    req.on("error", (err) => resolve([name, { status: null, error: err.message }]));
  });
}

async function handleHealthAggregate(_req, res) {
  const checks = await Promise.all([
    checkHealth("eta_service", "http://localhost:4001/health"),
    checkHealth("fare_service", "http://localhost:4002/health"),
    checkHealth("analytics_service", "http://localhost:4003/health")
  ]);

  const results = Object.fromEntries(checks);
  res.writeHead(200, { "Content-Type": "application/json" });
  res.end(JSON.stringify(results, null, 2));
}

const server = http.createServer((req, res) => {
  if (req.url === "/api/health") {
    handleHealthAggregate(req, res);
    return;
  }

  const route = API_ROUTES.find((r) => req.url.startsWith(r.prefix));
  if (route) {
    req.url = route.realPath;
    proxy.web(req, res, { target: route.target });
    return;
  }

  // Everything under /socket goes straight to dispatch_core's Phoenix
  // endpoint - this covers both the plain HTTP upgrade handshake path
  // and (via the "upgrade" handler below) the actual WebSocket traffic.
  if (req.url.startsWith("/socket")) {
    proxy.web(req, res, { target: "http://localhost:4000" });
    return;
  }

  serveStatic(req, res);
});

server.on("upgrade", (req, socket, head) => {
  if (req.url.startsWith("/socket")) {
    proxy.ws(req, socket, head, { target: "http://localhost:4000" });
  } else {
    socket.destroy();
  }
});

// ---- Start everything ----

console.log("Starting all Ride Dispatch Simulator services...\n");
SERVICES.forEach(startService);

server.listen(PORT, () => {
  console.log(`\n[orchestrator] All services launching. Once they're up, open: http://localhost:${PORT}`);
  console.log(`[orchestrator] Aggregate health check: http://localhost:${PORT}/api/health\n`);
});

function shutdown() {
  console.log("\n[orchestrator] Shutting down all services...");
  children.forEach((child) => {
    if (!child.pid) return;
    if (IS_WINDOWS) {
      // child.kill() often doesn't reach the real process on Windows
      // when shell: true spawned it via cmd.exe - taskkill on the PID
      // tree is the reliable way to actually stop it.
      spawn("taskkill", ["/pid", child.pid, "/T", "/F"]);
    } else {
      try {
        // Negative pid = signal the whole process group (see the
        // `detached` note in startService), so the shell wrapper and
        // the real process it launched both get the signal.
        process.kill(-child.pid, "SIGTERM");
      } catch (_err) {
        child.kill("SIGTERM");
      }
    }
  });
  setTimeout(() => process.exit(0), 500);
}

process.on("SIGINT", shutdown);
process.on("SIGTERM", shutdown);
