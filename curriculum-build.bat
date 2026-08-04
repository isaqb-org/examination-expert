@echo off
rem Build the iSAQB curricula of this repo via the prebuilt builder image. Renders into .\build.
rem   curriculum-build.bat                       all documents x languages x formats
rem   curriculum-build.bat pdf DE                single format + language, all documents
rem   curriculum-build.bat pdf DE REMARKS        + suffix tag
rem   set CURRICULUM_FILE=examination-criteria   build one document only
rem   curriculum-build.bat clean                 remove build\ outputs
rem
rem The builder image renders one AsciiDoc root per run, so this script runs the
rem container once per entry in CURRICULUM_FILES (see build.config).
setlocal enabledelayedexpansion

set "IMAGE=ghcr.io/isaqb-org/curriculum-builder:2026.3-rev3"
set "DIGEST=sha256:47fb269758499d2b0bdaf4690817f4ea2460c1a7ccd5e34da77c86674f0bf691"

set "REF=%IMAGE%"
if defined DIGEST set "REF=%IMAGE%@%DIGEST%"

set "REPO_ROOT=%~dp0"
if "%REPO_ROOT:~-1%"=="\" set "REPO_ROOT=%REPO_ROOT:~0,-1%"

rem build.config is read inside the container from /project; only forward host overrides.
set "ENVOPTS="
rem Values are quoted: LANGUAGES/SUFFIX_TAGS are space-separated lists.
if defined LANGUAGES   set "ENVOPTS=%ENVOPTS% -e "LANGUAGES=%LANGUAGES%""
if defined SUFFIX_TAGS set "ENVOPTS=%ENVOPTS% -e "SUFFIX_TAGS=%SUFFIX_TAGS%""
if defined PREPRESS    set "ENVOPTS=%ENVOPTS% -e "PREPRESS=%PREPRESS%""
if not defined RELEASE_VERSION set "RELEASE_VERSION=LocalBuild"

rem The document list must be known on the host, because each document is a separate
rem container run. An explicit CURRICULUM_FILE wins; otherwise take the list from
rem build.config (the line assigning CURRICULUM_FILES).
set "FILES=%CURRICULUM_FILE%"
if not defined FILES if defined CURRICULUM_FILES set "FILES=%CURRICULUM_FILES%"
if not defined FILES if exist "%REPO_ROOT%\build.config" (
  for /f "tokens=2 delims={}" %%A in ('findstr /c:"CURRICULUM_FILES:=" "%REPO_ROOT%\build.config"') do set "RAW=%%A"
  if defined RAW (
    set "RAW=!RAW:CURRICULUM_FILES:=!"
    set "FILES=!RAW:~1!"
  )
)

docker pull "%REF%" >nul || exit /b 1

rem "clean" needs no curriculum file and must not run once per document.
if "%~1"=="clean" (
  docker run --rm -v "%REPO_ROOT%:/project" -w /project "%REF%" %*
  if errorlevel 1 exit /b 1
  endlocal & exit /b 0
)

rem Empty list: run once so the image emits its own "CURRICULUM_FILE not set" error.
if not defined FILES (
  docker run --rm -v "%REPO_ROOT%:/project" -w /project %ENVOPTS% -e "RELEASE_VERSION=%RELEASE_VERSION%" "%REF%" %*
  exit /b 1
)

for %%F in (!FILES!) do (
  echo === %%F ===
  docker run --rm ^
    -v "%REPO_ROOT%:/project" ^
    -w /project ^
    %ENVOPTS% ^
    -e "CURRICULUM_FILE=%%F" ^
    -e "RELEASE_VERSION=%RELEASE_VERSION%" ^
    "%REF%" %*
  if errorlevel 1 exit /b 1
)

echo Done. Output in %REPO_ROOT%\build\
endlocal
