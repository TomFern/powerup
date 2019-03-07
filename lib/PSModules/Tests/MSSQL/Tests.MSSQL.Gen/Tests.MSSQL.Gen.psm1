# Test module

Import-Power 'Pester'
Import-Power 'MSSQL.Gen' -Reload

Describe "Tests.MSSQL.Gen" {

    $Tab = New-Object System.Data.DataTable 'TestTable'
    [void]$Tab.Columns.Add('Name','String')
    [void]$Tab.Columns.Add('Age','Int')
    [void]$Tab.Columns.Add('Weight','Float')

    It "Get-TableDDL #1" {
        { Get-TableDDL $Tab } | Should Not Throw
    }
    It "Get-TableDDL #2" {
        $ddl = Get-TableDDL $Tab
        $ddl.Length | Should BeGreaterThan 0
    }
    It "Get-TableDDL #3" {
        $ddl = Get-TableDDL $Tab -Overwrite
        $ddl.Length | Should BeGreaterThan 0
    }
}

