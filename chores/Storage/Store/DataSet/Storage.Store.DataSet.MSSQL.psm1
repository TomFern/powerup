# Generic Storage for tables on SQL Server

Set-StrictMode -version Latest

New-Variable -Scope Script 'EveryUsr'
New-Variable -Scope Script 'Config'

Import-Power 'TableMapper'
Import-Power 'DBI.MSSQL'


################################################
#
# Inputs
#
################################################

function StepPre {
    Param([HashTable]$usr,[HashTable]$Id)

    $Script:EveryUsr = $usr
    $Script:Config = $id['config']['mssql']

}


################################################
#
# Outputs
#
################################################

function StepNext {
    return @{}
}


################################################
#
# Process
#
################################################

function StepProcess {

    $ConnectionString = $Script:Config['storage']['connection_string']
    $Schema = $Script:Config['storage']['schema']

    $dbi = DBI.MSSQL\New-DBI $ConnectionString

    try {
        $dbi = DBI.MSSQL\Open-DBI $dbi
    }
    catch {
        Write-Warning ("[Store.Database.MSSQL] Connection to failed for: {0}. Error was: {1}" -f $instance,$_.Exception.Message)
    }

    If((DBI.MSSQL\Test-DBI $dbi) -eq 'OPEN') {

        # TableMapper should exist
        $Mapper = New-Table_TableMapper
        Try {
            Import-BulkCopy -DBI $DBi -Table $Mapper -Create
        }
        Catch {
            Write-Warning ("[Store.Database.MSSQL] Error creating TableMaper table: {0}" -f $_.Exception.Message)
        }

        $Mapper = New-Object System.Data.DataTable
        Try {
            $Mapper = DBI.MSSQL\Invoke-DBI  $dbi -Query "SELECT * FROM $Schema.TableMapper"
        }
        Catch {
            Write-Warning ("[Store.Database.MSSQL] No TableMapper found in schema: $schema")
            return
        }
        $Mapper = $Mapper.Tables[0]

        # For each DS, convert tables and insert on database
        Foreach($key in $Script:EveryUsr.Keys) {
            $Converted = @{}
            if($Script:EveryUsr[$key].gettype().name -eq 'DataSet') {
                $DSName = $key
                $Script:EveryUsr[$key].DataSetName = $DSName
                $Converted = ConvertTo-Storage $Mapper $Script:EveryUsr[$key]
                Foreach($tname in $Converted.Keys) {
                    Write-Verbose "[Store.Database.MSSQL] Inserting table $tname from dataset $DSName"
                    Import-BulkCopy -DBI $DBi -Table $Converted[$tname] -Create
                }
            }
        }

        # Update TableMapper
        Try {
            $ignore = DBI.MSSQL\Invoke-DBI -DBI $DBI -Query "DELETE FROM $Schema.TableMapper"
            Import-BulkCopy -DBI $DBi -Table $Mapper -TableName TableMapper
        }
        Catch {
            Write-Warning ("[Store.Database.MSSQL] Failed to update TableMapper. Error was {0}" -f $_.Exception.Message)
        }
    }
    else {
        Write-Warning ("[Store.Database.MSSQL] Connection is not open: {0}" -f $instance)
    }
}


