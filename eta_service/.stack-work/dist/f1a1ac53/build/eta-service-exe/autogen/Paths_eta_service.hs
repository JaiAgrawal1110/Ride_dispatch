{-# LANGUAGE CPP #-}
{-# LANGUAGE NoRebindableSyntax #-}
{-# OPTIONS_GHC -fno-warn-missing-import-lists #-}
{-# OPTIONS_GHC -w #-}
module Paths_eta_service (
    version,
    getBinDir, getLibDir, getDynLibDir, getDataDir, getLibexecDir,
    getDataFileName, getSysconfDir
  ) where


import qualified Control.Exception as Exception
import qualified Data.List as List
import Data.Version (Version(..))
import System.Environment (getEnv)
import Prelude


#if defined(VERSION_base)

#if MIN_VERSION_base(4,0,0)
catchIO :: IO a -> (Exception.IOException -> IO a) -> IO a
#else
catchIO :: IO a -> (Exception.Exception -> IO a) -> IO a
#endif

#else
catchIO :: IO a -> (Exception.IOException -> IO a) -> IO a
#endif
catchIO = Exception.catch

version :: Version
version = Version [0,1,0,0] []

getDataFileName :: FilePath -> IO FilePath
getDataFileName name = do
  dir <- getDataDir
  return (dir `joinFileName` name)

getBinDir, getLibDir, getDynLibDir, getDataDir, getLibexecDir, getSysconfDir :: IO FilePath



bindir, libdir, dynlibdir, datadir, libexecdir, sysconfdir :: FilePath
bindir     = "C:\\Users\\HP\\Desktop\\Ride_Dispatch\\eta_service\\.stack-work\\install\\c84bbe0f\\bin"
libdir     = "C:\\Users\\HP\\Desktop\\Ride_Dispatch\\eta_service\\.stack-work\\install\\c84bbe0f\\lib\\x86_64-windows-ghc-9.4.8\\eta-service-0.1.0.0-1G9uJHhKx4eC5cz5IiDtCK-eta-service-exe"
dynlibdir  = "C:\\Users\\HP\\Desktop\\Ride_Dispatch\\eta_service\\.stack-work\\install\\c84bbe0f\\lib\\x86_64-windows-ghc-9.4.8"
datadir    = "C:\\Users\\HP\\Desktop\\Ride_Dispatch\\eta_service\\.stack-work\\install\\c84bbe0f\\share\\x86_64-windows-ghc-9.4.8\\eta-service-0.1.0.0"
libexecdir = "C:\\Users\\HP\\Desktop\\Ride_Dispatch\\eta_service\\.stack-work\\install\\c84bbe0f\\libexec\\x86_64-windows-ghc-9.4.8\\eta-service-0.1.0.0"
sysconfdir = "C:\\Users\\HP\\Desktop\\Ride_Dispatch\\eta_service\\.stack-work\\install\\c84bbe0f\\etc"

getBinDir     = catchIO (getEnv "eta_service_bindir")     (\_ -> return bindir)
getLibDir     = catchIO (getEnv "eta_service_libdir")     (\_ -> return libdir)
getDynLibDir  = catchIO (getEnv "eta_service_dynlibdir")  (\_ -> return dynlibdir)
getDataDir    = catchIO (getEnv "eta_service_datadir")    (\_ -> return datadir)
getLibexecDir = catchIO (getEnv "eta_service_libexecdir") (\_ -> return libexecdir)
getSysconfDir = catchIO (getEnv "eta_service_sysconfdir") (\_ -> return sysconfdir)




joinFileName :: String -> String -> FilePath
joinFileName ""  fname = fname
joinFileName "." fname = fname
joinFileName dir ""    = dir
joinFileName dir fname
  | isPathSeparator (List.last dir) = dir ++ fname
  | otherwise                       = dir ++ pathSeparator : fname

pathSeparator :: Char
pathSeparator = '\\'

isPathSeparator :: Char -> Bool
isPathSeparator c = c == '/' || c == '\\'
