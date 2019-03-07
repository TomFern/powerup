# Test Module

If(-not($GLOBAL:_PWR['ELEVATED'])) {
    Write-Warning "Skip testing for MSSQL.Checkinstall: Session is not elevated"
    return
}

Import-Power 'Pester'
Import-Power 'Windows.Installer' -Reload

Describe "MSSQL.Checkinstall" {
    It "Get-InstalledPackages #1" {
        { Windows.Installer\Get-InstalledPackages } | Should Not Throw
    }
    It "Get-InstalledPackages #2" {
        { Windows.Installer\Get-InstalledPackages -Computer $GLOBAL:_PWR['CURRENT_HOSTNAME']} | Should Not Throw
    }
    It "Get-InstalledPackages #3" {
        { Windows.Installer\Get-InstalledPackages -FilterProduct "."} | Should Not Throw
    }
    It "Get-InstalledPackages #4" {
        $result = Windows.Installer\Get-InstalledPackages
        ($result.Select("InstallType = 'Product'") | Measure-Object).Count | Should BeGreaterThan 0
        ($result.Select("InstallType = 'Patch'") | Measure-Object).Count | Should BeGreaterThan 0
    }
}
