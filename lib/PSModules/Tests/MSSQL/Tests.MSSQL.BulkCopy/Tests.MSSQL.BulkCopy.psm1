# Test module

Import-Power 'Pester'
Import-Power 'DBI.MSSQL'
Import-Power 'Table'
Import-Power 'MSSQL.BulkCopy' -Reload

If(-not(Test-Path variable:_TEST) -or(-not($_TEST.ContainsKey('SQL_ConnectionString')))) {
    Write-Warning "Skipping Tests.MSSQL.BulkCopy. Value not set: _TEST['SQL_ConnectionString']"
    return
}


Describe "Tests.MSSQL.BulkCopy" {

    $ConnectionString = $_TEST['SQL_ConnectionString']

    $TableName1 = 'tests_mssql_bulkcopy'

    $Tab = New-Table 'TestTable'
    Add-TableColumn $Tab 'Name' 'String'
    Add-TableColumn $Tab 'Age' 'Int'
    Add-TableColumn $Tab 'Weight' 'Float'

    For($i=0; $i -lt 10000; $i++) {
        $Row = $Tab.NewRow()
        $Row.Name = 'Foo'
        $Row.Age = 10
        $Row.Weight = 1.12
        $Tab.Rows.Add($Row)
    }

    It "Open-DBI #1" {
        $dbi = DBI.MSSQL\New-DBI $ConnectionString
        { DBI.MSSQL\Open-DBI $dbi } | Should Not Throw
        { DBI.MSSQL\Close-DBI $dbi } | Should Not Throw
    }
    It "Create Temp Table #1" {
        $dbi = DBI.MSSQL\New-DBI $ConnectionString
        { DBI.MSSQL\Open-DBI $dbi } | Should Not Throw

        $sql = "IF EXISTS ( SELECT TOP 1 1 FROM sysobjects where name = '$TableName1') drop table [$TableName1]"
        { Invoke-DBI $dbi $sql } | Should Not Throw

        $sql = "create table [$TableName1] (Name Varchar(30), Age int, Weight Float)";
        { Invoke-DBI $dbi $sql } | Should Not Throw

        { DBI.MSSQL\Close-DBI $dbi } | Should Not Throw
    }
    It "Create Temp Table #2" {
        $dbi = DBI.MSSQL\New-DBI $ConnectionString
        { DBI.MSSQL\Open-DBI $dbi } | Should Not Throw

        $Name = $Tab.TableName

        $sql = "IF EXISTS ( SELECT TOP 1 1 FROM sysobjects where name = '$Name') drop table [$Name]"
        { Invoke-DBI $dbi $sql } | Should Not Throw

        $sql = "create table [$Name] (Name Varchar(30), Age int, Weight Float)";
        { Invoke-DBI $dbi $sql } | Should Not Throw

        { DBI.MSSQL\Close-DBI $dbi } | Should Not Throw
    }
    It "Import-BulkCopy #1" {
        $dbi = DBI.MSSQL\New-DBI $ConnectionString
        { DBI.MSSQL\Open-DBI $dbi } | Should Not Throw

        { Import-BulkCopy $dbi $Tab $TableName1 } | Should Not Throw
        { DBI.MSSQL\Close-DBI $dbi } | Should Not Throw
    }
    It "Import-BulkCopy #2" {
        $dbi = DBI.MSSQL\New-DBI $ConnectionString
        { DBI.MSSQL\Open-DBI $dbi } | Should Not Throw

        { Import-BulkCopy $dbi $Tab } | Should Not Throw
        { DBI.MSSQL\Close-DBI $dbi } | Should Not Throw
    }
    It "Import-BulkCopy #2" {
        $dbi = DBI.MSSQL\New-DBI $ConnectionString
        { DBI.MSSQL\Open-DBI $dbi } | Should Not Throw

        { Import-BulkCopy $dbi '__NONEXISTING_TABLE__' } | Should Throw
        { DBI.MSSQL\Close-DBI $dbi } | Should Not Throw
    }
    It "Drop Table #1" {
        $dbi = DBI.MSSQL\New-DBI $ConnectionString
        { DBI.MSSQL\Open-DBI $dbi } | Should Not Throw

        $sql = "IF EXISTS ( SELECT TOP 1 1 FROM sysobjects where name = '$TableName1') drop table [$TableName1]"
        { Invoke-DBI $dbi $sql } | Should Not Throw

        { DBI.MSSQL\Close-DBI $dbi } | Should Not Throw
    }
    It "Drop Table #2" {
        $dbi = DBI.MSSQL\New-DBI $ConnectionString
        { DBI.MSSQL\Open-DBI $dbi } | Should Not Throw

        $Name = $Tab.TableName

        $sql = "IF EXISTS ( SELECT TOP 1 1 FROM sysobjects where name = '$Name') drop table [$Name]"
        { Invoke-DBI $dbi $sql } | Should Not Throw

        { DBI.MSSQL\Close-DBI $dbi } | Should Not Throw
    }

}
