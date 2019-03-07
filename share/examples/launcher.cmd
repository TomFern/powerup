@echo Off

:: Open a PWR Session. Keep the window open.

set /p basedir=<LOCALDIR
:: set script=%1

powershell -ExecutionPolicy bypass -NoExit -Command . %basedir%\lib\Powerup;

