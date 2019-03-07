
# Get Replication Server threads
# Unfortunately neither ADO.NET nor ODBC works with RS, so we hack around isql

# isql -U {0} -P {1} -I {2} -S {3} -b -w1000 -i {4} -s `,
# isql -U sa -P agcssapw082012 -I C:\Sybase\isql\interfaces.ini -S AICREP1_RS -b -w1000 -i rs.sql -s `,
# $a=isql -U sa -P agcssapw082012 -I C:\Sybase\isql\interfaces.ini -S AICREP1_RS -w1000 -i rs.sql -b


# result:

# ,  22,DIST      ,Awaiting Wakeup     ,104 HOGEN03.acdprod                     ,
# ,  27,SQT       ,Awaiting Wakeup     ,104:1  DIST HOGEN03.acdprod             ,
# ,  14,SQM       ,Awaiting Message    ,104:1 HOGEN03.acdprod                   ,
# ,  13,SQM       ,Awaiting Message    ,104:0 HOGEN03.acdprod                   ,
# ,  23,DIST      ,Awaiting Wakeup     ,105 HOPNC03.pncprod                     ,
# ,  28,SQT       ,Awaiting Wakeup     ,105:1  DIST HOPNC03.pncprod             ,
# ,  16,SQM       ,Awaiting Message    ,105:1 HOPNC03.pncprod                   ,
# ,  15,SQM       ,Awaiting Message    ,105:0 HOPNC03.pncprod                   ,
# , 132,DSI EXEC  ,Awaiting Command    ,104(1) HOGEN03.acdprod                  ,
# , 131,DSI       ,Awaiting Message    ,104 HOGEN03.acdprod                     ,
# ,  32,REP AGENT ,Awaiting Command    ,HOGEN03.acdprod                         ,
# ,  36,DSI EXEC  ,Awaiting Command    ,105(1) HOPNC03.pncprod                  ,
# ,  35,DSI       ,Awaiting Message    ,105 HOPNC03.pncprod                     ,
# , 140,REP AGENT ,Awaiting Command    ,HOPNC03.pncprod                         ,
# ,  29,DSI EXEC  ,Awaiting Command    ,101(1) REPSERVER1.AICREP1_RS_RSSD       ,
# ,  19,DSI       ,Awaiting Message    ,101 REPSERVER1.AICREP1_RS_RSSD          ,
# ,  12,SQM       ,Awaiting Message    ,101:0 REPSERVER1.AICREP1_RS_RSSD        ,
# ,  20,dSUB      ,Sleeping            ,                                        ,
# ,   9,dCM       ,Awaiting Message    ,                                        ,
# ,  10,dAIO      ,Awaiting Message    ,                                        ,
# ,  24,dREC      ,Sleeping            ,dREC                                    ,
# ,  11,dDELSEG   ,Awaiting Message    ,                                        ,
# , 139,USER      ,Awaiting Command    ,pncprod_rep_agent                       ,
# , 182,USER      ,Awaiting Command    ,sa                                      ,
# , 196,USER      ,Active              ,sa                                      ,
# ,   8,dALARM    ,Awaiting Wakeup     ,                                        ,
# ,  25,dSYSAM    ,Sleeping            ,                                        ,

# Collect Instance and Device information for Sybase ASE

Set-StrictMode -version Latest

New-Variable -Scope Script 'IService'
New-Variable -Scope Script 'SvcSet'
New-Variable -Scope Script 'Config'

# Import-Power 'DBI.ASE'
# Import-Power 'ASE.RS'
Import-Power 'Table'
Import-Power 'Temp'
Import-Power 'ASE.Interfaces'
Import-Power 'Probe'


################################################
#
# Inputs
#
################################################

function StepPre {
    Param([HashTable]$usr,[hashtable]$id)

    $Script:SvcSet = $usr['Service.RepServer']
    $Script:IService = $Script:SvcSet.tables['IService']
    $Script:Config = $id['config']

}


################################################
#
# Outputs
#
################################################

function StepNext {

    $Script:SvcSet.Tables['RSWhoIsDown'].Rows[0]>$null
    # $Script:SvcSet.Tables['Get-Disk']>$null
    # Assert-Table { New-Table_ProbeRecord } $Script:SvcSet.Tables['ProbeRecord']

    return @{
        'Service.RepServer' = $Script:SvcSet;
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

    $RS = New-Object System.Data.DataSet 'Service.RepServer'
    # $ProbeRecord = New-Table_ProbeRecord
    $RS.Tables.Add((New-Object System.Data.DataTable 'RSWhoIsDown'))
    # $RS.Tables.Add($ProbeRecord)

    $WhoIsDown = $RS.Tables['RSWhoIsDown']
    [void]$WhoIsDown.Columns.Add('Hostname',[String])
    [void]$WhoIsDown.Columns.Add('Servicename',[String])
    [void]$WhoIsDown.Columns.Add('Instancename',[String])
    [void]$WhoIsDown.Columns.Add('IsDown',[Int])
    [void]$WhoIsDown.Columns.Add('Message',[String])


    # create interfaces
    $interfacesfn = New-TempFile -Extension '.ini'
    New-ASEInterfaces -Table $Script:SvcSet.Tables['IService'] -Path $interfacesfn
    $infn = New-TempFile -Extension '.sql'
    @"
admin who_is_down
go
"@ | Set-Content $infn

    $RowCount = ($Script:IService|Measure-Object).Count
    $RowNum = 0
    Foreach($Data in $Script:IService) {
        $RowNum += 1

        $computer = $Data['Hostname']
        $instance = $Data['Servicename']
        # $port = $Data['Port']

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

        Write-Progress -Activity "RS who_is_down" -Status "Instance" -CurrentOperation $instance -PercentComplete ($RowNum*100/$RowCount)

        # ISQL
        $cmd = ('isql -U {0} -P {1} -S {2} -I {3} -i {4} -b -w1000' -f $username,$password,$instance,$interfacesfn,$infn)
        # write-host $cmd
        Try {
            $who = (invoke-expression $cmd | Out-String)
            # write-host $who

            $new = $WhoIsDown.NewRow()
            $new['Hostname'] = $computer
            $new['Servicename'] = $instance
            $new['Instancename'] = $instance
            $new['Message'] = $who
            $new['IsDown'] = $false
            if($who.length -gt 0) {
                $new['IsDown'] = $true
            }
            $WhoIsDown.Rows.Add($new)
        }
        Catch {
            Write-Warning ("[Service.Probe.SybaseRS] Probe for Sybase RS failed {0}" -f $_.Exception.Message)
        }


        # $ConnectionString = ("pooling=false;na={0},{1};dsn={2};uid={3};password={4};" -f $computer,$Port,$Instance,$username,$password)
        # $DBi = DBI.ASE\New-DBI "$ConnectionString"
        # Connection string
        # $b = New-Object System.Data.SqlClient.SqlConnectionStringBuilder;
        # $b["Data Source"] = $instance
        # $b["Integrated Security"] = $true
        # $b["Connection Timeout"] = $timeout
        # $b["Database"] = 'master'
        # $dbi = $null
        # $dbi = DBI.ASE\New-DBI $b.ConnectionString

        # If((DBI.ASE\Test-DBI $dbi) -eq 'OPEN') {
        #     Try {
        #         DBI.ASE\Close-DBI $dbi
        #     }
        #     Catch {}
        # }

        # # try to connect and measure how many seconds it takes
        # Try {
        #     $dbi = DBI.ASE\Open-DBI $dbi
        # }
        # Catch {}

        # # Instance RS
        # $Probe = New-Probe -Memo 'Get-RS' -Record $ProbeRecord
        # Invoke-Probe -Probe $Probe -Id $instance -ScriptBlock { ASE.RS\Get-RS $dbi }
        # If($Probe.HasData) {
        #     $RS.Tables['Get-RS'].Merge($Probe.Result)
        # }
        # $Probe = New-Probe -Memo 'Get-Device' -Record $ProbeRecord
        # Invoke-Probe -Probe $Probe -Id $instance -ScriptBlock { ASE.RS\Get-Device $dbi -instancename $instance  }
        # If($Probe.HasData) {
        #     $RS.Tables['Get-Device'].Merge($Probe.Result)
        # }

        # Try {
        #     DBI.ASE\Close-DBI $dbi
        # }
        # Catch {}
    }
    # write-host $interfacesfn
    # copy $interfacesfn C:\sybase\agcs\i.ini
   Remove-Item -Force $infn
   Remove-Item -Force $interfacesfn

    Write-Progress -Activity "RS who_is_down" -Status "Complete" -Completed
    $Script:SvcSet.Merge($RS)
}

