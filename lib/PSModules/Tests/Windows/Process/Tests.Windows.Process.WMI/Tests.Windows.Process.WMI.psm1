# Test Tests.Windows.Process.WMI

Import-Power 'Pester'
Import-Power 'Windows.Process.WMI' -Reload
Import-Power 'Temp' -Reload

$tmpfn = New-TempFile -Extension '.bat'
'TIMEOUT 1' | Set-Content $tmpfn

Describe "Windows.Process.WMI" {
    It "Temp file" {
        $tmpfn | Should Be $true
    }
    $pd = $null
    It "New-Process" {
        $pd = New-Process -Program "cmd" -ArgumentList @('/C',$tmpfn)
        $pd | Should Not Be $null
    }
    It "Start-Process" {
        $pd = New-Process -Program "cmd" -ArgumentList @('/C',$tmpfn)
        Start-Process $pd
        $pd['PID'] | Should Not Be $null
        $pd['Started'] | Should Be $True
    }
    It "Test-Process Exists" {
        $pd = New-Process -Program "cmd" -ArgumentList @('/C',$tmpfn)
        Start-Process $pd
        Test-Process $pd
        $pd['Exists'] | Should be $true
        $pd['ImageName'] | Should not be $null
    }
    It "Test-Process Not Exists" {
        $pd = New-Process -Program "cmd" -ArgumentList @('/C',$tmpfn)
        Start-Process $pd
        sleep 2
        Test-Process $pd
        $pd['Exists'] | Should be $false
    }
    It "Remove Temp File" {
        Remove-Item $tmpfn
        Test-Path $tmpfn |Should Be $false
    }
}

