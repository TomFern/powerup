# Execute Database Sybase ASE LOADs. Run Paralell / Background Mode per Instance

Set-StrictMode -version Latest

New-Variable -Scope Script 'IService'
New-Variable -Scope Script 'DBSet'
New-Variable -Scope Script 'Config'

Import-Power 'DBI.ASE'
Import-Power 'ASE.Dump'
Import-Power 'Table'


################################################
#
# Inputs
#
################################################

function StepPre {
    Param([HashTable]$usr,[hashtable]$id)

    $Script:DBSet = $usr['Database.ASE']
    $Script:IService = $Script:DBSet.Tables['IService']
    $Script:Config = $id['config']

    # ASE.Dump\New-Table_Backup_Database
    $Script:DBSet.Tables['RestoreSelection'].Rows[0] >$null
}


################################################
#
# Outputs
#
################################################

function StepNext {
    return @{

        # Instancename,ASE.Dump\New-Table-Restore-Database
        'Database.ASE' = $Script:DBSet;
    }
}


################################################
#
# Process
#
################################################


# Connect to Instance, load all its databases
# function runjob {
$Job_ASEloadTable = {
    Param($JobArgs)
    $Powerup = $JobArgs[0]
    $Service = $JobArgs[1]
    $Thisloads = $JobArgs[2]
    $ThisHistory = $JobArgs[3]

    $MaxTries = 1
    $SleepOnFailure = 60
    # minutes
    $Timeout = 240

    $Hostname = $Service['Hostname']
    $Instance = $Service['Instancename']
    $Port = $Service['Port']
    $Username = $Service['Username']
    $Password = $Service['Password']

    . $Powerup -NoInteractive > $null

    Import-Power 'DBI.ASE'
    Import-Power 'ASE.Dump'

    # Try to open a connection to server
    $DBi = DBI.ASE\New-DBI "dsn=$Instance;db=master;na=$Hostname,$Port;uid=$Username;pwd=$Password"
    try {
        DBI.ASE\Open-DBI $dbi
    }
    catch {
        # Write-Warning ("[Execute.ASE.load] Connection to failed for: {0}. Error was: {1}" -f $instance,$_.Exception.Message)
        return
    }

    # Execute load if connected
    If((DBI.ASE\Test-DBI $dbi) -ne 'OPEN') {
        return
    }

    $ThisDB = $ThisLoads.Copy()
    $ThisDB.Columns.Remove('BackupFile')
    $ThisDB.Columns.Remove('BackupPath')
    $ThisDB.Columns.Remove('StripeNum')
    $ThisDB = $ThisDB.DefaultView.ToTable($true)


    $ThisDB | Foreach {
        $Database = [String]$_.Database
        $Directory = [String]$_.BackupDirectory
        $Compress = [Bool]$_.BackupCompress
        $Retry = $MaxTries
        $FileList = @()
        $Thisloads.Select(("Database = '{0}'" -f $Database)) | Foreach {
            $FileList += [String]$_.BackupPath
        }

        While($Retry -gt 0) {
            $LoadHistory = New-Object System.Data.DataTable
            Try {
                $LoadHistory = ASE.Dump\Restore-Database -DBi $dbi -Database $Database -Instancename $Instance -Compress:$Compress -FileList $FileList -Timeout $Timeout
            }
            Catch {
                # Write-Warning ("[Execute.ASE.load] Got exception with Restore-Database for {0}. Error was: {1}" -f $Instance,$_.Exception.Message)
                Sleep $SleepOnFailure
            }

            If(($LoadHistory|Measure-Object).Count -gt 0) {
                $ThisHistory.Merge($LoadHistory)
                If($LoadHistory.Rows[0].RestoreComplete) {
                    $Retry = 0
                }
                else {
                    Sleep $SleepOnFailure
                }
            }
            $Retry -= 1
        }
        DBI.ASE\Close-DBI $DBi | Out-Null

        # write-host ($ThisHistory|Format-Table|Out-String)
    }
}

function StepProcess {

    # Background process for each Sybase ASE Instance
    $AsyncQueue = @()
    $UniqueInstance = ($Script:DBSet.Tables['RestoreSelection'] | Select-Object -Property Instancename -Unique)
    $UniqueInstance | Foreach {
        $ThisInstancename = $_.Instancename

        Write-Host ("Unique instance: {0}" -f $ThisInstancename)

        # Get connection parameters for this instance
        $Server = $Script:IService.Select(("instancename = '{0}'" -f $ThisInstancename))
        If(($Server|Measure-Object).Count -eq 0) {
            Write-Warning ("[Execute.Database.Restore.ASE] No inventory entry found for instance: {0}" -f $ThisInstancename)
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
        $Thisloads = $Script:DBSet.Tables['RestoreSelection'].Clone()
        $Script:DBSet.Tables['RestoreSelection'].Select(("Instancename = '{0}'" -f $ThisInstancename)) | Foreach {
            $Thisloads.ImportRow($_)
        }

        # Pass an empty table to the background process, it should return with data
        $ThisHistory = New-Object System.Data.DataTable
        $JobArguments=@($_PWR['POWERUP_FILE'],$Service,$Thisloads,$ThisHistory)

        # Invoke background process
        $Powershell = [PowerShell]::Create()
        $Powershell.AddScript($Job_ASEloadTable).AddArgument($JobArguments) >$null
        $ThisJob = $Powershell.BeginInvoke()

        # Save process invocation for tracking
        $AsyncHandle = @{
            'powershell'=$Powershell;
            'jobhandle'=$Thisjob;
            'arguments'=$JobArguments;
        }
        $AsyncQueue += $AsyncHandle
    }

    Write-Host "Waiting for all instances"

    # Wait for all background processes to complete
    $pt = ($AsyncQueue|Measure-Object).Count
    $pi = 0
    $AsyncQueue | Foreach {
        Write-Progress -Id 10 -Activity "Execute database loads" -Status "Wait" -PercentComplete ($pi*100/$pt)
        $done = $_.jobhandle.AsyncWaitHandle.WaitOne()
        $pi+=1
    }
    Write-Progress -Activity "Execute database loads" -Status "Complete" -Complete

    Write-Host "All instances completed the load"

    # Merge all into a result table
    $Script:DBSet.Tables.Add((New-Object System.Data.DataTable 'RestoreHistory'))
    $AsyncQueue | Foreach {
        $powershell = $_.powershell
        $jobhandle = $_.jobhandle
        $arguments = $_.arguments
        $powershell.EndInvoke($jobhandle)

        $ThisHistory = $arguments[3]
        If(($ThisHistory|Measure-Object).Count -gt 0) {
            $Script:DBSet.Tables['RestoreHistory'].Merge($ThisHistory)
        }
    }
}
