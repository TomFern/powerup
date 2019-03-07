@echo Off

:: Open a Powerup session. Close session when script exits

set /p basedir=<LOCALDIR

powershell -ExecutionPolicy bypass -Command . %basedir%\lib\Powerup -NoInteractive; %*

