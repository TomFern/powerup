# Bulk Copy for MSSQL

Import-Power 'DBI.MSSQL'

Function Import-BulkCopy
{
<#
.SYNOPSIS
    Bulk Insert into MSSQL Table
.DESCRIPTION
    Inserts all the rows from a DataTable into an existing MSSQL Table

.PARAMTER dbi
    A MSSQL Dbi identifier
.PARAMETER Table
    The input DataTable
.PARAMETER TableName
    The output Table name, defaults to the Table TableName
.PARAMETER BatchSize
    The batch size to use, defaults to 10000.
.PARAMETER Timeout
    Timeout for bulk copy operation, defaults to 60 seconds
.PARAMETER Create
    Create the table first
.EXAMPLE
    $dbi = New-DBI $ConnectionString
    Open-DBI $dbi
    Import-BulkCopy $dbi $Table 'Foo'
#>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)][HashTable]$dbi,
        [Parameter(Mandatory=$true)][Object]$Table,
        [string] $TableName="",
        [int]$BatchSize = 10000,
        [int]$Timeout=60,
        [Switch]$Create
    )
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    if(-not(DBI.MSSQL\Test-DBI $dbi)) {
        Throw "[Import-BulkCopy] dbi is invalid or is not ready"
    }

    if(-not($TableName)) {
        $TableName = $Table.TableName
    }

    If($Create) {
        Write-Verbose "Test table exists"
        $rs = DBI.MSSQL\Invoke-DBI -DBI $dbi -Query "SELECT * FROM sysobjects where name = '$TableName' AND type = 'U'"
        If(($rs.Tables[0]|Measure-Object).Count -eq 0) {
                Write-Verbose "[Import-BulkCopy] Create table $TableName"
                $sqlcol = @()
                $Table.Columns | Foreach {
                    $sqlcol += ("{0} VARCHAR(MAX)" -f $_.ColumnName)
                }
                $sql = ("CREATE TABLE [$TableName] ({0})" -f ($sqlcol -join ','))
                Write-Verbose $sql
                $rs = DBI.MSSQL\Invoke-DBI -DBI $dbi -Query $sql
        }
    }

    $bulkCopy = New-Object ("Data.SqlClient.SqlBulkCopy") $dbi.object
    $bulkCopy.DestinationTableName = $TableName
    $bulkCopy.BatchSize = $BatchSize
    $bulkCopy.BulkCopyTimeout = $Timeout
    $bulkCopy.WriteToServer($Table)
    $bulkCopy.Close()

} # end function Import-BulkCopy
