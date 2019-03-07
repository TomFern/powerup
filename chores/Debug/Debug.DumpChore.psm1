# Dump Chore Variables

New-Variable -Scope Script 'UserVars'
New-Variable -Scope Script 'id'

function StepPre {
    Param([HashTable]$usr,[HashTable]$id)
    $Script:UserVars = $usr
    $Script:id = $id
}

function StepProcess {
    Write-Host "[Debug.DumpChore] USER" -ForegroundColor Magenta
    Foreach($v in $Script:UserVars.Keys) {
        Write-Host ("{0} <- {1}" -f $v,($Script:Uservars[$v]|Out-String).Trim())
    }
    Write-Host "[Debug.DumpChore] ID" -ForegroundColor Magenta
    Foreach($v in $Script:Id.Keys) {
        Write-Host ("{0} <- {1}" -f $v,($Script:Id[$v]|Out-String).Trim())
    }
}

function StepNext {
    @{}
}
