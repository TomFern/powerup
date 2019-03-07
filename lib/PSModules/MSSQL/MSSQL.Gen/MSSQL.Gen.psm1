# DDL/GEN for SQL Server

Function Get-TableDDL {
<#
    .SYNOPSIS
        Generate DDL for DataTable
    .DESCRIPTION
        Get a create table DDL from a DataTable
    .PARAMETER Table
        Source DataTable
    .PARAMETER Overwrite
        [Switch] Drop and create table if exists, deletes previous table.
    .LINK

    .EXAMPLE
        $ddl = Get-TableDDL $MyTable
        Invoke-DBI -DBI $dbi -query $ddl
#>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)][Object]$Table,
        [Switch]$Overwrite
    )
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    If(-not($Table.GetType().Name -eq 'DataTable')) {
        Throw "[Get-TableDDL] Not a DataTable"
    }

    $Name = $Table.TableName
    If(-not($Name)) {
        Throw "[Get-TableDDL] Table has no name"
    }

    $nl = [Environment]::Newline
    $ddl = ""

    # if exists/drop goes here
    If(-not($Overwrite)) {
        $ddl += ("IF OBJECT_ID (N'{0}', N'U') IS NULL {1}BEGIN{1}" -f $Name,$nl)
    }
    else {
        $ddl += ("IF OBJECT_ID (N'{0}', N'U') IS NOT NULL {1}BEGIN{1}DROP TABLE [{0}]{1}" -f $Name,$nl)
    }

    $ddl += ("CREATE TABLE [$Name] ($nl" -f $Name)
    $coldef = @()
    Foreach($Column in $Table.Columns) {
        $Name = $Column.ColumnName
        $Type = $Table.Columns[$Column.ColumnName].DataType
        $DBType = ""
        Switch($Type) {
            "String" { $DBType = "NVARCHAR(MAX)" }
            "Char" { $DBType = "NCHAR(1)" }
            "Int" { $DBType = "INT" }
            "Byte" { $DBType = "TINYINT" }
            "Long" { $DBType = "BIGINT" }
            "Decimal" { $DBType = "REAL" }
            "Float" { $DBType = "REAL" }
            "Single" { $DBType = "FLOAT(24)" }
            "Double" { $DBType = "FLOAT(53)" }
            "DateTime" { $DBType = "FLOAT" }
            "Bool" { $DBType = "BIT" }
        }
        $coldef += ('[{0}] {1}' -f $Name,$DBType)
    }
    $ddl += ($coldef -join ",$nl")
    $ddl += ")$nl"
    $ddl += "END;"

    return $ddl
} # end function Get-TableDDL

