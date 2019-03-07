# Generate Interfaces file for Sybase ASE

Import-Power 'Table'

Function New-ASEInterfaces
{
    <#
    .SYNOPSIS
        Create a Sybase Interfaces file
    .DESCRIPTION
        Takes a Table as argument (Inventory - IService) and generates the interfaces file required by some client tools.
    .PARAMETER Table
        IService, instance hostname and port are required.
    .PARAMETER Path
        Path to the new file
    .PARAMETER Format
        Format can be 'WINDOWS' (default) or 'UNIX'.
    .PARAMETER NoClobber
        (Switch) When set, don't overwrite existing files
    .EXAMPLE
        New-ASEInterfaces $Service 'sql.ini'
    #>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)][Object]$Table,
        [Parameter(Mandatory=$true)][String]$Path,
        [String]$Format='WINDOWS',
        [Switch]$NoClobber
    )
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    If($NoClobber -and(Test-Path -PathType leaf $Path)) {
        Throw "[New-ASEInterfaces] File already exists: $Path"
    }
    New-Item -Type F $Path -Force | Out-Null
    If(-not(Test-Path -PathType leaf $Path)) {
        Throw "[New-ASEInterfaces] Can't create file: $Path"
    }

    function _write_windows {
        Param($Hostname,$Instance,$Port)
        "" | Out-File -Encoding UTF8 -Append $Path
        ("[{0}]" -f $Instance) | Out-File -encoding UTF8 -width 1000 -append $Path
        ("master=NLWNSCK,{0},{1}" -f $Hostname,$Port) | Out-File -encoding UTF8 -width 1000 -append $Path
        ("query=NLWNSCK,{0},{1}" -f $Hostname,$Port) | Out-File -encoding UTF8 -width 1000 -append $Path
        "" | Out-File -Encoding UTF8 -append $Path
    }
    function _write_unix { #FIXME Newlines
        Param($Hostname,$Instance,$Port)
        "" | Out-File -Encoding UTF8 -Append $Path
        ("$Instance") | Out-File -encoding UTF8 -width 1000 -append $Path
        ("`tmaster tcp ether {0} {1}" -f $Hostname,$Port) | Out-File -encoding UTF8 -width 1000 -append $Path
        ("`tquery tcp ether {0} {1}" -f $Hostname,$Port) | Out-File -encoding UTF8 -width 1000 -append $Path
        "" | Out-File -Encoding UTF8 -append $Path
    }

    Invoke-Table $Table {
        Param($Row,$Data,$Columns,$Num,$Count)
        if($Format -eq 'WINDOWS') {
            _write_windows $Data['Hostname'] $Data['Instancename'] $Data['Port']
        }
        elseif($Format -eq 'UNIX') {
            _write_unix $Data['Hostname'] $Data['Instancename'] $Data['Port']
        }
        else {
            Throw "[New-ASEInterfaces] Format unknown: $Format"
        }
    }
} # end function New-ASEInterfaces
