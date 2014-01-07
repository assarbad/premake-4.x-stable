@echo off
@if not "%OS%"=="Windows_NT" @(echo This script requires Windows NT 4.0 or later to run properly! & goto :EOF)
call setvcvars.cmd 8.0
if NOT defined VCVER_FRIENDLY echo Unfortunately setvcvars.cmd didn't do its job. Fix the problem and run this script again.&goto :EOF
vcbuild /rebuild /time Premake4.vs8.sln "Release|Win32"