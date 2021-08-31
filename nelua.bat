@echo off
SETLOCAL
SET NELUA_ROOT=%~dp0
SET NELUA_ROOT_FIX=%NELUA_ROOT:\=\\%
SET EXE=%NELUA_ROOT%\nelua-lua.exe
IF NOT EXIST %EXE% (
  SET EXE=%NELUA_ROOT%\src\nelua-lua.exe
)
%EXE% -e "package.path='%NELUA_ROOT_FIX%\\?.lua;'..package.path" %NELUA_ROOT%\nelua.lua %*
