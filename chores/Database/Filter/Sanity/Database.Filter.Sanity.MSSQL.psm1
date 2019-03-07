# Filter Database Issues for MSSQL Server

Set-StrictMode -version Latest

New-Variable -Scope Script 'IService'
New-Variable -Scope Script 'DBSet'


################################################
#
# Inputs
#
################################################

function StepPre {
    Param([HashTable]$usr,[HashTable]$ctrl)

    $Script:DBSet = $usr['Database.MSSQL']
    $Script:IService = $Script:DBSet.Tables['IService']

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
        'Database.MSSQL' = $Script:DBSet;
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

        $UptimeDB | Foreach {
            $Database = $_.Database
            $IsFailed = $_.IsDBFailed
            $IsReadOnly = $_.IsDbReadOnly
            # write-warning $database

            If([DBNull]::Value.Equals($_.MirrorState)) { $MirrorState = '' }
            else { $MirrorState = $_.MirrorState }

            If([DBNull]::Value.Equals($_.LogshipState)) { $LSState = '' }
            else { $LSState = $_.LogshipState }

            If([DBNull]::Value.Equals($_.MirrorWitnessState)) { $WitnessState = '' }
            else { $WitnessState = $_.MirrorWitnessState }

            If($IsFailed) {
                Tabulate $Hostname $Role "$Servicename ~ Database $Database" "FAILED" $true
            }
            elseif(@('DISCONNECTED','SYNCHRONIZING','PENDING_FAILOVER','SUSPENDED','UNSYNCHRONIZED') -contains $MirrorState) {
                Tabulate $Hostname $Role "$Servicename ~ Database Mirror $Database" $MirrorState $true
            }
            elseif(@('UNKNOWN','DISCONNECTED') -contains $WitnessState) {
                Tabulate $Hostname $Role "$Servicename ~ Witness Mirror $Database" $WitnessState $true
            }
            elseif($LSState -eq 'NOSYNC') {
                Tabulate $Hostname $Role "$Servicename ~ Database LogShipping $Database" $LSState $true
            }
            # elseif($IsReadOnly) {
            #     Tabulate $Hostname $Role "Database $Database" "Read-Only" $true
            # }
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

