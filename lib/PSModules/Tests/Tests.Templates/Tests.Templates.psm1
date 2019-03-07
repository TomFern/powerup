# Unit test

Import-Power 'Pester'
Import-Power 'Charts.Pie'
Import-Power 'Templates' -Reload

$Summary = New-Object System.Data.DataTable 'Summary'
$Summary.Columns.Add((New-Object System.Data.DataColumn '_GID',([String])))
$Summary.Columns.Add((New-Object System.Data.DataColumn 'Servicename',([String])))
$Summary.Columns.Add((New-Object System.Data.DataColumn '_Role',([String])))
$Summary.Columns.Add((New-Object System.Data.DataColumn '_AttentionCount',([Int])))
$Summary.Columns.Add((New-Object System.Data.DataColumn '_AttentionMessage',([String])))
$Summary.Columns.Add((New-Object System.Data.DataColumn '_SummaryMessage',([String])))
$Summary.Columns["_AttentionCount"].DefaultValue = 0

$row = $Summary.NewRow()
$row._GID = "SRV1"
$row.Servicename = "FOO"
$row._Role = 'Prod'
$row._AttentionCount= 0
$row._SummaryMessage= "_SummaryMessage"
$Summary.Rows.Add($row)

$row = $Summary.NewRow()
$row._GID = "SRV2"
$row.Servicename = "BAR"
$row._Role = 'Prod'
$row._AttentionCount= 1
$row._AttentionMessage= "_AttentionMessage"
$row._SummaryMessage= "_SummaryMessage"
$Summary.Rows.Add($row)

$row = $Summary.NewRow()
$row._GID = "SRV3"
$row.Servicename = "FOOBAR"
$row._Role = 'Dev'
$row._AttentionCount = 0
$row._SummaryMessage= "_SummaryMessage"
$Summary.Rows.Add($row)

$Details = New-Object System.Data.DataTable 'Details'
$Details.Columns.Add((New-Object System.Data.DataColumn '_GID',([String])))
$Details.Columns.Add((New-Object System.Data.DataColumn 'Servicename',([String])))
$Details.Columns.Add((New-Object System.Data.DataColumn '_Role',([String])))
$Details.Columns.Add((New-Object System.Data.DataColumn 'Goodness',([String])))
$Details.Columns.Add((New-Object System.Data.DataColumn 'Attention',([Bool])))
$Details.Columns["Attention"].DefaultValue = $False

$row = $Details.NewRow()
$row._GID = 'SRV1'
$row.Servicename = 'Foo'
$row._Role = 'Prod'
$row.Goodness = 'All good'
$row.Attention = $False
$Details.Rows.Add($row) | Out-Null

$row = $Details.NewRow()
$row._GID = 'SRV1'
$row.Servicename = 'Foo1'
$row._Role = 'Prod'
$row.Goodness =  'So good'
$row.Attention = $False
$Details.Rows.Add($row) | Out-Null

$row = $Details.NewRow()
$row._GID = 'SRV2'
$row.Servicename = 'Foo'
$row._Role = 'Prod'
$row.Goodness = 'Oh not so good'
$row.Attention = $True
$Details.Rows.Add($row) | Out-Null

$row = $Details.NewRow()
$row._GID = 'SRV2'
$row.Servicename = 'Foo1'
$row._Role = 'Prod'
$row.Goodness =  'Pretty good'
$row.Attention = $False
$Details.Rows.Add($row) | Out-Null

$row = $Details.NewRow()
$row._GID = 'SRV3'
$row.Servicename = 'Foo'
$row._Role = 'Dev'
$row.Goodness = 'Maximum Goodness'
$row.Attention = $False
$Details.Rows.Add($row) | Out-Null

$Counters = New-Object System.Data.DataTable 'ReportCounters'
$Counters.Columns.Add((New-Object System.Data.DataColumn '_Ord',([String])))
$Counters.Columns.Add((New-Object System.Data.DataColumn '_Role',([String])))
$Counters.Columns.Add((New-Object System.Data.DataColumn 'Total',([Int])))
$Counters.Columns.Add((New-Object System.Data.DataColumn 'Success',([Int])))
$Counters.Columns.Add((New-Object System.Data.DataColumn 'Percent',([Float])))

$row = $Counters.NewRow()
$row._Ord = 1
$row._Role = 'Prod'
$row.Total = 100
$row.Success = 90
$row.Percent = 90
$Counters.Rows.Add($row) | Out-Null

$row = $Counters.NewRow()
$row._Ord = 2
$row._Role = 'Dev'
$row.Total = 60
$row.Success = 34
$row.Percent = 56.67
$Counters.Rows.Add($row) | Out-Null

$row = $Counters.NewRow()
$row._Ord = 3
$row._Role = 'Test'
$row.Total = 0
$row.Success = 0
$row.Percent = 0
$Counters.Rows.Add($row) | Out-Null

$Missing = New-Object System.Data.DataTable 'DataMissing'
$Missing.Columns.Add((New-Object System.Data.DataColumn '_GID',([String])))

$row = $Missing.NewRow()
$row._GID = 'Fizz'
$Missing.Rows.Add($row) | Out-Null

$UserData = @{
    'ReportInfo' = @{
        "Info" = "This is info";
        "Info2" = "This is more info";
    };
    'Counters' = $Counters;
    'Data' = $Details;
    'DataMissing' = $Missing;
    'Summary' = $Summary;
}


$ImgFn = ConvertTo-AbsolutePath (Join-Path $GLOBAL:_PWR['TMPDIR'] 'ExamplePie.png')
$Chart = New-Chart -Width 300 -Height 300
$Chart | Add-ChartDataPoint -Label "Foo" -Value 20 -Color 'Red' | Out-Null
$Chart | Add-ChartDataPoint -Label "Bar" -Value 20 -Color 'Black' | Out-Null
$Chart | Add-ChartDataPoint -Label "Fizz" -Value 20 -Color 'Yellow' | Out-Null
$Chart | Add-ChartDataPoint -Label "Buzz" -Value 40 -Color 'Blue' -Explode | Out-Null
$Chart | Out-ImageFile -Path $ImgFn -Format "png" -Force

Describe "Templates" {
    It "Invoke-Template Example #1" {
        $content = Invoke-Template 'GenericSanityTable' -UserData $UserData
        $content.length | Should BeGreaterThan 0
    }
    It "Invoke-Template Example #2 (ExampleTable.txt)" {
        $fn = Join-Path $GLOBAL:_PWR['TMPDIR'] 'ExampleTable.txt'
        $content = Invoke-Template 'GenericSanityTable' -UserData $UserData
        $content | Out-File -Encoding UTF8 $fn
        Test-Path $fn | Should Be $true
    }
    It "Invoke-Template Example #3" {
        $content = Invoke-Template 'GenericSanityHTML' -UserData $UserData -TemplateParameters @{'Title' = 'Example'; 'GraphUrl' = $ImgFn;}
        $content.length | Should BeGreaterThan 0
    }
    It "Invoke-Template Example #4" {
        $content = Invoke-Template 'GenericSanityHTML' -UserData $UserData -TemplateParameters @{'LinkCss' = $true; 'Title' = 'Example'; 'GraphUrl' = $ImgFn;}
        $content.length | Should BeGreaterThan 0
    }
    It "Invoke-Template Example #5" {
        $content = Invoke-Template 'GenericSanityHTML' -UserData $UserData -TemplateParameters @{'LinkCss' = $true; 'Title' = 'Example'; 'GraphUrl' = $ImgFn; 'Min_AttentionCount' = 10; }
        $content.length | Should BeGreaterThan 0
    }
    It "Invoke-Template Example #6 (Example.html)" {
        $fn = Join-Path $GLOBAL:_PWR['TMPDIR'] 'Example.html'
        $content = Invoke-Template 'GenericSanityHTML' -UserData $UserData -TemplateParameters @{'Title' = 'Example Sanity Report'; 'GraphUrl' = $ImgFn;}
        $content | Out-File -Encoding UTF8 $fn
        Test-Path $fn | Should Be $true
    }
}


