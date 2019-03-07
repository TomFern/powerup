# Sanity Check Report for Sybase ASE & Replication Server
Param(
    [String]$Recipients="",
    [String]$IService="",
    [String]$IService_RS="",
    [Switch]$Alert,
    [Switch]$NoMail,
    [Switch]$Help
)

Import-Power 'EmailRecipient'

# Defaults
$localdir = $Global:_PWR.LOCALDIR
$OD=@{}
$OD['IService'] = (jp $localdir,'inventory','Instance_ASE.csv')
$OD['IService_RS'] = (jp $localdir,'inventory','Instance_RepServer.csv')
$OD['Recipients'] = get-recipient ($MyInvocation.MyCommand.Name),dbastaff


if($Help) {
    wh ("Usage: {0} [SWITCHES] [OPTIONS] [ARGS]" -f ($MyInvocation.MyCommand.Name))

    wh "Switches:"

    wh -f white -NoNewLine "  -Help           "
    wh "Show this message"

    wh -f white -NoNewLine "  -Alert          "
    wh "Don't send email unless there are issues"

    wh -f white -NoNewLine "  -NoMail         "
    wh "Don't send email"

    wh "Options:"

    wh -f white -NoNewLine "  -Recipients    "
    wh ("Email address list. Default: {0}" -f $OD['Recipients'])

    wh -f white -NoNewLine "  -IService      "
    wh ("Service inventory file. Default: {0}" -f $OD['IService'])

    wh -f white -NoNewLine "  -IService_RS  "
    wh ("Replication Server file. Default: {0}" -f $OD['IService_RS'])

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
if(-not($IService)) { $IService=$OD['IService'] }
if(-not($IService_RS)) { $IService_RS=$OD['IService_RS'] }
if($NoMail) {
    $Recipients = ''
}

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

$IService_RS_Table = $null
If(test-path $IService_RS) {
    $IService_RS_Table = New-TableFromCSV $IService_RS
}
else {
    $new = New-Table_IService
    $new.Rows.Add() >$null
    $new | Export-CSV -NoTypeInformation $IService_RS
    Write-Warning "Please edit input and try again: $IService_RS"
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
    Write-Host -NoNewLine "Recipients: "
    Write-Host -ForegroundColor White $Recipients
}
Catch {}


# Prepare DataSet object
$DBSet = New-Object System.Data.DataSet
$DBSet.Merge($Inventory.Copy())
$SystemSet = $DBSet.Copy()
$ServiceSet = $DBSet.Copy()
$RSSet = New-Object System.Data.DataSet
$IService_RS_Table.TableName = 'IService'
$RSSet.Merge($IService_RS_Table)

$cfg = Get-Config "chores.Report_Sanity_ASE"
$Chore = New-Chore $cfg
$Chore['User']['Recipients'] = $Recipients
$Chore['User']['Title'] = ("Sanity {0}" -f $GLOBAL:_PWR['LOCAL']['project']['caption'])
$Chore['User']['Database.ASE'] = $DBSet
$Chore['User']['Service.RepServer'] = $RSSet
$Chore['Id']['Config']['SendOnlyOnIssue'] = $Alert
$Chore['User']['Service.ASE'] = $ServiceSet

Invoke-Chore $Chore
If(-not($GLOBAL:_PWR.INTERACTIVE)) {
    Remove-Variable 'Chore'
}
Remove-TempDir
Remove-TempFiles
