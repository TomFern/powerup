# Get installed SQL Products and patches from registry, check if cache files exist


Set-StrictMode -version Latest

New-Variable -Scope Script 'IHost'
New-Variable -Scope Script 'SystemSet'

Import-Power 'Table'
Import-Power 'Path'
Import-Power 'Windows.Installer'
Import-Power 'Probe'


################################################
#
# Inputs
#
################################################

function StepPre {
    Param([HashTable]$usr,[HashTable]$Id)

    $Script:SystemSet = $usr['System.Windows']
    $Script:IHost = $Script:SystemSet.Tables['IHost']
    $Script:Id = $id

}


################################################
#
# Outputs
#
################################################

function StepNext {

    $Script:SystemSet.Tables['Get-Install']>$null
    $Script:SystemSet.Tables['Get-Install__CacheFileExists']>$null
    Assert-Table { New-Table_ProbeRecord } $Script:SystemSet.Tables['ProbeRecord']

    return @{
        'System.Windows' = $Script:SystemSet;
    }
}


################################################
#
# Process
#
################################################

function StepProcess {

    $System = New-Object System.Data.DataSet 'System.Windows'
    $ProbeRecord = New-Table_ProbeRecord
    $System.Tables.Add($ProbeRecord)
    $System.Tables.Add((New-Object System.Data.DataTable 'Get-Install'))

    $RowCount = ($Script:IHost|Measure-Object).Count
    $RowNum = 0
    Foreach($RowData in $Script:IHost) {

        $RowNum += 1
        $Computer = $RowData['Hostname']

        Write-Progress -Activity "Installed Packages" -Status "Read Registry" -CurrentOperation $Computer -PercentComplete ($RowNum*100/$RowCount)


        $Probe = New-Probe -Memo 'Get-Install' -Record $ProbeRecord
        Invoke-Probe -Probe $Probe -Id $Computer -ScriptBlock { Windows.Installer\Get-Install -Computer $Computer -FilterProduct 'SQL' }
        If($Probe.HasData) {
            $System.Tables['Get-Install'].Merge($Probe.Result)
        }
    }

    Write-Progress -Activity "Installed Packages" -Status "Complete" -Completed

    $GetCache = $System.Tables['Get-Install'].Copy()
    $GetCache.TableName = 'Get-Install__CacheFileExists'
    [void]$GetCache.Columns.Add('CacheFileExists',[Bool])
    $System.Tables.Add($GetCache)

    # Check Windows Installer cache files
    $RowCount = ($GetCache|Measure-Object).Count
    $RowNum = 0
    Foreach($RowData in $GetCache.Rows) {
        $RowNum += 1
        $testfn = ConvertTo-RemotePath -Path $RowData['CacheFilePath'] -Computer $RowData['Hostname']

        Write-Progress -Activity "Installer Cache" -Status "Test File" -CurrentOperation $testfn -PercentComplete ($RowNum*100/$RowCount)

        If(Test-Path -PathType Leaf $testfn) {
            $RowData.CacheFileExists = $true
        }
        else {
            $RowData.CacheFileExists = $false
        }
    }

    # Write-Host ($GetCache|Format-Table|Out-String)
    Write-Progress -Activity "Installer Cache" -Status "Complete" -Completed
    $Script:SystemSet.Merge($System)
}
