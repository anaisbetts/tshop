@where fvm >nul 2>&1
@IF ERRORLEVEL 1 (
  @echo fvm is not installed. Install it from https://fvm.app
  @EXIT /B 1
)
@cd /d "%~dp0"
@fvm flutter %*
