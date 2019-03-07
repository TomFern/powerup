# Report for MSSQL Backups. HTML Report and Email.

Set-StrictMode -version Latest

Import-Power 'Templates'
Import-Power 'Charts.Pie'
Import-Power 'Email'
Import-Power 'Inventory'

New-Variable -Scope Script 'DBSet'
New-Variable -Scope Script 'Info'


################################################
#
# Inputs
#
################################################

function StepPre {
    Param([HashTable]$usr,[HashTable]$id)

    $Script:DBSet = $usr['Database.MSSQL']

    $Script:DBSet.Tables['Get-Database'].Rows[0] >$null
    $Script:DBSet.Tables['ProbeRecord'].Rows[0] >$null
    $Script:DBSet.Tables['Backup'].Rows[0] >$null

    Assert-Table { New-Table_IService } $Script:DBSet.Tables['IService']

    $Script:Info = @{}
    $Script:Info['Date'] = $Id['StartDateTime']
    $Script:Info['Host'] = $GLOBAL:_PWR['CURRENT_HOSTNAME']
    $Script:Info['Version'] = $GLOBAL:_PWR['VERSION']
    $Script:Info['Chore'] = $Id['ChoreName']

    If($Usr.ContainsKey('Title')) {
        $Script:Info['Title'] = $Usr['Title']
    }

    If($Usr.ContainsKey('Recipients')) {
        $Script:Info['Recipients'] = $Usr['Recipients']
    }

    If($GLOBAL:_PWR['TIMEZONE_INITIALS']) {
        $Script:Info['Timezone'] = $GLOBAL:_PWR['TIMEZONE_INITIALS'];
    }
}


################################################
#
# Outputs
#
################################################

function StepNext {
    return @{}
}


################################################
#
# Process
#
################################################

function StepProcess {

    $templatedir = $GLOBAL:_PWR['TEMPLATEDIR']
    $tmpdir = $GLOBAL:_PWR['TMPDIR']

    $SaveHtml = Join-Path $GLOBAL:_PWR['STORAGEDIR'] "BackupSQL.html"
    $SaveGraph = Join-Path $GLOBAL:_PWR['STORAGEDIR'] "BackupSQL.png"
    $SaveBackupCSV = Join-Path $GLOBAL:_PWR['STORAGEDIR'] "BackupSQL.csv"

    $Summary = ComputeSummary $Script:DBSet.Tables['Backup']
    $Counter = ComputeCounters $Summary

    $PieFn = New-TempFile -Extension '.png'
    ComputeGraph $Summary $Counter $PieFn

    # FIXME: strange bug, we end up with mixed row + datatable object
    $Missing = ComputeMissing $Script:DBSet.Tables['ProbeRecord']

    $BackupCsvFn = New-TempFile -Extension '.csv'
    ComputeBackupCsv $Script:DBSet.Tables['Get-Database'] $Script:DBSet.Tables['IService'] $BackupCsvFn

    # Template

    If(-not($Script:Info.ContainsKey('Title'))) {
        $Script:Info['Title'] = "SQL Backup Report"
    }

    $UserData = @{
        'ReportInfo' = $Script:Info;
        'Counters' = $Counter;
        'Data' = $Script:DBSet.Tables['Backup'];
        # 'DataMissing' = $Missing;
        'Summary' = $Summary;
    }

    $Params = @{
        'Title' = $Script:Info['Title'];
        'GraphUrl' = 'CID:GraphPie';
        }

    $ContentEmailHtml = Invoke-Template 'GenericSanityHTML' -UserData $UserData -TemplateParameters $Params
    $ContentEmailText = Invoke-Template 'GenericSanityTable' -UserData $UserData -TemplateParameters $Params

    $Params = @{
        'Title' = $Script:Info['Title'];
        'GraphUrl' = $SaveGraph;
        }

    $ContentSaveHtml = Invoke-Template 'GenericSanityHTML' -UserData $UserData -TemplateParameters $Params

    # Email
    If($Script:Info['Recipients']) {
        $Message = New-Email -Subject $Script:Info['Title'] -To ($Script:Info['Recipients'] -split ',')
        $BodyText = New-Body ($ContentEmailText|Out-String).Trim() "text/plain"
        Add-Body $Message $BodyText | Out-Null

        $BodyHtml = New-Body ($ContentEmailHtml|Out-String).Trim()  "text/html"
        $Graph = New-EmbeddedImage $piefn 'image/png' 'GraphPie'
        Add-EmbeddedImage $BodyHtml $Graph
        Add-Body $Message $BodyHtml

        # If((Get-Content $BackupCsvFn | Measure-Object).count -gt 0) {
        #     $AttachCSV = New-Attachment $BackupCsvFn 'text/plain'
        #     Add-Attachment $Message $AttachCSV
        # }

        Try {
            Send-Email $Message
        }
        Catch {
            Write-Warning ("Error sending email: {0}" -f $_.Exception.Message)
        }
        Finally {
            # if(test-path variable:AttachCSV) { $AttachCSV.Dispose() }
            $Graph.Dispose()
            $BodyText.Dispose()
            $BodyHtml.Dispose()
            $Message.Dispose()
        }
    }

    # Save Report
    $ContentSaveHtml | Out-File $SaveHtml
    Copy-Item $piefn $SaveGraph
    Copy-Item $BackupCsvFn $SaveBackupCSV
}


# Generate Summary table
function ComputeSummary {
    Param($BackupTable)
    $Backup = $BackupTable.Copy()

    $Summary = New-Object System.Data.DataTable
    [void]$Summary.Columns.Add('_GID',[String])
    [void]$Summary.Columns.Add('_Role',[String])
    [void]$Summary.Columns.Add('_AttentionCount',[Int])
    [void]$Summary.Columns.Add('_SummaryMessage',[String])
    [void]$Summary.Columns.Add('DatabaseCount',[Int])
    $Summary.Columns['DatabaseCount'].Caption = 'DB'
    [void]$Summary.Columns.Add('TotalBackupDuration',[String])
    [void]$Summary.Columns.Add('TotalBackupSizeGB',[Float])
    $Summary.Columns['TotalBackupSizeGB'].Caption = 'GB'
    [void]$Summary.Columns.Add('BackupMessage',[String])

    # Add all possible rows on Summary
    $Backup | Select-Object -Property '_GID' -Unique | Foreach {
        $Summary.Rows.Add($_._GID) > $null
    }

    # Compute columns
    Foreach($row in $Summary) {
        $select = ("_GID = '{0}'" -f $row['_GID'])

        $row['_Role'] = ($Backup.Select($Select))[0]['_Role']

        $row['DatabaseCount'] = (($Backup.Select($select)|Measure-Object).Count)
        $row['TotalBackupSizeGB'] = [Math]::Round(((($Backup.Select($select)|Measure-Object '__SizeMB' -Sum).Sum) / 1024),2)

        $ts = New-Timespan -Seconds 0
        $Backup.Select($select) | Foreach { $ts += $_['__Duration'] }
        $row['TotalBackupDuration'] = ("{0}h {1}m {2}s" -f [String]($ts.days*24+$ts.Hours),[String]$ts.Minutes,[String]$ts.Seconds)

        $ac = (($Backup.Select($select)|Measure-Object '_Attention' -Sum).Sum)
        $row['_AttentionCount'] = $ac
        If($ac -gt 0) {
            $row['BackupMessage']= "$ac backup missing"
        }
        else {
            $row['BackupMessage'] = 'OK'
        }

        $row['_SummaryMessage'] = ("{0} DB - {1} GB - {2}" -f [String]$row['DatabaseCount'],[String]$row['TotalBackupSizeGB'],$row['TotalBackupDuration'])
    }

    return ,$Summary
}


# Generate Counters per Role table
function ComputeCounters {
    Param($SummaryTable)

    $Summary = $SummaryTable.Copy()

    $Counter = New-Object System.Data.DataTable
    [void]$Counter.Columns.Add('_Ord',[Int])
    $Counter.Columns['_Ord'].Autoincrement = $true
    [void]$Counter.Columns.Add('Role',[String])
    [void]$Counter.Columns.Add('Total',[Int])
    [void]$Counter.Columns.Add('Completed',[Int])
    [void]$Counter.Columns.Add('Failed',[Int])
    [void]$Counter.Columns.Add('Success',[Float])
    $Counter.Columns['Success'].Caption = '%'

    $Summary | Select-Object -Property '_Role' -Unique | Foreach {
        $row = $Counter.NewRow()
        $row['Role'] = $_._Role
        $Counter.Rows.Add($row) > $null
    }

    Foreach($row in $Counter) {
        $select = ("_Role = '{0}'" -f $row['Role'])
        $row['Total'] = ($Summary.Select($select)|Measure-Object 'DatabaseCount' -Sum).Sum
        $row['Failed'] = (($Summary.Select($select)|Measure-Object '_AttentionCount' -sum).Sum)
        $row['Completed'] = $row['Total'] - $row['Failed']
        $row['Success'] = [Math]::Round(($row['Completed']*100/$row['Total']),1)
    }

    # Add Totals Row
    $row = $Counter.NewRow()
    $row['Role'] = 'TOTAL'
    $row['Total'] = (($Counter|Measure-Object 'Total' -Sum).Sum)
    $row['Failed'] = (($Counter|Measure-Object 'Failed' -Sum).Sum)
    $row['Completed'] = (($Counter|Measure-Object 'Completed' -Sum).Sum)
    $row['Success'] = [Math]::Round(($row['Completed']*100/$row['Total']),1)
    $Counter.Rows.Add($row) > $null

    return ,$Counter
}


# Generate and Export a Pie Graph File PNG
function ComputeGraph {
    Param($Summary,$Counter,$PathFn)

    $Chart = New-Chart -Width 300 -Height 300

    $TotalDB = ($Summary | Measure-Object 'DatabaseCount' -Sum).Sum
    $EveryRole = ($Summary | Select-Object -Property '_Role' -Unique)
    $EveryRole = @()
    $Summary | Select-Object -Property '_Role' -Unique | Foreach { $EveryRole += $_._Role }

    Foreach($Role in $EveryRole) {
        $select = ("Role = '{0}'" -f $Role)
        $CounterForRole = ($Counter.Select($select))[0]

        $CompletedForRole = $CounterForRole['Completed']
        $FailedForRole = $CounterForRole.Failed
        $TotalForRole = $CounterForRole.Total

        $FailRateForRole = [Math]::Round(($FailedForRole*100/$TotalForRole)*($TotalForRole/$TotalDB))
        $CompletedRateForRole = [Math]::Round(($CompletedForRole*100/$TotalForRole)*($TotalForRole/$TotalDB))

        If($FailRateForRole -gt 0) {
            $Chart | Add-ChartDataPoint -Label ("Fail "+$Role) -Value $FailRateForRole -Explode | Out-Null
        }
        If($CompletedRateForRole -gt 0) {
            $Chart | Add-ChartDataPoint -Label ("Complete "+$Role) -Value $CompletedRateForRole | Out-Null
        }
    }

    $Chart | Out-ImageFile -Path $PathFn -Format "PNG" -Force
}


# These are Probe Failed Instances
function ComputeMissing {
    Param($ProbeRecord)

    $Miss = New-Object System.Data.DataTable 'MissingGID'
    [void]$Miss.Columns.Add('_GID',[String])
    [void]$Miss.Columns.Add('ErrorMessage',[String])

    $MissingRows = $ProbeRecord.Select("HasData = $false and Memo = 'Get-Database'")
    Foreach($Row in $MissingRows) {
        $Miss.Rows.Add($Row.Id,$Row.ErrorMessage)
    }

    return ,$Miss
}


# A csv file with all the backup dates
function ComputeBackupCsv {
    Param($Uptime,$IService,$Fn)

    $CSV = New-Object System.Data.DataTable
    [void]$CSV.Columns.Add('Instance',[String])
    [void]$CSV.Columns.Add('Role',[String])
    [void]$CSV.Columns.Add('Database',[String])
    [void]$CSV.Columns.Add('Recovery',[String])
    [void]$CSV.Columns.Add('BackupFull',[String])
    [void]$CSV.Columns.Add('BackupDiff',[String])
    [void]$CSV.Columns.Add('BackupLog',[String])

    $Uptime | Foreach {
        $row = $CSV.NewRow()
        $row.Instance = $_.Servicename
        $row.Database = $_.Database
        $row.Recovery = $_.DbRecoveryModel
        $row.BackupFull = $_.BackupFullStopDate
        $row.BackupDiff = $_.BackupDiffStopDate
        $row.BackupLog = $_.BackupLogStopDate

        $row.Role = '_UNKNOWN_'
        $fetch = $IService.Select(("Servicename = '{0}'" -f $_.Servicename))
        If(($fetch|Measure-Object).Count -gt 0) {
            $row.Role = $fetch[0].Role
        }
        $CSV.Rows.Add($row)
    }

    $CSV | Export-CSV -NoTypeInformation $Fn
}
