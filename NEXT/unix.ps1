# linux powershell with linux sql server

use DBI.MSSQL
$d = new-dbi 'server=ix;User Id=sa;Password=HoLa1234'
open-dbi $d
$i = invoke-dbi $d "SELECT @@SERVERNAME as 'svc'"
foreach($r in $i.tables[0].rows) { $r['svc'] }

# an example with rsjob?

import-module -name (jp $GLOBAL:_PWR['BASEDIR'],'/NEXT/RSJob/PoshRSJob/PoshRSJob.psm1')
start-rsjob -argumentlist $GLOBAL:_PWR['POWERUP_FILE'],$d -ScriptBlock {
    Param($boot,$dbi)

    . $boot -nointeractive >$null
    # import-power 'DBI.MSSQL'

    # invoke-dbi $dbi "SELECT @@servername as 'svc'"
}

wait-rsjob|get-rsjob|receive-rsjob
get-rsjob|remove-rsjob
