# Base Charts entities

# Chart Types:
# https://msdn.microsoft.com/en-us/library/dd489233.aspx

# Try system's first
Try {
    [Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms.DataVisualization")
	new-object System.Windows.Forms.DataVisualization.Charting.Chart>$null
}
Catch {
    Write-Verbose "Can't load System.Windows.Forms.DataVisualization. Trying workaround"
    Get-ChildItem -Recurse -Filter "*.dll" (Join-Path $GLOBAL:_PWR['PSASSEMBLIES_DIR'] 'MSCharts') | Foreach {
        Add-Type -Path $_.fullname
    }
}

# Import-Power 'Assemblies.MSCharts'
Import-Power 'Temp'


Function Out-ImageFile
{
    <#
    .SYNOPSIS
        Export Chart as Image
    .DESCRIPTION
        Save the chart into an image file
    .PARAMETER

    .PARAMETER

    .EXAMPLE
        Out-ImageFile $Chart 'mychart.png'
    #>
    [cmdletbinding()]
    Param(
        [Parameter(Position=0,Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]$Chart,
        [Parameter(Mandatory=$true)]$Path,
        [String]$Format="PNG",
        [Switch]$Force
    )
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    if((test-path -Type Leaf $path) -and(-not($Force))) {
        Throw "[Out-ImageFile] File exists: $Path"
    }
    New-Item -type f $Path -Force | Out-Null
    if(-not(Test-Path -Type Leaf $path)) {
        Throw "[Out-ImageFile] Unable to write file: $Path"
    }

    $Chart.SaveImage($Path,$Format)
} # end function Out-ImageFile
