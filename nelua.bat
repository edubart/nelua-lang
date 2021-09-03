@echo off
SETLOCAL
SET EXE=%~dp0\nelua-lua.exe
"%EXE%" -lnelua nelua.lua %*
