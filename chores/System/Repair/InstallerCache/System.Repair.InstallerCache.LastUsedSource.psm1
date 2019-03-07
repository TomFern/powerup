# Auto-repair Windows Installer cache from LastUsedSource

Set-StrictMode -version Latest

New-Variable -Scope Script 'SystemSet'
New-Variable -Scope Script 'CheckCache'

Import-Power 'Table'
Import-Power 'Path'


################################################
#
# Inputs
#
################################################

function StepPre {
    Param([HashTable]$usr)

    $Script:SystemSet = $usr['System.Windows']
    $Script:CheckCache = $Script:SystemSet.Tables['Get-Install__CacheFileExists']
    $Script:CheckCache.Rows[0]>$null
}


################################################
#
# Outputs
#
################################################

function StepNext {
    return @{
        'System.Windows' = $Script:SystemSet;
    }
}


################################################
#
# Process
#
################################################

function StepProcess {

    $CheckCache = $Script:CheckCache
    $RowTotal = ($CheckCache.Rows|Measure-Object).Count
    $RowNum = 0

    Foreach($Package in $CheckCache) {
        $computer = $Package.Hostname
        $RowNum += 1

        Write-Progress -Activity "Installer Cache" -Status "Test File" -PercentComplete ($RowNum*100/$RowTotal)

        If(-not($Package.CacheFileExists)) {

            $RemoteLastUsed = ConvertTo-RemotePath -Computer $computer -Path $Package.PackageLastUsedPath
            $RemoteCacheFn = ConvertTo-RemotePath -Computer $computer -Path $Package.CacheFilePath

            If(Test-Path -PathType leaf $RemoteLastUsed) {
                Try {
                    Copy-Item $RemoteLastUsed $RemoteCacheFn
                }
                Catch {
                    Write-Warning ("Copy file error ({0} -> {1}): {2}" -f $RemoteLastUsed,$RemoteCacheFn,$_.Exception.Message)
                }
            }
            If(Test-Path -PathType leaf $RemoteCacheFn) {
                $Package.CacheFileExists = $true
            }
            else {
                $Package.CacheFileExists = $false
            }
        }

    }
    Write-Progress -Activity "Installer Cache" -Status "Complete" -Completed
}
