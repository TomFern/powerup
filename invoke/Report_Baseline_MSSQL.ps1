# Baseline Spreasheet Report Email

Import-Power 'Chores'
Import-Power 'Table'
Import-Power 'Inventory'
Import-Power 'EmailRecipient'

$Recipients = get-recipient ($MyInvocation.MyCommand.Name),dbastaff

# Instance List from a CSV
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
    Write-Host -NoNewLine "Recipients: "
    Write-Host -ForegroundColor White $Recipients
}
Catch {}

# Prepare DataSet object
$DBSet = New-Object System.Data.DataSet
$DBSet.Merge($Inventory.Copy())
$SystemSet = $DBSet.Copy()
$ServiceSet = $DBSet.Copy()

# Uncomment to use cluster default node check
# $ClusterDefaultHost = New-TableFromCSV ".\inventory\Cluster.Default.MSSQL.csv"
# $ClusterDefaultHost.TableName = 'ClusterDefaultHostname'
# $ServiceSet.Tables.Add($ClusterDefaultHost)


$cfg = Get-Config "chores.Report_Baseline_MSSQL"

Try {
    $Chore = New-Chore $cfg
    $Chore['User']['Recipients'] = $Recipients
    $Chore['User']['Title'] = ("Baseline {0}" -f $GLOBAL:_PWR['LOCAL']['project']['caption'])
    $Chore['User']['Database.MSSQL'] = $DBSet
    $Chore['User']['System.Windows'] = $SystemSet
    $Chore['User']['Service.MSSQL'] = $ServiceSet
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


