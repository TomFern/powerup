# Uptime/Info module for Sybase ASE

Import-Power 'DBI.ASE'


Function Get-Uptime
{
    <#
    .SYNOPSIS
        Get basic information for Sybase ASE Instance
    .DESCRIPTION
        Returns a DataTable with one row.

        Columns:

            Hostname = Server hostname
            Servicename = Instance name
            Instancename = Instance name
            ProductName = Product Name (eg. Adaptive Server Enterprise)
            Version = version number as integer (eg. 15700)
            VersionFull = Full version string (@@version)
            OSPlatform = OS Platform String
            OSProductName = OS Product Name
            OSArch = OS Arch (eg. 64-bit)
            AuthMechanism = Instance Auth mechanism
            PageSize = Instance Page Size in bytes
            BootCount = Instance Boot count
            BootTime = Instance Last Boot datetime
            LicenseEnabled = 1 if instance has a valid ASE_CORE license
            Language = Instance laguange
            NodeId = Instance Unique Node ID
            OptimizationLevel = Instance OptimizationLevel
            RecoveryState = Instance Recovery state (normal = NOT_IN_RECOVERY)
            OpenTimeMs = how long it took last to open a connection to instance, in milliseconds
            IsBackupServerRunning = True if default backup server is found running

    .PARAMETER dbi
        A valid dbi
    .EXAMPLE
        $dbi = New-DBI "Connection String"
        $dbi = Open-DBI $dbi
        Get-Uptime $dbi
    #>
    [cmdletbinding()]
    Param([Parameter(Mandatory=$true)][HashTable]$dbi)
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    If((DBI.ASE\Test-DBI $dbi) -ne 'OPEN') {
        Throw "[Get-Uptime] dbi is invalid or not ready"
    }

$q = @'
SET NOCOUNT ON

DECLARE @now DATETIME
SELECT @now = GETDATE()
-- SELECT

DECLARE @ProductName VARCHAR(100)
DECLARE @OSProductName VARCHAR(100)
DECLARE @OSArch VARCHAR(100)
DECLARE @OSPlatform VARCHAR(100)
DECLARE @VersionCode VARCHAR(100)
DECLARE @MysteriousNumber VARCHAR(100)
DECLARE @MysteriousLetter VARCHAR(100)
DECLARE @VersionString VARCHAR(100)
DECLARE @EBFString VARCHAR(100)
DECLARE @WP INT
DECLARE @WS VARCHAR(1000)

SELECT @WS = @@VERSION

SELECT @WP = CHARINDEX('/', @WS) - 1
SELECT @ProductName = LTRIM(SUBSTRING(@WS,1,@WP))
SELECT @WS = str_replace(@ws,@ProductName+'/','')

SELECT @WP = CHARINDEX('/', @WS) - 1
SELECT @VersionString = SUBSTRING(@WS,1,@WP)
SELECT @WS = str_replace(@ws,@VersionString+'/','')

SELECT @WP = CHARINDEX('/', @WS) - 1
SELECT @EBFString = LTRIM(SUBSTRING(@WS,1,@WP))
SELECT @WS = str_replace(@ws,@EBFString+'/','')

SELECT @WP = CHARINDEX('/', @WS) - 1
SELECT @MysteriousLetter = SUBSTRING(@WS,1,@WP)
SELECT @WS = str_replace(@ws,@MysteriousLetter+'/','')

SELECT @WP = CHARINDEX('/', @WS) - 1
SELECT @OSPlatform = LTRIM(SUBSTRING(@WS,1,@WP))
SELECT @WS = str_replace(@ws,@OSPlatform+'/','')

SELECT @WP = CHARINDEX('/', @WS) - 1
SELECT @OSProductName = LTRIM(SUBSTRING(@WS,1,@WP))
SELECT @WS = str_replace(@ws,@OSProductName+'/','')

SELECT @WP = CHARINDEX('/', @WS) - 1
SELECT @VersionCode = SUBSTRING(@WS,1,@WP)
SELECT @WS = str_replace(@ws,@VersionCode+'/','')

SELECT @WP = CHARINDEX('/', @WS) - 1
SELECT @MysteriousNumber = SUBSTRING(@WS,1,@WP)
SELECT @WS = str_replace(@ws,@MysteriousNumber+'/','')

SELECT @WP = CHARINDEX('/', @WS) - 1
SELECT @OSArch = LTRIM(SUBSTRING(@WS,1,@WP))
SELECT @WS = str_replace(@ws,@OSArch+'/','')

--select @ProductName, @WP, @WS


SELECT
  asehostname() as 'Hostname',
  @@servername as 'Servicename',
  @@servername as 'Instancename',
  @ProductName as 'ProductName',
  @@version_number as 'Version',
  @@version as 'VersionFull',
  @OSPlatform as 'OSPlatform',
  @OSProductName as 'OSProductName',
  @OSArch as 'OSArch',
  @EBFString as 'EBF',
  authmech() as 'AuthMechanism',
  @@pagesize as 'PageSize',
  @@bootcount as 'BootCount',
  @@boottime as 'BootTime',
  license_enabled('ase_server') as 'LicenseEnabled',
  @@language as 'Language',
  @@nodeid as 'NodeId',
  @@optlevel as 'OptimizationLevel',
  @@recovery_state as 'RecoveryState'
'@

    $result = dbi.ase\invoke-dbi -query $q -dbi $dbi
    if(($result|measure-object).count -eq 0 -or($result.tables[0]|measure-object).count -eq 0) {
        throw "[Get-Uptime] got error while running query"
    }
    $return = $result.tables[0]

    [void]$return.Columns.Add('OpenTimeMs',[float])
    $return.rows[0].opentimems = ($dbi.opentime.milliseconds + $dbi.opentime.seconds * 1000 + $dbi.opentime.minutes * 1000 * 60 + $dbi.opentime.hours * 1000 * 60 * 60)

    [void]$return.Columns.Add('IsBackupServerRunning',[Bool])
    $bkpresult = new-object System.Data.DataTable
    $ErrorMessage = ''
    $ok = $false
    try {
        $bkpresult = DBI.ASE\Invoke-DBI -dbi $dbi -query "SYB_BACKUP...sp_who"
        $ok = $true
    }
    catch {
        $ErrorMessage = $_.Exception.Message
        $ok = $false
    }

    if($ok -and($ErrorMessage -eq '')) {
        $return.rows[0]['IsBackupServerRunning'] = $True
    }
    else {
        $return.rows[0]['IsBackupServerRunning'] = $False
    }
    return ,($return)
} # end function get-uptime


Function New-Table_Device {
<#
    .SYNOPSIS
        Table definition for Sybase ASE Devices
    .DESCRIPTION
        Columns:
            Instancename - [String] Dataserver instance name
            LogicalName - [String] Device Logical Name
            PhysicalName - [String] Device Physical Name
            VDevNo - [int] Virtual Dev Number
            DeviceType - [String] Type of device: unknown (tape?), filesystem or raw
            Description - [string] Desc string (sp_helpdevice)
            Status - [int] Status Int
            SizeMB - [Float] Total device size in MB (-1 when unknown)
            FreeMB - [Float] Free MBs (-1 when unknown)
            UsedPercent - [Float] Space Usage % (-1 when unknown)
    .LINK
        Get-Device
        Get-Database
        Get-Fragment
#>
    $Table = New-Object System.Data.DataTable 'Device'
    $Table.Columns.Add('Instancename',[String])>$null
    $Table.Columns.Add('LogicalName',[String])>$null
    $Table.Columns.Add('PhysicalName',[String])>$null
    $Table.Columns.Add('VDevNo',[Int])>$null
    $Table.Columns.Add('DeviceType',[String])>$null
    $Table.Columns.Add('Description',[String])>$null
    $Table.Columns.Add('Status',[Int])>$null
    $Table.Columns.Add('SizeMB',[Float])>$null
    $Table.Columns.Add('FreeMB',[Float])>$null
    $Table.Columns.Add('UsedPercent',[Float])>$null
    return ,$Table
} # end function New-Table_Devices


Function Get-Device {
<#
    .SYNOPSIS
        Get Sybase ASE Devices
    .DESCRIPTION
        Get Device information using sp_helpdevice. Returns New-Table_Device
    .PARAMETER DBi
        DBi for the connection
    .PARAMETER Instancename
        The instance name for table column
    .LINK
        Get-Device
        Get-Database
        Get-Fragment
        New-Table_Device
    .EXAMPLE
        $conString = "DSN=FOO;DB=master;NA=192.168.56.15,5000;UID=sa;PWD=password;"

        $dbi = dbi.ASE\new-dbi $conString
        dbi.ASE\open-dbi $dbi

        Get-Device -DBi $dbi -Instancename FOO
#>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)][HashTable]$DBi,
        [String]$Instancename=''
    )
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    Try {
        DBI.ASE\Open-DBi $DBi > $null
    }
    Catch {
        Write-Warning ("[Get-Device] Open-DBI error: {0}" -f $_.Exception.Message)
    }

    $Table = ASE.Uptime\New-Table_Device

    $sql = "exec sp_helpdevice"
    $result = New-Object System.Data.DataSet
    $ErrorMessage = ''
    Try {
        $result = DBI.ASE\Invoke-DBI -DBI $DBi -Query $sql
    }
    Catch {
        Write-Warning ("[Get-Device] {0} sp_helpdevice failed with error: {1}" -f  $Instancename,$_.Exception.Message)
        $ErrorMessage = $_.Exception.Message
    }

    If(-not($ErrorMessage) -and(($result|measure-object).count -gt 0) -and($result.tables[0]|measure-object).Count -gt 0) {
        $result.Tables[0] | Foreach {

            $newrow = $Table.NewRow()
            $newrow.Instancename = $Instancename
            $newrow.LogicalName = $_.device_name
            $newrow.PhysicalName = $_.physical_name
            $newrow.VDevNo = $_.vdevno
            $newrow.Status = $_.status
            $newrow.Description = $_.description

            $Elements = @()
            ($newrow.Description -split ',') | Foreach { $Elements += ($_ | Out-String).Trim() }

            $newrow.SizeMB = -1
            $newrow.FreeMB = -1
            $Elements | Foreach {
                If($_ -eq 'file system device') {
                    $newrow.DeviceType = 'filesystem'
                }
                elseIf($_ -eq 'unknown device type') {
                    $newrow.DeviceType = 'unknown'
                }
                If($_ -eq 'raw device') {
                    $newrow.DeviceType = 'raw'
                }
                elseif($_ -match '^Free:\s[0-9]+\.?[0-9]+?\sMB$'){
                    $value = $_
                    $value = $value -replace 'Free:',''
                    $value = $value -replace 'MB',''
                    $value = $value -replace ' ',''
                    $value = [Int]$value
                    $newrow.FreeMB = $value
                }
                elseif($_ -match '^[0-9]+\.?[0-9]+?\sMB$'){
                    $value = $_
                    $value = $value -replace 'MB',''
                    $value = $value -replace ' ',''
                    $value = [Int]$value
                    $newrow.SizeMB = $value
                }
            }
            If(($newrow.SizeMB -ge 0) -and($newrow.FreeMB -ge 0)) {
                $newrow.UsedPercent = [Math]::Round((100*(($newrow.SizeMB -$newrow.FreeMB)/$newrow.SizeMB)),2)
            }
            else {
                $newrow.UsedPercent = -1
            }
            $Table.Rows.Add($newrow)
        }
    }

    return ,$Table

} # end function Get-Device


Function New-Table_Fragment {
<#
    .SYNOPSIS
        Table definition for Sybase ASE Databases
    .DESCRIPTION
        Columns:
            Ord - [Int] Autoincremented Device Number
            Instancename - [String] Dataserver Instance Name
            Database - [String] Database name
            DeviceLogicalName - [String] Fragment device logical name
            CreateDate - [DateTime] Fragment creation date
            UsageType - [String] can be 'data', 'log', or 'data and log'
            SizeMB - [Float] Fragment size in MB
            FreeMB - [Float] Fragment free size in MB

    .LINK
        Get-Device
        Get-Database
        Get-Fragment

#>
    $Table = New-Object System.Data.DataTable 'Fragment'
    $Table.Columns.Add('Ord',[Int])>$null
    $Table.Columns['Ord'].Autoincrement = $true
    $Table.Columns.Add('Instancename',[String])>$null
    $Table.Columns.Add('Database',[String])>$null
    $Table.Columns.Add('DeviceLogicalName',[String])>$null
    $Table.Columns.Add('CreateDate',[DateTime])>$null
    $Table.Columns.Add('UsageType',[String])>$null
    $Table.Columns.Add('SizeMB',[Float])>$null
    $Table.Columns.Add('FreeMB',[Float])>$null
    return ,$Table
} # end function New-Table_Fragment


Function Get-Fragment {
<#
    .SYNOPSIS
        Get Database Fragments for Sybase ASE
    .DESCRIPTION
        Get database fragments info and sizes (sp_helpdb). Returns New-Table_Fragment
    .PARAMETER DBi
        DBi for the connection
    .PARAMETER Database
        Database name
    .PARAMETER Instancename
        The instance name for table column
    .LINK
        Get-Device
        Get-Database
        Get-Fragment
        New-Table_Fragment

    .EXAMPLE
        $conString = "DSN=FOO;DB=master;NA=192.168.56.15,5000;UID=sa;PWD=password;"

        $dbi = dbi.ASE\new-dbi $conString
        dbi.ASE\open-dbi $dbi

        Get-Fragment -Database master -DBi $dbi -Instancename FOO

#>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)][HashTable]$DBi,
        [Parameter(Mandatory=$true)][String]$Database,
        [String]$Instancename=''
    )
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    Try {
        DBI.ASE\Open-DBi $DBi > $null
    }
    Catch {
        Write-Warning ("[Get-Device] Open-DBI error: {0}" -f $_.Exception.Message)
    }

    $Table = ASE.Uptime\New-Table_Fragment

    $sql = "exec sp_helpdb $Database"
    $result = New-Object System.Data.DataSet
    $ErrorMessage = ''
    Try {
        $result = DBI.ASE\Invoke-DBI -DBI $DBi -Query $sql
    }
    Catch {
        Write-Warning ("[Get-Device] {0} sp_helpdevice failed with error: {1}" -f  $Instancename,$_.Exception.Message)
        $ErrorMessage = $_.Exception.Message
    }

    function _get_usage {
        param([string]$usage)

        if($usage -match '.*data.*log.*') {
            return 'data+log'
        }
        elseif($usage -match '^data.*') {
            return 'data'
        }
        elseif($usage -match '^log.*') {
            return 'log'
        }
        else {
            return 'UNKNOWN'
        }
    }

    If(-not($ErrorMessage) -and(($result|measure-object).count -gt 0) -and($result.tables[1]|measure-object).Count -gt 0) {
        $result.Tables[1] | Foreach {
            $freeMB = 0
            try {
                $free_kbytes = ($_['free kbytes'] -replace ' ','')
                if($free_kbytes -match "^[\d\.]+$") {
                $FreeMB = $free_kbytes
                }
            }
            catch {
                write-warning ("[Get-Fragment] Exception: {0}" -f $_.Exception.Message)
                $freeMB = 0
            }


            # write-host ($_|out-string)

            # If((($_['free kbytes']|Measure-Object).Count -gt 0) -and($_['free kbytes'] -match "^[\d\.]+$")) { $Free = ($_['free kbytes']|out-String).Trim() }
            # ElseIf((($_['free_kbytes']|Measure-Object).Count -gt 0) -and($_['free kbytes'] -match "^[\d\.]+$")) { $Free = ($_['free_kbytes']|Out-String).Trim() }

            $newrow = $Table.NewRow()
            $newrow.Instancename = $Instancename
            $newrow.Database = $Database
            try {
                $newrow.DeviceLogicalName = $_.device_fragments
            }
            catch {
                write-warning ("[Get-Fragment] Exception: {0}" -f $_.Exception.Message)
                $newrow.DeviceLogicalName = ''
            }
            $Size = ($_.size|Out-String).Trim()
            $Size = $Size -replace 'MB',''
            $Size = $Size -replace ' ',''
            $Size = [Int]$Size
            $newrow.SizeMB = $Size
            $newrow.UsageType = (_get_usage $_.usage)
            $newrow.CreateDate = $_.created
            If($freeMB -ge 0) {
                $freeMB = [Float]$freeMB
                $freeMB = $freeMB / 1024
            }
            $newrow.FreeMB = $freeMB
            $Table.Rows.Add($newrow)
        }
    }
    return ,$Table
} # end function Get-Fragment


Function New-Table_Database {
<#
    .SYNOPSIS
        Table definition for Sybase ASE Databases
    .DESCRIPTION
    .LINK
        Get-Device
        Get-Database
        Get-Fragment

#>
    $Table = New-Object System.Data.DataTable 'Database'
    $Table.Columns.Add('Hostname',[String])>$null
    $Table.Columns.Add('Servicename',[String])>$null
    $Table.Columns.Add('Instancename',[String])>$null
    $Table.Columns.Add('Database',[String])>$null
    $Table.Columns.Add('DBId',[Int])>$null
    $Table.Columns.Add('CreateDate',[DateTime])>$null
    $Table.Columns.Add('IsOnline',[Bool])>$null
    $Table.Columns.Add('IsSuspect',[Bool])>$null
    $Table.Columns.Add('IsReadOnly',[Bool])>$null
    $Table.Columns.Add('IsSingleUser',[Bool])>$null
    $Table.Columns.Add('TotalSizeMB',[Float])>$null
    $Table.Columns.Add('DataSizeMB',[Float])>$null
    $Table.Columns.Add('DataFreeMB',[Float])>$null
    $Table.Columns.Add('DataUsedPercent',[Float])>$null
    $Table.Columns.Add('LogSizeMB',[Float])>$null
    $Table.Columns.Add('LogFreeMB',[Float])>$null
    $Table.Columns.Add('LogUsedPercent',[Float])>$null
    $Table.Columns.Add('DataLogSizeMB',[Float])>$null
    $Table.Columns.Add('DataLogFreeMB',[Float])>$null
    $Table.Columns.Add('DataLogUsedPercent',[Float])>$null
    return ,$Table
} # end function New-Table_Database



Function Get-Database {
<#
    .SYNOPSIS
        Get All Databases from Sybase ASE
    .DESCRIPTION
        Get databases info and sizes (sysdatabass and sp_helpdb). Returns New-Table_Database

        Columns:
            Hostname - [String] Server hostname
            Servicename - [String] Dataserver Instance Name
            Instancename - [String] Dataserver Instance Name
            Database - [String] Database name
            DBid - [in] Database Id
            CreateDate - [DateTime] DB creation date
            IsOnline - [Bool] True when DB is online
            IsSuspect - [Bool] True when DB is suspect
            IsSingleUser - [Bool] True when DB is in single user mode
            IsReadOnly - [Bool] True when DB is in readonly user mode
            TotalSizeMB - [Float] DB total size in MB
            DataSizeMB - [Float] Total data segment size in MB
            DataFreeMB - [Float] Free space in data segment in MB
            DataUsedPercent - [Float] Space usage for data segment
            LogSizeMB - [Float] Total Log segment size in MB
            LogFreeMB - [Float] Free space in Log segment in MB
            LogUsedPercent - [Float] Space usage for Log segment
            DataLogSizeMB - [Float] Total Data+Log (mixed) segment size in MB
            DataLogFreeMB - [Float] Free space in Data+Log (mixed) segment in MB
            DataLogUsedPercent - [Float] Space usage for Data+Log (mixed) segment
    .PARAMETER DBi
        DBi for the connection
    .PARAMETER Instancename
        The instance name for table column
    .LINK
        Get-Device
        Get-Database
        Get-Fragment
        New-Table_Database

    .EXAMPLE
        $conString = "DSN=FOO;DB=master;NA=192.168.56.15,5000;UID=sa;PWD=password;"

        $dbi = dbi.ASE\new-dbi $conString
        dbi.ASE\open-dbi $dbi

        Get-Database -DBi $dbi -Instancename FOO
#>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)][HashTable]$DBi,
        [String]$Instancename=''
    )
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    Try {
        DBI.ASE\Open-DBi $DBi > $null
    }
    Catch {
        Write-Warning ("[Get-Database] Open-DBI error: {0}" -f $_.Exception.Message)
    }

    $Table = ASE.Uptime\New-Table_Database
    $hostname = ''
    $Servicename = ''
    $sql = "select asehostname() as hostname,@@servername as servicename"
    Try {
        $result = DBI.ASE\Invoke-DBI -DBI $DBi -Query $sql
        $hostname = $result.tables[0].rows[0]['hostname']
        $servicename = $result.tables[0].rows[0]['servicename']
    }
    Catch {
        Write-Warning ("[Get-Database] {0} query failed: {1}" -f  $Instancename,$_.Exception.Message)
        $ErrorMessage = $_.Exception.Message
    }

    # $sql = "exec sp_helpdb"
    $sql = "select * from master..sysdatabases"
    $result = New-Object System.Data.DataSet
    $ErrorMessage = ''
    Try {
        $result = DBI.ASE\Invoke-DBI -DBI $DBi -Query $sql
    }
    Catch {
        Write-Warning ("[Get-Database] {0} query failed: {1}" -f  $Instancename,$_.Exception.Message)
        $ErrorMessage = $_.Exception.Message
    }

    $Mask1 = @{
        32 = 'norecovery';
        256 = 'suspect';
        1024 = 'read-only';
        4096 = 'single-user';
    }

    $Mask2 = @{
        16 = 'offline';
        32 = 'offline-transient';
        128 = 'suspect-pages';
        -32768 = 'mixed-datalog';
    }
    $Mask3 = @{
        32 = 'mounted';
        64 = 'mounted';
        4096 = 'shutdown';
    }

    function IsStatus {
        Param($Mask,$Bitvalue,$Status)
        $result = ( $Mask.Keys | Where { $_ -band $Bitvalue } | Foreach { $Mask.Get_Item($_) } )
        If($result -contains $Status) {
            return $true
        }
        else {
            return $false
        }
    }


    If(-not($ErrorMessage) -and(($result|measure-object).count -gt 0) -and($result.tables[0]|measure-object).Count -gt 0) {
        $result.Tables[0] | Foreach {
            $newrow = $Table.NewRow()
            $newrow.hostname = $hostname
            $newrow.Servicename = $servicename
            $newrow.Instancename = $Servicename
            $newrow.Database = $_.name
            $newrow.DBId = $_.dbid
            $newrow.CreateDate = $_.crdate

            $newrow.IsReadOnly = [bool](IsStatus $Mask1 $_.status 'read-only')
            $newrow.IsSingleUser = [bool](IsStatus $Mask1 $_.status 'single-user')

            If((IsStatus $Mask2 $_.status2 'offline') -or(IsStatus $Mask2 $_.status2 'offline-transient') -or(IsStatus $Mask3 $_.status3 'shutdown') -or(IsStatus $Mask1 $_.status 'norecovery')) {
                $newrow.IsOnline = $false
            }
            else {
                $newrow.IsOnline = $true
            }

            If((IsStatus $Mask2 $_.status2 'suspect-pages') -or(IsStatus $Mask1 $_.status 'suspect')) {
                $newrow.IsSuspect = $true
            }
            else {
                $newrow.IsSuspect = $false
            }
            $Table.Rows.Add($newrow)
        }
    }



    # Space Usage
    Foreach($row in $Table) {
        $Database = $row.Database
        # write-host $database
        $logFreeMB = 0
        $helpdb = Invoke-DBI -dbi $DBI -Query ("sp_helpdb {0}" -f $Database)
        if(($helpdb.tables|measure).count -ge 3) {
            $helpdb_tail = $helpdb.tables[2].rows[0][0]
            if($helpdb_tail -match 'log only free') {
                $logfreemb = ((([int]$helpdb_tail.split('=')[1].trim()))/1024)
            }
        }
        # write-host ( $helpdb|get-table|foreach { $helpdb.tables[$_] |ft } | out-string)
        # convert free kbytes log to mb
        # $logFreeMB = (([int]($helpdb.tables[2].rows[0][0].split('=')[1].trim()))/1024)

        $Fragment = Get-Fragment $DBi $Database
        $Total = @{
            'data' = @{ 'Size' = 0; 'Free' = 0; 'UsedPercent' = 0;};
            'data+log' = @{ 'Size' = 0; 'Free' = 0; 'UsedPercent' = 0;};
            'log' = @{ 'Size' = 0; 'Free' = 0; 'UsedPercent' = 0;};
        }
        # write-host ($Total|Out-String)
        Foreach($Frag IN $Fragment.rows) {
        # write-host $frag.UsageType
        # $Fragment | Foreach {
        # write-host ($_|out-string)
            $Total[$Frag.UsageType]['Size'] += $Frag.SizeMB
            $Total[$Frag.UsageType]['Free'] += $Frag.FreeMB
            $Total[$Frag.UsageType]['UsedPercent'] = [Math]::Round((100*($Total[$Frag.UsageType]['Size']-$Total[$Frag.UsageType]['Free'])/$Total[$Frag.UsageType]['Size']),2)
        }

        $row.DataSizeMB = $Total['data']['Size']
        $row.DataFreeMB = $Total['data']['Free']
        $row.DataUsedPercent = $Total['data']['UsedPercent']
        $row.logSizeMB = $Total['log']['Size']
        # $row.logFreeMB = $Total['log']['Free']
        # $row.logUsedPercent = $Total['log']['UsedPercent']
        $row.DataLogSizeMB = $Total['data+log']['Size']
        $row.DataLogFreeMB = $Total['data+log']['Free']
        $row.DataLogUsedPercent = $Total['data+log']['UsedPercent']
        $row.TotalSizeMB = ($Total['data']['Size'] + $Total['log']['Size'] + $Total['data+log']['Size'])
        $row.logFreemb = $logFreeMB
        $row.LogUsedPercent =  [Math]::Round(((($row.logsizemb-$row.logfreemb)*100/$row.logSizeMB)),2)
    }
    return ,$Table
}


Function Get-ErrorLog {
<#
    .SYNOPSIS
        Retrieve Errorlog for ASE
    .DESCRIPTION
        Gets the errorlog from monitoring table.

        Monitoring must be configured and activated first:

            exec sp_configure 'enable monitoring',1

            exec sp_configure 'errorlog pipe active', 1

            -- tweak it as needed
            exec sp_configure 'errorlog pipe max messages', 300

    .PARAMETER DBi
        ASE DBi
    .PARAMETER Instancename
        Name of the instance
    .PARAMETER Limit
        Limit number of rows
    .PARAMETER Descending
        [Switch] Sort descending by time
    .LINK

    .EXAMPLE
    $e = Get-ErrorLog -DBi $dbi -Limit 100 -Descending -Instancename 'FOO'

#>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)][HashTable]$DBi,
        [String]$Instancename,
        [Int]$Limit=0,
        [Switch]$Descending
    )
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    $sl = @()
    $sl += "SELECT"
    if($Limit -gt 0) {
        $sl += "TOP $Limit"
    }
    $sl += "* FROM master..monErrorLog"
    $sl += "ORDER BY Time"
    If($Descending) {
        $sl += "DESC"
    }
    else {
        $sl += "ASC"
    }

    $stmt = $sl -join " "
    # write-host $stmt

    $ds = DBI.ASE\Invoke-DBI -DBI $DBi -Query $stmt

    $ErrorTable = New-Object System.Data.DataTable 'Get-ErrorLog'
    $ErrorTable.Columns.Add("Servicename",[String]) >$null
    $ErrorTable.Merge($ds.Tables[0].Copy())

    if($Instancename) {
        foreach($r in $ErrorTable.Rows) {
            $r['Servicename'] = $Instancename
        }
    }

    return ,$ErrorTable
} # end function Get-ErrorLog
