# Pie Charts
#

Import-Power 'Charts.Common'

Function New-Chart
{
    <#
    .SYNOPSIS
        Create a Pie Chart
    .DESCRIPTION
        Creates a new Pie Chart that can be exported as an image
    .PARAMETER Title
        (optinal) The chart title
    .PARAMETER Width
    (optional) Chart width in pixels
    .PARAMETER Height
    (optional) Chart Height in pixels
    .EXAMPLE
        $chart = New-Chart -Title "My Chart"
        $chart | Add-ChartDataPoint -Value 25 -Label "A Quarter" -Color "Red"
        $chart | Add-ChartDataPoint -Value 25 -Label "Another Quarter" -Color "Yellow"
        $chart | Add-ChartDataPoint -Value 50 -Label "An a half" -Color "Blue"
        $chart | Out-ImageFile -Path "C:\Temp\MyChart.png"
    #>
    [cmdletbinding()]
    Param(
        [String]$Title=$null,
        [Int]$Width=640,
        [Int]$Height=480
        # [Int]$Left=0,
        # [Int]$Top=0
    )

    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    $Chart = New-object System.Windows.Forms.DataVisualization.Charting.Chart
    $Chart.Width = $Width
    $Chart.Height = $Height
    # $Chart.Left = $Left
    # $Chart.Top = $Top
    $Chart.BackColor = [System.Drawing.Color]::Transparent

    # create a chartarea to draw on and add to chart
    $ChartArea = New-Object System.Windows.Forms.DataVisualization.Charting.ChartArea
    $Chart.ChartAreas.Add($ChartArea)

    $Chart.Series.Add("Data") | Out-Null
    $Chart.Series["Data"].ChartType = [System.Windows.Forms.DataVisualization.Charting.SeriesChartType]::Pie
    $Chart.Series["Data"]["PieLabelStyle"] = "Outside"
    $Chart.Series["Data"]["PieLineColor"] = "Black"
    $Chart.Series["Data"]["PieDrawingStyle"] = "Concave"

    if($Title) {
        $Chart.Titles.Add($Title) | Out-Null
    }

    return ,$Chart
}

Function Add-ChartDataPoint
{
    <#
    .SYNOPSIS
        Add a datapoint
    .DESCRIPTION
        Adds a new datapoint to an existing chart
    .PARAMETER Chart
        The Chart object (can be piped in)
    .PARAMETER Value
        The datapoint Value (float)
    .PARAMETER Label
        (optional) A label for the data point
    .EXAMPLE
        $chart = New-Chart -Title "My Chart"
        $chart | Add-ChartDataPoint -Value 25 -Label "A Quarter" -Color "Red"
        $chart | Add-ChartDataPoint -Value 25 -Label "Another Quarter" -Color "Yellow"
        $chart | Add-ChartDataPoint -Value 50 -Label "An a half" -Color "Blue"
        $chart | Out-ImageFile -Path "C:\Temp\MyChart.png"
    #>
    [cmdletbinding()]
    Param(
        [Parameter(Position=0,Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]$Chart,
        [Parameter(Mandatory=$true)][float] $Value,
        [string]$Label=$null,
        [String]$Color=$null,
        [Switch]$Explode
    )
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    $Point = $Chart.Series["Data"].Points.Add()
    $Point.YValues = $Value
    if($Label) {
        $Point.Label = $Label
        $Point.AxisLabel = $Label
    }
    if($Color) {
        $Point.Color = $Color
    }
    if($Explode) {
        $Point["Exploded"] = $true
    }

    # return ,$Chart
} # end function Add-ChartDataPoint

