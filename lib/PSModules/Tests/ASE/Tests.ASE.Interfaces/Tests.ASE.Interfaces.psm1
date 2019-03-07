# Tests for module

Import-Power 'Pester'
Import-Power 'ASE.Interfaces' -Reload
Import-Power 'Inventory'
Import-Power 'Temp'


Describe "ASE.Interfaces" {

    $IService = New-Table_IService

    $row = $IService.NewRow()
    $row.Hostname = "Fizz"
    $row.Instancename = "Foo"
    $row.Port = "1234"
    $IService.Rows.Add($row)

    $row = $IService.NewRow()
    $row.Hostname = "Baz"
    $row.Instancename = "Bar"
    $row.Port = "5678"
    $IService.Rows.Add($row)

    It "New-ASEInterfaces #1" {
        $tempfn = New-TempFile -Extension '.ini'
        { New-ASEInterfaces $IService $tempfn } | Should not Throw
        $content = Get-Content $tempfn
        $content.length | Should BeGreaterThan 0
    }
    It "New-ASEInterfaces #2" {
        $tempfn = New-TempFile -Extension '.unix'
        { New-ASEInterfaces $IService $tempfn -Format 'UNIX' } | Should not Throw
        $content = Get-Content $tempfn
        $content.length | Should BeGreaterThan 0
    }
    # It "Remove TempFiles" {
    #     Remove-TempFile | Should Be @{}
    # }
}
