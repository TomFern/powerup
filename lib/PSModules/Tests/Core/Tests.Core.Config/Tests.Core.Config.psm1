# Test Config

Import-Power 'Pester'
Import-Power 'Core.Config' -Reload

Describe "Config" {
    $c = $null
    It "Search-Configs" {
        $c = Search-Config 
        ($c | measure-object).count | Should begreaterthan 0
    }
    It "Get-Config #1" {
        $c = Get-Config 'defaults'
        ($c | measure-object).count | Should begreaterthan 0
    }
    It "Get-Config #2" {
        $c = Get-Config 'defaults'
        ($c['paths'] -is [Array]) | Should Be $true
    }
    It "Get-Config #3" {
        $c = Get-Config 'defaults'
        ($c -is [HashTable]) | Should Be $True
    }
}
