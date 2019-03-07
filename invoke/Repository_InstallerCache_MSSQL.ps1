# Maintain a index of valid installer cache packages for MSSQL

Import-Power 'Chores'
Import-Power 'Table'
Import-Power 'Inventory'

# Host from a List
$Localdir = $Global:_PWR.LOCALDIR
$ServiceFN = "$localdir\inventory\Instance_MSSQL.csv"
$IServiceTable = $null
If(test-path $ServiceFN) {
    $IServiceTable = New-TableFromCSV $ServiceFN
}
else {
    $new = New-Table_IService
    $new.Rows.Add() >$null
    $new | Export-CSV -NoTypeInformation $ServiceFN
    Write-Warning "Please input file and try again: $ServiceFN"
    return
}
$Inventory = New-Inventory -IService $IServiceTable

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

$cfg = Get-Config "chores.Repository_InstallerCache_MSSQL"
$Chore = New-Chore $cfg
$Chore['User']['System.Windows'] = $SysSet

# Start chore
Invoke-Chore $Chore
Remove-TempDir
Remove-TempFiles
