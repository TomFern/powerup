# Checkout for Sybase
Param(
    [String]$Recipients="",
    [String]$IService="",
    [String]$IService_RS="",
    [Switch]$Alert
)

Import-Power 'Chores'
Import-Power 'Table'
Import-Power 'Inventory'
Import-Power 'EmailRecipient'
$Localdir = $Global:_PWR.LOCALDIR

if(-not($Recipients)) { $Recipients = get-recipient ($MyInvocation.MyCommand.Name),dbastaff }
if(-not($IService)) { $IService="$localdir\inventory\Instance_ASE.csv" }
if(-not($IService_RS)) { $IService_RS="$localdir\inventory\Instance_RepServer.csv" }

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

$cfg = Get-Config "chores.Checkout_Sybase"
Try {
    $Chore = New-Chore $cfg
    $Chore['User']['Recipients'] = $Recipients
    $Chore['User']['Title'] = ("Checkout {0}" -f $GLOBAL:_PWR['LOCAL']['project']['caption'])
    # $Chore['User']['Database.ASE'] = $DBSet
    # $Chore['User']['Service.RepServer'] = $RSSet
    # $Chore['Id']['Config']['SendOnlyOnIssue'] = $Alert
    $Chore['User']['Service.ASE'] = $ServiceSet
    # $Chore['User']['Checkout.ASE'] = New-Object System.Data.DataSet 'Checkout.ASE'
}
Catch {
    Send-ErrorReport -Message ("Can't create chore {0}: {1}" -f $cfg['name'],$_.Exception.Message)
    Throw ("Can't create chore: {0}" -f $_.Exception.Message)
}

Try {
    Invoke-Chore $Chore
}
Catch {
    Send-ErrorReport -Message ("Chore had an error:{0}. Error was: {1}" -f $cfg['Name'], $_.Exception.Message)
    Write-Warning ("Chore had an error: {0}" -f $_.Exception.Message)
}
Finally {
    If(-not($GLOBAL:_PWR.INTERACTIVE)) {
        Remove-Variable 'Chore'
    }
    Remove-TempDir
    Remove-TempFiles
}



