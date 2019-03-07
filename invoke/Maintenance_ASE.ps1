# Run Maintenance on Sybase Audit Archive

Import-Power 'Chores'
Import-Power 'Table'
Import-Power 'Inventory'

# Instance Table from a CSV
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
$SvcSet = New-Object System.Data.DataSet
$SvcSet.Merge($Inventory)

$cfg = Get-Config "chores.Maintenance_ASE"

Try {
    $Chore = New-Chore $cfg
    $Chore['User']['Service.ASE'] = $SvcSet
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

