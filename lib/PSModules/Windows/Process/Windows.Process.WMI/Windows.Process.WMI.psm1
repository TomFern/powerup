# Start (remote) processes

If(-not($_PWR['ELEVATED'])) {
    Write-Warning "[Windows.Process.WMI] The session should be Elevated to work with this module"
}

Function New-Process
{
    <#
    .SYNOPSIS
        Create a Process descriptor
    .DESCRIPTION
        Creates a process descriptor. To actually start the process use 'Start-Process'
    .PARAMETER Program
        The path to the program binary
    .PARAMETER ArgumentList
        An array with all the arguments (optional). Please split each element into it's own array position.
    .PARAMETER Computer
        The remote computer name to execute the command (optional)
    .LINK
        Start-Process
        Test-Process
    .EXAMPLE
        $p = New-Process -Program "notepad" -ArgumentList @('c:\tmp\foobar.txt')
        Start-Process $p
        Test-Process $p
    #>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)][String]$Program,
        [Array]$ArgumentList=@(),
        [String]$Computer=$null
    )
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'


    $cmd = '"{0}"' -f $Program
    foreach($a in $ArgumentList) {
        $e = $a -replace '"',''
        if($e) {
            $cmd += ' {0}' -f $e
        }
    }

    $pd = @{
        'Program' = $Program;
        'Arguments' = $ArgumentList;
        'ExecString' = $cmd;
        'Computer' = $Computer;
        'ImageName' = $null;
        'PID' = 0;
        'Started' = $False;
        'Exists' = $null;
        'ReturnValue' = $null;
    }

    return $pd
} # end function New-Process

Function Start-Process
{
    <#
    .SYNOPSIS
        Start a Process
    .DESCRIPTION
        Start a local or remote Process
    .PARAMETER Process
        A Process descriptor created with New-Process
    .LINK
        New-Process
        Start-Process
    .EXAMPLE
        $p = New-Process -Program "notepad" -ArgumentList @('c:\tmp\hola.txt')
        Start-Process $p
        Test-Process $p
    #>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)][HashTable] $Process
    )
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    $cmd = $Process['ExecString']
    $computer = $Process['Computer']
    $pf = $null
    if($computer) {
        $pf = Invoke-WMIMethod -Path win32_process -name create -computerName $computer -ArgumentList "$cmd"
    }
    else {
        $pf = Invoke-WMIMethod -Path win32_process -name create -ArgumentList "$cmd"
    }
    if($pf) {
        $Process['PID'] = $pf['ProcessId']
        $Process['ReturnValue'] = $pf['ReturnValue']
        $Process['Started'] = $True
    }

    # $Process = Test-Process $Process

    return $Process
} # end function Start-Process

Function Test-Process
{
    <#
    .SYNOPSIS
        Check if process running
    .DESCRIPTION
        Test and update info on running process
    .PARAMETER Process
        A Process Definition created with New-Process
    .LINK
        New-Process
        Start-Process
    .EXAMPLE
        $p = New-Process -Program "notepad" -ArgumentList @('c:\tmp\hola.txt')
        Start-Process $p
        Test-Process $p
    #>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)][HashTable] $Process
    )
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    if(-not($Process['Started'])) {
        Write-Verbose "[Test-Process] Process must be started with Start-Process. Ignored."
        return $Process
    }

    $computer = $Process['Computer']
    $pi=$null
    if($computer) {
        try {
            $pi = Get-Process -id $Process['PID'] -ComputerName $computer -ErrorAction Stop
        }
        catch [System.Management.Automation.ActionPreferenceStopException] {
            $null
        }
    }
    else {
        try {
            $pi = Get-Process -id $Process['PID'] -ErrorAction Stop
        }
        catch [System.Management.Automation.ActionPreferenceStopException] {
            $null
        }
    }

    if($pi) {
        $Process['Exists'] = $True
        $Process['ImageName'] = $pi.ProcessName
    }
    else {
        $Process['Exists'] = $False
    }

    return $Process
} # end function Test-Process

Function Test-ProcessList
{
    <#
    .SYNOPSIS
        Test a list of processes
    .DESCRIPTION
        A convenience function, calls test-process for each item in list,
        updating the status for each one.
        Each of the process should be first started with Start-Process
    .PARAMETER ProcessList
        An array or hashtable where each value is a process object as returned by New-Process
    .EXAMPLE
        $spawns = @{}
        $spawns['SRV1'] = New-Process ....
        Start-Process $spawns['SRV1']
        $spawns['SRV2'] = New-Process ....
        Start-Process $spawns['SRV2']
        $list = Test-ProcessList $spawns
    #>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)][array] $ProcessList
    )
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    $keys = @()
    if($ProcessList -is [Array]) {
        $keys = (0..($ProcessList.Count-1))
    }
    elseif($ProcessList -is [HashTable]) {
        Foreach($k in $ProcessList.Keys) {
            $keys += $k
        }
    }
    else {
        Throw "[Test-ProcessList] -ProcessList must be Array or HashTable"
    }

    Foreach($pd in $ProcessList) {
        Test-Process $pd
    }

    return $ProcessList
} # end function Test-ProcessList
