@echo Off

:: Open a Powerup session. Close session when script exits

set /p basedir=<LOCALDIR

%SystemRoot%\syswow64\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy bypass -Command . %basedir%\lib\Powerup -NoInteractive; %*

