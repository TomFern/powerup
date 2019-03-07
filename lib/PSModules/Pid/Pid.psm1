
$PIDDIR = join-path $GLOBAL:_PWR.WORKDIR 'run'

function Find-PidFile {

# EXAMPLE
# $process_id = Find-PidFile 'MyScript'
# if($process_id) {
#   if($pid -eq $process_id) {
#       Throw "Already running process"
#   }
#   else {
#       Remove-PidFile 'MyScript'
#   }
# }
#   
#$testt = Get-Process | ?{$_.ID -eq $pid}
    Param(
        [Parameter(Mandatory=$true)][string] $name
    )
    
    # Open file, return PID
    $process_id
    return
}

function Add-PidFile {
    Param(
        [Parameter(Mandatory=$true)][string] $name,
        [Parameter(Mandatory=$true)][integer] $process_id
    )
}

function Remove-PidFile {
    Param(
        [Parameter(Mandatory=$true)][string] $name
    )
}


# vim: ft=ps1
