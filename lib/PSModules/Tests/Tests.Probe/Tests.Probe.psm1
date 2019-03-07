# Tests for Probe

Import-Power 'Pester'
Import-Power 'Probe' -Reload

Describe "Probe" {

    It "New-Probe #1" {
        { New-Table_ProbeRecord } | Should Not Throw
        { New-Probe -Memo probe1 } | Should Not Throw
    }
    It "New-Probe #2" {
        $Probe = New-Probe -Memo probe1
        $Probe.Memo | Should Be probe1
    }
    It "Invoke-Probe #1" {
        $Probe = New-Probe -Memo probe1
        { Invoke-Probe -Probe $Probe -Id Id1 { New-Object System.Data.DataTable } } | Should Not Throw
    }
    It "Invoke-Probe #2" {
        $Probe = New-Probe -Memo probe1
        Invoke-Probe -Probe $Probe -Id Id1 { New-Object System.Data.DataTable }
        $Probe.HasData |  Should Be $false
        $Probe.ErrorMessage | Should Be ""
        $Probe.TableCount | Should Be 1
        $Probe.RowCount | Should Be 0
        $Probe.Result.Gettype().Name |  Should Be 'DataTable'
        $Probe.Record.Rows[0].HasData | Should Be $false
        $Probe.Record.Rows[0].ErrorMessage | Should Be ""
        $Probe.Record.Rows[0].TableCount | Should Be 1
        $Probe.Record.Rows[0].RowCount | Should Be 0
    }
    It "Invoke-Probe #3" {
        $Probe = New-Probe -Memo probe1 -AllowEmpty
        Invoke-Probe -Probe $Probe -Id Id1 { New-Object System.Data.DataTable }
        $Probe.HasData |  Should Be $true
        $Probe.ErrorMessage | Should Be ""
        $Probe.TableCount | Should Be 1
        $Probe.RowCount | Should Be 0
        $Probe.Result.Gettype().Name |  Should Be 'DataTable'
        $Probe.Record.Rows[0].HasData | Should Be $true
        $Probe.Record.Rows[0].ErrorMessage | Should Be ""
        $Probe.Record.Rows[0].TableCount | Should Be 1
        $Probe.Record.Rows[0].RowCount | Should Be 0
    }
    It "Invoke-Probe #4" {
        $Probe = New-Probe -Memo probe1
        $Tab = New-Object System.Data.DataTable 'Table1'
        [void]$Tab.Columns.Add('Name',[String])
        [void]$Tab.Rows.Add('Foo')
        Invoke-Probe -Probe $Probe -Id Id1 { return ,$Tab }
        $Probe.HasData |  Should Be $true
        $Probe.ErrorMessage | Should Be ""
        $Probe.TableCount | Should Be 1
        $Probe.RowCount | Should Be 1
        $Probe.Result.Gettype().Name |  Should Be 'DataTable'
        $Probe.Record.Rows[0].HasData | Should Be $true
        $Probe.Record.Rows[0].ErrorMessage | Should Be ""
        $Probe.Record.Rows[0].TableCount | Should Be 1
        $Probe.Record.Rows[0].RowCount | Should Be 1
    }
    It "Invoke-Probe #5" {
        $Probe = New-Probe -Memo probe1 -AllowEmpty
        Invoke-Probe -Probe $Probe -Id Id1 { NonExistentCommand }
        $Probe.HasData |  Should Be $false
        $Probe.ErrorMessage.Length | Should BeGreaterThan 0
        $Probe.TableCount | Should Be 0
        $Probe.RowCount | Should Be 0
        $Probe.Record.Rows[0].HasData | Should Be $false
        $Probe.Record.Rows[0].ErrorMessage.Length | Should BeGreaterThan 0
        $Probe.Record.Rows[0].TableCount | Should Be 0
        $Probe.Record.Rows[0].RowCount | Should Be 0
    }
    It "Invoke-Probe #6" {
        $Probe = New-Probe -Memo probe1
        $Tab = New-Object System.Data.DataTable 'Table1'
        [void]$Tab.Columns.Add('Name',[String])
        [void]$Tab.Rows.Add('Foo')
        Invoke-Probe -Probe $Probe -Id Id1 { return ,$Tab }
        $Probe = New-Probe -Memo probe2 -Record $Probe.Record
        Invoke-Probe -Probe $Probe -Id Id2 { return ,$Tab }
        ($Probe.Record.Rows | Measure-Object).Count | Should Be 2
    }
}
