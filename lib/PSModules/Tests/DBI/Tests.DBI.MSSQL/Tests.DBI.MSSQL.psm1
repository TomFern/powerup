# Test Module

Import-Power 'Pester'
Import-Power 'DBI.MSSQL' -Reload

If(-not(Test-Path variable:_TEST) -or(-not($_TEST.ContainsKey('SQL_ConnectionString')))) {
    Write-Warning "Skipping Tests.DBI.MSSQL. Value not set: _TEST['SQL_ConnectionString']"
    return
}


Describe "DBI.MSSQL" {

    $ConnectionString = $_TEST['SQL_ConnectionString']

    It "New-DBI #1" {
        { DBI.MSSQL\New-DBI -ConnectionString $ConnectionString } | Should Not Throw
    }
    It "New-DBI #2" {
        $dbi = DBI.MSSQL\New-DBI $ConnectionString
        ($dbi.object | measure-object).count | Should BeGreaterThan 0
        $dbi.interface | Should Be 'MSSQL'
        $dbi.provider | Should Be 'ADO.NET'
        $dbi.ConnectionString.length | Should BeGreaterThan 0
        $dbi.openTime | Should Be (New-TimeSpan)
    }
    It "Test-DBI #1" {
        $dbi = DBI.MSSQL\New-DBI $ConnectionString
        DBI.MSSQL\Test-DBI $dbi | Should Be 'CLOSE'
    }
    It "Test-DBI #2" {
        DBI.MSSQL\Test-DBI @{} | Should Be 'INVALID'
    }
    It "Open-DBI #1" {
        $dbi = DBI.MSSQL\New-DBI $ConnectionString
        { DBI.MSSQL\Open-DBI $dbi } | Should Not Throw
        { DBI.MSSQL\Close-DBI $dbi } | Should Not Throw
    }
    It "Open-DBI #2" {
        $dbi = DBI.MSSQL\New-DBI $ConnectionString
        DBI.MSSQL\Open-DBI $dbi 
        DBI.MSSQL\Test-DBI $dbi | Should Be 'OPEN'
        { DBI.MSSQL\Close-DBI $dbi } | Should Not Throw
    }
    It "Close-DBI #1" {
        $dbi = DBI.MSSQL\New-DBI $ConnectionString
        DBI.MSSQL\Open-DBI $dbi 
        { DBI.MSSQL\Close-DBI $dbi } | Should Not Throw
        DBI.MSSQL\Test-DBI $dbi | Should Be 'CLOSE'
    }
    It "Invoke-DBI #1" {
        $dbi = DBI.MSSQL\New-DBI $ConnectionString
        DBI.MSSQL\Open-DBI $dbi 
        { DBI.MSSQL\Invoke-DBI $dbi "SELECT @@SERVERNAME" } | Should Not Throw
        { DBI.MSSQL\Close-DBI $dbi } | Should Not Throw
    }
    It "Invoke-DBI #2" {
        $dbi = DBI.MSSQL\New-DBI $ConnectionString
        DBI.MSSQL\Open-DBI $dbi 
        $rs = DBI.MSSQL\Invoke-DBI $dbi "SELECT @@SERVERNAME AS SERVERNAME"
        ($rs.Tables[0].Rows[0]['SERVERNAME']|Out-String).length | Should BeGreaterThan 0
        { DBI.MSSQL\Close-DBI $dbi } | Should Not Throw
    }
}
