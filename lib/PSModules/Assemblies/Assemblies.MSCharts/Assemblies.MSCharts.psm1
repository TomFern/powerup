# MS Charts Assemblies

# Try system's first
Write-Warning "THIS ASSEMBLY LOADER IS EMPTY"

# Try {
#     [Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms.DataVisualization")
# 	new-object System.Windows.Forms.DataVisualization.Charting.Chart>$null
# }
# Catch {
#     Write-Verbose "Can't load System.Windows.Forms.DataVisualization. Trying workaround"
#     Get-ChildItem -Recurse -Filter "*.dll" (Join-Path $GLOBAL:_PWR['PSASSEMBLIES_DIR'] 'MSCharts') | Foreach {
#         Add-Type -Path $_.fullname
#     }
# }


