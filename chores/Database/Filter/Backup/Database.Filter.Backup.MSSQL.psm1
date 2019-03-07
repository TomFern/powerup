# Filter for MSSQL Backup Data

Set-StrictMode -version Latest

New-Variable -Scope Script 'Config'
New-Variable -Scope Script 'Date'
New-Variable -Scope Script 'DBSet'
New-Variable -Scope Script 'Exception'

Import-Power 'Table'


################################################
#
# Inputs
#
################################################

function StepPre {
    Param([HashTable]$usr,[HashTable]$id)

    $Script:Date = [DateTime](Get-Date)
    If($id.ContainsKey('StartDateTime')) {
        $Script:Date = $id['StartDateTime']
    }

    $Script:Config = $id['Config']['mssql']
    New-TimeSpan -Minutes $Script:Config['backup']['maxage']['full'] >$null
    New-TimeSpan -Minutes $Script:Config['backup']['maxage']['diff'] >$null
    New-TimeSpan -Minutes $Script:Config['backup']['maxage']['log'] >$null
    $Script:Config['backup']['ignoredb']

    $Script:DBSet = $usr['Database.MSSQL']
    $Script:DBSet.Tables['Get-Database'].Rows[0]['Database'] >$null
    $Script:DBSet.Tables['Get-Database'].Rows[0]['Servicename'] >$null
    $Script:DBSet.Tables['Get-Database'].Rows[0]['BackupFullDurationSec'] >$null
    $Script:DBSet.Tables['Get-Database'].Rows[0]['BackupFullSizeMB'] >$null
    $Script:DBSet.Tables['Get-Database'].Rows[0]['BackupFullStopDate'] >$null
    $Script:DBSet.Tables['Get-Database'].Rows[0]['BackupLogStopDate'] >$null
    $Script:DBSet.Tables['Get-Database'].Rows[0]['BackupDiffStopDate'] >$null

    $Script:IService = $Script:DBSet.Tables['IService']
    $Script:IService.Rows[0]['Role'] >$null
    $Script:IService.Rows[0]['Servicename'] >$null

    $Script:Exception = New-Object System.Data.DataTable 'BackupException'
    [void]$Script:Exception.Columns.Add('Hostname',[String])
    [void]$Script:Exception.Columns.Add('Servicename',[String])
    [void]$Script:Exception.Columns.Add('DatabaseRegex',[String])
    [void]$Script:Exception.Columns.Add('Ignore',[Bool])
    [void]$Script:Exception.Columns.Add('MaxAgeFull',[Int])
    [void]$Script:Exception.Columns.Add('MaxAgeDiff',[Int])
    [void]$Script:Exception.Columns.Add('MaxAgeLog',[Int])
    If(($Script:DBSet.Tables['BackupException']|Measure-Object).Count -gt 0) {
        $Script:Exception = $Script:DBSet.Tables['BackupException']
    }
}


################################################
#
# Outputs
#
################################################

function StepNext {

    $Script:DBSet.Tables['Backup'].Rows[0] >$null

    return @{
        'Database.MSSQL' = $Script:DBSet;
    }
}


################################################
#
# Process
#
################################################

function StepProcess {




    # Backup status for every instance, every db
    $Backup = New-Object System.Data.DataTable 'Backup'
    [void]$Backup.Columns.Add('_GID',[String])
    [void]$Backup.Columns.Add('_Attention',[Bool])
    [void]$Backup.Columns.Add('_Role',[String])
    [void]$Backup.Columns.Add('Database',[String])
    [void]$Backup.Columns.Add('BackupMessage',[String])
    [void]$Backup.Columns.Add('BackupDate',[DateTime])
    [void]$Backup.Columns.Add('__SizeMB',[Int])
    $Backup.Columns['__SizeMB'].Caption = 'MB'
    [void]$Backup.Columns.Add('__Duration',[TimeSpan])

    # Convert Date to age
    function Date2Age {
        Param($dateconv)
        if(-not($dateconv) -or([DBNull]::Value.Equals($dateconv))) {
            return $AgeForNulls
        }
        else {
            return (New-TimeSpan -Start $dateconv -End $Script:date)
        }
    }

    # Convert Timespan into String
    function Age2String {
        Param($Age)
        if($Age.Days -gt (365*10)) {
            return "never"
        }
        elseif($Age.Days -gt 0) {
            return ("{0} days ago" -f $Age.Days)
        }
        elseif($Age.Hours -gt 0) {
            return ("{0} hours ago" -f $Age.hours)
        }
        elseif($Age.Minutes -gt 0) {
            return ("{0} minutes ago" -f $Age.minutes)
        }
        else {
            return "ERROR"
        }
    }


    # Process a new row, update all output tables in one go
    function Tabulate {
        Param([String]$Servicename,[String]$Database,$BackupSizeMB,$BackupDate,$DurationSeconds,[String]$Message,[Bool]$Attention)

        # Get Role
        $Role = '_UNKNOWN_'
        $inv = $Script:IService.Select(("Servicename = '{0}'" -f $Servicename))
        if(($inv|measure-object).count -gt 0) {
            $Role = [String]($inv[0].Role)
        }

        If([DBNull]::Value.Equals($Database)) {
            $Database = '_UNKNOWN_'
        }
        If([DBNull]::Value.Equals($DurationSeconds)) {
            $DurationSeconds = 0
        }
        If([DBNull]::Value.Equals($BackupSizeMB)) {
            $BackupSizeMB = 0
        }

        $row = $Backup.NewRow()
        $row['_GID'] = [String]$Servicename
        $row['_Role'] = [String]$Role
        $row['_Attention'] = [Bool]$Attention
        $row['Database'] = [String]$Database
        $row['BackupMessage'] = [String]$Message
        $row['BackupDate'] = $BackupDate
        $row['__Duration'] = (New-TimeSpan -Seconds ([int]$DurationSeconds))
        $row['__SizeMB'] = [int]$BackupSizeMB
        $Backup.Rows.Add($row)
    }


    # Main Process
    Invoke-Table $Script:DBSet.Tables['Get-Database'] {
        Param($RowObj,$Data,$Columns,$RowNum,$RowCount)

         # Set this age when backup date is NULL (unix epoch)
        $DateForNulls = [DateTime](Get-Date '1970-01-01')
        $AgeForNulls = (New-TimeSpan -Start $DateForNulls -End $Script:date)
        $IgnoreDatabaseList = @()

        Try {
            $MaxFull = New-TimeSpan -Minutes $Script:Config['backup']['maxage']['full']
            $Maxdiff = New-TimeSpan -Minutes $Script:Config['backup']['maxage']['diff']
            $MaxLog = New-TimeSpan -Minutes $Script:Config['backup']['maxage']['log']
            $IgnoreDatabaseList = $Script:Config['backup']['ignoredb']
        }
        Catch {
            Throw "Parameters missing in config: backups->maxage->{full,diff,log}"
        }

        # Get backup end date as a TimeSpan since epoch
        $AgeFull = Date2Age $Data['BackupFullStopDate']
        $AgeDiff = Date2Age $Data['BackupDiffStopDate']
        $AgeLog = Date2Age $Data['BackupLogStopDate']

        # default thresholds
        $MaxFull = New-TimeSpan -Minutes $Script:Config['backup']['maxage']['full']
        $Maxdiff = New-TimeSpan -Minutes $Script:Config['backup']['maxage']['diff']
        $MaxLog = New-TimeSpan -Minutes $Script:Config['backup']['maxage']['log']

        # Backup State
        $Message = ''
        $Success = $null

        # Check in the exception table for a match
        $ExceptionForInstance = $Exception.Select("Servicename = '{0}'" -f $Data['Servicename'])
        If(($ExceptionForInstance|Measure).Count -gt 0) {
            Foreach($row in $ExceptionForInstance) {
                if($Data['Database'] -match $row['DatabaseRegex']) {
                    if(@(1,'true','yes') -contains $row['Ignore']) {
                        $IgnoreDatabaseList += $Data['Database']
                        break
                    }
                    else {
                    $MaxFull = New-TimeSpan -Minutes $row['MaxAgeFull']
                    $MaxDiff = New-TimeSpan -Minutes $row['MaxAgeDiff']
                    $MaxLog = New-TimeSpan -Minutes $row['MaxAgeLog']
                    break
                    }
                }
            }
        }



        # Check Ignore List
        If($IgnoreDatabaseList -contains $Data.Database) {
            $BackupDate = $Data['BackupFullStopDate']
            $BackupDurationSec = $Data['BackupFullDurationSec']
            $BackupSizeMB = $Data['BackupFullSizeMB']
            Tabulate $Data['Servicename'] $Data['Database'] $BackupSizeMB $BackupDate $BackupDurationSec ("{0} is ignored" -f $Data['Database']) $false
        }
                # Check offline
        elseif($Data.IsDbUp -eq 0) {
            Tabulate $Data['Servicename'] $Data['Database'] 0 $DateForNulls 0 ("{0} is offline" -f $Data['Database']) $false
        }
        # Check for Age
        else {
            $Attention = $false
            $Message = 'OK'

            $BackupDate = $Data['BackupFullStopDate']
            $BackupDurationSec = $Data['BackupFullDurationSec']
            $BackupSizeMB = $Data['BackupFullSizeMB']

            # Diff not NULL and FULL is TOO OLD
            if(($AgeDiff -ne $AgeForNulls) -and($AgeDiff -gt $MaxDiff) -and($AgeFull -eq $AgeForNulls -or($AgeFull -gt $MaxFull))) {
                $AgeString = Age2String $AgeDiff
                $BackupDate = $Data['BackupDiffStopDate']
                $BackupDurationSec = $Data['BackupDiffDurationSec']
                $BackupSizeMB = $Data['BackupDiffSizeMB']
                $Message = ('Diff was {0}' -f $AgeString)
                $Attention = $true
            }
            # FULL is TOO OLD
            elseif(($AgeFull -eq $AgeForNulls) -or($AgeFull -gt $MaxFull)) {
                $AgeString = Age2String $AgeFull
                $BackupDate = $Data['BackupFullStopDate']
                $BackupDurationSec = $Data['BackupFullDurationSec']
                $BackupSizeMB = $Data['BackupFullSizeMB']
                $Message = ('Full was {0}' -f $AgeString)
                $Attention = $true
            }
            # LOG is TOO OLD
            elseif(($Data['DbRecoveryModel'] -eq 'FULL') -and($AgeLog -gt $MaxLog)) {
                $AgeString = Age2String $AgeLog
                $BackupDate = $Data['BackupLogStopDate']
                $BackupDurationSec = $Data['BackupLogDurationSec']
                $BackupSizeMB = $Data['BackupLogSizeMB']
                $Message = ('Log was {0}' -f $AgeString)
                $Attention = $true
            }

            Tabulate $Data['Servicename'] $Data['Database'] $BackupSizeMB $BackupDate $BackupDurationSec $Message $Attention
        }
    } # main loop ended

    $Script:DBSet.Tables.Add($Backup)
}

