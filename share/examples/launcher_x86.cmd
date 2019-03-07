@echo Off

:: Open a PWR Session. Keep the window open.

set /p basedir=<LOCALDIR
:: set script=%1

%SystemRoot%\syswow64\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy bypass -NoExit -Command . %basedir%\lib\Powerup;

