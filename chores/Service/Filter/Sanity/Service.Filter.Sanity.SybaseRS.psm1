# Filter Service Issues for ASE Server

Set-StrictMode -version Latest

New-Variable -Scope Script 'IService'
New-Variable -Scope Script 'ServiceSet'


################################################
#
# Inputs
#
################################################

function StepPre {
    Param([HashTable]$usr,[HashTable]$ctrl)

    $Script:ServiceSet = $usr['Service.RepServer']
    $Script:IService = $Script:ServiceSet.Tables['IService']

    $Script:ServiceSet.Tables['RSWhoIsDown'].Rows[0]>$null
    # $Script:ServiceSet.Tables['ProbeRecord'].Rows[0]>$null
}


################################################
#
# Outputs
#
################################################

function StepNext {
    Assert-Table { New-Table_Sanity } $Script:ServiceSet.Tables['SanityService']
    return @{
        'Service.RepServer' = $Script:ServiceSet;
    }
}


################################################
#
# Process
#
################################################

function StepProcess {
    $Sanity = New-Table_Sanity
    $Sanity.TableName = 'SanityService'

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

    Foreach($service in $Script:IService) {
        $Hostname = $service.Hostname
        $Servicename = $service.Servicename
        $Role = $service.Role

        If(($Script:ServiceSet.Tables['RSWhoIsDown'].Select("Servicename = '$Servicename' and IsDown = 1") |
            Measure-Object).Count -gt 0) {
            Tabulate $Hostname $Role ("RepServer {0}" -f $Servicename) "Replication DOWN" $true
        }
        else {
            Tabulate $Hostname $Role ("RepServer {0}" -f $Servicename) "Replication OK" $false
        }
    }
    $Sanity = $Sanity.DefaultView.ToTable($True)
    $Script:ServiceSet.Tables.Add($Sanity)
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


