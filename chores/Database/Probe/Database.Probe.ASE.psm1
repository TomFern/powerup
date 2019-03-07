# Collect Database information for Sybase ASE

Set-StrictMode -version Latest

New-Variable -Scope Script 'IService'
New-Variable -Scope Script 'DBSet'
New-Variable -Scope Script 'Config'

Import-Power 'DBI.ASE'
Import-Power 'ASE.Uptime'
Import-Power 'Table'
Import-Power 'Probe'


################################################
#
# Inputs
#
################################################

function StepPre {
    Param([HashTable]$usr,[hashtable]$id)

    $Script:DBSet = $usr['Database.ASE']
    $Script:IService = $Script:DBSet.tables['IService']
    $Script:Config = $id['config']

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
        'Database.ASE' = $Script:DBSet;
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

    $Uptime = New-Object System.Data.DataSet 'Database.ASE'
    $ProbeRecord = New-Table_ProbeRecord
    $Uptime.Tables.Add($ProbeRecord)
    $Uptime.Tables.Add((New-Object System.Data.DataTable 'Get-Database'))
    $Uptime.Tables.Add((New-Object System.Data.DataTable 'Get-Fragment'))

    $RowCount = ($Script:IService|Measure-Object).Count
    $RowNum = 0
    Foreach($Data in $Script:IService) {

        $computer = $Data['Hostname']
        $instance = $Data['Servicename']
        $port = $Data['Port']

        If(-not(($instance|Out-String).Trim().Length)) {
            continue
        }

        # Get password from config
        $cfg = $Script:Config['sybase']['login']
        $Username = ''
        $Password = ''
        if($cfg.containskey($computer) -and($cfg[$computer].containskey($instance))) {
            $username = $cfg[$computer][$instance]['username']
            $password = $cfg[$computer][$instance]['password']
        }
        else {
            $username = $cfg['_DEFAULT']['username']
            $password = $cfg['_DEFAULT']['password']
        }

        Write-Progress -Activity "Uptime Database" -Status "Instance" -CurrentOperation $instance -PercentComplete ($RowNum*100/$RowCount)

        # Connection string
        $ConnectionString = ("pooling=false;na={0},{1};dsn={2};uid={3};password={4};" -f $computer,$Port,$Instance,$username,$password)
        $DBi = DBI.ASE\New-DBI "$ConnectionString"

        If((DBI.ASE\Test-DBI $dbi) -eq 'OPEN') {
            Try {
                DBI.ASE\Close-DBI $dbi
            }
            Catch {}
        }

        Try {
            $dbi = DBI.ASE\Open-DBI $dbi
        }
        Catch { }

        $Probe = New-Probe -Memo 'Get-Database' -Record $ProbeRecord
        Invoke-Probe -Probe $Probe -Id $instance -ScriptBlock { ASE.Uptime\Get-Database $dbi -instancename $instance  }
        If($Probe.HasData) {
            $Uptime.Tables['Get-Database'].Merge($Probe.Result)
        }

        $dbfilter = ($Probe.Result|Select -Property 'Database' -Unique)
        Foreach($db in $dbfilter) {
            $dbname = ""
            Try {
                $dbname = $db.database
            }
            catch {}
            if($dbname) {
                $Probe = New-Probe -Memo "Get-Fragment $dbname" -Record $ProbeRecord
                Invoke-Probe -Probe $Probe -Id $instance -ScriptBlock { ASE.Uptime\Get-Fragment $dbi -instancename $instance -database $dbname }
                If($Probe.HasData) {
                    $Uptime.Tables['Get-Fragment'].Merge($Probe.Result)
                }
            }
        }

        # Write-Verbose "[Probe.Database.Uptime] Close connection to: $instance"
        Try {
            DBI.ASE\Close-DBI $dbi
        }
        Catch {}
    }
    Write-Progress -Activity "Uptime Database" -Status "Complete" -Completed
    $Script:DBSet.Merge($Uptime)
}

