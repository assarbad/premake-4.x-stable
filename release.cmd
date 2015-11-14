@echo off
@if not "%OS%"=="Windows_NT" @(echo This script requires Windows NT 4.0 or later to run properly! & goto :EOF)
setlocal ENABLEEXTENSIONS & pushd .
call setvcvars.cmd 8.0
if NOT defined VCVER_FRIENDLY echo Unfortunately setvcvars.cmd didn't do its job. Fix the problem and run this script again.&goto :EOF
set HGTIPFILE="%~dp0src\host\hgtip.h"
for /f %%i in ('hg id -i -r tip') do @call :SetVar HG_TIP_ID "%%i"
for /f %%i in ('hg id -n -r tip') do @call :SetVar HG_TIP_REVNO "%%i"
echo #define HG_TIP_ID "%HG_TIP_ID%" > %HGTIPFILE%
echo #define HG_TIP_REVNO "%HG_TIP_REVNO%" >> %HGTIPFILE%
if exist %HGTIPFILE% type %HGTIPFILE%
vcbuild /rebuild /time Premake4.vs8.sln "Publish|Win32"
set NEWNAME=%~dp0premake4.rev-%HG_TIP_REVNO%-%HG_TIP_ID%.exe
copy /y "%~dp0bin\release\premake4.exe" "%NEWNAME%"
sigcheck -a "%NEWNAME%"
gpg2 -bao "%NEWNAME%.asc" "%NEWNAME%"
popd & endlocal & goto :EOF
goto :EOF

::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
::: / SetVar subroutine
:::   Param1 == name of the variable, Param2 == value to be set for the variable
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:SetVar
:: Get the name of the variable we are working with
setlocal ENABLEEXTENSIONS&set VAR_NAME=%1
endlocal & set %VAR_NAME%=%~2
goto :EOF
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
::: \ SetVar subroutine
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
