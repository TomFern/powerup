# Test for Inventory

Import-Power 'Pester'
Import-Power 'Table' -Reload
Import-Power 'Inventory' -Reload

Describe "Inventory" {

    It "New-Table_IHost #1" {
        $hosts = New-Table_IHost
        $hosts.TableName | Should Be 'IHost'
    }
    It "New-Table_IHost #2" {
        $Old = New-Table 'Dummy'
        Add-TableColumn $Old 'Hostname' 'String'
        $row = $Old.NewRow()
        $row.Hostname = 'Foobar'
        $Old.Rows.Add($row)

        $hosts = New-Table_IHost $Old
        $hosts.Rows[0].Hostname | Should Be 'Foobar'
    }
    It "New-Table_IHost #3" {
        $hosts = New-Table_IHost
        $row = $hosts.NewRow()
        $row.Hostname = 'Foobar'
        $hosts.Rows.Add($row)
        $hosts2 = New-Table_IHost $hosts
        $hosts2.Rows[0].Hostname| Should Be 'Foobar'
        }
    It "New-Table_IHost #4" {

        $hosts = New-Table_IHost
        $row = $hosts.NewRow()
        $row.Hostname = 'Foobar'
        $hosts.Rows.Add($row)

        $row = $hosts.NewRow()
        $row.Hostname = ''
        $row.Role = ''
        $hosts.Rows.Add($row)

        $hosts2 = New-Table_IHost $hosts
        ($hosts2|Measure-Object).Count | Should Be 1
    }
    It "New-Table_IService #1" {
        $svc = New-Table_IService
        $svc.TableName | Should Be 'IService'
    }
    It "New-Table_IService #2" {
        $svc = New-Table_IService

        $row = $svc.NewRow()
        $row.Hostname = "Foo"
        $row.Servicename = "Foo"
        $row.Role = "Prod"
        $svc.Rows.Add($row)

        $row = $svc.NewRow()
        $row.Hostname = "Bar"
        $row.Servicename = "Bar"
        $row.Role = "Dev"
        $svc.Rows.Add($row)
        ($svc.Rows | Measure-Object).Count | Should Be 2
    }
    It "New-Table_IService #3" {
        $svc = New-Table_IService

        $row = $svc.NewRow()
        $row.Hostname = "Foo"
        $row.Servicename = "Foo"
        $row.Role = "Prod"
        $svc.Rows.Add($row)

        $row = $svc.NewRow()
        $row.Hostname = "Bar"
        $row.Servicename = "Bar"
        $row.Role = "Dev"
        $svc.Rows.Add($row)
        $svc.Rows[1].Servicename | Should Be "Bar"
    }
    It "New-Table_IService #4" {
        $svc = New-Table_IService

        $row = $svc.NewRow()
        $row.Hostname = "Foo"
        $row.Servicename = "Foo"
        $row.Role = "Prod"
        $svc.Rows.Add($row)

        $row = $svc.NewRow()
        $row.Hostname = "Bar"
        $row.Servicename = "Bar"
        $row.Role = "Dev"
        $svc.Rows.Add($row)

        $svc2 = New-Table_IService $svc
        ($svc2.Select("Servicename = 'Bar'") | Measure-Object).Count | Should be 1
    }
    It "New-Table_IService #5" {

        $svc = New-Table_IService

        $row = $svc.NewRow()
        $row.Hostname = "Foo"
        $row.Servicename = "Foo"
        $row.Role = "Prod"
        $svc.Rows.Add($row)

        $row = $svc.NewRow()
        $row.Hostname = ""
        $row.Servicename = ""
        $row.Role = "Dev"
        $svc.Rows.Add($row)

        $svc2 = New-Table_IService $svc
        ($svc2|Measure-Object).Count | Should Be 1

    }
    It "ConvertTo-Table_Host #1" {
        $svc = New-Table_IService

        $row = $svc.NewRow()
        $row.Hostname = "Foo"
        $row.Servicename = "Foo"
        $row.Role = "Prod"
        $svc.Rows.Add($row)

        $row = $svc.NewRow()
        $row.Hostname = "Bar"
        $row.Servicename = "Bar"
        $row.Role = "Dev"
        $svc.Rows.Add($row)

        $row = $svc.NewRow()
        $row.Hostname = "Bar"
        $row.Servicename = "Bar\Foobar"
        $row.Role = "Dev"
        $svc.Rows.Add($row)
        $host = ConvertTo-Table_Host $svc
        $host.TableName | Should Be "IHost"
    }
    It "ConvertTo-Table_Host #2" {
        $svc = New-Table_IService
        $row = $svc.NewRow()
        $row.Hostname = "Foo"
        $row.Servicename = "Foo"
        $row.Role = "Prod"
        $svc.Rows.Add($row)

        $row = $svc.NewRow()
        $row.Hostname = "Bar"
        $row.Servicename = "Bar"
        $row.Role = "Dev"
        $svc.Rows.Add($row)

        $row = $svc.NewRow()
        $row.Hostname = "Bar"
        $row.Servicename = "Bar\Foobar"
        $row.Role = "Dev"
        $svc.Rows.Add($row)

        $hosts = ConvertTo-Table_Host $svc
        ($hosts.Rows | Measure-Object).Count | Should Be 2
    }
    It "ConvertTo-Table_Host #3" {
        $svc = New-Table_IService

        $row = $svc.NewRow()
        $row.Hostname = "Foo"
        $row.Servicename = "Foo"
        $row.Role = "Prod"
        $svc.Rows.Add($row)

        $row = $svc.NewRow()
        $row.Hostname = "Bar"
        $row.Servicename = "Bar"
        $row.Role = "Dev"
        $svc.Rows.Add($row)

        $row = $svc.NewRow()
        $row.Hostname = "Bar"
        $row.Servicename = "Bar\Foobar"
        $row.Role = "Dev"
        $svc.Rows.Add($row)

        $hosts = ConvertTo-Table_Host $svc
        ($hosts.Select("","Hostname DESC"))[1].Hostname | Should Be "Bar"
    }
    It "New-Inventory #1" {
        $inv = New-Inventory
        ($inv.tables["IHost"].gettype()).Name -eq 'DataTable' | Should Be $True
    }
    It "New-Inventory #2" {
        $inv = New-Inventory
        ($inv.tables["IService"].gettype()).Name -eq 'DataTable' | Should Be $True
    }
    It "New-Inventory #3" {
        $hosts = New-Table_IHost

        $row = $hosts.NewRow()
        $row.Hostname = "Foo"
        $row.Role = "Prod"
        $hosts.Rows.Add($row)

        $row = $hosts.NewRow()
        $row.Hostname = "Bar"
        $row.Role = "Dev"
        $hosts.Rows.Add($row)

        $svc = New-Table_IService

        $row = $svc.NewRow()
        $row.Hostname = "Foo"
        $row.Servicename = "Foo"
        $row.Role = "Prod"
        $svc.Rows.Add($row)

        $row = $svc.NewRow()
        $row.Hostname = "Bar"
        $row.Servicename = "Bar"
        $row.Role = "Dev"
        $svc.Rows.Add($row)

        $inv = New-Inventory -IHost $hosts -IService $svc
        ($inv.Tables["IHost"].Rows | Measure-Object).Count | Should Be 2

    }
    It "New-Inventory #4" {
        $svc = New-Table_IService

        $row = $svc.NewRow()
        $row.Hostname = "Foo"
        $row.Servicename = "Foo"
        $row.Role = "Prod"
        $svc.Rows.Add($row)

        $row = $svc.NewRow()
        $row.Hostname = "Bar"
        $row.Servicename = "Bar"
        $row.Role = "Dev"
        $svc.Rows.Add($row)

        $inv = New-Inventory -IService $svc
        ($inv.Tables["IHost"].Rows | Measure-Object).Count | Should Be 2
    }
    It "New-Inventory #5" {
        $hosts = New-Table_IHost

        $row = $hosts.NewRow()
        $row.Hostname = "Foo"
        $row.Role = "Prod"
        $hosts.Rows.Add($row)

        $row = $hosts.NewRow()
        $row.Hostname = "Bar"
        $row.Role = "Dev"
        $hosts.Rows.Add($row)

        $inv = New-Inventory -IHost $hosts
        ($inv.Tables["IHost"].Rows | Measure-Object).Count | Should Be 2
        ($inv.Tables["IService"].Rows | Measure-Object).Count | Should Be 0
    }
}
