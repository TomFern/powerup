# Execute Database Sybase AS Dumps. Run Paralell / Background Mode per Instance

Set-StrictMode -version Latest

New-Variable -Scope Script 'IService'
New-Variable -Scope Script 'DBSet'
New-Variable -Scope Script 'Config'

# Import-Power 'DBI.ODBC'
Import-Power 'DBI.ASE'
Import-Power 'ASE.Dump'
Import-Power 'Table'


################################################
#
# Inputs
#
################################################

function StepPre {
    Param([HashTable]$usr,[HashTable]$id)

    $Script:DBSet = $usr['Database.ASE']
    $Script:IService = $Script:DBSet.Tables['IService']

    $Script:Config = $id['config']

    # FIXME column missing Pattern
    # Assert-Table { ASE.Dump\New-Table_Backup_Selection } $Script:DBSet.Tables['BackupSelection']
}


################################################
#
# Outputs
#
################################################

function StepNext {
    return @{

        # Instancename,ASE.DUMP\New-Table-Backup-Database
        'Database.ASE' = $Script:DBSet;
    }
}


################################################
#
# Process
#
################################################


# Connect to Instance, Dump all its databases
# function runjob {
$Job_ASEDumpTable = {
    Param($JobArgs)
    $Powerup = $JobArgs[0]
    $Service = $JobArgs[1]
    $ThisDumps = $JobArgs[2]
    $ThisHistory = $JobArgs[3]

    $MaxTries = 2
    $SleepOnFailure = 120
    # Mins
    $Timeout = 240

    $Hostname = $Service['Hostname']
    $Instance = $Service['Instancename']
    $Port = $Service['Port']
    $Username = $Service['Username']
    $Password = $Service['Password']

    . $Powerup -NoInteractive > $null

    Import-Power 'DBI.ASE'
    Import-Power 'ASE.DUMP'

    # Try to open a connection to server
    $DBi = DBI.ASE\New-DBI "dsn=$Instance;db=master;na=$Hostname,$Port;uid=$Username;pwd=$Password"
    try {
        DBI.ASE\Open-DBI $dbi
    }
    catch {
        # Write-Warning ("[Execute.ASE.Dump] Connection to failed for: {0}. Error was: {1}" -f $instance,$_.Exception.Message)
        return
    }

    # Execute Dump if connected
    If((DBI.ASE\Test-DBI $dbi) -ne 'OPEN') {
        return
    }


    $ThisDumps | Foreach {
        $Database = [String]$_.Database
        $Stripes = [Int]$_.StripeTotal
        $Directory = [String]$_.BackupDirectory
        $Pattern = [String]$_.Pattern
        $Retry = $MaxTries

        While($Retry -gt 0) {
            $DumpFile = New-Object System.Data.DataTable
            Try {
                $DumpFile = ASE.Dump\Backup-Database -DBi $dbi -Database $Database -Stripes $Stripes -Directory $Directory -Instancename $Instance -Pattern $Pattern -Timeout $Timeout
            }
            Catch {
                # Write-Warning ("[Execute.ASE.Dump] Got exception with Backup-Database for {0}. Error was: {1}" -f $Instance,$_.Exception.Message)
                Sleep $SleepOnFailure
            }

            If(($DumpFile|Measure-Object).Count -gt 0) {
                $ThisHistory.Merge($DumpFile)
                If($DumpFile.Rows[0].BackupComplete) {
                    $Retry = 0
                }
                else {
                    Sleep $SleepOnFailure
                }
            }
            $Retry -= 1
        }
        DBI.ASE\Close-DBI $DBi >$null

        # write-host ($ThisHistory|Format-Table|Out-String)
    }
}

function StepProcess {

    # Background process for each Sybase ASE Instance
    $AsyncQueue = @()
    $UniqueInstance = ($Script:DBSet.Tables['BackupSelection'] | Select-Object -Property Instancename -Unique)
    $UniqueInstance | Foreach {
        $ThisInstancename = $_.Instancename

        # Write-Host ("Unique instance: {0}" -f $ThisInstancename)

        # Get connection parameters for this instance
        $Server = $Script:IService.Select(("instancename = '{0}'" -f $ThisInstancename))
        If(($Server|Measure-Object).Count -eq 0) {
            Write-Warning ("[Execute.ASE.Dump] No inventory entry found for instance: {0}" -f $ThisInstancename)
            continue
        }

        $Instancename = $ThisInstancename
        $Hostname = $Server[0].Hostname
        $Port  = $Server[0].Port

        # Get password from config
        $cfg = $Script:Config['sybase']['login']
        $Username = ''
        $Password = ''
        if($cfg.containskey($Hostname) -and($cfg[$Hostname].containskey($Instancename))) {
            $username = $cfg[$Hostname][$Instancename]['username']
            $password = $cfg[$Hostname][$Instancename]['password']
        }
        else {
            $username = $cfg['_DEFAULT']['username']
            $password = $cfg['_DEFAULT']['password']
        }


        # Save connection parameters
        $Service = @{
            'Instancename' = $Instancename;
            'Hostname' = $Hostname;
            'Port' = $Port;
            'Username' = $Username;
            'Password' = $Password;
        }

        # Select only the databases on this instance
        $ThisDumps = $Script:DBSet.Tables['BackupSelection'].Clone()
        $Script:DBSet.Tables['BackupSelection'].Select(("Instancename = '{0}'" -f $ThisInstancename)) | Foreach {
            $ThisDumps.ImportRow($_)
        }

        # Pass an empty table to the background process, it should return with data
        $ThisHistory = New-Object System.Data.DataTable
        $JobArguments=@($_PWR['POWERUP_FILE'],$Service,$ThisDumps,$ThisHistory)

        # Invoke background process
        $Powershell = [PowerShell]::Create()
        $Powershell.AddScript($Job_ASEDumpTable).AddArgument($JobArguments) >$null
        $ThisJob = $Powershell.BeginInvoke()

        # Save process invocation for tracking
        $AsyncHandle = @{
            'powershell'=$Powershell;
            'jobhandle'=$Thisjob;
            'arguments'=$JobArguments;
        }
        $AsyncQueue += $AsyncHandle
    }

    # Write-Host "Waiting for all instances"

    # Wait for all background processes to complete
    $pt = ($AsyncQueue|Measure-Object).Count
    $pi = 0
    $AsyncQueue | Foreach {
        Write-Progress -Id 10 -Activity "Execute database dumps" -Status "Wait" -PercentComplete ($pi*100/$pt)
        $done = $_.jobhandle.AsyncWaitHandle.WaitOne()
        $pi+=1
    }
    Write-Progress -Activity "Execute database dumps" -Status "Complete" -Complete

    # Write-Host "All instances completed the dump"

    # Merge all into a result table
    $Script:DBSet.Tables.Add((New-Object System.Data.DataTable 'BackupHistory'))
    $AsyncQueue | Foreach {
        $powershell = $_.powershell
        $jobhandle = $_.jobhandle
        $arguments = $_.arguments
        $powershell.EndInvoke($jobhandle)

        $ThisHistory = $arguments[3]
        If(($ThisHistory|Measure-Object).Count -gt 0) {
            $Script:DBSet.Tables['BackupHistory'].Merge($ThisHistory)
        }
    }
}
