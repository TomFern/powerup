RECIPES

= Sybase ASE


Quickly Connect to a Sybase ASE

```
# target instance: FOO

use dbi.ase
use table
use dsql

$service = New-TableFromCSV .\inventory\Instance_ASE.csv
$cstring = Get-ConnectionString -IService $service -Module ASE
$dbi = New-DBI $cstring['FOO']
# Your connection should be ready after opening
Open-DBI $dbi
```


Generate DISK INIT

```
# target instsance: FOO
use ase.gen

$device = Get-Device $DBi
Get-DeviceDDL $device > DISKINIT.sql


```

Generate Database DDL

```
# target instance: FOO
# target db: BAZ

use ase.gen

$fragment = Get-Fragment -DBI $DBi -Database BAZ
Get-DatabaseDDL -Fragment $fragment > CREATEDB.sql
```

