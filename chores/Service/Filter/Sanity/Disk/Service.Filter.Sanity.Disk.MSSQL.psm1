# Filter Disk Space for MSSQL Service
# Complement from System:Windows Disk when needed

Set-StrictMode -version Latest

New-Variable -Scope Script 'IService'
New-Variable -Scope Script 'Config'
New-Variable -Scope Script 'ServiceSet'
New-Variable -Scope Script 'SystemSet'


################################################
#
# Inputs
#
################################################

function StepPre {
    Param([HashTable]$usr,[HashTable]$ctrl)

    $Script:ServiceSet = $usr['Service.MSSQL']
    $Script:IService = $Script:ServiceSet.Tables['IService']
    $Script:SystemSet = $usr['System.Windows']
    $Script:Config = $ctrl['Config']['mssql']['sanity']

    $Script:ServiceSet.Tables['Get-Disk'].Rows[0]>$null
    $Script:ServiceSet.Tables['ProbeRecord'].Rows[0]>$null
    $Script:SystemSet.Tables['Get-Disk'].Rows[0]>$null
    $Script:SystemSet.Tables['ProbeRecord'].Rows[0]>$null
}


################################################
#
# Outputs
#
################################################

function StepNext {
    Assert-Table { New-Table_Sanity } $Script:ServiceSet.Tables['SanityDisk']
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
    $Sanity.TableName = 'SanityDisk'
    $MaxFillFigure = $Script:Config['disk']['fillfigure']
    $ExcludeLetters = $Script:Config['disk']['exclude_always']

    function Tabulate {
        Param($Hostname,$Role,$Letter,$Fillfigure,$SizeGB,$UsedGB)
        $row = $Sanity.NewRow()
        $row._GID = [String]$Hostname
        $row._Role = [String]$Role
        $Size = [Math]::Round($SizeGB)
        $Used = [Math]::Round($UsedGB)
        $Free = $Size - $Used

        If(($Fillfigure -ge $MaxFillFigure) -and(-not($ExcludeLetters -contains $Letter))) {
            $row._Attention = $True
        }
        else {
            $row._Attention = $False
        }

        If($Letter) {
            $row.FaultComponent = ("Drive {0}:" -f $Letter)
            $row.FaultMessage = ("Used {0}% - {1}GB of {2}GB ({3}GB free)" -f $Fillfigure,$Used,$Size,$Free)
        }
        else {
            $row.FaultComponent = "Disk info missing."
            $row.FaultMessage = ""
            $row._Attention = $true
        }

        $Sanity.Rows.Add($row)
    }

    $Script:IService | Foreach {
        $Role = $_.Role
        $Servicename = $_.Servicename
        $Hostname = $_.Hostname

        If(($Script:ServiceSet.Tables['ProbeRecord'].Select("HasData = $True and Id = '$Hostname' and Memo = 'Get-Disk'") |
             Measure-Object).Count -gt 0) {
            $Script:ServiceSet.Tables['Get-Disk'].Select("Hostname = '$Hostname'") | Foreach {
                Tabulate $Hostname $Role $_.Letter $_.Fillfigure $_.SizeGB $_.UsedGB
            }
        }
        ElseIf(($Script:SystemSet.Tables['ProbeRecord'].Select("HasData = $True and Id = '$Hostname' and Memo = 'Get-Disk'") |
             Measure-Object).Count -gt 0) {
            $Script:ServiceSet.Tables['Get-Disk'].Select("Hostname = '$Hostname'") | Foreach {
                Tabulate $Hostname $Role $_.Letter $_.Fillfigure $_.SizeGB $_.UsedGB
            }
        }
        Else {
            Tabulate $Hostname $Role "" 100 0 0
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
