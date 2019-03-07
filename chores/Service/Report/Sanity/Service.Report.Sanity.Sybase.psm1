# Sanity Report, Per Server, For ASE Instances with Bar Graph

New-Variable -Scope Script 'DBSet'
New-Variable -Scope Script 'SystemSet'
New-Variable -Scope Script 'ServiceSet'
New-Variable -Scope Script 'Info'
New-Variable -Scope Script 'Config'

Import-Power 'Templates'
Import-Power 'Charts.Bar'
Import-Power 'Temp'
Import-Power 'Email'


################################################
#
# Inputs
#
################################################

function StepPre {
    Param([HashTable]$usr,[HashTable]$id)
    $Script:ServiceSet = $usr['Service.ASE']
    $Script:RSSet = $usr['Service.RepServer']
    # $Script:SystemSet = $usr['System.Windows']
    $Script:DBSet = $usr['Database.ASE']
    $Script:Config = $id['config']


    # $Script:ServiceSet.Tables['SanityDisk'].Rows[0]>$null
    $Script:ServiceSet.Tables['SanityService'].Rows[0]>$null
    $Script:RSSet.Tables['SanityService'].Rows[0]>$null
    Assert-Table { New-Table_IService } $Script:ServiceSet.Tables['IService']

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
    return @{
    }
}


################################################
#
# Process
#
################################################

function StepProcess {

    $SaveHtml = Join-Path  $GLOBAL:_PWR['STORAGEDIR'] 'Sybase_Sanity.html'
    $SaveGraph = Join-Path  $GLOBAL:_PWR['STORAGEDIR'] 'Sybase_Sanity.png'

    $SanityAll = New-Object System.Data.DataTable 'Sanity'

    # if(($Script:SystemSet|Get-Table) -contains 'SanityDisk') {
    #     $SanityDisk = $Script:ServiceSet.Tables['SanityDisk'].Copy()
    #     $SanityDisk.Columns.Add('_Source',[String])
    #     $SanityDisk | Foreach { $_._Source = 'Disk' }
    #     $SanityAll.Merge($SanityDisk)
    # }

    if(($Script:ServiceSet|Get-Table) -contains 'SanityService') {
        $SanityService = $Script:ServiceSet.Tables['SanityService'].Copy()
        $SanityService.Columns.Add('_Source',[String])
        $SanityService | Foreach { $_._Source = 'Service' }
        $SanityAll.Merge($SanityService)
    }
    if(($Script:RSSet|Get-Table) -contains 'SanityService') {
        $SanityRS = $Script:RSSet.Tables['SanityService'].Copy()
        $SanityRS.Columns.Add('_Source',[String])
        $SanityRS | Foreach { $_._Source = 'RepServer' }
        $SanityAll.Merge($SanityRS)
    }

    # if(($Script:ServiceSet|Get-Table) -contains 'SanityCluster') {
    #     $SanityService = $Script:ServiceSet.Tables['SanityCluster'].Copy()
    #     $SanityService.Columns.Add('_Source',[String])
    #     $SanityService | Foreach { $_._Source = 'Cluster' }
    #     $SanityAll.Merge($SanityService)
    # }

    if(($Script:DBSet|Get-Table) -contains 'SanityDatabase') {
        $SanityDatabase = $Script:DBSet.Tables['SanityDatabase'].Copy()
        $SanityDatabase.Columns.Add('_Source',[String])
        $SanityDatabase | Foreach { $_._Source = 'Database' }
        $SanityAll.Merge($SanityDatabase)
    }

    $Summary = GetSummary $SanityAll
    $Counter = GetCounter $Summary

    $GraphFn = New-TempFile -Extension '.png'
    GetChart $SanityAll $GraphFn

    # Remove DB that are OK
    $SanityFinal = $SanityAll.Clone()
    $SanityAll | Foreach {
        If(!(($_['_Source'] -eq 'Database') -and($_['_Attention'] -eq $false))) {
            $SanityFinal.ImportRow($_)
        }
    }

    If(-not($Script:Info.ContainsKey('Title'))) {
        $Script:Info['Title'] = "Sybase Sanity Check"
    }

    $UserData = @{
        'ReportInfo' = $Script:Info;
        'Counters' = $Counter;
        'Data' = $SanityFinal;
        # 'DataMissing' = $Missing;
        'Summary' = $Summary;
    }

    $Params = @{
        'Title' = $Script:Info['Title'];
        'GraphUrl' = 'CID:GraphBar';
        }

    $ContentEmailHtml = Templates\Invoke-Template 'GenericSanityHTML' -UserData $UserData -TemplateParameters $Params
    $ContentEmailText = Templates\Invoke-Template 'GenericSanityTable' -UserData $UserData -TemplateParameters $Params

    $Params = @{
        'Title' = $Script:Info['Title'];
        'GraphUrl' = $SaveGraph;
        }

    $ContentSaveHtml = Invoke-Template 'GenericSanityHTML' -UserData $UserData -TemplateParameters $Params

    # Email report to Recipients
    if(-not($Script:Config['SendOnlyOnIssue']) -or(($Counter|Measure -Sum 'Total Issues').Sum -gt 0)) {
        If($Script:Info['Recipients']) {
            $Message = New-Email -Subject $Script:Info['Title'] -To ($Script:Info['Recipients'] -split ',')
            $BodyText = New-Body ($ContentEmailText|Out-String).Trim() "text/plain"
            Add-Body $Message $BodyText | Out-Null

            $BodyHtml = New-Body ($ContentEmailHtml|Out-String).Trim()  "text/html"
            $Graph = New-EmbeddedImage $GraphFn 'image/png' 'GraphBar'
            Add-EmbeddedImage $BodyHtml $Graph
            Add-Body $Message $BodyHtml

            Try {
                Send-Email $Message
            }
            Catch {
                Write-Warning ("Error sending email: {0}" -f $_.Exception.Message)
            }
            Finally {
                $Graph.Dispose()
                $BodyText.Dispose()
                $BodyHtml.Dispose()
                $Message.Dispose()
            }
        }
    }
    else {
        Write-Warning "No issues found, report was not sent"
    }

    # Save Report
    $ContentSaveHtml | Out-File $SaveHtml
    Copy-Item $GraphFn $SaveGraph
    # Copy-Item $BackupCsvFn $SaveBackupCSV
}


# Summary Table
function GetSummary {
    Param($Sanity)

    $Summary = New-Object System.Data.DataTable 'Summary'
    [void]$Summary.Columns.Add('_GID',[String])
    [void]$Summary.Columns.Add('_AttentionCount',[String])
    [void]$Summary.Columns.Add('_SummaryMessage',[String])
    [void]$Summary.Columns.Add('_Role',[String])
    [void]$Summary.Columns.Add('InstanceCount',[Int])
    $Summary.Columns['InstanceCount'].Caption = 'Instances'
    [void]$Summary.Columns.Add('DBCount',[Int])
    $Summary.Columns['DBCount'].Caption = 'DBs'
    [void]$Summary.Columns.Add('FaultMessage',[String])

    $Script:ServiceSet.Tables['IHost'] | Foreach {
        $GID = [String]$_.Hostname
        $Role = [String]$_.Role

        $row = $Summary.NewRow()

        $InstanceCount = [Int](($Script:ServiceSet.Tables['IService'].Select("Hostname = '$GID'")|Measure-Object).Count)
        $DBCount = [Int](($Script:DBSet.Tables['Get-Database'].Select("Hostname = '$GID'")|Measure-Object).Count)


        $row._GID = $GID
        $row._Role = $Role
        $row.InstanceCount = $InstanceCount
        $row.DBCount = $DBCount
        $row._SummaryMessage = ("{0} instances {1} DBs" -f $InstanceCount,$DBCount)

        $Issues = [Int](($Sanity.Select("_GID = '$GID' and _Attention = $true")|Measure-Object).Count)
        $row._AttentionCount = $Issues
        If($Issues -gt 0) {
            $row.FaultMessage = ("{0} issues found" -f $Issues)
        }
        else {
            $row.FaultMessage = 'OK'
        }
        $Summary.Rows.Add($row)>$null
    }
    return ,$Summary
}


# Counter: Total issues per Role
function GetCounter {
    Param($Summary)

    $Counter = New-Object System.Data.DataTable 'Counter'
    [void]$Counter.Columns.Add('_Ord',[Int])
    $Counter.Columns['_Ord'].Autoincrement = $true
    [void]$Counter.Columns.Add('Role',[String])
    [void]$Counter.Columns.Add('Total Servers',[Int])
    [void]$Counter.Columns.Add('Servers with Issues',[Int])
    [void]$Counter.Columns.Add('Total Issues',[Int])

    $AllRoles = @()
    $Summary |Select -Property _Role -Unique | Foreach { $AllRoles += $_._Role }

    $AllRoles | Foreach {
        $Role = $_

        $row = $Counter.NewRow()
        $row.Role = $Role

        $row['Total Servers'] = (($Summary.Select("_Role = '$Role'")|Measure-Object).Count)
        $row['Servers with Issues'] = (($Summary.Select("_Role = '$Role' and _AttentionCount > 0")|Measure-Object).Count)
        $row['Total Issues'] = (($Summary.Select("_Role = '$Role'")|Measure-Object -Sum _AttentionCount).Sum)
        $Counter.Rows.Add($row)>$null
    }
    return ,$Counter
}


# Bar Chart: Series=Role, Axis=Source
function GetChart {
    Param($Sanity,$GraphFn)

    $Chart = New-Chart -Title 'Issues' -ShowLegend -Width 300 -Height 300

    $AllRoles = @()
    $Sanity |Select -Property _Role -Unique | Foreach { $AllRoles += $_._Role }

    $AllSources = @()
    $Sanity |Select -Property _Source -Unique | Foreach { $AllSources += $_._Source }

    $ExistingSeries = @()
    $AllRoles | Foreach {
        $Role = $_
        $AllSources | Foreach {
            $Source = $_
            $TotalIssues = (($Sanity.Select("_Role = '$Role' and _Source = '$Source'")|Measure-Object -Sum _Attention).Sum)
            If(-not($ExistingSeries -contains $Role)) {
                $ExistingSeries += $Role
                $Chart | Add-ChartSeries -SeriesName $Role
            }
            $Chart | Add-ChartDataPoint -Value $TotalIssues -SeriesName $Role -Label $Source
        }
    }

    $Chart | Out-ImageFile -Path $GraphFn -Format 'png' -Force
}

