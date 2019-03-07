# Test Charts.Pie

Import-Power 'Pester'
Import-Power 'Charts.Pie' -Reload

$Chart = New-Chart -Width 300 -Height 300
$Chart | Add-ChartDataPoint -Label "Foo" -Value 20 -Color 'Red' | Out-Null
$Chart | Add-ChartDataPoint -Label "Bar" -Value 20 -Color 'Black' | Out-Null
$Chart | Add-ChartDataPoint -Label "Fizz" -Value 20 -Color 'Yellow' | Out-Null
$Chart | Add-ChartDataPoint -Label "Buzz" -Value 40 -Color 'Blue' -Explode | Out-Null

Describe "Charts.Pie" {
    It "New-Chart #1" {
        $chart = new-chart
        ($chart.gettype()).name | Should be 'Chart'
    }
    It "New-Chart #2" {
        $chart = new-chart -width 100 -height 200
        $chart.width | Should be 100
    }
    It "New-Chart #3" {
        $chart = new-chart -width 100 -height 200
        $chart.Height | Should be 200
    }
    It "Add-ChartDataPoint #1" {
        $Chart = New-Chart -Width 300 -Height 300
        $Chart | Add-ChartDataPoint -Label "Foo" -Value 20 -Color 'Red' | Out-Null
        ($Chart.Series["Data"].Points | Measure-Object).count | should be 1
    }
    It "Add-ChartDataPoint #2" {
        $Chart = New-Chart -Width 300 -Height 300
        $Chart | Add-ChartDataPoint -Label "Foo" -Value 20 -Color 'Red' | Out-Null
        $Chart | Add-ChartDataPoint -Label "Bar" -Value 20 -Color 'Black' | Out-Null
        ($Chart.Series["Data"].Points | Measure-Object).count | should be 2
    }
    It "Add-ChartDataPoint #3" {
        $Chart = New-Chart -Width 300 -Height 300
        $Chart | Add-ChartDataPoint -Label "Foo" -Value 20 -Color 'Red' | Out-Null
        $Chart | Add-ChartDataPoint -Label "Bar" -Value 20 -Color 'Black' | Out-Null
        $Chart | Add-ChartDataPoint -Label "Buzz" -Value 40 -Color 'Blue' -Explode | Out-Null
        ($Chart.Series["Data"].Points | Measure-Object).count | should be 3
    }
    It "Out-ImageFile #1" {
        $tmppie = New-TempFile -Extension '.PNG'
        $Chart = New-Chart -Width 300 -Height 300
        $Chart | Add-ChartDataPoint -Label "Foo" -Value 20 -Color 'Red' | Out-Null
        $Chart | Add-ChartDataPoint -Label "Bar" -Value 20 -Color 'Black' | Out-Null
        $Chart | Add-ChartDataPoint -Label "Fizz" -Value 20 -Color 'Yellow' | Out-Null
        $Chart | Add-ChartDataPoint -Label "Buzz" -Value 40 -Color 'Blue' -Explode | Out-Null
        $Chart | Out-ImageFile -Path $tmppie -Format "PNG" -Force
        $content = get-content $tmppie
        $content.length | Should begreaterthan 0
    }
    It "Out-ImageFile #2" {
        $tmppie = New-TempFile -Extension '.JPG'
        $Chart = New-Chart -Width 300 -Height 300
        $Chart | Add-ChartDataPoint -Label "Foo" -Value 20 -Color 'Red' | Out-Null
        $Chart | Add-ChartDataPoint -Label "Bar" -Value 20 -Color 'Black' | Out-Null
        $Chart | Add-ChartDataPoint -Label "Fizz" -Value 20 -Color 'Yellow' | Out-Null
        $Chart | Add-ChartDataPoint -Label "Buzz" -Value 40 -Color 'Blue' -Explode | Out-Null
        $Chart | Out-ImageFile -Path $tmppie -Format "Jpeg" -Force
        $content = get-content $tmppie
        $content.length | Should begreaterthan 0
    }
    It "Remove-TempFiles #1" {
        (Remove-TempFiles | Measure-Object).Count | Should Be 0
    }
}

