# this example works
# the only thing is tthat wait-rsjob doesn't really wait?

import-module .\PoshRSJob\PoshRSJob.psm1
use dsql
$c=Get-ConnectionString .\inventory\Instance_ASE.csv


$wu = @{
'boot' = $GLOBAL:_PWR['POWERUP_FILE'];
'cs' = $c['APPS04'];
}

get-rsjob|remove-rsjob
@($wu) | Start-RSJob -name test -Scriptblock {
	$wu = $_

	. $wu['boot'] -nointeractive >$Null

import-power 'DBI.ASE'
$dbi = new-dbi $wu['cs']
open-dbi $dbi >$null
invoke-dbi $dbi 'SELECT @@SERVERNAME as "svc"'

}
wait-rsjob -state Completed
$r=(get-rsjob|receive-rsjob)
$r.tables[0]|ft
