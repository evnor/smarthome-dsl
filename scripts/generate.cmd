@echo off
setlocal

if "%~2"=="" (
  echo Usage: scripts\generate.cmd input.smrt output.py
  exit /b 1
)

set "ROOT=%~dp0.."
set "INPUT=%~f1"
set "OUTPUT=%~f2"
set "LOG=%TEMP%\smarthome-generate-%RANDOM%.log"

if not exist "%ROOT%\target\classes\rascal\smarthome\$Generate.tpl" (
  pushd "%ROOT%"
  call mvn compile
  if errorlevel 1 (
    popd
    exit /b 1
  )
  popd
)

java -cp "%ROOT%\target\classes;%USERPROFILE%\.m2\repository\org\rascalmpl\rascal\0.42.0\rascal-0.42.0.jar;%USERPROFILE%\.m2\repository\org\rascalmpl\rascal-lsp\2.22.5\rascal-lsp-2.22.5.jar" org.rascalmpl.shell.RascalShell smarthome::Generate "%INPUT%" "%OUTPUT%" > "%LOG%" 2>&1
set "STATUS=%ERRORLEVEL%"

type "%LOG%" | findstr /V /C:"Declared dependency does not exist"
del "%LOG%" > nul 2>&1
exit /b %STATUS%
