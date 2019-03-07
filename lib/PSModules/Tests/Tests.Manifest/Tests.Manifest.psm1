# Test MANIFEST

Import-Power 'Pester'
Import-Power 'Path'


$ManifestFn = ConvertTo-AbsolutePath (Join-Path $GLOBAL:_PWR['BASEDIR'] 'share\MANIFEST')
$ManifestContents = (Get-Content $ManifestFn | Out-String).Trim()

Describe "MANIFEST" {
    It "MANIFEST Exists" {
        Test-Path -PathType leaf $ManifestFn | Should Be $True
    }
    It "MANIFEST Not Empty" {
        $ManifestContents.Length | Should BeGreaterThan 0
    }
    It "Check Files" {
        Get-Content $ManifestFn | Foreach {
            $fn = ($_ | Out-String).Trim()
            If($fn) {
                $testfn = ConvertTo-AbsolutePath (Join-Path $GLOBAL:_PWR['BASEDIR'] $fn)
                Test-Path -PathType leaf $testfn | Should Be $true
            }
        }
    }
}
