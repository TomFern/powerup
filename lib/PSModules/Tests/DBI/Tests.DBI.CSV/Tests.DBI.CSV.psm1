# Test for DBI.CSV

If($GLOBAL:_PWR['PSARCH'] -ne '32-bit') {
    Write-Warning "Skipping Tests.DBI.CSV. This powershell session is not 32-bit."
    return
}

Import-Power 'Pester'
Import-Power 'DBI.CSV' -Reload
Import-Power 'Temp' -Reload

Describe "DBI.CSV" {

    # this is required so digit separator is not converted, eg from 1.1 to 1,1
    [System.Threading.Thread]::CurrentThread.CurrentCulture = 'en-US'
    [System.Threading.Thread]::CurrentThread.CurrentUICulture = 'en-US'
    
    $csvdir = New-TempDir
    $tab1 = Get-Item (New-TempFile -Path $csvdir -Extension '.csv')
    $tab2 = Get-Item (New-TempFile -Path $csvdir -Extension '.csv')

    $tab1data = New-Object System.Data.DataTable 'tab1data'
    $tab1data.Columns.Add((New-Object System.Data.DataColumn 'Name',([String])))
    $tab1data.Columns.Add((New-Object System.Data.DataColumn 'Race',([String])))
    $tab1data.Columns.Add((New-Object System.Data.DataColumn 'Age',([String])))
    $tab1data.Columns.Add((New-Object System.Data.DataColumn 'Weight',([String])))
    $tab1data.Columns["Race"].DefaultValue = 'Dog'

    $row = $tab1data.NewRow()
    $row.Name = 'Bobby'
    $row.Age = 2
    $row.Weight = 4.2
    $tab1data.Rows.Add($row) | Out-Null
    
    $row = $tab1data.NewRow()
    $row.Name = 'Spot'
    $row.Race = 'Cat'
    $row.Age = 1
    $row.Weight = 2.1
    $tab1data.Rows.Add($row) | Out-Null

    $row = $tab1data.NewRow()
    $row.Name = 'Bianca'
    $row.Race = 'Bird'
    $row.Age = 6
    $row.Weight = 0.5
    $tab1data.Rows.Add($row) | Out-Null

    $tab1data | Export-CSV -NoTypeInformation $tab1

    It "New-DBI #1" {
        $dbi = New-DBI 
        $dbi -is [HashTable]| Should be $true
    }
    It "New-DBI #2" {
        $dbi = New-DBI ("Data Source='$csvdir'")
        $dbi['object'] | Should not be $null
    }
    It "Open-DBI #1" {
        $dbi = New-DBI
        Open-Dbi $dbi
        $dbi['OpenTime'] | Should begreaterthan 0
    }
    It "Open-DBI #2" {
        $dbi = New-DBI ("Data Source='$csvdir'")
        Open-Dbi $dbi
        $dbi['OpenTime'] | Should begreaterthan 0
    }
    It "Test-DBI #1" {
        $dbi = $null
        $dbi = New-DBI ("Data Source='$csvdir'")
        Open-DBI $dbi
        Test-DBI $dbi | Should Be $true
    }
    It "Invoke-DBI #1" {
        $dbi = $null
        $dbi = New-DBI ("Data Source='$csvdir'")
        Open-DBI $dbi
        # $fn = (Get-Item $tab1).Name
        $fn = $tab1.Name
        $rs =  Invoke-DBI $dbi ("Select * from [$fn]")
        ($rs.gettype()).Name | Should be 'DataSet'
    }
    It "Invoke-DBI #2" {
        $dbi = $null
        $dbi = New-DBI ("Data Source='$csvdir'")
        Open-DBI $dbi
        $fn = $tab1.Name
        $rs =  Invoke-DBI $dbi ("Select * from [$fn]")
        $rs.Tables[0].Rows[0].Name | Should Be 'Bobby'
    }
    It "Invoke-DBI #3" {
        $dbi = $null
        $dbi = New-DBI ("Data Source='$csvdir'")
        Open-DBI $dbi
        $fn = $tab1.Name
        $rs = Invoke-DBI $dbi ("Select * from [$fn]")
        $rs.Tables[0].Rows[2].Weight | Should Be 0.5
    }
    It "Invoke-DBI #4" {
        $dbi = $null
        $dbi = New-DBI ("Data Source='$csvdir'")
        Open-DBI $dbi
        $fn = $tab1.Name
        $rs = Invoke-DBI $dbi ("Select * from [$fn]")
        ($rs.Tables[0].Select("name = 'Spot'"))[0].Race | Should Be 'Cat'
    }
    It "Close-DBI #1" {
        $dbi = New-DBI ("Data Source='$csvdir'")
        Open-DBI $dbi
        Close-DBI $dbi
        $dbi.Object.State | Should be 'Closed'
    }
    It "Close-DBI #2" {
        $dbi = New-DBI ("Data Source='$csvdir'")
        Open-DBI $dbi
        Close-DBI $dbi
        Test-DBI $dbi | Should be 'close'
    }
    It "Write-DBI #1" {
        $dbi = $null
        $dbi = New-DBI ("Data Source='$csvdir'")
        Open-DBI $dbi
        $fn = $tab2.name
        Write-DBI $dbi $tab1data $fn -create 
        $tab2 -ne $null | Should Be $true
    }
    It "Write-DBI #2" {
        $dbi = $null
        $dbi = New-DBI ("Data Source='$csvdir'")
        Open-DBI $dbi
        $fn = $tab2.name
        rm -force $tab2
        Write-DBI $dbi $tab1data $fn -create
        ((Compare-Object (Get-Content $tab1) (Get-Content $tab2)) -eq $null) | Should Be $true
    }
     It "Remove-TempFiles" {
        (Remove-TempFiles | Measure-Object).Count | Should Be 0
    }
    It "Remove TempDir" {
        (Remove-TempDir | Measure-Object).Count | Should Be 0
    }
}
