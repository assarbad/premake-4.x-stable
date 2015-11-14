@echo off
@if not "%OS%"=="Windows_NT" @(echo This script requires Windows NT 4.0 or later to run properly! & goto :EOF)
setlocal ENABLEEXTENSIONS & pushd .
call setvcvars.cmd 8.0
if NOT defined VCVER_FRIENDLY echo Unfortunately setvcvars.cmd didn't do its job. Fix the problem and run this script again.&goto :EOF
set HGTIPFILE="%~dp0src\host\hgtip.h"
for /f %%i in ('hg id -i -r tip') do @echo #define HG_TIP_ID "%%i" > %HGTIPFILE%
for /f %%i in ('hg id -n -r tip') do @echo #define HG_TIP_REVNO "%%i" >> %HGTIPFILE%
if exist %HGTIPFILE% type %HGTIPFILE%
vcbuild /rebuild /time Premake4.vs8.sln "Publish|Win32"
popd & endlocal & goto :EOF
