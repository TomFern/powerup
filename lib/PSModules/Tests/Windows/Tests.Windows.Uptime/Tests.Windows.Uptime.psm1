# Test Module

Import-Power 'Pester'
Import-Power 'Windows.Uptime' -Reload

Describe "Windows.Uptime" {
    It "Get-Uptime #1" {
        { Windows.Uptime\Get-Uptime } | Should Not Throw
    }
    It "Get-Uptime #2" {
        { Windows.Uptime\Get-Uptime -Computer $GLOBAL:_PWR['CURRENT_HOSTNAME'] } | Should Not Throw
    }
    It "Get-Uptime #3" {
        $diag = Windows.Uptime\Get-Uptime -Computer $GLOBAL:_PWR['CURRENT_HOSTNAME']
        $diag.Rows[0].Hostname | Should be $GLOBAL:_PWR['CURRENT_HOSTNAME']
        $diag.Rows[0].Up | Should Be $true
        $diag.Rows[0].Uptime | Should BeGreaterThan 0
    }
    It "Get-Disk #1" {
        { Windows.Uptime\Get-Disk } | Should Not Throw
    }
    It "Get-Disk #2" {
        { Windows.Uptime\Get-Disk -Computer $GLOBAL:_PWR['CURRENT_HOSTNAME'] } | Should Not Throw
    }
    It "Get-Disk #3" {
        { Windows.Uptime\Get-Disk -includeDrives 'C' -Computer $GLOBAL:_PWR['CURRENT_HOSTNAME'] } | Should Not Throw
    }
    It "Get-Disk #4" {
        $disk = Windows.Uptime\Get-Disk -Computer $GLOBAL:_PWR['CURRENT_HOSTNAME']
        $disk.Rows[0].Hostname | Should Be $GLOBAL:_PWR['CURRENT_HOSTNAME']
        $disk.Rows[0].Letter | Should Be 'C'
        $disk.Rows[0].SizeB | Should BeGreaterThan 0
        $disk.Rows[0].UsedB | Should BeGreaterThan 0
        $disk.Rows[0].FreePercent | Should BeGreaterThan 0
        $disk.Rows[0].UsedPercent | Should BeGreaterThan 0
        $disk.Rows[0].FillFigure | Should BeGreaterThan 0
    }

}
