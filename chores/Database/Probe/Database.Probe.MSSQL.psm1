# Collect Database Space information from SQL Server.
# Before using this one try Service.QuickProbe.MSSQL which does the same but quicker

Set-StrictMode -version Latest

New-Variable -Scope Script 'IService'
New-Variable -Scope Script 'DBSet'

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

    $Script:DBSet = $usr['Database.MSSQL']
    $Script:IService = $Script:DBSet.tables['IService']

}


################################################
#
# Outputs
#
################################################

function StepNext {

    $Script:DBSet.Tables['Get-Uptime']>$null
    $Script:DBSet.Tables['ProbeRecord']>$null
    Assert-Table { New-Table_ProbeRecord } $Script:DBSet.Tables['ProbeRecord']

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

    # Seconds
    $timeout = 10

    $Uptime = New-Object System.Data.DataSet 'Database.MSSQL'
    $ProbeRecord = New-Table_ProbeRecord
    $Uptime.Tables.Add($ProbeRecord)
    $Uptime.Tables.Add((New-Object System.Data.DataTable 'Get-Database'))

    $RowCount = ($Script:IService|Measure-Object).Count
    $RowNum = 0
    Foreach($Data in $Script:IService) {

        $computer = $Data['Hostname']
        $instance = $Data['Servicename']

        If(-not(($instance|Out-String).Trim().Length)) {
            continue
        }

        Write-Progress -Activity "Uptime Database" -Status "Instance" -CurrentOperation $instance -PercentComplete ($RowNum*100/$RowCount)

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

        Try {
            $dbi = DBI.MSSQL\Open-DBI $dbi
        }
        Catch { }

        $Probe = New-Probe -Memo 'Get-Database' -Record $ProbeRecord
        Invoke-Probe -Probe $Probe -Id $instance -ScriptBlock { MSSQL.Uptime\Get-Database $dbi }
        If($Probe.HasData) {
            $Uptime.Tables['Get-Database'].Merge($Probe.Result)
        }

        # Write-Verbose "[Probe.Database.Uptime] Close connection to: $instance"
        Try {
            DBI.MSSQL\Close-DBI $dbi
        }
        Catch {}
    }
    Write-Progress -Activity "Uptime Database" -Status "Complete" -Completed
    $Script:DBSet.Merge($Uptime)
}
