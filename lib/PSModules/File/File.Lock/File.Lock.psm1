# Lock file for Windows

Function Lock-File {
<#
    .SYNOPSIS
        Try to lock a file
    .DESCRIPTION
        Tries to aquire an exclusive lock on a file.
        Returns a hashtable with a handle

    .PARAMETER Name
        File Name
    .PARAMETER Directory
        (Optional) directory to work, defaults to TMPDIR
    .PARAMETER Timeout
        (Optional) Timeout in seconds, if < 0 wait forever, defaults to -1
    .LINK
        Lock-File
        Unlock-File
    .EXAMPLE
        $l = Lock-File -name 'Foo'
#>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)][String]$Name,
        [String]$Directory=$GLOBAL:_PWR['TMPDIR'],
        [Int]$Timeout=-1
    )

    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'


    $ds= $GLOBAL:_PWR.DIRECTORY_SEPARATOR
    $path = ("{0}{1}{2}" -f $Directory,$ds,$Name)
    $handle = @{
        'ok' = $False;
        'locked' = $False;
        'error' = '';
        'name' = $Name;
        'directory' = $Directory;
        'path' = $Path;
        'fd' = $null;
        'timeout' = $Timeout
    }

    if(-not(Test-Path -PathType leaf $path)) {
        New-Item -f -type f $Path >$null
    }

    function _try_lock {
        Param($Path)

        $fd = $null
        $ok = $false
        Try {
            $fd = [System.IO.File]::Open($Path, "Open", "Read", "None")
            $ok = $True
        }
        Catch {
        }
        return $ok,$fd
    }

    $timer = $Timeout
    while($timer -ne 0) {
        $ok, $fd = _try_lock $path
        if($ok) {
            $handle['ok'] = $True
            $handle['locked'] = $True
            $handle['fd'] = $fd
            $timer = 0
        }
        else {
            if($timer -gt 0) {
                $timer -= 1
                sleep 1
            }
        }
    }
    return $handle
}


Function Unlock-File {
<#
    .SYNOPSIS
        Unlock file locked with Lock-File
    .DESCRIPTION
        Tries to release a lock acquired with Lock-File
    .PARAMETER Handle
        Handle created with Lock-File
    .PARAMETER Remove
        [Switch] Delete file after unlock
    .LINK
        <`8`>
    .EXAMPLE
        <`9`>
#>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)][HashTable]$Handle,
        [Switch]$Remove
    )
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    If(-not($handle['locked'])) {
        Throw ("[Unzip-File] Handle reports file was not locked")
    }

    $handle['fd'].close()
    if($Remove) {
        Remove-Item -Force $handle['path']
    }
    $handle['locked'] = $False
    return $Handle
} # end function Unlock-File

# vim: ft=ps1
