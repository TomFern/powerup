# Filter Service Issues for MSSQL Server

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

    $Script:ServiceSet = $usr['Service.MSSQL']
    $Script:IService = $Script:ServiceSet.Tables['IService']

    $Script:ServiceSet.Tables['Get-Uptime'].Rows[0]>$null
    $Script:ServiceSet.Tables['ProbeRecord'].Rows[0]>$null
}


################################################
#
# Outputs
#
################################################

function StepNext {
    Assert-Table { New-Table_Sanity } $Script:ServiceSet.Tables['SanityService']
    return @{
        'Service.MSSQL' = $Script:ServiceSet;
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

    $Script:IService | Foreach {
        $Hostname = $_.Hostname
        $Servicename = $_.Servicename
        $Role = $_.Role

        If(($Script:ServiceSet.Tables['ProbeRecord'].Select("HasData = $True and Id = '$Servicename' and Memo = 'Get-Uptime'") |
             Measure-Object).Count -gt 0) {

            Tabulate $Hostname $Role ("Instance {0}" -f $Servicename) "OK" $false

            If(($Script:ServiceSet.Tables['Get-Uptime'].Select("Servicename = '$Servicename' and IsAgentRunning = 1") |
                Measure-Object).Count -gt 0) {
                Tabulate $Hostname $Role ("Instance {0}" -f $Servicename) "SQL Agent OK" $false
            }
            else {
                Tabulate $Hostname $Role ("Instance {0}" -f $Servicename) "SQL Agent DOWN" $true
            }
        }
        else {
            Tabulate $Hostname $Role ("Instance {0}" -f $Servicename) "Instance is DOWN" $true
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
