# Filter Cluster Service Issues for MSSQL Server

Set-StrictMode -version Latest

New-Variable -Scope Script 'IService'
New-Variable -Scope Script 'Config'
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

    If(($Script:ServiceSet.Tables['ClusterDefaultHostname'] | Measure-Object).Count -gt 0) {
        $Script:ClusterDefault = $Script:ServiceSet['ClusterDefaultHostname']
        Assert-Table -AllowEmpty { New-Table_ClusterDefault } $Script:ClusterDefault
    }
    else {
        $Script:ClusterDefault = New-Table_ClusterDefault
    }

    $Script:ServiceSet.Tables['Get-Uptime'].Rows[0]>$null
}


################################################
#
# Outputs
#
################################################

function StepNext {
    Assert-Table -AllowEmpty { New-Table_Sanity } $Script:ServiceSet.Tables['SanityCluster']
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
    $Sanity.TableName = 'SanityCluster'

    $Script:ClusterDefault | Foreach {
        $VirtualName = $_.VirtualServiceName
        $DefaultHost = $_.DefaultHostname

        $Script:ServiceSet.Tables['Get-Uptime'].Select(("IsClustered = 1 and Hostname = '{0}'") -f $VirtualName) | Foreach {
            $row = $Sanity.NewRow()
            $row._GID = [String]$_.Hostname
            $row._Role = [String]$_.Role
            $row.FaultComponent = ('Cluster service {0}' -f $_.Servicename)
            $row.FaultMessage = ('Host {0}' -f $_.PhysicalName)
            If($_.PhysicalName -eq $DefaultHost) {
                $row._Attention = $false
            }
            else {
                $row._Attention = $false
            }
            $Sanity.Rows.Add($row)
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

function New-Table_ClusterDefault {
    $Table = New-Object System.Data.DataTable 'Cluster'
    [void]$Table.Columns.Add('VirtualServiceName',[String])
    [void]$Table.Columns.Add('DefaultHostname',[String])
    return ,$Table
}
