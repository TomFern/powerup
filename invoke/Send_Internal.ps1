# Send Internal storage by email

Import-Power 'Chores'
Import-Power 'Table'
Import-Power 'EmailRecipient'

$Recipients = get-recipient ($MyInvocation.MyCommand.Name),operator

$cfg = Get-Config "chores.Send_Internal"

Try {
    $Chore = New-Chore $cfg
    $Chore['User']['Recipients'] = $Recipients
    $Chore['User']['Title'] = "Powerup Storage"
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


