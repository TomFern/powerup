# Tests for Table.Mapper

Import-Power 'Pester'
Import-Power 'TableMapper' -Reload

Describe "TableMapper" {

    $ds1 = New-Object System.Data.DataSet 'My:Dataset:1'
    $ds1_t1 = New-Object System.Data.DataTable 'Table1'
    [void]$ds1_t1.Columns.Add('Name',[String])
    [void]$ds1_t1.Columns.Add('Age',[int])
    [void]$ds1_t1.Rows.Add('Foo',12)
    [void]$ds1_t1.Rows.Add('Bar',21)
    $ds1.Tables.Add($ds1_t1)


    It "ConvertTo-Storage #1" {
        $m = New-Table_TableMapper
        { ConvertTo-Storage $m $ds1 } | Should Not Throw
    }
    It "ConvertTo-Storage #2" {
        $m = New-Table_TableMapper
        $all = ConvertTo-Storage $m $ds1
        $all['My_Dataset_1__Table1'].gettype().name | Should Be 'DataTable'
        $m.Rows[0]['MapName'] | Should Be 'My_Dataset_1__Table1'
        $m.Rows[0]['DataSetName'] | Should Be 'My:Dataset:1'
        $m.Rows[0]['TableName'] | Should Be 'Table1'
    }
    It "ConvertTo-Storage #3" {
        $m = New-Table_TableMapper
        $m.Rows.Add('My:Dataset:1','Table1','DS1T1',10,([Datetime](Get-Date)))
        # write-host ($m|ft|out-string)
        $all = ConvertTo-Storage $m $ds1
        $all['DS1T1'].gettype().name | Should Be 'DataTable'
        $m.Rows[0]['LastGenId'] | Should Be 11
        $all['DS1T1'].Rows[0]['__GenId__'] | Should Be 11
    }
    It "ConvertTo-Storage #4" {
        $m = New-Table_TableMapper
        $d = ([DateTime](Get-Date))
        $m.Rows.Add('My:Dataset:1','Table1','DS1T1',10,$d)
        $all = ConvertTo-Storage $m $ds1
        Sleep 1
        # $m.Rows[0].LastGenDate -eq $d | Should Be $true
            [Math]::Abs((New-TimeSpan -Start $m.Rows[0].LastGenDate -End $d).TotalSeconds) | Should BeLessThan 1
    }
    It "ConvertTo-Storage #5" {
        $m = New-Table_TableMapper
        $all = ConvertTo-Storage $m $ds1
        $all = ConvertTo-Storage $m $ds1
        $all['My_Dataset_1__Table1'].gettype().name | Should Be 'DataTable'
        $m.Rows[0]['LastGenId'] | Should Be 2
        $all['My_Dataset_1__Table1'].Rows[0]['__GenId__'] | Should Be 2
        $m.Rows[0]['MapName'] | Should Be 'My_Dataset_1__Table1'
        $m.Rows[0]['DataSetName'] | Should Be 'My:Dataset:1'
        $m.Rows[0]['TableName'] | Should Be 'Table1'
    }
}
