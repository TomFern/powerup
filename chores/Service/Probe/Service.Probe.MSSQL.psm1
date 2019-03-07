# Collect Instance Disk Space information from SQL Server.
# Before using this one try Service.QuickProbe.MSSQL which does the same but quicker

Set-StrictMode -version Latest

New-Variable -Scope Script 'IService'
New-Variable -Scope Script 'SvcSet'

Import-Power 'DBI.MSSQL'
Import-Power 'MSSQL.Uptime'
Import-Power 'Table'
Import-Power 'Probe'


################################################
#
# Inputs
#
################################################

function StepPre {
    Param([HashTable]$usr)

    $Script:SvcSet = $usr['Service.MSSQL']
    $Script:IService = $Script:SvcSet.tables['IService']

}


################################################
#
# Outputs
#
################################################

function StepNext {

    $Script:SvcSet.Tables['Get-Uptime'].Rows[0]>$null
    $Script:SvcSet.Tables['Get-Disk']>$null
    Assert-Table { New-Table_ProbeRecord } $Script:SvcSet.Tables['ProbeRecord']

    return @{
        'Service.MSSQL' = $Script:SvcSet;
    }
}


################################################
#
# Process
#
################################################

function StepProcess {

    # Seconds
    $timeout = 60

    $Uptime = New-Object System.Data.DataSet 'Service.MSSQL'
    $ProbeRecord = New-Table_ProbeRecord
    $Uptime.Tables.Add((New-Object System.Data.DataTable 'Get-Uptime'))
    $Uptime.Tables.Add((New-Object System.Data.DataTable 'Get-Disk'))
    $Uptime.Tables.Add($ProbeRecord)

    $RowCount = ($Script:IService|Measure-Object).Count
    $RowNum = 0
    Foreach($Data in $Script:IService) {
        $RowNum += 1

        $computer = $Data['Hostname']
        $instance = $Data['Servicename']

        If(-not(($instance|Out-String).Trim().Length)) {
            continue
        }

        Write-Progress -Activity "Uptime Instance" -Status "Instance" -CurrentOperation $instance -PercentComplete ($RowNum*100/$RowCount)

        # Connection string
        $b = New-Object System.Data.SqlClient.SqlConnectionStringBuilder;
        $b["Data Source"] = $instance
        $b["Integrated Security"] = $true
        $b["Connection Timeout"] = $timeout
        $b["Database"] = 'master'
        $dbi = $null
        $dbi = DBI.MSSQL\New-DBI $b.ConnectionString

        If((DBI.MSSQL\Test-DBI $dbi) -eq 'OPEN') {
            Try {
                DBI.MSSQL\Close-DBI $dbi
            }
            Catch {}
        }

        # try to connect and measure how many seconds it takes
        Try {
            $dbi = DBI.MSSQL\Open-DBI $dbi
        }
        Catch {}

        # Instance Uptime
        $Probe = New-Probe -Memo 'Get-Uptime' -Record $ProbeRecord
        Invoke-Probe -Probe $Probe -Id $instance -ScriptBlock { MSSQL.Uptime\Get-Uptime $dbi }
        If($Probe.HasData) {
            $Uptime.Tables['Get-Uptime'].Merge($Probe.Result)
        }

        # Instance Disk
        $Probe = New-Probe -Memo 'Get-Disk' -Record $ProbeRecord
        Invoke-Probe -Probe $Probe -Id $instance -ScriptBlock { MSSQL.Uptime\Get-Disk $dbi }
        If($Probe.HasData) {
            $Uptime.Tables['Get-Disk'].Merge($Probe.Result)
        }

        Try {
            DBI.MSSQL\Close-DBI $dbi
        }
        Catch {}
    }

    Write-Progress -Activity "Uptime Instance" -Status "Complete" -Completed
    $Script:SvcSet.Merge($Uptime)
}
