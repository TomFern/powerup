# Collect Service & DB Uptime for Sybase ASE
# Multithreading edition

Set-StrictMode -version Latest

New-Variable -Scope Script 'IService'
New-Variable -Scope Script 'Svcset'
New-Variable -Scope Script 'Checkout'
New-Variable -Scope Script 'Config'

Import-Power 'Table'
Import-Power 'PoshRSJob'
Import-Power 'Probe'
Import-Power 'Inventory'


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

}


################################################
#
# Outputs
#
################################################

function StepNext {

    # if(!(Test-Table $Script:SvcSet.Tables['Get-Uptime'])  `
        # -or(!(Test-Table $Script:SvcSet.Tables['Get-Device']))) {
        # Throw "Invalid output tables: Service"
    # }
    # if(!(Test-Table $Script:DBSet.Tables['Get-Database'])) {
        # Throw "Invalid output tables: Database"
    # }

    # Assert-Table { New-Table_ProbeRecord } $Script:SvcSet.Tables['ProbeRecord']
    # Assert-Table { New-Table_ProbeRecord } $Script:DBSet.Tables['ProbeRecord']

    return @{
        'Checkout.ASE' = $Script:Checkout;
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
    $Service = New-Object System.Data.DataSet 'Checkout.ASE'
    $ProbeRecord = New-Table_ProbeRecord
    $Service.Tables.Add($ProbeRecord) >$null
    $IService = New-Table_IService
    $Service.Tables.Add($IService) >$null
    $Service.Tables.Add((New-Object System.Data.DataTable 'Get-Uptime')) >$null
    $Service.Tables.Add((New-Object System.Data.DataTable 'Get-Device')) >$null
    $Service.Tables.Add((New-Object System.Data.DataTable 'Get-Database')) >$null
    $Service.Tables.Add((New-Object System.Data.DataTable 'Get-Fragment')) >$null
    $Service.Tables.Add((New-Object System.Data.DataTable 'Get-ErrorLog')) >$null
    $Service.Tables.Add((New-Object System.Data.DataTable 'IService_Checked')) >$null
    $Service.Tables.Add((New-Object System.Data.DataTable 'ServiceStartDate')) >$null

    $Service.Tables['ServiceStartDate'].Columns.Add('Servicename',[String]) >$null
    $Service.Tables['ServiceStartDate'].Columns.Add('BootTime',[DateTime]) >$null



    $DS = New-Object System.Data.DataSet 'Checkout.ASE'

    # $ServiceStartDate = New-Object System.Data.DataTable 'ServiceStartDate'
    # $ServiceStartDate = $Ser
    # [void]$ServiceStartDate.Columns.Add('Servicename',[String])
    # [void]$ServiceStartDate.Columns.Add('BootTime',[DateTime])

    Try {
        $DS = Unfreeze-Dataset -Name 'Checkout.ASE'
        $ServiceStartDate = $DS.Tables['ServiceStartDate']
    }
    Catch {
        $DS = New-Object System.Data.DataSet 'Checkout.ASE'
    }

    If(($DS|Get-Table) -contains 'ServiceStartDate') {
        foreach($r in $DS.Tables['ServiceStartDate'].Rows) {
            write-host ("{0} {1}" -f $r['servicename'],$r['Boottime'])
            $Service.Tables['ServiceStartDate'].Rows.Add($r.itemarray)
        }
    }
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
                'previous_check_failed' = @();
                'cs' = @();
                'count' = 0;
                'force'=$false;
                'random_failure'=$false;
                'boottime' = @();

            }
        }

        $cs = ("pooling=false;na={0},{1};dsn={2};uid={3};password={4};" -f $sr['hostname'],$sr['port'],$sr['servicename'],$username,$password)


        $ssdrow = $Service.Tables['ServiceStartDate'].Select(("Servicename = '{0}'" -f $sr['Servicename']))
        $previous_check_failed = $false
        if($ssdrow) {
# write-host ($boottime[0]['BootTime']).gettype()
            $boottime = $ssdrow[0]['BootTime']
            write-host ("SSDROW: {0} {1}" -f $ssdrow[0]['Servicename'],$ssdrow[0]['BootTime'])
            $previous_check_failed = $false
        }
        else {
            $boottime = (Get-Date -Year 1970 -Month 1 -Day 1 -Hour 0 -Minute 0 -Second 0)
            $previous_check_failed = $true

        }
# write-host $Boottime.gettype()

        $Threads[$i]['previous_check_failed'] += $previous_check_failed
        $Threads[$i]['cs'] += $cs
        $Threads[$i]['count'] += 1
        $Threads[$i]['serviceid'] += $sr['Servicename']
        $Threads[$i]['hostid'] += $sr['Hostname']
        $Threads[$i]['boottime'] += $boottime
        write-host ("Previous {0} - {1}" -f $sr['servicename'],$boottime)



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
            Import-Power 'Inventory'

            $Service = New-Object System.Data.DataSet 'Service.ASE'
            $ProbeRecord = New-Table_ProbeRecord
            $IService = New-Table_IService
            $IService.TableName = 'IService_Checked'
            $Service.Tables.Add($IService) >$null
            $Service.Tables.Add($ProbeRecord) >$null
            $Service.Tables.Add((New-Object System.Data.DataTable 'Get-Uptime')) >$null
            $Service.Tables.Add((New-Object System.Data.DataTable 'Get-Device')) >$null
            $Service.Tables.Add((New-Object System.Data.DataTable 'Get-Database')) >$null
            $Service.Tables.Add((New-Object System.Data.DataTable 'Get-Fragment')) >$null
            $Service.Tables.Add((New-Object System.Data.DataTable 'Get-ErrorLog')) >$null

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

                    $NewDate = $Probe.Result.Rows[0]['BootTime']

                    # run checkout ?
                    $CheckoutReason = ''


                    If($work['force']) {
                        $CheckoutReason = 'FORCED'
                    }
                    elseIf($work['previous_check_failed'][$i]) {
                        $CheckoutReason = 'Previous Check Failed'
                    }
                    elseif($work['boottime'][$i].Tostring() -ne $NewDate.ToString()) {
                        $CheckoutReason = 'BootTime changed'
                    }
                    elseif($work['random_failure']) {
                        $dice = Get-Random
                        If(($dice % 2) -eq 1) {
                            $CheckoutReason = 'RandomFailure'
                        }
                    }

                    $Probe.Result.Columns.Add('CheckoutReason',[String]) >$null
                    $Probe.Result.Rows[0]['CheckoutReason'] = $CheckoutReason
                    $Service.Tables['Get-Uptime'].Merge($Probe.Result) >$null

                    if($CheckoutReason -ne '') {
                    # If($work['force'] -or($work['boottime'][$i].Tostring() -ne $NewDate.ToString())) {

                        $isr = $Service.tables['IService_Checked'].NewRow()
                        $isr['Servicename'] = $work['serviceid'][$i]
                        $isr['Hostname'] = $work['hostid'][$i]
                        $Service.Tables['IService_Checked'].Rows.Add($isr)

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

                        # Errorlog
                        $Probe = New-Probe -Memo 'Get-ErrorLog' -Record $ProbeRecord
                        Invoke-Probe -Probe $Probe -Id $work['serviceid'][$i] -ScriptBlock { ASE.Uptime\Get-Errorlog $dbi -descending -limit 300 -instancename $work['serviceid'][$i] } >$null
                        If($Probe.HasData) {
                            $Service.Tables['Get-ErrorLog'].Merge($Probe.Result)>$null
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
if($ds){
                foreach($tn in (Get-Table $ds)) {
                    write-host ("{0} - {1}" -f $tn,($ds.tables[$tn].rows|measure).count)

                    if(-not((Get-Table $Service) -contains $tn)) {
                    Write-host "New table $tn"
                        $Service.Tables.Add((New-Object System.Data.DataTable $tn)) >$null
                    }

                    # $table = $ds.Tables[$tn]
                    $Service.Tables[$tn].Merge($ds.Tables[$tn].Copy()) >$null
                }
                Remove-RSJob -Id $job.Id
            }
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

    # ServiceStartDate needs BootTime column
    # $ServiceStartDate = $Service.Tables['Get-Uptime'].Clone()
    # $ServiceStartDate.TableName = 'ServiceStartDate'

    $Service.Tables.Remove('ServiceStartDate') >$null
    $Service.Tables.Add((New-Object System.Data.DataTable 'ServiceStartDate')) >$null
    $Service.Tables['ServiceStartDate'].Columns.Add('Servicename',[String]) >$null
    $Service.Tables['ServiceStartDate'].Columns.Add('BootTime',[DateTime]) >$null
    foreach($r in $Service.Tables['Get-Uptime'].rows) {
        $Service.Tables['ServiceStartDate'].rows.add($r['servicename'],$r['boottime'])
    }

    # If checkout was run, remove them from StartDateTime unless fully recovered
    # If(($Service.Tables['Get-Database'].rows|measure).count -gt 0) {
    $Service.Tables.Remove('IService')
    $Service.Tables.Add((New-Table_IService))
    If(($Service.Tables['IService_Checked'].Rows|Measure).count -gt 0) {
        $IService_Checked = New-Table_IService

        # Foreach($r in $Service.Tables['Get-Uptime'].rows) {
        Foreach($sr in $Service.Tables['IService_Checked'].Rows) {

            $Uptime = Select-Table -Table $Service.Tables['Get-Uptime'] -Select (("Servicename = '{0}'" -f $sr['Servicename']))
            foreach($ur in $Uptime.Rows) {
                # $DB = Select-Table -Table $Service.Tables['Get-Database'] -Select ("Servicename = '{0}'" -f $ur['Servicename'])
                if(($ur['RecoveryState'] -ne 'NOT_IN_RECOVERY')) { #-and(($DB | Where { $_.IsOnline -eq $false } | Measure).count -eq 0)) {
                    # not really recovered , change boottime and add to iservice
                    write-host ("{0} is NOT really recovered" -f $ur['BootTime'])
                    foreach($ssr in $Service.Tables['ServiceStartDate'].Select(("Servicename='{0}'" -f $sr['Servicename']))) {
                        $boottime = (Get-Date -Year 1970 -Month 1 -Day 1 -Hour 0 -Minute 0 -Second 0)
                        $ssr['BootTime'] = $boottime
                    }
                }
                else {
                    # really recovered, save correct boottime
                    write-host ("{0} {1} is really recovered" -f $ur['Servicename'],$ur['BootTime'])
                    # $Service.Tables['ServiceStartDate'].Rows.Add($ur['Servicename'],$ur['BootTime'])
                    $IService_Checked.rows.add($sr.itemarray)
                }
            }
        }
        # $IService_Checked = $Service.Tables['IService_Checked'].Copy()
        $IService_Checked.TableName = 'IService'
        $Service.Tables.Remove('IService') >$null
        $Service.Tables.Add($IService_Checked.Copy()) >$null
        # $Service.Tables['IService'].Merge($IService_Checked)
        #$Service.Tables.Add($IService_Corrected.Copy())
    }
    # else {

    #     foreach($r in $Service.Tables['Get-Uptime'].rows) {
    #         $Service.Tables['ServiceStartDate'].rows.add($r['servicename'],$r['boottime'])
    #     }
    #     # if no checkout was run just store current StartDateTime
    #     # $ServiceStartDate = $Service.Tables['Get-Uptime'].Copy()
    #     # $ServiceStartDate.TableName = 'ServiceStartDate'
    # }

    # $Service.Tables.Add($ServiceStartDate.Copy())

    Freeze-Dataset -Dataset $Service -Timeout 60

    $Script:Checkout = $Service
}
