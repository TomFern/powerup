# Test module

Import-Power 'Pester'
Import-Power 'Table'
Import-Power 'DBI.MSSQL'
Import-Power 'MSSQL.Uptime' -Reload

If(-not(Test-Path variable:_TEST) -or(-not($_TEST.ContainsKey('SQL_ConnectionString')))) {
    Write-Warning "Skipping Tests.MSSQL.Uptime. Value not set: _TEST['SQL_ConnectionString']"
    return
}


Describe "Tests.MSSQL.Uptime" {

    $ConnectionString = $_TEST['SQL_ConnectionString']

    It "Open-DBI #1" {
        $dbi = DBI.MSSQL\New-DBI $ConnectionString
        { DBI.MSSQL\Open-DBI $dbi } | Should Not Throw
        { DBI.MSSQL\Close-DBI $dbi } | Should Not Throw
    }
    It "Get-Uptime #1" {
        $dbi = DBI.MSSQL\New-DBI $ConnectionString
        { DBI.MSSQL\Open-DBI $dbi } | Should Not Throw
        { MSSQL.Uptime\Get-Uptime $dbi } | Should Not Throw
        { DBI.MSSQL\Close-DBI $dbi } | Should Not Throw
    }
    It "Get-Uptime #2" {
        $dbi = DBI.MSSQL\New-DBI $ConnectionString
        { DBI.MSSQL\Open-DBI $dbi } | Should Not Throw
        $result = MSSQL.Uptime\Get-Uptime $dbi
        ($result | Measure-Object).Count | Should BeGreaterThan 0
        $result.Rows[0].Hostname | Should Be $GLOBAL:_PWR['CURRENT_HOSTNAME']
        # $result.Rows[0].OpenTimeMs | Should BeGreaterThan 0
        $result.Rows[0].OwnedDrives.Length | Should BeGreaterThan 0
        { DBI.MSSQL\Close-DBI $dbi } | Should Not Throw
    }
    It "Get-Database #1" {
        $dbi = DBI.MSSQL\New-DBI $ConnectionString
        { DBI.MSSQL\Open-DBI $dbi } | Should Not Throw
        { MSSQL.Uptime\Get-Database $dbi } | Should Not Throw
        { DBI.MSSQL\Close-DBI $dbi } | Should Not Throw
    }
    It "Get-Database #2" {
        $dbi = DBI.MSSQL\New-DBI $ConnectionString
        { DBI.MSSQL\Open-DBI $dbi } | Should Not Throw
        $result = MSSQL.Uptime\Get-Database $dbi
        ($result | Measure-Object).Count | Should BeGreaterThan 0
        $result.Rows[0].Hostname | Should Be $GLOBAL:_PWR['CURRENT_HOSTNAME']
        ($result.Select("Database = 'master'") | Measure-Object).Count | Should BeGreaterThan 0
        { DBI.MSSQL\Close-DBI $dbi } | Should Not Throw
    }
    It "Get-Disk #1" {
        $dbi = DBI.MSSQL\New-DBI $ConnectionString
        { DBI.MSSQL\Open-DBI $dbi } | Should Not Throw
        { MSSQL.Uptime\Get-Disk $dbi } | Should Not Throw
        { DBI.MSSQL\Close-DBI $dbi } | Should Not Throw
    }
    It "Get-Disk #2" {
        $dbi = DBI.MSSQL\New-DBI $ConnectionString
        { DBI.MSSQL\Open-DBI $dbi } | Should Not Throw
        $result = MSSQL.Uptime\Get-Disk $dbi
        ($result | Measure-Object).Count | Should BeGreaterThan 0
        $result.Rows[0].Hostname | Should Be $GLOBAL:_PWR['CURRENT_HOSTNAME']
        ($result.Select("Letter = 'C'") | Measure-Object).Count | Should BeGreaterThan 0
        { DBI.MSSQL\Close-DBI $dbi } | Should Not Throw
    }
}
