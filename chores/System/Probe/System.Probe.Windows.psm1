# Colect OS/Uptime and Disk from Windows

Set-StrictMode -version Latest

New-Variable -Scope Script 'IHost'
New-Variable -Scope Script 'Windows'

Import-Power 'Windows.Uptime'
Import-Power 'Probe'

################################################
#
# Inputs
#
################################################

function StepPre {
    Param([HashTable]$usr)

    $Script:SystemSet = $usr['System.Windows']
    $Script:IHost = $Script:SystemSet.Tables['IHost']
}

################################################
#
# Outputs
#
################################################

function StepNext {

    $Script:SystemSet.Tables['Get-Disk'].Rows[0] > $null
    $Script:SystemSet.Tables['Get-Uptime'].Rows[0] > $null
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

    $Uptime = New-Object System.Data.DataSet 'System.Windows'
    $ProbeRecord = New-Table_ProbeRecord
    $Uptime.Tables.Add((New-Object System.Data.DataTable 'Get-Uptime'))
    $Uptime.Tables.Add((New-Object System.Data.DataTable 'Get-Disk'))
    $Uptime.Tables.Add($ProbeRecord)

    $RowCount = ($Script:IHost|Measure-Object).Count
    $RowNum = 0
    Foreach($RowData in $Script:IHost) {
        $RowNum += 1
        $computer = $RowData['hostname']
        Write-Progress -Activity "Uptime/Disk Windows" -Status "Server" -CurrentOperation $computer -PercentComplete ($RowNum*100/$RowCount)

        # Windows Uptime
        $Probe = New-Probe -Memo 'Get-Uptime' -Record $ProbeRecord
        Invoke-Probe -Probe $Probe -Id $computer -ScriptBlock { Windows.Uptime\Get-Uptime -computer $computer }
        If($Probe.HasData) {
            $Uptime.Tables['Get-Uptime'].Merge($Probe.Result)
        }

        # Windows Disk
        $Probe = New-Probe -Memo 'Get-Disk' -Record $ProbeRecord
        Invoke-Probe -Probe $Probe -Id $computer -ScriptBlock { Windows.Uptime\Get-Disk -computer $computer }
        If($Probe.HasData) {
            $Uptime.Tables['Get-Disk'].Merge($Probe.Result)
        }
    }
    Write-Progress -Activity "Uptime/Disk Windows" -Status "Complete" -Completed
    $Script:SystemSet.Merge($Uptime)
}
