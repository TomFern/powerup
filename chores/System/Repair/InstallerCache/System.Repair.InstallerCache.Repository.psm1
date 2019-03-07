# Repair Windows Cache from other servers using a repository

Set-StrictMode -version Latest

New-Variable -Scope Script 'IHost'
New-Variable -Scope Script 'SystemSet'
New-Variable -Scope Script 'RepoTable'
New-Variable -Scope Script 'CheckCache'

Import-Power 'Table'
Import-Power 'Path'


################################################
#
# Inputs
#
################################################

function StepPre {
    Param([HashTable]$usr,[HashTable]$Id)

    $Script:SystemSet = $usr['System.Windows']
    $Script:RepoTable = $Script:SystemSet.Tables['Get-Install__CacheFileRepository']
    $Script:CheckCache = $Script:SystemSet.Tables['Get-Install__CacheFileExists']

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

    $RowCount = ($Script:CheckCache.Rows|Measure-Object).Count
    $RowNum = 0
    Foreach($CachePackage in $Script:CheckCache) {
        $RowNum += 1
        $Computer = $CachePackage.Hostname
        Write-Progress -Activity "Installer Cache" -Status "Search in other machines" -CurrentOperation $Computer -PercentComplete ($RowNum*100/$RowCount)

        If(-not($CachePackage.CacheFileExists)) {
            $InstallType = $CachePackage.InstallType
            $ProductName = $CachePackage.ProductName
            $PackageName = $CachePackage.PackageName
            $CacheFilePath = $CachePackage.CacheFilePath

            $RepairCandidates = $null
            If($InstallType -eq 'Patch') {
                $PatchName = $CachePackage.PatchName
                $RepairCandidates = $Script:RepoTable.Select( `
                    ("ProductName = '$ProductName' AND InstallType = '$InstallType' AND PackageName = '$PackageName' AND PatchName = '$PatchName'"))
            }
            elseif($InstallType -eq 'Product') {
                $RepairCandidates = $Script:RepoTable.Select( `
                    ("ProductName = '$ProductName' AND InstallType = '$InstallType' AND PackageName = '$PackageName'"))
            }

            Foreach($RepoPackage in $RepairCandidates) {
                $RepoPath = ConvertTo-RemotePath -Computer $RepoPackage.Hostname -Path $RepoPackage.CacheFilePath
                $CacheFileRepairPath = ConvertTo-RemotePath -Computer $Computer -Path $CacheFilePath
                If(Test-Path -PathType leaf $RepoPath) {
                    Try {
                        Copy-Item $RepoPath $CacheFileRepairPath
                    }
                    Catch {
                        Write-Warning ("Copy file error ({0} -> {1}): {2}" -f $RepoPath,$CacheFileRepairPath,$_.Exception.Message)
                    }
                    If(Test-Path -PathType leaf $CacheFileRepairPath) {
                        $CachePackage.CacheFileExists = $true
                        break
                    }
                }
            }
        }
    }
    Write-Progress -Activity "Installer Cache" -Status "Complete" -Completed
}

