# Test Module

Import-Power 'Pester'
Import-Power 'DBI.ODBC' -Reload

If(-not(Test-Path variable:_TEST) -or(-not($_TEST.ContainsKey('ODBC_ConnectionString'))) -or(-not($_TEST.ContainsKey('ODBC_Driver')))) {
    Write-Warning "Skipping Tests.DBI.ODBC. Value not set: _TEST['ODBC_ConnectionString'] or _TEST['ODBC_Driver']"
    return
}


Describe "DBI.ODBC" {

    $ConnectionString = $_TEST['ODBC_ConnectionString']
    $Driver = $_TEST['ODBC_Driver']

    It "New-DBI #1" {
        { DBI.ODBC\New-DBI -ConnectionString $ConnectionString $Driver } | Should Not Throw
    }
    It "New-DBI #2" {
        $dbi = DBI.ODBC\New-DBI $ConnectionString $Driver
        ($dbi.object | measure-object).count | Should BeGreaterThan 0
        $dbi.interface | Should Be 'ODBC'
        $dbi.provider | Should Be 'ODBC'
        $dbi.ConnectionString.length | Should BeGreaterThan 0
        $dbi.openTime | Should Be (New-TimeSpan)
    }
    It "Test-DBI #1" {
        $dbi = DBI.ODBC\New-DBI $ConnectionString $Driver
        DBI.ODBC\Test-DBI $dbi | Should Be 'CLOSE'
    }
    It "Test-DBI #2" {
        DBI.ODBC\Test-DBI @{} | Should Be 'INVALID'
    }
    It "Open-DBI #1" {
        $dbi = DBI.ODBC\New-DBI $ConnectionString $Driver
        { DBI.ODBC\Open-DBI $dbi } | Should Not Throw
        { DBI.ODBC\Close-DBI $dbi } | Should Not Throw
    }
    It "Open-DBI #2" {
        $dbi = DBI.ODBC\New-DBI $ConnectionString $Driver
        DBI.ODBC\Open-DBI $dbi
        DBI.ODBC\Test-DBI $dbi | Should Be 'OPEN'
        { DBI.ODBC\Close-DBI $dbi } | Should Not Throw
    }
    It "Close-DBI #1" {
        $dbi = DBI.ODBC\New-DBI $ConnectionString $Driver
        DBI.ODBC\Open-DBI $dbi
        { DBI.ODBC\Close-DBI $dbi } | Should Not Throw
        DBI.ODBC\Test-DBI $dbi | Should Be 'CLOSE'
    }
    It "Invoke-DBI #1" {
        $dbi = DBI.ODBC\New-DBI $ConnectionString $Driver
        DBI.ODBC\Open-DBI $dbi
        { DBI.ODBC\Invoke-DBI $dbi "SELECT @@SERVERNAME" } | Should Not Throw
        { DBI.ODBC\Close-DBI $dbi } | Should Not Throw
    }
    It "Invoke-DBI #2" {
        $dbi = DBI.ODBC\New-DBI $ConnectionString $Driver
        DBI.ODBC\Open-DBI $dbi
        $rs = DBI.ODBC\Invoke-DBI $dbi "SELECT @@SERVERNAME AS SERVERNAME"
        ($rs.Tables[0].Rows[0]['SERVERNAME']|Out-String).length | Should BeGreaterThan 0
        { DBI.ODBC\Close-DBI $dbi } | Should Not Throw
    }
}
