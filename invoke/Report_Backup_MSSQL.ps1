# Backup Report for SQL Server
Param(
    [String]$IService="",
    [String]$Recipients="",
    [String]$ExceptionTable="",
    [Switch]$NoMail,
    [Switch]$Help
)

Import-Power 'EmailRecipient'

# Defaults
$localdir = $Global:_PWR.LOCALDIR
$OD=@{}
$OD['IService'] = (jp $localdir,'inventory','Instance_MSSQL.csv')
$OD['Recipients'] = get-recipient ($MyInvocation.MyCommand.Name),dbastaff
$OD['ExceptionTable'] = (jp $localdir,'inventory','Backup_Exception_MSSQL.csv')


if($Help) {
    wh ("Usage: {0} [SWITCHES] [OPTIONS] [ARGS]" -f ($MyInvocation.MyCommand.Name))

    wh "Switches:"

    wh -f white -NoNewLine "  -Help           "
    wh "Show this message"

    wh -f white -NoNewLine "  -NoMail         "
    wh "Don't send email"

    wh "Options:"

    wh -f white -NoNewLine "  -Recipients      "
    wh ("Email address list. Default: {0}" -f $OD['Recipients'])

    wh -f white -NoNewLine "  -IService        "
    wh ("Service inventory file. Default: {0}" -f $OD['IService'])

    wh -f white -NoNewLine "  -ExceptionTable  "
    wh ("(OPTIONAL) Backup exception table. Default: {0}" -f $OD['ExceptionTable'])

    wh "Packages required: poshrsjob"

    return
}


Trap {
    If(-not($GLOBAL:_PWR['INTERACTIVE'])) {
        Send-ErrorReport -Message ("{0} {1}" -f $MyInvocation.MyCommand.Name, $_.ToString())
        Remove-Variable 'Chore'
        Remove-TempDir
        Remove-TempFiles
    }
    Throw
}

Import-Power 'Chores'
Import-Power 'Table'
Import-Power 'Inventory'

if(-not($Recipients)) { $Recipients = $OD['Recipients'] }
if(-not($IService)) { $IService= $OD['IService'] }
if(-not($ExceptionTable)) { $ExceptionTable = $OD['ExceptionTable'] }
if($NoMail) {
    $Recipients = ''
}

# Instance List from a CSV
$IServiceTable = $null
If(test-path $IService) {
    $IServiceTable = New-TableFromCSV $IService
}
else {
    $new = New-Table_IService
    $new.Rows.Add() >$null
    $new | Export-CSV -NoTypeInformation $IService
    Write-Warning "Please edit input and try again: $IService"
    return
}
$Inventory = New-Inventory -IService $IServiceTable

# Instance List from a CSV
Try {
    Write-Host -NoNewLine -ForegroundColor White $MyInvocation.MyCommand.Name
    Write-Host -NoNewLine " has "
    Write-Host -NoNewLine -ForegroundColor Cyan ($Inventory.Tables['IHost'] | Measure-Object).Count
    Write-Host -NoNewLine " Hosts and "
    Write-Host -NoNewLine -ForegroundColor Magenta ($Inventory.Tables['IService'] | Measure-Object).Count
    Write-Host " Services "
    Write-Host -NoNewLine "Recipients: "
    Write-Host -ForegroundColor White $Recipients
}
Catch {}

$DBSet = New-Object System.Data.DataSet
$DBSet.Merge($Inventory)
$SvcSet = $DBSet.Copy()

if(test-path -PathType leaf $ExceptionTable) {
    try {
        Write-Host -NoNewLine "Using backup exception file: "
        Write-Host -ForegroundColor White $ExceptionTable
    }
    catch {}
    $Exception = New-TableFromCSV $ExceptionTable
    $Exception.TableName = "BackupException"
    $DBSet.Tables.Add($Exception)
}

$cfg = Get-Config "chores.Report_Backup_MSSQL"

$Chore = New-Chore $cfg
$Chore['User']['Recipients'] = $Recipients
$Chore['User']['Title'] = ("Database Backups {0}" -f $GLOBAL:_PWR['LOCAL']['project']['caption'])
$Chore['User']['Database.MSSQL'] = $DBSet
$Chore['User']['Service.MSSQL'] = $SvcSet

Invoke-Chore $Chore

If(-not($GLOBAL:_PWR.INTERACTIVE)) {
    Remove-Variable 'Chore'
}
Remove-TempDir
Remove-TempFiles
