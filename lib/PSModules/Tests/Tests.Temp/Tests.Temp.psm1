# Test Tempfiles

Import-Power 'Pester'
Import-Power 'Temp' -Reload

Describe "Temp" {
    $tmpfn1 = $null
    $tmpfn2 = $null
    $tmpfn3 = $null
    $tmpfn4 = $null
    $tmpdn1 = $null
    $tmpdn2 = $null

    It "New-TempFile #1" {
        $tmpfn1 = New-TempFile
        Test-Path $tmpfn1 | Should Be $true
    }
    It "New-TempFile #2" {
        $tmpfn2 = New-TempFile -Extension '.test'
        Test-Path $tmpfn2 | Should Be $true
    }
    It "New-TempFile #3" {
        $tmpfn3 = New-TempFile -Path ".\tmp"
        Test-Path $tmpfn3 | Should Be $true
    }
    It "New-TempDir #1" {
        $tmpdn1 = New-TempDir
        Test-Path -PathType container $tmpdn1 | Should Be $true
    }

    It "New-TempDir #2" {
        $tmpdn2 = New-TempDir
        $tmpfn4 = New-TempFile -Path $tmpdn2
        Test-Path -PathType leaf $tmpfn4 | Should Be $true
    }

    It "Remove-TempFiles #1" {
        (Remove-TempFiles | Measure-Object).count | Should Be 0
    }
    It "Remove-Tempfiles #2" {
        (Remove-TempDir | Measure-Object).count | should be 0
    }
}


