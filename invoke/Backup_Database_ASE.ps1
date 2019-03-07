# Dump Sybase ASE Databases in parallel

Import-Power 'Chores'
Import-Power 'Table'
Import-Power 'Inventory'
Import-Power 'ASE.Dump'
Import-Power 'EmailRecipient'


# Input Files
$Localdir = $Global:_PWR.LOCALDIR
$ServiceFN = "$localdir\inventory\Instance_ASE.csv"
$IServiceTable = $null
If(test-path $ServiceFN) {
    $IServiceTable = New-TableFromCSV $ServiceFN
}
else {
    $new = New-Table_IService
    $new.Rows.Add() >$null
    $new | Export-CSV -NoTypeInformation $ServiceFN
    Write-Warning "Please edit input and try again: $ServiceFN"
    return
}
$Inventory = New-Inventory -IService $IServiceTable

$BackupSelectionFn = "$Localdir\inventory\Backup_Selection_ASE.csv"
$BackupSelectionTable = $null
If(test-path $BackupSelectionFn) {
    $BackupSelectionTable = New-TableFromCSV $BackupSelectionFn
    $BackupSelectionTable.TableName = 'BackupSelection'
}
else {
    $new = New-Table_Backup_Selection
    $new.Rows.Add() >$null
    $new | Export-CSV -NoTypeInformation $BackupSelectionFn
    Write-Warning "Please edit input and try again: $BackupSelectionFn"
    return
}


Try {
    Write-Host -NoNewLine -ForegroundColor White $MyInvocation.MyCommand.Name
    Write-Host -NoNewLine " has "
    Write-Host -NoNewLine -ForegroundColor Cyan ($Inventory.Tables['IHost'] | Measure-Object).Count
    Write-Host -NoNewLine " Hosts and "
    Write-Host -NoNewLine -ForegroundColor Magenta ($Inventory.Tables['IService'] | Measure-Object).Count
    Write-Host " Services "
}
Catch {}

# Give a chance to cancel
Write-Host -ForegroundColor Cyan ("Backup Selection file is {0}" -f $BackupSelectionFn)
$BackupSelectionTable | Format-Table -Autosize
Write-Host -ForegroundColor Cyan ("Backup will start in 1 minute. You have a chance to CANCEL now with Control-C ...")
Sleep 60
Write-Host -ForegroundColor Cyan "Backup is starting soon.."

# Prepare DataSet
$DBSet = New-Object System.Data.DataSet
$DBSet.Merge($Inventory)
$DBSet.Tables.Add($BackupSelectionTable)

$Recipients = get-recipient ($MyInvocation.MyCommand.Name),dbastaff
$cfg = Get-Config "chores.Backup_Database_ASE"

Try {
    $Chore = New-Chore $cfg
    $Chore['User']['Database.ASE'] = $DBSet
    $Chore['User']['Recipients'] = $Recipients
    $Chore['User']['Title'] = "Report Backup Sybase ASE"

}
Catch {
    Send-ErrorReport -Message ("Can't create chore {0}: {1}" -f $cfg['name'],$_.Exception.Message)
    Throw ("Can't create chore: {0}" -f $_.Exception.Message)
}

Try {
    Invoke-Chore $Chore
}
Catch {
    Send-ErrorReport -Message ("Chore had an error:{0}. Error was: {1}" -f $cfg['name'], $_.Exception.Message)
    Write-Warning ("Chore had an error: {0}" -f $_.Exception.Message)
}

If(-not($GLOBAL:_PWR.INTERACTIVE)) {
    Remove-Variable 'Chore'
}
Remove-TempDir
Remove-TempFiles

