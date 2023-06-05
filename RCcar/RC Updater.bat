@echo off

REM Set the variables
set "repository=https://github.com/lua-gods/RC-Car-Reborn.git"
set "cloned_folder=RC-Car-Reborn"
set "source_folder=RCcar"
set "destination=%~dp0"

REM Clone the repository
git clone %repository% "%TEMP%\%cloned_folder%"

REM Move all files from the source folder to the destination
for /R "%TEMP%\%cloned_folder%\%source_folder%" %%F in (*) do (
    if /I "%%~nxF"=="RCmain.lua" (
        move /Y "%%F" "%destination%"
    ) else (
        if not exist "%destination%%%~nxF" (
            move "%%F" "%destination%"
        )
    )
)

REM Clean up cloned folder
rd /s /q "%TEMP%\%cloned_folder%"
