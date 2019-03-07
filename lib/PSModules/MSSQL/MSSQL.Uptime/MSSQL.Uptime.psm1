#
# MSSQL Diagnostics

Import-Power 'DBI.MSSQL'

Set-StrictMode -version 2

Function Get-Uptime
{
    <#
    .SYNOPSIS
        Get basic information for a MS SQL Server instance
    .DESCRIPTION
        Returns a DataTable with one row.

        Columns:
            Hostname = computer Hostname (virtual name if IsClustered)
            Physicalname = computer physical name (changes when active cluster node switches)
            Servicename = sql instance full instance name (SERVER\INSTANCE)
            Instancename = sql instance name (INSTANCE)
            IsDefaultInstance = 1 when the IsDefaultInstance Instance, 0 otherwise
            IsClustered = 1 when this is a IsClustered node, 0 otherwise
            MajorVersion = leading version number (eg 11 -> SQL 2012, etc)
            ProductVersion = full version number
            ProductName = full product name (eg. SQL Server 2012)
            ProductEdition = sql server edition name (eg. express)
            ServicePackLevel = service pack level (eg. SP3, RTM)
            ServerCollation = Default Server collation
            AuthenticationMode = 'mixed' or 'windows' for integrated security mode
            OSPlatform = 'OSType' 'Processor' 'Arch' (eg. NT INTEL X86)
            WindowsVersion = Windows NT version number
            Language = SQL Server language
            PID = Instance process Id
            ProcessorCount = number of cores
            PhysicalMemoryMB = installed memory in MB
            DatabaseCount = number of databases, including system and tempdb
            TotalAllocatedMB = total size of allocated disk space in MB
            StartDate = date & time instance started
            UptimeSec = instance uptime in seconds
            UptimeDHMS = instance uptime in human readable value
            WindowsStartDate = date & time computer started
            WindowsUptimeSec = computer uptime in seconds
            WindowsUptimeDHMS = human readable computer uptime
            IsAgentRunning = 1 for sql agent running, 0 otherwise, -1 if no agent installed (eg. express, localdb, etc)
            OwnedDrives = a comma separated list of drive letters that host databases (eg. D,E,F)
            OpenTimeMs = how long it took last to open a connection to instance, in milliseconds

            More counters I cound add later:

            total size used percent:
            memory_allocated_mb:
            memory_max_mb:
            memory_min_mb:

    .PARAMETER dbi
        A valid dbi, if not supplied tries LAST_DBI
    .EXAMPLE
        $dbi = New-DBI "Connection String"
        $dbi = Open-DBI $dbi
        Get-SQLUptime $dbi
    #>
    [cmdletbinding()]
    Param([Parameter(Mandatory=$true)][HashTable]$dbi)
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    If((DBI.MSSQL\Test-DBI $dbi) -ne 'OPEN') {
        Throw "[Get-Uptime] dbi is invalid or not ready"
    }

$q = @'

SET NOCOUNT ON

DECLARE @now DATETIME
SELECT @now = GETDATE()

DECLARE @productversion NVARCHAR(MAX)
DECLARE @MajorVersion INT
DECLARE @starttime_host DATETIME
DECLARE @starttime DATETIME
DECLARE @uptime INT
DECLARE @uptime_host INT
DECLARE @uptime_s NVARCHAR(100)
DECLARE @uptime_host_s NVARCHAR(100)
DECLARE @letters varchar(100)
DECLARE @isIsDefaultInstance INT
DECLARE @AuthenticationMode VARCHAR(8)

SELECT @productversion = CAST(SERVERPROPERTY('ProductVersion') AS NVARCHAR(MAX))
SELECT @MajorVersion = CAST(LEFT(@productversion, CHARINDEX('.',@productversion) - 1) AS INT);

IF (@MajorVersion < 9)
BEGIN
    PRINT 'This version of sql server is too old. You must have SQL 2008 or greater.'
    RETURN
END

IF (SERVERPROPERTY('IsIntegratedSecurityOnly') = 1)
    SELECT @AuthenticationMode = 'windows'
ELSE
    SELECT @AuthenticationMode = 'mixed'

IF SERVERPROPERTY('Instancename') IS NULL
    SELECT @isIsDefaultInstance = 0
ELSE
    SELECT @isIsDefaultInstance = 1

SELECT @starttime = create_date
FROM master.sys.databases
WHERE name = 'tempdb';

SELECT @uptime = DATEDIFF(second, @starttime, @now)
SELECT @uptime_s = CAST(FLOOR(@uptime / 86400) AS NVARCHAR(10))+'d ' +
    CONVERT(NVARCHAR(5), DATEADD(SECOND, @uptime, '19000101'), 8)

SELECT @starttime_host = DATEADD(ms,-sample_ms,GETDATE() )
FROM master.sys.dm_io_virtual_file_stats(1,1);
SELECT @uptime_host = DATEDIFF(second, @starttime_host, @now)
SELECT @uptime_host_s = CAST(FLOOR(@uptime_host / 86400) AS NVARCHAR(10))+'d ' +
    CONVERT(NVARCHAR(5), DATEADD(SECOND, @uptime_host, '19000101'), 8)

DECLARE @agentrunning INT
--IF ((SERVERPROPERTY('EngineEdition') <> 4) OR (CAST(SERVERPROPERTY('Edition') AS NVARCHAR(100)) NOT LIKE'%express%'))
IF (SERVERPROPERTY('EngineEdition') <> 4)
BEGIN
        SELECT @agentrunning = -1
    IF EXISTS (
        SELECT TOP 1 1
        FROM master..sysprocesses
        WHERE program_name LIKE N'SQLAgent - %'
            )
        SELECT @agentrunning = 1
    ELSE
        SELECT @agentrunning = 0
END

-- Get Drives for Database files
select @letters = COALESCE(@letters + ',','') + drive_letter
from (
select DISTINCT SUBSTRING(filename,1,1) drive_letter from master..sysaltfiles
) as drive_letter

-- Append drive with the ERRORLOG
if @MajorVersion >= 12
begin
    select @letters = COALESCE(@letters + ',','') + substring(path,1,1)
    from Sys.dm_os_server_diagnostics_log_configurations
    where is_enabled = 1
end

-- get information from xp_msver
DECLARE @xp_msver TABLE (
    [idx] [int] NULL
    ,[c_name] [varchar](100) NULL
    ,[int_val] [float] NULL
    ,[c_val] [varchar](128) NULL
    )

INSERT INTO @xp_msver
EXEC ('[master]..[xp_msver]')
--SELECT * from @xp_msver

DECLARE @WindowsVersion VARCHAR(15)
DECLARE @OSPlatform VARCHAR(15)
DECLARE @processors INT
DECLARE @PhysicalMemoryMB INT
DECLARE @language VARCHAR(50)

SELECT @WindowsVersion = c_val FROM @xp_msver WHERE c_name = 'WindowsVersion'
SELECT @OSPlatform = c_val FROM @xp_msver WHERE c_name = 'Platform'
SELECT @language = c_val FROM @xp_msver WHERE c_name = 'Language'
SELECT @processors = c_val FROM @xp_msver WHERE c_name = 'ProcessorCount'
SELECT @PhysicalMemoryMB = int_val FROM @xp_msver WHERE c_name = 'PhysicalMemory'

-- size databases
DECLARE @db_size_total INT
;with fs
as
(
    select database_id, type, size * 8.0 / 1024 size
    from sys.master_files
)
SELECT @db_size_total = ROUND(SUM(size),0) from fs

DECLARE @DatabaseCount INT
SELECT @DatabaseCount = COUNT(*) from master.sys.databases


SELECT
    SERVERPROPERTY('MachineName') AS [Hostname],
    SERVERPROPERTY('ComputerNamePhysicalNetBIOS') AS [Physicalname],
    SERVERPROPERTY('ServerName') AS [Servicename],
    SERVERPROPERTY('Instancename') AS [Instancename],
    @isIsDefaultInstance AS [IsDefaultInstance],
    SERVERPROPERTY('IsClustered') AS [IsClustered],
    @MajorVersion AS [MajorVersion],
    @productversion AS [ProductVersion],
    Left(@@Version, Charindex('(', @@version) - 1) As [ProductName],
    SERVERPROPERTY('Edition') AS [ProductEdition],
    SERVERPROPERTY('ProductLevel') AS [ServicePackLevel],
    SERVERPROPERTY('Collation') as [ServerCollation],
    @AuthenticationMode AS [AuthenticationMode],
    @OSPlatform as 'OSPlatform',
    @WindowsVersion as 'WindowsVersion',
    SERVERPROPERTY('ProcessID') as [PID],
    @language as [Language],
    @processors as [ProcessorCount],
    @PhysicalMemoryMB as [PhysicalMemoryMB],
    @DatabaseCount as [DatabaseCount],
    @db_size_total as [TotalAllocatedMB],
    @starttime AS [StartDate],
    @uptime as [UptimeSec],
    @uptime_s AS [UptimeDHMS],
    @starttime_host AS [WindowsStartDate],
    @uptime_host as [WindowsUptimeSec],
    @uptime_host_s AS [WindowsUptimeDHMS],
    @agentrunning AS [IsAgentRunning],
    @letters as [OwnedDrives]

'@

    $result = DBI.MSSQL\Invoke-DBI -Query $q -dbi $dbi
    If(($result|Measure-Object).Count -eq 0 -or($result.Tables[0]|Measure-Object).count -eq 0) {
        Throw "[Get-Uptime] Got error while running query"
    }
    $return = $result.Tables[0]

    $return.Columns.Add((New-Object system.Data.DataColumn 'OpenTimeMs'))

    # FIXME This doesn't seem to work
    # if($dbi.ContainsKey('OpenTime')) {
        $return.Rows[0].OpenTimeMs = ($dbi.OpenTime.Milliseconds + $dbi.openTime.Seconds * 1000 + $dbi.OpenTime.Minutes * 1000 * 60 + $dbi.OpenTime.Hours * 1000 * 60 * 60)
    # }
    return ,($return)


} # end function Get-Uptime


Function Get-Database
{
    <#
    .SYNOPSIS
        Get a long list of Databases, statuses and more
    .DESCRIPTION
        Gets a Datatable with databases, their status, backups, mirroring, log shipping and more

        Columns:
            Hostname = machine name
            Servicename = full instance name (eg. SERVER\INSTANCE)
            Instancename = instane name (eg. INSTANCE)
            Database = database name
            DbCreateDate = create time
            DbCompatibilityLevel = compatibility level (eg. 120)
            DbCollation = collation name
            DbAccessMode = user access level (eg. MULTI_USER)
            DbState = database state (eg. ONLINE)
            DbRecoveryModel = recovery model (eg. FULL)
            IsDbReadOnly = false if read-write
            IsDBAutoClose = true if auto close enabled
            IsDBAutoShrink = true if auto shrink enabled
            IsDBStandBy = true if in-standby
            IsDBCleanShutdown = true if closed cleanly (??)
            DBState2 = database state extended (eg. LS-Standby "Log Shipping Stdby")
            IsDBUp = 1 when DB can be considered up, 0 otherwise
            IsDBFailed = 1 when DB has failed to start (eg. suspect), 0 otherwise
            BackupFullStartDate = last full backup start datetime
            BackupFullStopDate = last full backpup stop datetime
            BackupFullRecoveryModel  = recovery model during last full backup
            BackupFullDevice = last path / device name for full backup
            BackupFullSizeMB = total size of full backup file in MB
            BackupFullDurationSec = last full backup duration in seconds
            BackupDiffStartDate = last diff backup start datetime
            BackupDiffStopDate = last diff backpup stop datetime
            BackupDiffRecoveryModel  = recovery model during last diff backup
            BackupDiffDevice = last path / device name for diff backup
            BackupDiffSizeMB = total size of diff backup file in MB
            BackupDiffDurationSec = last diff backup duration in seconds
            BackupLogStartDate = last log backup start datetime
            BackupLogStopDate = last log backpup stop datetime
            BackupLogRecoveryModel  = recovery model during last log backup
            BackupLogDevice = last path / device name for log backup
            BackupLogSizeMB = total size of log backup file in MB
            BackupLogDurationSec = last log backup duration in seconds
            MirrorRole = mirroring role (eg. PRIMARY)
            MirrorState = mirroring state (eg. SYNC)
            MirrorSafetyLevel = mirroring safety level
            MirrorInstancePartner  = mirroring partner instance
            MirrorInstanceWitness = mirroring witness instance
            MirrorWitnessState = mirroring witness state
            LogshipState = log shipping status
            LogshipRole = log shipping role
            LogshipInstancePartner = log shipping partner instance
            LogshipDatabasePartner = log shipping partner database
            LogshipSinceLastBackup = log shipping time since last log backup
            LogshipSinceLastRestore = log shipping time since last log restore
            LogshipSinceLastCopy = log shipping time since last log copy
            LogshipLatencyRestore = log shipping latency for last restore

            I'd like to add (maybe):
            db_owner
            db_filegroup_count = 1
            db_size_data_allocated_mb =
            db_size_data_used_mb
            db_size_data_free_mb
            db_size_data_used_percent
            db_size_log_allocated_mb =
            db_size_log_used_mb
            db_size_log_free_mb
            db_size_log_used_percent
            db_size_total_allocated_mb =
            db_size_total_used_mb
            db_size_total_free_mb
            db_size_total_used_percent
            db_last_checkdb_date

            these should be aggregates
            db_grow_data_enable
            db_grow_data_limit_mb
            db_grow_data_increment
            db_grow_log_enable
            db_grow_log_limit_mb
            db_grow_log_increment


    .PARAMETER dbi
        A valid dbi, if not supplied tries LAST_DBI
    .EXAMPLE
        $dbi = New-DBI "Connection String"
        $dbi = Open-DBI $dbi
        Get-Database $dbi
    #>
    [cmdletbinding()]
    Param([Parameter(Mandatory=$true)][HashTable]$dbi)
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    If((DBI.MSSQL\Test-DBI $dbi) -ne 'OPEN') {
        Throw "[Get-Database] dbi is invalid or not ready"
    }

$q = @'

SET NOCOUNT ON

DECLARE @now DATETIME
SELECT @now = GETDATE()

DECLARE @productversion NVARCHAR(MAX)
DECLARE @MajorVersion INT
SELECT @productversion = CAST(SERVERPROPERTY('ProductVersion') AS NVARCHAR(MAX))
SELECT @MajorVersion = CAST(LEFT(@productversion, CHARINDEX('.',@productversion) - 1) AS INT);

 IF (@MajorVersion < 9)
BEGIN
    PRINT 'This version of sql server is too old. Booo!'
    RETURN
END

-- backup set information
DECLARE @backups TABLE (
Servicename nvarchar(128),
db_name nvarchar(128),
starttime datetime,
stoptime datetime,
physical_device_name nvarchar(260),
file_size_mb int,
duration int,
mode nvarchar(4),
recovery_model nvarchar(60)
)

;WITH backup_cte AS (
SELECT
    s.server_name as [Servicename],
    s.database_name as [db_name],
    s.backup_start_date as [starttime],
    s.backup_finish_date as [stoptime],
    m.physical_device_name,
    CAST(s.backup_size / (1024*1024) AS INT) as [file_size_mb],
    DATEDIFF(second, s.backup_start_date, s.backup_finish_date) as [duration],
    CASE s.[type]
    WHEN 'D' THEN 'FULL'
    WHEN 'I' THEN 'DIFF'
    WHEN 'L' THEN 'LOG'
    END AS [mode],
    s.recovery_model,
    rownum = row_number() over
            (
                partition by database_name, type
                order by backup_finish_date desc
            )
    FROM msdb.dbo.backupset s
    INNER JOIN msdb.dbo.backupmediafamily m ON s.media_set_id = m.media_set_id
)
INSERT INTO @backups
SELECT TOP 1000
    [Servicename],
    [db_name],
    [starttime],
    [stoptime],
    [physical_device_name],
    [file_size_mb],
    [duration],
    [mode],
    [recovery_model]
FROM backup_cte
WHERE rownum = 1

-- Log shipping is a mess
DECLARE @logship TABLE (
    status BIT, is_primary BIT,
    server NVARCHAR(36),
    database_name NVARCHAR(255),
    time_since_lst_backup INT,
    last_backup_file NVARCHAR(500)
    ,backup_threshold INT,
    is_backup_alert_enabled BIT,
    time_since_last_copy INT,
    last_copied_file NVARCHAR(500)
    ,time_since_last_restore INT,
    last_restored_file NVARCHAR(500),
    last_restored_latency INT,
    restore_threshold INT,is_restore_alert_enabled INT
)

-- No logshipping on Express edition, raises exception
IF (CAST(SERVERPROPERTY('Edition') AS NVARCHAR(100)) NOT LIKE'%express%')
 INSERT INTO @logship EXEC sp_help_log_shipping_monitor

 -- get output
SELECT
    SERVERPROPERTY('MachineName') AS [Hostname],
    SERVERPROPERTY('ServerName') AS [Servicename],
    SERVERPROPERTY('Instancename') AS [Instancename],
    d.name as [Database],
    d.create_date as [DbCreateDate],
    d.compatibility_level as [DbCompatibilityLevel],
    d.collation_name as [DbCollation],
    d.user_access_desc as [DbAccessMode],
    d.state_desc as [DbState],
    d.recovery_model_desc as [DbRecoveryModel],
    d.is_read_only as [IsDbReadOnly],
    d.is_auto_close_on as [IsDbAutoClose],
    d.is_auto_shrink_on as [IsDBAutoShrink],
    d.is_in_standby as [IsDBStandBy],
    d.is_cleanly_shutdown as [IsDBCleanShutdown],

    -- db extended status
    CASE
    WHEN databaseproperty(d.name,'IsOffline') = 1 THEN 'offline'
    WHEN databaseproperty(d.name,'IsShutDown') = 1 THEN 'shutdown'
    WHEN databaseproperty(d.name,'IsNotRecovered') = 1 THEN 'norecover'
    WHEN databaseproperty(d.name,'IsInLoad') = 1 AND (SELECT COUNT(*) FROM msdb.dbo.log_shipping_secondary_databases WHERE d.name=secondary_database) = 1 THEN  'LS-restoring'
    WHEN databaseproperty(d.name,'IsInLoad') = 1 AND (SELECT COUNT(*) FROM msdb.dbo.log_shipping_secondary_databases WHERE d.name=secondary_database) = 0 THEN  'restoring'
    WHEN databaseproperty(d.name,'IsInRecovery') = 1 THEN  'recovering'
    WHEN databaseproperty(d.name,'IsInStandby') = 1 AND (SELECT COUNT(*) FROM msdb.dbo.log_shipping_secondary_databases WHERE d.name=secondary_database) = 1 THEN  'LS-standby'
    WHEN databaseproperty(d.name,'IsInStandby') = 1 AND (SELECT COUNT(*) FROM msdb.dbo.log_shipping_secondary_databases WHERE d.name=secondary_database) = 0 THEN  'standby'
    WHEN databaseproperty(d.name,'IsSuspect') = 1 THEN  'suspect'
    WHEN has_dbaccess(d.name) <> 1  AND
    (SELECT COUNT(*) FROM   master.sys.database_mirroring m
    WHERE  m.database_id= d.database_id AND m.mirroring_role_desc = 'MIRROR') = 1 THEN 'mirror'
    ELSE 'online'
END as DbState2,

    CASE
    WHEN databaseproperty(d.name,'IsOffline') = 1 THEN 0
    WHEN databaseproperty(d.name,'IsShutDown') = 1 THEN 0
    WHEN databaseproperty(d.name,'IsNotRecovered') = 1 THEN 0
    WHEN databaseproperty(d.name,'IsSuspect') = 1 THEN 0
    -- log shipping
    WHEN databaseproperty(d.name,'IsInLoad') = 1 AND
        (SELECT COUNT(*)
            FROM msdb.dbo.log_shipping_secondary_databases
            WHERE secondary_database=d.name) = 1 THEN  1
    WHEN has_dbaccess(d.name) <> 1 AND
        (SELECT COUNT(*) FROM   master.sys.database_mirroring m
        WHERE  m.database_id= d.database_id AND m.mirroring_role_desc = 'MIRROR') = 0 THEN 0
    ELSE 1
    END as IsDbUp,

    CASE
    WHEN databaseproperty(d.name,'IsShutDown') = 1 THEN 1
    WHEN databaseproperty(d.name,'IsNotRecovered') = 1 THEN 1
    WHEN databaseproperty(d.name,'IsSuspect') = 1 THEN 1
    ELSE 0
    END as IsDbFailed,

    -- log shipping
    --backups
    bf.starttime as [BackupFullStartDate],
    bf.stoptime as [BackupFullStopDate],
    bf.recovery_model as [BackupFullRecoveryModel],
    bf.physical_device_name as [BackupFullDevice],
    bf.file_size_mb as [BackupFullSizeMB],
    bf.duration as [BackupFullDurationSec],
    bd.starttime as [BackupDiffStartDate],
    bd.stoptime as [BackupDiffStopDate],
    bd.recovery_model as [BackupDiffRecoveryModel],
    bd.physical_device_name as [BackupDiffDevice],
    bd.file_size_mb as [BackupDiffSizeMB],
    bd.duration as [BackupDiffDurationSec],
    bl.starttime as [BackupLogStartDate],
    bl.stoptime as [BackupLogStopDate],
    bl.recovery_model as [BackupLogRecoveryModel],
    bl.physical_device_name as [BackupLogDevice],
    bl.file_size_mb as [BackupLogSizeMB],
    bl.duration as [BackupLogDurationSec],

    -- mirroring
    m.mirroring_Role_desc as [MirrorRole],
    m.mirroring_state_desc as [MirrorState],
    m.mirroring_safety_level_desc as [MirrorSafetyLevel],
    m.mirroring_partner_instance as [MirrorInstancePartner],
    m.mirroring_witness_name as [MirrorInstanceWitness],
    m.mirroring_witness_state_desc as [MirrorWitnessState],

    -- log shipping
    CASE
        WHEN l.status is NULL THEN NULL
        WHEN l.status = 0 THEN 'SYNC'
        ELSE 'NOSYNC'
    END as LogshipState,
    CASE
        WHEN l.is_primary IS NULL THEN NULL
        WHEN l.is_primary = 1 THEN 'PRIMARY'
        ELSE 'SECONDARY'
    END AS LogshipRole,
    l.[server] as [LogshipInstancePartner],
    l.database_name as [LogshipDatabasePartner],
    l.time_since_lst_backup AS [LogshipSinceLastBackup],
    l.time_since_last_restore AS [LogshipSinceLastRestore],
    l.time_since_last_copy AS [LogshipSinceLastCopy],
    l.last_restored_latency AS [LogshipLatencyRestore]
    FROM master.sys.databases d
    INNER JOIN master.sys.database_mirroring m
    ON m.database_id = d.database_id
    LEFT OUTER JOIN @logship l
    ON l.database_name = d.name
    LEFT OUTER JOIN @backups bf
    ON bf.db_name = d.name AND bf.mode = 'FULL'
    LEFT OUTER JOIN @backups bd
    ON bd.db_name = d.name AND bd.mode = 'DIFF'
    LEFT OUTER JOIN @backups bl
    ON bl.db_name = d.name AND bl.mode = 'LOG'
    WHERE l.[server] IS NULL
    OR l.[server] = @@SERVERNAME

'@

    $result = DBI.MSSQL\Invoke-DBI -Query $q -dbi $dbi
    If(($result|Measure-Object).Count -eq 0 -or($result.Tables[0]|Measure-Object).count -eq 0) {
        Throw "[Get-Database] Got error while running query"
    }

    return ,($result.Tables[0])

} # end function Get-Database



Function Get-Disk
{
    <#
    .SYNOPSIS
        Get disk space information from SQL Server
    .DESCRIPTION
        Query SQL DMVs for disk space information, same columns as MSWIN.Diag\Get-DiskSpace.
        This only works for 2008 R2+

    .PARAMETER dbi
        A valid dbi, if not supplied tries LAST_DBI
    .EXAMPLE
        $dbi = New-DBI "Connection String"
        $dbi = Open-DBI $dbi
        Get-Disk $dbi
    #>
    [cmdletbinding()]
    Param(
        $dbi = $null
    )
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    If((DBI.MSSQL\Test-DBI $dbi) -ne 'OPEN') {
        Throw "[Get-Disk] dbi is invalid or not ready"
    }

$q = @'
set nocount on;

DECLARE @productversion NVARCHAR(MAX)
DECLARE @MajorVersion INT
SELECT @productversion = CAST(SERVERPROPERTY('ProductVersion') AS NVARCHAR(MAX))
SELECT @MajorVersion = CAST(LEFT(@productversion, CHARINDEX('.',@productversion) - 1) AS INT);

-- Version should be 10.5 onwards
IF (@MajorVersion < 10)
BEGIN
    PRINT 'This version of sql server is too old. Booo!'
    RETURN
END

IF (@productversion like '10.0%')
BEGIN
    PRINT 'This version of sql server is too old. Booo!'
    RETURN
END

select
DISTINCT
convert(varchar(255),serverproperty('MachineName')) as 'Hostname',
logical_volume_name as 'DriveLabel',
substring(volume_mount_point,0,2) as 'Letter',
round(total_bytes/(1024*1024*1024),0) as 'SizeGB',
round(total_bytes/(1024*1024),0) as 'SizeMB',
total_bytes as 'SizeB',
round(available_bytes/(1024*1024*1024),0) as 'FreeGB',
round(available_bytes/(1024*1024),0) as 'FreeMB',
available_bytes as 'FreeB',
round((total_bytes-available_bytes)/(1024*1024*1024),0) as 'UsedGB',
round((total_bytes-available_bytes)/(1024*1024),0) as 'UsedMB',
total_bytes-available_bytes as 'UsedB',
100 - round(available_bytes*100/total_bytes,0) as 'UsedPercent',
round(available_bytes*100/total_bytes,0) as 'FreePercent',
case
when (100 - round(available_bytes*100/total_bytes,0) - round(log10(available_bytes/(1024*1024*1024)),0)) < 0
then 0
when (100 - round(available_bytes*100/total_bytes,0) - round(log10(available_bytes/(1024*1024*1024)),0)) > 100
then 100
else (100 - round(available_bytes*100/total_bytes,0) - round(log10(available_bytes/(1024*1024*1024)),0))
end as 'FillFigure'
FROM master.sys.master_files f
CROSS APPLY sys.dm_os_volume_stats(f.database_id, f.file_id);

'@

    $result = DBI.MSSQL\Invoke-DBI -Query $q -dbi $dbi
    If(($result|Measure-Object).Count -eq 0 -or($result.Tables[0]|Measure-Object).count -eq 0) {
        # if(-not($result) -or(-not($result.Tables))) {
        Throw "[Get-SQLDatabases] error while doing query"
    }
    return ,($result.Tables[0])

} # end function Get-Disk

