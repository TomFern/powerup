# Dump Module for Sybase ASE

Import-Power 'DBI.ASE'


Function New-Table_Backup_Selection {
<#
.SYNOPSIS
    Table definition for ASE.Dump\Backup-Database
.DESCRIPTION
    Table definition:
        Instancename [String] Instance name
        Database [String] Database Name
        BackupDirectory [String] Path to backup directory/folder
        StripeTotal [Int] Total stripes to use (starting from 1)
        Pattern [String] A pattern for backup file (see Backup-Database)
#>
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'
    $Table = New-Object System.Data.DataTable 'BackupSelection'
    $Table.Columns.Add('Instancename',[String])>$null
    $Table.Columns.Add('Database',[String])>$null
    $Table.Columns.Add('BackupDirectory',[String])>$null
    $Table.Columns.Add('StripeTotal',[Int])>$null
    $Table.Columns.Add('Pattern',[String])>$null
    return ,$Table
} # end function New-Table_Backup_Selection

Function New-Table_Backup_Database {
    <#
    .SYNOPSIS
        Table definition for ASE.Dump\Backup-Database
    .DESCRIPTION
        Table definition:
            Instancename [String] Instance name, this value is informative only
            Database [String] Database Name
            BackupComplete [Bool] True on backup success, false on failure (see ErrorMessage)
            BackupDirectory [String] Path backup directory
            BackupFile [String] Backup file name
            BackupPath [String] Full path to backup file, ie. BackupDirectory+BackupFile
            BackupCompress [Bool] True on backup compress, false when not compressed
            StripeNum [Int] Stripe number, start from 1
            StripeTotal [Int] Total stripes
            StartDate [DateTime] Backup start date
            StopDate [DateTime] Backup start date
            Duration [TimeSpan] Backup duration
            ServerMessage [String] Message returned by server
            ErrorMessage [String] Error message
    .LINK
        Backup-Database
        Backup-DatabaseList
        Restore-Database
        Restore-DatabaseList
        New-Table_Restore_Database
        New-Table_Backup_Database
        DBI.ASE
    #>

    $Table = New-Object System.Data.DataTable 'ASE.Dump\New-Table_Backup_Database'
    [void]$Table.Columns.Add('Instancename',[String])
    [void]$Table.Columns.Add('Database',[String])
    [void]$Table.Columns.Add('BackupComplete',[Bool])
    [void]$Table.Columns.Add('BackupDirectory',[String])
    [void]$Table.Columns.Add('BackupFile',[String])
    [void]$Table.Columns.Add('BackupPath',[String])
    [void]$Table.Columns.Add('BackupCompress',[Bool])
    [void]$Table.Columns.Add('StripeNum',[Int])
    [void]$Table.Columns.Add('StripeTotal',[Int])
    [void]$Table.Columns.Add('StartDate',[DateTime])
    [void]$Table.Columns.Add('StopDate',[DateTime])
    [void]$Table.Columns.Add('Duration',[TimeSpan])
    [void]$Table.Columns.Add('ServerMessage',[String])
    [void]$Table.Columns.Add('ErrorMessage',[String])
    return ,$Table
} # end function <`1`>New-Table_Backup_Database


Function Backup-Database
{
    <#
    .SYNOPSIS
        Perform a Sybase database dump
    .DESCRIPTION
        Executes a Sybase ASE database dump using an opened DBi

        Returns New-Table_Backup_Database. Backup sucess or failure on column BackupComplete

        On backup failure, sends a warning and sets BackupComplete to $false

        Throws an exception when passed an invalid DBi.

        The name of the Backup files can be customized -Pattern. Valid tokens:
            %s  Instance Name
            %d  Database name
            %i  Stripe File Number (from 1 to %t)
            %t  Total Stripe number (counting from 1)
            %U  Current time in format YearMonthDay-HourMinuteSecond

        Default pattern: %s_%d_%iof$t.dmp

        If you are using stripes, then at least %i should be used to duplicate file names.

    .PARAMETER DBi
        A valid DBI.ASE
    .PARAMETER Database
        [String] A single database name
    .PARAMETER Directory
        [String] Backup directory to use
    .PARAMETER Stripes
        [Int] Number of stripes to use, defaults to 1
    .PARAMETER Instancename
        [String] Instance, not mandatory, defaults to empty string.
    .PARAMTER Timeout
        [Int] Restore timeout in MINUTES. Defaults to 60.
    .PARAMETER Pattern
        [String] Pattern for backup file name.
    .PARAMETER NoCompress
        [Switch] Don't use dump compression
    .LINK
        Backup-Database
        Backup-DatabaseList
        Restore-Database
        Restore-DatabaseList
        New-Table_Restore_Database
        New-Table_Backup_Database
        DBI.ASE
    .EXAMPLE
        $DBi = New-DBi "dsn=FOO;db=master;na=HOSTNAME,PORT;uid=sa;pwd=BAR;" "Adaptive Server Enterprise"
        Open-DBI $DBi

        # Backup master with 2 stripes to C:\Sybase\Dumps
        $dt = Backup-Database $DBi master "C:\Sybase\Dumps" 2

        # Backup master with an unique name, don't compress backup, use only 1 stripe
        $dt = Backup-Database $DBi master "C:\Sybase\Dumps" -Unique -NoCompress

        # Check if backup failed
        If(($dt|where { $_.BackupComplete -eq $false }|measure-object).count -gt 0) {
            Write-Error "A backup has failed, booo!"
        }

        Close-DBI $DBi
    #>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)][HashTable]$DBi,
        [Parameter(Mandatory=$true)][String]$Database,
        [Parameter(Mandatory=$true)][String]$Directory,
        [ValidateRange(1,99)][Int]$Stripes=1,
        [String]$Instancename="",
        [Int]$Timeout=60,
        [String]$Pattern="%s_%d_%iof%t.dmp",
        # [Switch]$Unique,
        [Switch]$NoCompress
    )
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    # If($DBi['Driver'] -ne 'Adaptive Server Enterprise') {
    #     Throw "[Backup-Database] DBi driver seems incorrect, should be 'Adaptive Server Enterprise'"
    # }

    Try {
        DBI.ASE\Open-DBi $DBi > $null
    }
    Catch {
        Write-Warning ("[Backup-Database] Open-DBI error: {0}" -f $_.Exception.Message)
    }

    $StartDate = [DateTime](Get-Date)
    $StartDateStr = (Get-Date -uformat "%Y%m%d-%H%M%S"|Out-String).Trim()

    If($NoCompress) {
        $compress = $false
        $prefix = ''
    }
    else {
        $compress = $true
        $prefix= 'compress::'
    }

    $TableBackupFile = ASE.Dump\New-Table_Backup_Database

    function _dumpfile {
        Param([int]$i)

        $fn = $Pattern
        $fn = $fn -creplace '%s',$Instancename
        $fn = $fn -creplace '%d',$Database
        $fn = $fn -creplace '%i',$i
        $fn = $fn -creplace '%t',$Stripes
        $fn = $fn -creplace '%U',$StartDateStr

        # $Servername = ''
        # If($Instancename) {
        #     $Servername = ("{0}_" -f $Instancename)
        # }

        # If($Unique) {
        #     $fn = "{0}{1}_{2}_{3}of{4}.dmp" -f $Servername,$Database,$StartDateStr,$i,$Stripes
        # }
        # else {
        #     $fn = "{0}{1}_{2}of{3}.dmp" -f $Servername,$Database,$i,$Stripes
        # }

        $filestripe = ("{0}{1}/{2}" -f $prefix,$Directory,$fn)
        $fullfile = ("{0}/{1}" -f $Directory,$fn)

        $row = $TableBackupFile.NewRow()
        $row.Instancename = $Instancename
        $row.Database = $Database
        $row.StartDate = $StartDate
        $row.BackupDirectory = $Directory
        $row.BackupFile = $fn
        $row.BackupPath = $fullfile
        $row.BackupCompress = $compress
        $row.StripeNum = $i
        $row.StripeTotal = $Stripes
        $TableBackupFile.Rows.Add($row) | Out-Null

        return $filestripe
    }

    $nl = [Environment]::Newline
    $sql = "use master$nl"
    $sql = ("dump database {0} to '{1}'$nl" -f $Database,(_dumpfile 1))
    $i=2
    For($i=2;$i -le $Stripes;$i++) {
        $sql += ("stripe on '{0}'$nl" -f (_dumpfile $i))
    }

    $ServerMessage = ""
    $ErrorMessage = ""
    $BackupComplete = $true
    $result = New-Object System.Data.DataSet
    $TimeoutSeconds = [Int]($Timeout*60)
    Try {
        $result = DBI.ASE\Invoke-DBI -DBI $DBi -Query $sql -Timeout $TimeoutSeconds
    }
    Catch {
        Write-Warning ("[Backup-Database] Dump database {0} failed with error: {1}" -f  $Database,$_.Exception.Message)
        $BackupComplete = $false
        $ErrorMessage = $_.Exception.Message
    }
    If($BackupComplete -and(($result|measure-object).count -gt 0) -and($result.tables[0]|measure-object).Count -gt 0) {
        Write-Warning ("[Backup-Database] Dump database {0} failed. Message from server is: {1}" -f  $Database,($result.Tables[0]|Format-List|Out-String).Trim())
        $ServerMessage = ($result.tables[0] | Out-String).Trim()
        Write-Warning ("[Backup-Database] Server message for {0} is: {1}" -f  $Database,($result.Tables[0]|Format-List|Out-String).Trim())
    }

    # Compute StopDate and Duration
    $StopDate = [DateTime](Get-Date)
    $TableBackupFile | Foreach {
        $_['StopDate']= $StopDate
        $_['Duration'] = (New-TimeSpan -Start $StartDate -End $StopDate)
        $_['BackupComplete'] = $BackupComplete
        $_['ServerMessage'] = $ServerMessage
        $_['ErrorMessage'] = $ErrorMessage
    }

    return ,$TableBackupFile
} # end function Backup-Database



Function New-Table_Restore_Database {
    <#
    .SYNOPSIS
        Table definition for ASE.Dump\Restore-Database
    .DESCRIPTION
        Table definition:
            Instancename [String] Instance, this value is informative only
            Database [String] Database name
            RestoreComplete [Bool] True on restore success, false on failure (see ErrorMessage)
            StartDate [DateTime] Backup start date
            StopDate [DateTime] Backup start date
            Duration [TimeSpan] Backup duration
            ServerMessage [String] Message returned by server
            ErrorMessage [String] Error message
    .LINK
        Backup-Database
        Backup-DatabaseList
        Restore-Database
        Restore-DatabaseList
        New-Table_Restore_Database
        New-Table_Backup_Database
        DBI.ASE
    #>

    $Table = New-Object System.Data.DataTable 'ASE.Dump\New-Table_Restore_Database'
    [void]$Table.Columns.Add('Instancename',[String])
    [void]$Table.Columns.Add('Database',[String])
    [void]$Table.Columns.Add('RestoreComplete',[Bool])
    [void]$Table.Columns.Add('StartDate',[DateTime])
    [void]$Table.Columns.Add('StopDate',[DateTime])
    [void]$Table.Columns.Add('Duration',[TimeSpan])
    [void]$Table.Columns.Add('ServerMessage',[String])
    [void]$Table.Columns.Add('ErrorMessage',[String])
    return ,$Table
} # end function New-Table_Restore_Database


Function Restore-Database
{
    <#
    .SYNOPSIS
        Perform a Sybase database load
    .DESCRIPTION
        Executes a Sybase ASE database load using a DBi

        Returns a New-Table_Restore_Database

        On restore failure, sends a warning and sets RestoreComplete to $false

        Throws an exception when passed an invalid DBi.

        WARNING: Restore-Database will try to kill all connections to the target database before trying to do the load.

    .PARAMETER DBi
        A valid DBI.ASE
    .PARAMETER Database
        [String] Database name
    .PARAMETER FileList
        [String[]] Dump files, stripes files
    .PARAMETER Instancename
        [String] Instance name, not mandatory, defaults to empty string.
    .PARAMTER Timeout
        [Int] Restore timeout in MINUTES. Defaults to 60.
    .PARAMETER Compress
        [Switch] True when compression was used on the dump
    .PARAMETER Offline
        [Switch] Leave the database offline
    .LINK
        Backup-Database
        Backup-DatabaseList
        Restore-Database
        Restore-DatabaseList
        New-Table_Restore_Database
        New-Table_Backup_Database
        DBI.ASE
    .EXAMPLE
        $DBi = New-DBi "dsn=FOO;db=master;na=HOSTNAME,PORT;uid=sa;pwd=BAR;" "Adaptive Server Enterprise"
        Open-DBI $DBi

        $result = Restore-Database $DBi "pubs2" "C:\Sybase\Dump\pubs2_1.bak","C:\Sybase\Dump\pubs2_2.bak" -Instancename 'FOO'
        Close-DBI $DBi
    #>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)][HashTable]$DBi,
        [Parameter(Mandatory=$true)][String]$Database,
        [Parameter(Mandatory=$true)][String[]]$FileList,
        [String]$Instancename="",
        [Int]$Timeout=60,
        [Switch]$Compress,
        [Switch]$Offline
    )
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    # If($DBi['Driver'] -ne 'Adaptive Server Enterprise') {
    #     Throw "[Restore-Database] DBi driver seems incorrect, should be 'Adaptive Server Enterprise'"
    # }

    Try {
        DBI.ASE\Open-DBi $DBi > $null
    }
    Catch {
        Write-Warning ("[Restore-Database] Open-DBI error: {0}" -f $_.Exception.Message)
    }

    $StartDate = [DateTime](Get-Date)
    $StartDateStr = (Get-Date -uformat "%Y%m%d-%H%M%S"|Out-String).Trim()

    $prefix = ''
    If($Compress) { $prefix = 'compress::' }
    $StripePath = @()
    $FileList | Foreach {
        $StripePath += ("{0}{1}" -f $prefix,$_)
    }

    $nl = [Environment]::Newline

    $sql = "use master$nl"
    $sql += ('select spid from master..sysprocesses where dbid = db_id("{0}")' -f $Database)

    $LockSet = New-Object System.Data.DataSet
    $TimeoutSeconds = [Int]($Timeout*60)
    Try {
        $Lockset = DBI.ASE\Invoke-DBI -DBI $DBi -Query $sql -Timeout $TimeoutSeconds
    }
    Catch {
        Write-Warning ("[Restore-Database] Error checking sysprocesses: {0}. Error was: {1}" -f $database,$_.Exception.Message)
    }

    $sql = "use master$nl"
    $LockSet.Tables[0] | Foreach {
        $sql += ("kill {0}$nl" -f $_.spid)
    }

    $sql += ("load database {0} from '{1}'$nl" -f $Database,$StripePath[0])
    for($i=1;$i -lt $StripePath.Count; $i++) {
        $sql += ("stripe on '{0}'" -f $StripePath[$i])
    }

    $ServerMessage = ""
    $ErrorMessage = ""
    $RestoreComplete = $true
    $result = New-Object System.Data.DataSet
    $TimeoutSeconds = [Int]($Timeout*60)
    Try {
        $result = DBI.ASE\Invoke-DBI -DBI $DBi -Query $sql -Timeout $TimeoutSeconds
    }
    Catch {
        Write-Warning ("[Restore-Database] Load database {0} failed with error: {1}" -f  $Database,$_.Exception.Message)
        $RestoreComplete = $false
        $ErrorMessage = $_.Exception.Message
    }

    If($RestoreComplete -and(($result|measure-object).count -gt 0) -and($result.tables[0]|measure-object).Count -gt 0) {
        Write-Warning ("[Restore-Database] Load database {0} failed. Message from server is: {1}" -f  $Database,($result.Tables[0]|Format-List|Out-String).Trim())
        $ServerMessage = ($result.tables[0] | Out-String).Trim()
        Write-Warning ("[Restore-Database] Server message for {0} is: {1}" -f  $Database,($result.Tables[0]|Format-List|Out-String).Trim())


    }

    If($RestoreComplete -and(-not($Offline))) {
        $sql = "use master$nl"
        $sql += ("online database {0}" -f $Database)
        $result = New-Object System.Data.DataSet
        $TimeoutSeconds = [Int]($Timeout*60)
        Try {
            $result = DBI.ASE\Invoke-DBI -DBI $DBi -Query $sql -Timeout $TimeoutSeconds
        }
        Catch {
            Write-Warning ("[Restore-Database] Can't online database {0} failed with error: {1}" -f  $Database,$_.Exception.Message)
            $RestoreComplete = $false
            $ErrorMessage = $_.Exception.Message
        }
    }

    $StopDate = [DateTime](Get-Date)
    $ReturnTable = (New-Table_Restore_Database)
    $row = $ReturnTable.NewRow()
    $row.Instancename = $Instancename
    $row.Database = $Database
    $row.StartDate = $StartDate
    $row.StopDate = $StopDate
    $row.Duration = [TimeSpan](New-TimeSpan -Start $StartDate -End $StopDate)
    $row.RestoreComplete = $RestoreComplete
    $row.ServerMessage = $ServerMessage
    $row.ErrorMessage = $ErrorMessage
    $ReturnTable.Rows.Add($row)

    return ,$ReturnTable
} # end function Restore-Database


Function Restore-DatabaseList {
<#
    .SYNOPSIS
        Execute Restore-Database on multiple databases
    .DESCRIPTION
        Takes a New-Table_Backup_Database table as an argument and runs Restore-Database on each database
    .PARAMETER DBi
        A valid DBi object
    .PARAMETER Table
        A table of type New-Table_Backup_Database
    .PARAMETER Offline
        [Switch] Leave Database offline
    .LINK
        Backup-Database
        Backup-DatabaseList
        Restore-Database
        Restore-DatabaseList
        New-Table_Restore_Database
        New-Table_Backup_Database
        DBI.ASE
    .EXAMPLE
        $DBi = New-DBi "dsn=FOO;db=master;na=HOSTNAME,PORT;uid=sa;pwd=BAR;" "Adaptive Server Enterprise"
        Open-DBI $DBi

        # Backup master with 2 stripes to C:\Sybase\Dumps
        $dt = Backup-Database $DBi master "C:\Sybase\Dumps" 2

        # Restore
        $dt2 = Restore-DatabaseList -DBI $DBi -Table $dt

#>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)][HashTable]$DBi,
        [Parameter(Mandatory=$true)][Object]$Table,
        [Switch]$Offline
    )
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    $DBList = @()
    $Table|Select-Object -Property Database -Unique|Foreach {
        $DBlist += $_.Database
    }

    $return = New-Object System.Data.DataTable 'Restore-DatabaseList'

    Foreach($Database in $DBList) {
        $compress = $true
        $filelist = @()
        $Table.Select(("Database = '{0}'" -f $Database)) | Foreach {
            $filelist += $_.BackupPath
            $compress = $_.BackupCompress
            $Instancename = $_.Instancename
        }

        $result = ASE.Dump\Restore-Database -DBI $DBi -Database $Database -FileList $filelist -Compress:$compress -Instancename $Instancename -Offline:$Offline
        If(($result|Measure-Object).Count -gt 0) {
            $return.Merge($result)
        }
    }
    return ,$return
} # end function Restore-DatabaseList


Function Backup-DatabaseList {
<#
    .SYNOPSIS
        Execute Backup-Database on multiple databases
    .DESCRIPTION
        Takes a New-Table_Backup_Database table as an argument and runs Backup-Database on each database
    .PARAMETER DBi
        A valid DBi object
    .PARAMETER Table
        A table of type New-Table_Backup_Database
    .LINK

    .EXAMPLE
        $DBi = New-DBi "dsn=FOO;db=master;na=HOSTNAME,PORT;uid=sa;pwd=BAR;" "Adaptive Server Enterprise"
        Open-DBI $DBi

        # Backup master with 2 stripes to C:\Sybase\Dumps
        $dt = Backup-Database $DBi master "C:\Sybase\Dumps" 2

#>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)][HashTable]$DBi,
        [Object]$Table
    )
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    $DBList = @()
    $Table|Select-Object -Property Database -Unique|Foreach {
        $DBlist += $_.Database
    }

    $return = New-Object System.Data.DataTable 'Backup-DatabaseList'

    Foreach($Database in $DBList) {
        $Directory = ""
        $Stripes = 0
        $NoCompress = $false
        $Table.Select(("Database = '{0}'" -f $Database)) | Foreach {
            $Stripes = $_.StripeTotal
            $Directory = $_.BackupDirectory
            $NoCompress = -not($_.BackupCompress)
            $Instancename = $_.Instancename
        }

        $result = ASE.Dump\Backup-Database -DBI $DBi -Database $Database -Directory $Directory -Stripes $Stripes -NoCompress:$nocompress -Instancename $Instancename
        If(($result|Measure-Object).Count -gt 0) {
            $return.Merge($result)
        }
    }
    return ,$return
} # end function Backup-DatabaseList
