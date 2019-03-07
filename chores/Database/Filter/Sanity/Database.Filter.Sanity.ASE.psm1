# Filter Database Issues for ASE Databases

Set-StrictMode -version Latest

New-Variable -Scope Script 'IService'
New-Variable -Scope Script 'CfgSanity'
New-Variable -Scope Script 'DBSet'


################################################
#
# Inputs
#
################################################

function StepPre {
    Param([HashTable]$usr,[HashTable]$ctrl)

    $Script:DBSet = $usr['Database.ASE']
    $Script:IService = $Script:DBSet.Tables['IService']
    $Script:CfgSanity = $ctrl['Config']['sybase']['sanity']

    $Script:DBSet.Tables['Get-Database'].Rows[0]>$null
    # $Script:DBSet.Tables['UptimeRecord'].Rows[0]>$null
}


################################################
#
# Outputs
#
################################################

function StepNext {
    Assert-Table { New-Table_Sanity } $Script:DBSet.Tables['SanityDatabase']
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
    $Sanity = New-Table_Sanity
    $Sanity.TableName = 'SanityDatabase'

    function Tabulate {
        Param($GID,$Role,$FaultComponent,$FaultMessage,$Attention)

        $row = $Sanity.NewRow()
        $row._GID = [String]$GID
        $row._Role = [String]$Role
        $row._Attention = $Attention
        $row.FaultComponent = $FaultComponent
        $row.FaultMessage = $FaultMessage

        $Sanity.Rows.Add($row)
    }

    $Script:IService | Foreach {
        $Hostname = $_.Hostname
        $Servicename = $_.Servicename
        $Role = $_.Role

        # Filter by instance unless there is only one
        $UptimeDB = New-Object System.Data.DataTable 'Uptime'
        If(($Script:DBSet.Tables['Get-Database']|Select-Object -Property Servicename -Unique|Measure-Object).count -eq 1) {
            $UptimeDB = $Script:DBSet.Tables['Get-Database']
        }
        else {
            $UptimeDB = $Script:DBSet.Tables['Get-Database'].Select("Servicename = '$Servicename'")
        }

        foreach($dbrow in $UptimeDB) {
            $Database = $dbrow.Database
            $IsOnline = $dbrow.IsOnline
            $IsSuspect = $dbrow.IsSuspect
            $DataUsedPct = $dbrow.DataUsedPercent
            if(-not($IsOnline)) {
                Tabulate $Hostname $Role "$Servicename ~ Database $Database" "OFFLINE" $true
            }
            elseif(-not($IsOnline)) {
                Tabulate $Hostname $Role "$Servicename ~ Database $Database" "SUSPECT" $true
            }
            elseif($DataUsedPct -ge $Script:CfgSanity['database']['datafill']) {
                Tabulate $Hostname $Role "$Servicename ~ Database $Database" ("Data {0}%" -f $DataUsedPct) $true
            }
            else {
                Tabulate $Hostname $Role "$Servicename ~ Database $Database" "OK" $false
            }
        }
    }
    $Sanity = $Sanity.DefaultView.ToTable($True)
    $Script:DBSet.Tables.Add($Sanity)
}


function New-Table_Sanity {
    $Table = New-Object System.Data.DataTable 'Sanity'
    [void]$Table.Columns.Add('_GID',[String])
    [void]$Table.Columns.Add('_Attention',[Bool])
    [void]$Table.Columns.Add('_Role',[String])
    [void]$Table.Columns.Add('FaultComponent',[String])
    [void]$Table.Columns.Add('FaultMessage',[String])
    return ,$Table
}


