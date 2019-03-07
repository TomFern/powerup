# Tests for Table

Import-Power 'Pester'
Import-Power 'Table' -Reload
Import-Power 'Temp' -Reload
Import-Power 'Inventory'

Describe "Table" {

    $listfn = New-TempFile -Extension '.list'
    $csvfn = New-TempFile -Extension '.csv'
    $samplecsv = Join-Path $GLOBAL:_PWR['SAMPLEDIR'] 'IService.csv'
    $tempdir = $GLOBAL:_PWR['TMPDIR']

    It "New-Table #1" {
        $tab = New-Table 'People'
        ($tab.gettype()|Select -Property Name).Name | Should Be 'DataTable'
    }
    It "New-Table #2" {
        $tab = New-Table 'People'
        $tab.TableName | Should Be 'People'
    }
    It "Add-TableColumn #1" {
        $tab = New-Table 'People'
        Add-TableColumn $tab 'Name' "String"
        $tab.Columns[0].ColumnName | Should be 'Name'
    }
    It "Add-TableColumn #2" {
        $tab = New-Table 'People'
        Add-TableColumn $tab 'Name' "String"
        $tab.Columns[0].DataType | Should be 'String'
    }
    It "Add Rows #1" {
        $tab = New-Table 'People'
        Add-TableColumn $tab 'Name' "String"
        Add-TableColumn $tab 'Age' "Int"
        $row = $tab.NewRow()
        $row.Name = 'Foo'
        $row.Age = '30'
        $tab.Rows.Add($row)
        $tab.Rows[0].Name | Should be 'Foo'
    }
    It "Add Rows #2" {
        $tab = New-Table 'People'
        Add-TableColumn $tab 'Name' "String"
        Add-TableColumn $tab 'Age' "Int"
        $row = $tab.NewRow()
        $row.Name = 'Foo'
        $row.Age = '30'
        $tab.Rows.Add($row)
        $tab.Rows[0].Age | Should be 30
    }
    It "New-Table #3" {
        $tab = New-Table 'People'
        Add-TableColumn $tab 'Name' "String"
        Add-TableColumn $tab 'Age' "Int"
        $row = $tab.NewRow()
        $row.Name = 'Foo'
        $row.Age = '30'
        $tab.Rows.Add($row)
        $copy = New-Table 'Copy-Table' $tab
        $copy.Rows[0].Name | Should be 'Foo'
    }
    It "New-Table #4" {
        $tab = New-Table 'People'
        Add-TableColumn $tab 'Name' "String"
        Add-TableColumn $tab 'Age' "Int"
        $row = $tab.NewRow()
        $row.Name = 'Foo'
        $row.Age = '30'
        $tab.Rows.Add($row)
        $copy = New-Table 'ACopy' $tab
        $copy.Rows[0].Age | Should be 30
    }
    It "New-Table #5" {
        $tab = New-Table 'People'
        Add-TableColumn $tab 'Name' "String"
        Add-TableColumn $tab 'Age' "Int"
        $row = $tab.NewRow()
        $row.Name = 'Foo'
        $row.Age = '30'
        $tab.Rows.Add($row)
        $row = $tab.NewRow()
        $row.Name = 'Bar'
        $row.Age = '32'
        $tab.Rows.Add($row)
        $copy = New-Table 'Example' $tab
        $copy.Rows[1].Name | Should be 'Bar'
    }
    It "Invoke-Table #1" {
        $tab = New-Table 'People'
        Add-TableColumn $tab 'Name' "String"
        Add-TableColumn $tab 'Age' "Int"

        $row = $tab.NewRow()
        $row.Name = 'Foo'
        $row.Age = '30'
        $tab.Rows.Add($row)

        $row = $tab.NewRow()
        $row.Name = 'Bar'
        $row.Age = '32'
        $tab.Rows.Add($row)

        function concat {
            $text="";
            {
                param($cat="")
                $script:text += $cat
                $text
            }.GetNewClosure()
        }
        $c = concat

        Invoke-Table -Table $tab {
            Param($row,$data)
            &$c $data['Name']
        } | Out-Null
        &$c | Should Be 'FooBar'
    }
    It "Invoke-Table #2" {
        $tab = New-Table 'People'
        Add-TableColumn $tab 'Name' "String"
        Add-TableColumn $tab 'Age' "Int"

        $row = $tab.NewRow()
        $row.Name = 'Foo'
        $row.Age = '30'
        $tab.Rows.Add($row)

        $row = $tab.NewRow()
        $row.Name = 'Bar'
        $row.Age = '32'
        $tab.Rows.Add($row)

        $script:counter = 0
        Invoke-Table -Table $tab {
            Param($row,$data,$cols,$rnum,$rcount)
            $script:counter = $rcount
        }
        $counter | Should Be 2
    }
    It "Invoke-Table #3" {
        $tab = New-Table 'People'
        Add-TableColumn $tab 'Name' "String"
        Add-TableColumn $tab 'Age' "Int"

        $row = $tab.NewRow()
        $row.Name = 'Foo'
        $row.Age = '30'
        $tab.Rows.Add($row)

        $row = $tab.NewRow()
        $row.Name = 'Bar'
        $row.Age = '32'
        $tab.Rows.Add($row)

        $script:counter = 0
        Invoke-Table -Table $tab {
            Param($row,$data,$cols,$rnum,$rcount)
            $script:counter = $rnum
        }
        $counter | Should Be 1
    }
    It "Invoke-Table #4" {
        $tab = New-Table 'People'
        Add-TableColumn $tab 'Name' "String"
        Add-TableColumn $tab 'Age' "Int"

        $row = $tab.NewRow()
        $row.Name = 'Foo'
        $row.Age = '30'
        $tab.Rows.Add($row)

        $row = $tab.NewRow()
        $row.Name = 'Bar'
        $row.Age = '32'
        $tab.Rows.Add($row)

        Invoke-Table -Table $tab -ScriptBlock {
            Param($row,$data)
            $data['Name'] = 'Fizz'
        }
        $tab.Rows[0].Name | Should be 'Foo'
    }
    It "Invoke-Table #5" {
        $tab = New-Table 'People'
        Add-TableColumn $tab 'Name' "String"
        Add-TableColumn $tab 'Age' "Int"

        $row = $tab.NewRow()
        $row.Name = 'Foo'
        $row.Age = '30'
        $tab.Rows.Add($row)

        $row = $tab.NewRow()
        $row.Name = 'Bar'
        $row.Age = '32'
        $tab.Rows.Add($row)

        $copy = Invoke-Table -Table $tab -ScriptBlock {
            Param($row)
            $row['Name'] = 'Fizz'
        }
        $copy.Rows[0].Name | Should be 'Fizz'
    }
    It "Split-Table #1" {
        $tab = New-Table 'People'
        Add-TableColumn $tab 'Name' "String"
        Add-TableColumn $tab 'Age' "Int"
        Add-TableColumn $tab 'Manager' "Bool"
        $row = $tab.NewRow()
        $row.Name = 'Foo'
        $row.Age = '30'
        $row.Manager = $true
        $tab.Rows.Add($row)
        $copy = Split-Table $tab Name,Age
        $copy.Rows[0].Age | Should be 30
    }
    It "Split-Table #2" {
        $tab = New-Table 'People'
        Add-TableColumn $tab 'Name' "String"
        Add-TableColumn $tab 'Age' "Int"
        Add-TableColumn $tab 'Manager' "Bool"
        $copy = Split-table $tab Name,Age
        ($copy.Columns | Measure-Object).Count | Should be 2
    }
    It "Split-Table #3" {
        $tab = New-Table 'People'
        Add-TableColumn $tab 'Name' "String"
        Add-TableColumn $tab 'Age' "Int"
        Add-TableColumn $tab 'Manager' "Bool"
        $row = $tab.NewRow()
        $row.Name = $null
        $row.Age = '30'
        $row.Manager = $false
        $tab.Rows.Add($row)
        $copy = Split-Table $tab Name,Age
        $copy.Rows[0].Name -eq [DBNull]::Value | Should Be $true
    }
    It "List File" {
        "Foo" | Out-File -Encoding UTF8 $listfn
        "Foo\Bar" | Out-File -Append -Encoding UTF8 $listfn
        "" | Out-File -Append -Encoding UTF8 $listfn
        "Baz" | Out-File -Append -Encoding UTF8 $listfn
        "" | Out-File -Append -Encoding UTF8 $listfn
        (Get-Content $listfn|Measure-Object).Count | Should BeGreaterThan 0
    }
    It "New-TableFromList #1" {
        $tab = New-TableFromList $listfn
        $tab.TableName | Should Be 'New-TableFromList'
    }
    It "New-TableFromList #2" {
        $tab = New-TableFromList $listfn
        $tab.Columns[0].ColumnName | Should Be 'New-TableFromList'
    }
    It "New-TableFromList #3" {
        $tab = New-TableFromList $listfn 'TestColumn' 'TestTable'
        $tab.TableName | Should Be 'TestTable'
    }
    It "New-TableFromList #4" {
        $tab = New-TableFromList $listfn 'TestColumn' 'TestTable'
        $tab.Columns[0].ColumnName | Should Be 'TestColumn'
    }
    It "New-TableFromList #5" {
        $tab = New-TableFromList $listfn 'Service' 'TestTable'
        $tab.Rows[0].Service | Should Be 'Foo'
    }
    It "New-TableFromList #6" {
        $tab = New-TableFromList $listfn 'Service' 'TestTable'
        $tab.Rows[1].Service | Should Be 'Foo\Bar'
    }
    It "New-TableFromList #7" {
        $tab = New-TableFromList $listfn 'Service' 'TestTable'
        ($tab.Rows|Measure-Object).Count | Should Be 3
    }
    It "CSV File" {
        "Hostname,Servicename,Role" | Out-File -Encoding UTF8 $csvfn
        "Foo,Foo,Test" | Out-File -Encoding UTF8 -Append $csvfn
        "Foo,Foo\Bar,Dev" | Out-File -Encoding UTF8 -Append $csvfn
        Get-Content $csvfn | Should be $true
    }
    It "New-TableFromCSV #1" {
        $tab = New-TableFromCSV $csvfn
        $tab.TableName | Should Be "New-TableFromCSV"
    }
    It "New-TableFromCSV #2" {
        $tab = New-TableFromCSV $csvfn
        $tab.Columns[0].ColumnName| Should Be "Hostname"
    }
    It "New-TableFromCSV #3" {
        $tab = New-TableFromCSV $csvfn
        $tab.Rows[1].Servicename| Should Be "Foo\Bar"
    }
    It "New-TableFromCSV #4" {
        $tab = New-TableFromCSV $csvfn
        ($tab.Rows | Measure-Object).Count | Should Be 2
    }
    It "New-TableFromCSV #5" {
        $tab = New-TableFromCSV $csvfn
        ($tab.Rows | Measure-Object).Count | Should Be 2
        $tab.Columns[0].ColumnName | Should Be 'Hostname'
        $tab.Columns[1].ColumnName | Should Be 'Servicename'
        $tab.Columns[2].ColumnName | Should Be 'Role'
    }
    It "New-TableFromCSV #6" {
        {$tab = New-TableFromCSV $samplecsv } |Should Not Throw
    }
    It "New-TableFromCSV #7" {
        $tab = New-TableFromCSV $samplecsv
        ($tab.Rows | Measure-Object).Count | Should Be 4
        $tab.Columns[0].ColumnName | Should Be 'Hostname'
        $tab.Columns[1].ColumnName | Should Be 'Servicename'
        $tab.Columns[2].ColumnName | Should Be 'Instancename'
        $tab.Columns[3].ColumnName | Should Be 'Port'
        $tab.Columns[4].ColumnName | Should Be 'Role'
        $tab.Columns[5].ColumnName | Should Be 'Username'
        $tab.Columns[6].ColumnName | Should Be 'Password'
    }
    It "Join-TableRows #1" {
        $tab1 = New-TableFromCSV $samplecsv
        $tab3 = Join-TableRows $tab1 (New-Table)
        ($tab3|measure-object).count -eq ($tab1|measure-object).count | Should Be $true
    }
    It "Join-TableRows #2" {
        $tab1 = New-TableFromCSV $samplecsv
        $tab2 = New-TableFromCSV $samplecsv
        $tab3 = Join-TableRows $tab1 $tab1
        ($tab3|measure-object).count -eq (($tab1|measure-object).count*2) | Should Be $true
    }
    It "Join-TableRows #3" {
        $tab1 = New-Object System.Data.Datatable
        $tab2 = New-Object System.Data.Datatable
        $tab1.TableName = 'Hola'
        {$tab3 = Join-TableRows $tab1 $tab1} | Should Not Throw
    }

    It "Test-Table #1" {
        $Me = "NOT A TABLE"
        Test-table $Me | Should Be $false
        $He = New-Object System.Data.Datatable 'Hello'
        Test-Table $He | Should Be $true
    }
    It "Assert-Table #1" {
        $Me = "NOT A TABLE"
        $He = New-Object System.Data.Datatable 'Hello'

        { Assert-Table { } $Me } | Should Throw
        { Assert-Table { } $He } | Should Throw
        { Assert-Table { New-Object System.Data.Datatable 'Reference' } $He } | Should Throw
        { Assert-Table { New-TableFromCSV $csvfn } $He } | Should Throw
        $He.Columns.Add('Hostname',[String])
        { Assert-Table { New-TableFromCSV $csvfn } $He } | Should Throw
    }
    It "Assert-Table #2" {
        $He = New-TableFromCSV $csvfn
        { Assert-Table { New-TableFromCSV $csvfn } $He } | Should Not Throw
        $She = $He.Copy()
        $She.Columns.Add('__NEWCOLUMN__',[String])>$null
        { Assert-Table { return ,$She } $He } | Should Throw

    }
    It "Freeze-Table #1" {
        $tab = New-Table 'People'
        Add-TableColumn $tab 'Name' "String"
        Add-TableColumn $tab 'Age' "Int"
        Add-TableColumn $tab 'Nice' "Bool"
        $row = $tab.NewRow()
        $row.Name = 'Foo'
        $row.Age = '30'
        $row.Nice = $true
        $tab.Rows.Add($row)
        $row = $tab.NewRow()
        $row.Name = 'Bar'
        $row.Age = '20'
        $row.Nice = $false
        $tab.Rows.Add($row)
        { Freeze-Table $tab $tempdir } | Should Not Throw
    }
    # It "Import-TableFromCSV #1" {
    #     $tab = New-Table_IService
    #     { Import-TableFromCSV $tab $samplecsv } | Should Not Throw
    # }
    # It "Import-TableFromCSV #2" {
    #     $tab = New-Table_IService
    #     Import-TableFromCSV $tab $samplecsv
    #     { ($tab.Rows | Measure-Object).Count } | Should BeGreaterThan 0
    # }
    It "Unfreeze-Table #1" {
        { UnFreeze-Table 'People' $tempdir } | Should Not Throw
    }
    It "Unfreeze-Table #2" {
        $tab = UnFreeze-Table 'People' $tempdir
        $tab.Columns['Nice'].DataType.Name | Should Be 'Boolean'
        $tab.Rows[1].Name | Should Be 'Bar'
    }
    It "Clean Temp Files" {
        Remove-TempFiles | Should Be $null
    }

}
