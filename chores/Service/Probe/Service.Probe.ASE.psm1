# Collect Instance and Device information for Sybase ASE

Set-StrictMode -version Latest

New-Variable -Scope Script 'IService'
New-Variable -Scope Script 'SvcSet'
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

    $Script:SvcSet = $usr['Service.ASE']
    $Script:IService = $Script:SvcSet.tables['IService']
    $Script:Config = $id['config']

}


################################################
#
# Outputs
#
################################################

function StepNext {

    $Script:SvcSet.Tables['Get-Uptime'].Rows[0]>$null
    # $Script:SvcSet.Tables['Get-Disk']>$null
    Assert-Table { New-Table_ProbeRecord } $Script:SvcSet.Tables['ProbeRecord']

    return @{
        'Service.ASE' = $Script:SvcSet;
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

    $Uptime = New-Object System.Data.DataSet 'Service.ASE'
    $ProbeRecord = New-Table_ProbeRecord
    $Uptime.Tables.Add((New-Object System.Data.DataTable 'Get-Uptime'))
    $Uptime.Tables.Add((New-Object System.Data.DataTable 'Get-Device'))
    # $Uptime.Tables.Add((New-Object System.Data.DataTable 'Get-Disk'))
    $Uptime.Tables.Add($ProbeRecord)

    # create interfaces
    $inifn = New-TempFile -Extension '.ini'
    New-ASEInterfaces -Table $Script:SvcSet.Tables['IService'] -Path $inifn

    $RowCount = ($Script:IService|Measure-Object).Count
    $RowNum = 0
    Foreach($Data in $Script:IService) {
        $RowNum += 1

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

        Write-Progress -Activity "Uptime Instance" -Status "Instance" -CurrentOperation $instance -PercentComplete ($RowNum*100/$RowCount)

        $ConnectionString = ("pooling=false;na={0},{1};dsn={2};uid={3};password={4};" -f $computer,$Port,$Instance,$username,$password)
        $DBi = DBI.ASE\New-DBI "$ConnectionString"
        # Connection string
        # $b = New-Object System.Data.SqlClient.SqlConnectionStringBuilder;
        # $b["Data Source"] = $instance
        # $b["Integrated Security"] = $true
        # $b["Connection Timeout"] = $timeout
        # $b["Database"] = 'master'
        # $dbi = $null
        # $dbi = DBI.ASE\New-DBI $b.ConnectionString

        If((DBI.ASE\Test-DBI $dbi) -eq 'OPEN') {
            Try {
                DBI.ASE\Close-DBI $dbi
            }
            Catch {}
        }

        # try to connect and measure how many seconds it takes
        Try {
            $dbi = DBI.ASE\Open-DBI $dbi
        }
        Catch {}

        # Instance Uptime
        $Probe = New-Probe -Memo 'Get-Uptime' -Record $ProbeRecord
        Invoke-Probe -Probe $Probe -Id $instance -ScriptBlock { ASE.Uptime\Get-Uptime $dbi }
        If($Probe.HasData) {
            $Uptime.Tables['Get-Uptime'].Merge($Probe.Result)
        }
        $Probe = New-Probe -Memo 'Get-Device' -Record $ProbeRecord
        Invoke-Probe -Probe $Probe -Id $instance -ScriptBlock { ASE.Uptime\Get-Device $dbi -instancename $instance  }
        If($Probe.HasData) {
            $Uptime.Tables['Get-Device'].Merge($Probe.Result)
        }

        Try {
            DBI.ASE\Close-DBI $dbi
        }
        Catch {}
    }

    Write-Progress -Activity "Uptime Instance" -Status "Complete" -Completed
    $Script:SvcSet.Merge($Uptime)
}

