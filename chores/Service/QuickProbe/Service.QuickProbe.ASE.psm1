# Collect Service & DB Uptime for Sybase ASE
# Multithreading edition

Set-StrictMode -version Latest

New-Variable -Scope Script 'IService'
New-Variable -Scope Script 'DBSet'
New-Variable -Scope Script 'Svcset'
New-Variable -Scope Script 'Config'

Import-Power 'Table'
Import-Power 'PoshRSJob'
Import-Power 'Probe'


################################################
#
# Inputs
#
################################################

function StepPre {
    Param([HashTable]$usr,[Hashtable]$id)

    $Script:SvcSet = $usr['Service.ASE']
    $Script:Config = $id['Config']['sybase']
    $Script:IService = $Script:SvcSet.tables['IService']

    # Not using it's data, just passing along
    if($usr.ContainsKey('Database.ASE')) {
        $Script:DBSet = $usr['Database.ASE']
    }
    else {
        $Script:DBSet = New-Object System.Data.DataSet 'Database.ASE'
    }
}


################################################
#
# Outputs
#
################################################

function StepNext {

    if(!(Test-Table $Script:SvcSet.Tables['Get-Uptime'])  `
        -or(!(Test-Table $Script:SvcSet.Tables['Get-Device']))) {
        Throw "Invalid output tables: Service"
    }
    if(!(Test-Table $Script:DBSet.Tables['Get-Database'])) {
        Throw "Invalid output tables: Database"
    }

    Assert-Table { New-Table_ProbeRecord } $Script:SvcSet.Tables['ProbeRecord']
    Assert-Table { New-Table_ProbeRecord } $Script:DBSet.Tables['ProbeRecord']

    return @{
        'Service.ASE' = $Script:SvcSet;
        'Database.ASE' = $Script:DBSet;
    }
}


################################################
#
# Process
#
################################################

function StepProcess {

    $ThreadCountMax = $GLOBAL:_PWR['LOCAL']['maxthreads']
    $ThreadCount = 1

    $timeout = $Script:Config['timeout']

    # Datasets
    $Service = New-Object System.Data.DataSet 'Service.ASE'
    $ProbeRecord = New-Table_ProbeRecord
    $Service.Tables.Add($ProbeRecord) >$null
    $Service.Tables.Add((New-Object System.Data.DataTable 'Get-Uptime')) >$null
    $Service.Tables.Add((New-Object System.Data.DataTable 'Get-Device')) >$null
    $Service.Tables.Add((New-Object System.Data.DataTable 'Get-Database')) >$null
    $Service.Tables.Add((New-Object System.Data.DataTable 'Get-Fragment')) >$null

    # Thread list
    $Threads = @()

    $IServiceRowCount = ($Script:IService.Rows|Measure).count
    If($IServiceRowCount -le $ThreadCountMax) {
        $ThreadCount = $IServiceRowCount
    }
    else {
        $ThreadCount = $ThreadCountMax
    }

    # Write-Host ("Using {0} Threads" -f $ThreadCount)

    # Create thread work units
    # Each unit has count=n connection strings, hostid and serviceid
    $i = 0
    foreach($sr in $Script:IService) {

        If(-not(($sr['Servicename']|Out-String).Trim().Length)) {
            Write-Warning "Skip row missing column"
            continue
        }

        # Get password from config
        $cfg = $Script:Config['login']
        $Username = ''
        $Password = ''
        if($cfg.containskey($sr['hostname']) -and($cfg[$sr['hostname']].containskey($sr['servicename']))) {
            $username = $cfg[$sr['hostname']][$sr['servicename']]['username']
            $password = $cfg[$sr['hostname']][$sr['servicename']]['password']
        }
        else {
            $username = $cfg['_DEFAULT']['username']
            $password = $cfg['_DEFAULT']['password']
        }

        if(($Threads.length - 1) -le $i) {
            $Threads += @{
                'workerid' = $i;
                'pwr' = $GLOBAL:_PWR;
                'serviceid' = @();
                'hostid' = @();
                'cs' = @();
                'count' = 0;
            }
        }

        $cs = ("pooling=false;na={0},{1};dsn={2};uid={3};password={4};" -f $sr['hostname'],$sr['port'],$sr['servicename'],$username,$password)

        $Threads[$i]['cs'] += $cs
        $Threads[$i]['count'] += 1
        $Threads[$i]['serviceid'] += $sr['Servicename']
        $Threads[$i]['hostid'] += $sr['Hostname']

        if($i -lt ($ThreadCount-1)) {
            $i += 1
        }
        else {
            $i = 0
        }
    }

    # Foreach($thread in $Threads) {
    #     foreach($cs in $thread['cs']]) {
    #         write-host $cs
    #     }
    # }

    # Remove existing threads if any
    Try{
        Get-RSJob|Remove-RSJob >$null
    }
    Catch {}

    # Start workers in parallel
    foreach($i in 0..($ThreadCount-1)) {
        # Write-Host ("start worker {0}" -f $i)

        $Threads[$i] | Start-RSJob -Name "Service_Probe_ASE_Id_$i" {

            # For each connection string in the work unit: create and open dbi, runs queries and closes dbi
            # Merge the datasets for all cs in list, including proberecord and return the whole dataset

            $work = $_

            # Spin up Powerup
            . $work['pwr']['POWERUP_FILE'] -NoInteractive >$null

            Import-Power 'DBI.ASE'
            Import-Power 'ASE.Uptime'
            Import-Power 'Probe'
            Import-Power 'Table'

            $Service = New-Object System.Data.DataSet 'Service.ASE'
            $ProbeRecord = New-Table_ProbeRecord
            $Service.Tables.Add($ProbeRecord) >$null
            $Service.Tables.Add((New-Object System.Data.DataTable 'Get-Uptime')) >$null
            $Service.Tables.Add((New-Object System.Data.DataTable 'Get-Device')) >$null
            $Service.Tables.Add((New-Object System.Data.DataTable 'Get-Database')) >$null
            $Service.Tables.Add((New-Object System.Data.DataTable 'Get-Fragment')) >$null

            # Foreach service
            Foreach($i in 0..($work['count']-1)) {

                $dbi = New-DBI $work['cs'][$i]

                Try {
                    Open-DBI $dbi >$null
                }
                Catch {}


                # Instance uptime
                $Probe = New-Probe -Memo 'Get-Uptime' -Record $ProbeRecord
                Invoke-Probe -Probe $Probe -Id $work['serviceid'][$i] -ScriptBlock { ASE.Uptime\Get-Uptime $dbi } >$null
                If($Probe.HasData) {
                    $Service.Tables['Get-Uptime'].Merge($Probe.Result)>$null
                }

                # Instance Disk
                $Probe = New-Probe -Memo 'Get-Device' -Record $ProbeRecord
                Invoke-Probe -Probe $Probe -Id $work['serviceid'][$i] -ScriptBlock { ASE.Uptime\Get-Device $dbi -instancename $work['serviceid'][$i] } >$null
                If($Probe.HasData) {
                    $Service.Tables['Get-Device'].Merge($Probe.Result)>$null
                }

                # Database uptime
                $Probe = New-Probe -Memo 'Get-Database' -Record $ProbeRecord
                Invoke-Probe -Probe $Probe -Id $work['serviceid'][$i] -ScriptBlock { ASE.Uptime\Get-Database $dbi -instancename $work['serviceid'][$i] } >$null
                If($Probe.HasData) {
                    $Service.Tables['Get-Database'].Merge($Probe.Result)>$null
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
                        Invoke-Probe -Probe $Probe -Id $work['serviceid'][$i] -ScriptBlock { ASE.Uptime\Get-Fragment $dbi -instancename $work['serviceid'][$i] -database $dbname } >$null
                        If($Probe.HasData) {
                            $Service.Tables['Get-Fragment'].Merge($Probe.Result)
                        }
                    }
                }


                Try {
                    Close-DBI $dbi >$null
                }
                Catch {}
            }
            return $Service
        }
    }

    # Wait for threads to finish, master merge results
    Write-Progress -Activity 'Service Uptime' -Status 'Running' -PercentComplete 0
    Do {
        $Jobs = Get-RSJob
        Foreach($job in $Jobs) {
            If($job.State -eq 'Failed') {
                Throw ("Exception in thread id {0} {1}" -f $job.id,$job.name)
            }
            elseif($Job.State -ne 'Running') {
                # write-host ("Thread id {0} not running name {1}" -f $job.id,$job.name)
                $ds = Receive-RSJob -Name $job.Name
                $GLOBAL:_PWR['D'] = $ds
                foreach($tn in (Get-Table $ds)) {
                    # write-host $tn
                    $table = $ds.Tables[$tn]
                    $Service.Tables[$tn].Merge($table)>$null
                }
                Remove-RSJob -Id $job.Id
            }
        }
        Sleep 1
        $active = (Get-RSJob|Measure).Count
        $percent = (($ThreadCount-$active)*100/$ThreadCount)
        Write-Progress -Activity 'Service Uptime' -Status 'Running' -PercentComplete $percent
    } While($active -gt 0)


    # Remove existing threads if any remains, there shouldn't be any
    Try{
        Get-RSJob|Remove-RSJob >$null
    }
    Catch {}

    Write-Progress -Activity 'Service Uptime' -Status 'Done' -Completed

    # Split Datasets: Service -> Database
    $DBSet = New-Object System.Data.DataSet 'Database.ASE'
    $DBSet.Tables.Add($Service.Tables['Get-Database'].Copy())
    $DBSet.Tables.Add($Service.Tables['Get-Fragment'].Copy())
    $DBSet.Tables.Add($Service.Tables['ProbeRecord'].Copy())
    $Service.Tables.Remove('Get-Database')
    $Service.Tables.Remove('Get-Fragment')

    $Script:SvcSet.Merge($Service)
    $Script:DBSet.Merge($DBSet)
}


