# Checkinstall for SQL Server
#
# * Missing Installer Cache packages
# * Auto repair from repository
# * Auto repair from LastUsedSource
# * Check compressed foldes
# * Manual repair
#

If(-not($GLOBAL:_PWR.INTERACTIVE)) {
    Throw "This script should be run in an interactive console"
}

If($GLOBAL:_PWR.PSARCH -ne '64-bit') {
    Write-Warning "It is HIGHLY recommended to run this script on a 64-bit session"
}

Import-Power 'Chores'
Import-Power 'Table'
Import-Power 'Inventory'

# Host from a List
$Localdir = $Global:_PWR.LOCALDIR

$IHostFN = "$Localdir\inventory\Checkinstall_MSSQL.list"
$IHostTable = $null
If(test-path $IHostFN) {
    $IHostTable = New-TableFromList $IHostFN -ColumnName Hostname
}
else {
    New-Item -Type F -Force $IHostFN >$null
    Write-Warning "Please edit input file and try again: $IHostFN"
    return
}
$Inventory = New-Inventory -IHost $IHostTable


Try {
    Write-Host -NoNewLine -ForegroundColor White $MyInvocation.MyCommand.Name
    Write-Host -NoNewLine " has "
    Write-Host -NoNewLine -ForegroundColor Cyan ($Inventory.Tables['IHost'] | Measure-Object).Count
    Write-Host -NoNewLine " Hosts and "
    Write-Host -NoNewLine -ForegroundColor Magenta ($Inventory.Tables['IService'] | Measure-Object).Count
    Write-Host " Services "
}
Catch {}

# Prepare DataSet object
$SysSet = New-Object System.Data.DataSet
$SysSet.Merge($Inventory)

# Summary for final report
$Summary = @{
    'Total Hosts' = (($Inventory.Tables['IHost'] | Measure-Object).Count);
    'Total Instances' = (($Inventory.Tables['IService'] | Measure-Object).count);
    'Compressed Folders Found' = 0;
    'Cache Packages Repaired Automatically' = 0;
    'Cache Packages NOT Repaired' = 0;
}
$CacheMissingInitial = 0
$CacheMissingAfterRepair = 0


# This chore scans for missing packages and runs the repair from lastusedsource
# it also checks for compressed folders
$cfg = Get-Config 'chores.CheckInstall_MSSQL'

$Chore = New-Chore $cfg
$Chore['User']['System.Windows'] = $SysSet

Invoke-Chore $Chore
Remove-TempDir
Remove-TempFiles

$CacheMissingInitial = ($Chore['User']['System.Windows'].Tables['Get-Install__CacheFileExists'].Select("CacheFileExists = $false")|Measure-Object).Count
$Summary['Compressed Folders Found'] = ($Chore['User']['System.Windows'].Tables['NTFS_Compress'].Select("FolderCompressed = $true")|Measure-Object).Count


# Run repair from repository if available
# this will only work if the repository tables have been created by their script
$CheckCacheTable = $Chore['User']['System.Windows'].Tables['Get-Install__CacheFileExists']
If(($CheckCacheTable|Where { $_.CacheFileExists -eq $false} |Measure-Object).Count -gt 0) {
    $cfgrepair = Get-Config 'chores.Checkinstall_MSSQL_RepairFromRepository'

    $ChoreRepair = New-Chore $cfgrepair
    $ChoreRepair['User']['System.Windows'] = New-Object System.Data.DataSet 'System.Windows'
    $ChoreRepair['User']['System.Windows'].Tables.Add($CheckCacheTable.Copy())
    Try {
        Invoke-Chore $ChoreRepair
    }
    Catch {
        Write-Warning "Repository Repair failed, check if you are running the maintenace scripts"
    }
    $RepairTable = $ChoreRepair['User']['System.Windows'].Tables['Get-Install__CacheFileExists']
    $Chore['User']['System.Windows'].Tables.Remove('Get-Install__CacheFileExists')
    $Chore['User']['System.Windows'].Tables.Add($RepairTable.Copy())
    $CacheMissingAfterRepair = ($RepairTable.Select("CacheFileExists = $false")|Measure-Object).Count
}

$Summary['Cache Packages Repaired Automatically'] = $CacheMissingAfterRepair


# Show unfixable packages in an editor, so user can correct the paths (lastusedsource)
function _edit_lastusedsource {

    $CheckCacheTable = $Chore['User']['System.Windows'].Tables['Get-Install__CacheFileExists']
    $tmpcsv = New-TempFile -Extension '.csv'

    $CacheMissing = $CheckCacheTable.Clone()
    $CheckCacheTable.Select("CacheFileExists = $False") | Foreach {
        $CacheMissing.ImportRow($_)
    }
    $CacheOK = $CheckCacheTable.Clone()
    $CheckCacheTable.Select("CacheFileExists = $True") | Foreach {
        $CacheOK.ImportRow($_)
    }

    $CacheMissing | Export-CSV -NoTypeInformation $tmpcsv
    Invoke-Expression ("{0} {1}" -f $Global:_PWR['LOCAL']['editor'],$tmpcsv)

    Write-Host -nonewline "Type Y when ready or N to cancel: "
    $response = read-host
    If($response -eq 'Y') {
        $CheckCacheTable = $CheckCacheTable.Clone()
        (New-TableFromCSV $tmpcsv).Rows | Foreach {
            $CheckCacheTable.ImportRow($_)
        }
        $CheckCacheTable.TableName = 'Get-Install__CacheFileExists'
        $CheckCacheTable.Rows | Foreach { $_.CacheFileExists = $false }
        $CacheOk.Rows | Foreach { $CheckCacheTable.ImportRow($_) }
        $Chore['User']['System.Windows'].Tables.Remove('Get-Install__CacheFileExists')
        $Chore['User']['System.Windows'].Tables.Add($CheckCacheTable)
    }
}

$continue = $true
While($continue) {
    $CheckCacheTable = $Chore['User']['System.Windows'].Tables['Get-Install__CacheFileExists']
    $Summary['Cache Packages NOT Repaired'] = ($CheckCacheTable.Select("CacheFileExists = $false") | Measure-Object).Count
    If(($CheckCacheTable|Where { $_.CacheFileExists -eq $false} |Measure-Object).Count -gt 0) {
        Write-Host -ForegroundColor Cyan "Some cache files couldn't be fixed"

        $response = -1
        While(-not(@(1,2,3) -contains $response)) {
            Write-Host "  1 - Edit Cache Table and try again to repair (eg. try another LastUsedSource)"
            Write-Host "  2 - Try again to repair as it is"
            Write-Host "  3 - Exit, leave system unrepaired"
            Write-Host -NoNewLine "-> Choose an option: "
            $response = Read-Host
            $response = $response.Trim()
        }
        switch($response) {
            1 { _edit_lastusedsource; Invoke-Chore -From 1 $Chore; };
            2 { Invoke-Chore -From 1 $Chore; };
            3 { $continue = $false; };
        }
    }
    else {
        $continue = $false
    }
}


# Show final results
If(($Chore['User']['System.Windows'].Tables['NTFS_Compress'].Select("FolderCompressed = $true")|Measure-Object).Count -gt 0) {
    Write-Host "COMPRESSED FOLDER FOUND:"
    Write-Host ($Chore['User']['System.Windows'].Tables['NTFS_Compress'].Select("FolderCompressed = $true") | Format-Table | Out-String)
}
else {
    Write-Host "No compressed folders found"
}


# This neeeds more work
# Write-Host "SUMMARY"
# Foreach($Key in $Summary.Keys) {
#     Write-Host $Summary[$Key]
# }
