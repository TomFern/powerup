# (Stacked) Bar Chart

Import-Power 'Charts.Common'

Function New-Chart
{
    <#
    .SYNOPSIS
        Create a (Stacked) Bar/Column Chart
    .DESCRIPTION
        Creates a new Bar Chart that can be exported as an image
    .PARAMETER Title
        (Optional) The chart title
    .PARAMETER Width
        (optional) Chart width in pixels
    .PARAMETER Height
        (optional) Chart Height in pixels
    .PARAMETER ShowLegend
        [Switch] When set, show Series Name Legend on the side of the Graph
    .LINK
        New-Chart
        Add-ChartSeries
        Add-ChartDataPoint
        Out-ImageFile
    .EXAMPLE
        $Chart = New-Chart -Title 'ISSUES'
        $Chart | Add-ChartSeries -SeriesName 'Prod' -Horizontal
        $Chart | Add-ChartDataPoint -Value 10 -SeriesName 'Prod' -Label 'Disk'
        $Chart | Add-ChartDataPoint -Value 20 -SeriesName 'Prod' -Label 'DB'
        $Chart | Add-ChartSeries -SeriesName 'Dev' -Horizontal
        $Chart | Add-ChartDataPoint -Value 15 -SeriesName 'Dev' -Label 'Disk'
        $Chart | Add-ChartDataPoint -Value 30 -SeriesName 'Dev' -Label 'DB'
        $Chart | Out-ImageFile -Path 'bar.png' -Format 'png' -Force
    #>
    [cmdletbinding()]
    Param(
        [String]$Title=$null,
        [Int]$Width=640,
        [Int]$Height=480,
        [Switch]$ShowLegend
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
    $Chart.ChartAreas.Add($ChartArea)>$null

    if($Title) {
        $Chart.Titles.Add($Title) >$null
    }
    If($ShowLegend) {
        $Chart.Legends.Add('Legend')>$null
    }

    return ,$Chart
}


Function Add-ChartSeries {
<#
    .SYNOPSIS
        Add a Series to a Bar Chart
    .DESCRIPTION
        Adds a new Data Series to a Bar/Column Stacked Chart

        NOTE: If at least one Series has -Horizontal, then all the rest must alseo have it. Otherwise there will
              be an incompatible chart error when exporting the image.

    .PARAMETER Chart
        Chart Object
    .PARAMETER SeriesName
        The New series Name
    .PARAMETER Horizontal
        [Switch] If set the chart bars are horizontal (Type = StackedBar) otherwise bars are vertical (Type = StackedColumn)
    .LINK
        New-Chart
        Add-ChartSeries
        Add-ChartDataPoint
        Out-ImageFile
    .EXAMPLE
        $Chart = New-Chart -Title 'ISSUES'
        $Chart | Add-ChartSeries -SeriesName 'Prod' -Horizontal
        $Chart | Add-ChartDataPoint -Value 10 -SeriesName 'Prod' -Label 'Disk'
        $Chart | Add-ChartDataPoint -Value 20 -SeriesName 'Prod' -Label 'DB'
        $Chart | Add-ChartSeries -SeriesName 'Dev' -Horizontal
        $Chart | Add-ChartDataPoint -Value 15 -SeriesName 'Dev' -Label 'Disk'
        $Chart | Add-ChartDataPoint -Value 30 -SeriesName 'Dev' -Label 'DB'
        $Chart | Out-ImageFile -Path 'bar.png' -Format 'png' -Force
#>
    [cmdletbinding()]
    Param(
        [Parameter(Position=0,Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]$Chart,
        [Parameter(Mandatory=$true)][String]$SeriesName,
        [Switch]$Horizontal
        )
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    $Chart.Series.Add($SeriesName) >$null
    If($Horizontal) {
        $Chart.Series[$SeriesName].ChartType = [System.Windows.Forms.DataVisualization.Charting.SeriesChartType]::StackedBar
    }
    else {
        $Chart.Series[$SeriesName].ChartType = [System.Windows.Forms.DataVisualization.Charting.SeriesChartType]::StackedColumn
    }

} # end function Add-ChartSeries


Function Add-ChartDataPoint
{
    <#
    .SYNOPSIS
        Add a datapoint
    .DESCRIPTION
        Adds a new datapoint to an existing series on a chart
    .PARAMETER Chart
        The Chart object (can be piped in)
    .PARAMETER Value
        The datapoint Value (float)
    .PARAMETER Label
        (optional) A label for the data point
    .PARAMETER SeriesName
        The DataPoint Series name, defaults to 'Series1'
    .LINK
        New-Chart
        Add-ChartSeries
        Add-ChartDataPoint
        Out-ImageFile
    .EXAMPLE
        $Chart = New-Chart -Title 'ISSUES'
        $Chart | Add-ChartSeries -SeriesName 'Prod' -Horizontal
        $Chart | Add-ChartDataPoint -Value 10 -SeriesName 'Prod' -Label 'Disk'
        $Chart | Add-ChartDataPoint -Value 20 -SeriesName 'Prod' -Label 'DB'
        $Chart | Add-ChartSeries -SeriesName 'Dev' -Horizontal
        $Chart | Add-ChartDataPoint -Value 15 -SeriesName 'Dev' -Label 'Disk'
        $Chart | Add-ChartDataPoint -Value 30 -SeriesName 'Dev' -Label 'DB'
        $Chart | Out-ImageFile -Path 'bar.png' -Format 'png' -Force
    #>
    [cmdletbinding()]
    Param(
        [Parameter(Position=0,Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]$Chart,
        [Parameter(Mandatory=$true)][float] $Value,
        [Parameter(Mandatory=$true)][String]$SeriesName,
        [string]$Label=$null,
        [String]$Color=$null
    )
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    $Point = $Chart.Series[$SeriesName].Points.Add()
    $Point.YValues = $Value

    if($Label) {
        $Point.AxisLabel = $Label
    }
    if($Color) {
        $Point.Color = $Color
    }

    # return ,$Chart
} # end function Add-ChartDataPoint

