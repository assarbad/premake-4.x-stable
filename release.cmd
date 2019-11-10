@echo off
@if not "%OS%"=="Windows_NT" @(echo This script requires Windows NT 4.0 or later to run properly! & goto :EOF)
setlocal ENABLEEXTENSIONS & pushd .
call "%~dp0setvcvars.cmd" 8.0
if NOT defined VCVER_FRIENDLY echo Unfortunately setvcvars.cmd didn't do its job. Fix the problem and run this script again.&goto :EOF
set HGTIPFILE="%~dp0src\host\hgtip.h"
for /f %%i in ('hg id -i -r tip') do @call :SetVar HG_TIP_ID "%%i"
for /f %%i in ('hg id -n -r tip') do @call :SetVar HG_TIP_REVNO "%%i"
echo #define HG_TIP_ID "%HG_TIP_ID%" > %HGTIPFILE%
echo #define HG_TIP_REVNO "%HG_TIP_REVNO%" >> %HGTIPFILE%
if exist %HGTIPFILE% type %HGTIPFILE%
vcbuild /rebuild /time Premake4.vs8.sln "Publish|Win32"
"%~dp0bin\release\premake4.exe" embed
call :BuildSignCopyOne "%~dp0" "premake4" "bin\release" "%HG_TIP_REVNO%" "%HG_TIP_ID%" Premake4.vs8.sln Publish Win32
popd & endlocal & goto :EOF
goto :EOF

::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
::: / SignAndCopyOne subroutine
:::   Copies a 
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:BuildSignCopyOne
setlocal ENABLEEXTENSIONS
set BASEPATH=%~1
set BASENAME=%~2
set BINDIR=%~3
set HG_TIP_REVNO=%~4
set HG_TIP_ID=%~5
set SLNFILE=%~6
set SLNCFGNAME=%~7
set SLNCFGPLTF=%~8
vcbuild /rebuild /time "%SLNFILE%" "%SLNCFGNAME%|%SLNCFGPLTF%"
set NEWNAME=%BASEPATH%%BASENAME%.rev-%HG_TIP_REVNO%-%HG_TIP_ID%.exe
copy /y "%BASEPATH%%BINDIR%\%BASENAME%.exe" "%NEWNAME%"
sigcheck -a "%NEWNAME%"
gpg --batch --yes -u 0xC779D8290E88590F -bao "%NEWNAME%.asc" "%NEWNAME%"
copy /y "%BASEPATH%%BINDIR%\%BASENAME%.exe" "%BASEPATH%%BASENAME%.exe"
endlocal
goto :EOF
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
::: \ SignAndCopyOne subroutine
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

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
