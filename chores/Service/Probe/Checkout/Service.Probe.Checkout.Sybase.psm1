# Run a quick Sanity Probe on recently started Sybase ASE

Set-StrictMode -version Latest

New-Variable -Scope Script 'IService'
New-Variable -Scope Script 'Checkout'
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

    $Script:Config = $id['config']
    $Script:IService = $usr['Service.ASE'].tables['IService']

}


################################################
#
# Outputs
#
################################################

function StepNext {
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

    # Set true to run checkout even if not rebooted recently
    $ForceCheckout = $false

    # Check if ServiceStartDate table exists in Checkout.ASE Dataset
    # If yes, check if current start date is different from ServiceStartDate for instance
    # If no, don't run the checkout, just get the date and pass it along
    # Run checkout probe only on services that have restarted since last time

    $Script:Checkout = New-Object System.Data.DataSet 'Checkout.ASE'
    $Script:Checkout.Tables.Add((New-Object System.Data.Datatable 'Get-Uptime'))
    $Script:Checkout.Tables.Add((New-Object System.Data.Datatable 'Get-Device'))
    $Script:Checkout.Tables.Add((New-Object System.Data.Datatable 'Get-Database'))
    $Script:Checkout.Tables.Add((New-Object System.Data.Datatable 'Get-Fragment'))

    $ServiceStartDate = New-Object System.Data.DataTable 'ServiceStartDate'
    [void]$ServiceStartDate.Columns.Add('Servicename',[String])
    [void]$ServiceStartDate.Columns.Add('BootTime',[DateTime])

    Try {
        $DS = Unfreeze-Dataset -Name 'Checkout.ASE'
        $ServiceStartDate = $DS.Tables['ServiceStartDate']
    }
    Catch {}


    # Services that have been restarted go here
    $IService_Restarted = $Script:IService.Clone()

    # Seconds
    $timeout = 10

    $ProbeRecord = New-Table_ProbeRecord

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

        Write-Progress -Activity "Service Uptime" -Status "Instance" -CurrentOperation $instance -PercentComplete ($RowNum*100/$RowCount)

        # Connection string
        $ConnectionString = ("pooling=false;na={0},{1};dsn={2};uid={3};password={4};" -f $computer,$Port,$Instance,$username,$password)
        $DBi = DBI.ASE\New-DBI "$ConnectionString"

        Try {
            $dbi = DBI.ASE\Open-DBI $dbi
        }
        Catch { }


        $Probe = New-Probe -Memo 'Get-Uptime' -Record $ProbeRecord
        Invoke-Probe -Probe $Probe -Id $instance -ScriptBlock { ASE.Uptime\Get-Uptime $dbi }
        If($Probe.HasData) {
            $Script:Checkout.Tables['Get-Uptime'].merge($Probe.Result)
            $OldDateSel = $ServiceStartDate.Select("Servicename = '$instance'")
            $NewDate = $Probe.Result.Rows[0]

            # detect recovered or new
            If($ForceCheckout -or(-not($OldDateSel) -and($NewDate['BootTime']))) {
                Write-Warning "$instance recovered or recently added"
                $IService_Restarted.ImportRow($Data)
                run_checkout $Script:Checkout $dbi
            }
            # detect different boot time
            elseIf($OldDateSel -and(-not(datediff $OldDateSel[0]['BootTime'] $NewDate['BootTime']))) {
                Write-Warning "$instance has been rebooted"
                $IService_Restarted.ImportRow($Data)
                run_checkout $Script:Checkout $dbi
            }
        }

        Try {
            DBI.ASE\Close-DBI $dbi
        }
        Catch {}
    }

    Write-Progress -Activity "Service Uptime" -Status "Complete" -Completed

    try {
        $Script:Checkout.Tables.Remove('ServiceStartDate')
    }
    catch {}

    $ServiceStartDate = $Script:Checkout.Tables['Get-Uptime'].Copy()
    $ServiceStartDate.TableName = 'ServiceStartDate'
    $Script:Checkout.Tables.Add($ServiceStartDate)

    try {
        $Script:Checkout.Tables.Remove('IService')
    }
    catch {}
    $IService_Restarted.TableName = 'IService'
    $Script:Checkout.Tables.Add($IService_Restarted)

    Freeze-Dataset -Dataset $Script:Checkout
}


function run_checkout {
    Param($Checkout, $dbi)

    $Probe = New-Probe -Memo 'Get-Uptime' -Record $ProbeRecord
    Invoke-Probe -Probe $Probe -Id $instance -ScriptBlock { ASE.Uptime\Get-Uptime $dbi }
    If($Probe.HasData) {
        $Checkout.Tables['Get-Uptime']
        $Checkout.Tables['Get-Uptime'].Merge($Probe.Result)
    }

    $Probe = New-Probe -Memo 'Get-Device' -Record $ProbeRecord
    Invoke-Probe -Probe $Probe -Id $instance -ScriptBlock { ASE.Uptime\Get-Device $dbi -instancename $instance  }
    If($Probe.HasData) {
        $Checkout.Tables['Get-Device']
        $Checkout.Tables['Get-Device'].Merge($Probe.Result)
    }

    $Probe = New-Probe -Memo 'Get-Database' -Record $ProbeRecord
    Invoke-Probe -Probe $Probe -Id $instance -ScriptBlock { ASE.Uptime\Get-Database $dbi -instancename $instance  }
    If($Probe.HasData) {
        $Checkout.Tables['Get-Database']
        $Checkout.Tables['Get-Database'].Merge($Probe.Result)
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
                $Checkout.Tables['Get-Fragment']
                $Checkout.Tables['Get-Fragment'].Merge($Probe.Result)
            }
        }
    }
}

function datediff {
    Param($d1, $d2)
    return (`
        ($d1.year -eq $d2.year) `
        -and($d1.month -eq $d2.month) `
        -and($d1.day -eq $d2.day) `
        -and($d1.hour -eq $d2.hour) `
        -and($d1.minute -eq $d2.minute) `
        -and($d1.second -eq $d2.second) `
    )
}
