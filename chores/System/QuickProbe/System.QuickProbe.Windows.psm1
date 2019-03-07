# Collect System Uptime for Windows
# Multithreading edition

Set-StrictMode -version Latest

New-Variable -Scope Script 'IHost'
New-Variable -Scope Script 'SysSet'

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

    $Script:SysSet = $usr['System.Windows']
    $Script:IHost = $Script:SysSet.Tables['IHost']

}


################################################
#
# Outputs
#
################################################

function StepNext {

    if(!(Test-Table $Script:SysSet.Tables['Get-Uptime'])  `
        -or(!(Test-Table $Script:SysSet.Tables['Get-Disk']))) {
        Throw "Invalid output tables: System"
    }

    Assert-Table { New-Table_ProbeRecord } $Script:SysSet.Tables['ProbeRecord']

    return @{
        'System.Windows' = $Script:SysSet;
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


    # Datasets
    $System = New-Object System.Data.DataSet 'System.Windows'
    $ProbeRecord = New-Table_ProbeRecord
    $System.Tables.Add($ProbeRecord) >$null
    $System.Tables.Add((New-Object System.Data.DataTable 'Get-Uptime')) >$null
    $System.Tables.Add((New-Object System.Data.DataTable 'Get-Disk')) >$null

    # Thread list
    $Threads = @()

    $IHostRowCount = ($Script:IHost.Rows|Measure).count
    If($IHostRowCount -le $ThreadCountMax) {
        $ThreadCount = $IHostRowCount
    }
    else {
        $ThreadCount = $ThreadCountMax
    }

    # Write-Host ("Using {0} Threads" -f $ThreadCount)

    # Create thread work units
    # Each unit has count=n hostids
    $i = 0
    foreach($hr in $Script:IHost) {
        if(($Threads.length - 1) -le $i) {
            $Threads += @{
                'workerid' = $i;
                'pwr' = $GLOBAL:_PWR;
                'hostid' = @();
                'count' = 0;
            }
        }

        $Threads[$i]['count'] += 1
        $Threads[$i]['hostid'] += $hr['Hostname']

        if($i -lt ($ThreadCount-1)) {
            $i += 1
        }
        else {
            $i = 0
        }
    }

    # Remove existing threads if any
    Try{
        Get-RSJob|Remove-RSJob >$null
    }
    Catch {}

    # Start workers in parallel
    foreach($i in 0..($ThreadCount-1)) {
        # Write-Host ("start worker {0}" -f $i)

        $Threads[$i] | Start-RSJob -Name "System_Probe_Windows_Id_$i" {

            # For each connection string in the work unit: create and open dbi, runs queries and closes dbi
            # Merge the datasets for all cs in list, including proberecord and return the whole dataset

            $work = $_

            # Spin up Powerup
            . $work['pwr']['POWERUP_FILE'] -NoInteractive >$null

            Import-Power 'Windows.Uptime'
            Import-Power 'Probe'
            Import-Power 'Table'

            $System = New-Object System.Data.DataSet 'System.Windows'
            $ProbeRecord = New-Table_ProbeRecord
            $System.Tables.Add($ProbeRecord) >$null
            $System.Tables.Add((New-Object System.Data.DataTable 'Get-Uptime')) >$null
            $System.Tables.Add((New-Object System.Data.DataTable 'Get-Disk')) >$null

            # Foreach host
            Foreach($i in 0..($work['count']-1)) {

                # Windows Uptime
                $Probe = New-Probe -Memo 'Get-Uptime' -Record $ProbeRecord
                Invoke-Probe -Probe $Probe -Id $work['hostid'][$i] -ScriptBlock { Windows.Uptime\Get-Uptime -computer $work['hostid'][$i] } >$null
                If($Probe.HasData) {
                    $System.Tables['Get-Uptime'].Merge($Probe.Result)
                }

                # Windows Disk
                $Probe = New-Probe -Memo 'Get-Disk' -Record $ProbeRecord
                Invoke-Probe -Probe $Probe -Id $work['hostid'][$i] -ScriptBlock { Windows.Uptime\Get-Disk -computer $work['hostid'][$i] } >$null
                If($Probe.HasData) {
                    $System.Tables['Get-Disk'].Merge($Probe.Result)
                }
            }
            return $System
        }
    }

    # Wait for threads to finish, master merge results
    Write-Progress -Activity 'System Uptime' -Status 'Running' -PercentComplete 0
    Do {
        $Jobs = Get-RSJob
        Foreach($job in $Jobs) {
            If($job.State -eq 'Failed') {
                Throw ("Exception in thread id {0} {1}" -f $job.id,$job.name)
            }
            elseif($Job.State -ne 'Running') {
                # write-host ("Thread id {0} not running name {1}" -f $job.id,$job.name)
                $ds = Receive-RSJob -Name $job.Name
                # $GLOBAL:_PWR['D'] = $ds
                If($ds -and($ds.gettype().name -eq 'DataSet')) {
                    foreach($tn in (Get-Table $ds)) {
                        write-host $tn
                        $table = $ds.Tables[$tn]
                        $System.Tables[$tn].Merge($table)>$null
                    }
                }
                Remove-RSJob -Id $job.Id
            }
        }
        Sleep 1
        $active = (Get-RSJob|Measure).Count
        $percent = (($ThreadCount-$active)*100/$ThreadCount)
        Write-Progress -Activity 'System Uptime' -Status 'Running' -PercentComplete $percent
    } While($active -gt 0)


    # Remove existing threads if any remains, there shouldn't be any
    Try{
        Get-RSJob|Remove-RSJob >$null
    }
    Catch {}

    Write-Progress -Activity 'System Uptime' -Status 'Done' -Completed

    $Script:SysSet.Merge($System)
}


