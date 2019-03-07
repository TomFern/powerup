#
# MS Windows Diagnostics
#

Set-StrictMode -version latest

Function Get-Uptime
{
    <#
    .SYNOPSIS
        Get Windows basic information and diagnostics
    .DESCRIPTION
        Returns a DataTable with diagnostic information

        Columns:
            Hostname - [String] Computer hostname
            Up - [bool] false when server is down or unreacheable
            BootDate - [String] Last Bootup Date
            LocalData - [String] Local Date & Time
            Uptime - [String] Uptime in NNd HH:MM:SS
            UptimeSeconds - [Long] Uptime in seconds
            Ipaddr - [String] IPV4 Address (resolved with ping)
            Ipaddr6 - [String] IPV6 Address (resolved with ping)
            Domain - [String] Windows Domain
            MemorySizeByte - [Long] Memory Size in Bytes
            Cpucount - [Int] Cpu Count
            Version - [String] Windows Version
            Arch - [String] '32-bit' or '64-bit'
            LogicalCpuCount - [Int] Number of logical cpus
            PhysicalCpuCount - [Int] Number of Physical cpus
            ProcessorName - [String] Name of the processor
            ProcessorCaption - [String] Caption of the processor
            ProcessorManufacturer - [String] Manufacturer of the processor
            ProcessorSeatCount - [Int] Total Number of socket/seat cpu chips
            ProcessorCoreCount - [Int] Total Number of cores
            ProcessorLogicalCount - [Int] Total Number of logical processor = core * hypertreading

        The host Up check is a little more involved than just a ping:
            1. Tries a ping
            2. Checks RDP port opened
            3. Checks RPC/Services
            4. Tries a ping again
        If any of these are positive then Up is $True

    .PARAMETER computer
        The machine hostname. Defaults to localhost (.)
    .EXAMPLE
        $info = Get-Uptime -computer FOO
    #>
    [cmdletbinding()]
    Param(
        [string] $computer='.'
    )
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    $diag = New-Object System.Data.DataTable 'WinDiag'
    $diag.Columns.Add((New-Object System.Data.DataColumn 'Hostname', ([String])))
    $diag.Columns.Add((New-Object System.Data.DataColumn 'Up', ([Bool])))
    $diag.Columns.Add((New-Object System.Data.DataColumn 'BootDate', ([String])))
    $diag.Columns.Add((New-Object System.Data.DataColumn 'LocalDate', ([String])))
    $diag.Columns.Add((New-Object System.Data.DataColumn 'UptimeSeconds', ([Long])))
    $diag.Columns.Add((New-Object System.Data.DataColumn 'Uptime', ([String])))
    $diag.Columns.Add((New-Object System.Data.DataColumn 'Ipaddr', ([String])))
    $diag.Columns.Add((New-Object System.Data.DataColumn 'Ipaddr6', ([String])))
    $diag.Columns.Add((New-Object System.Data.DataColumn 'Domain', ([String])))
    $diag.Columns.Add((New-Object System.Data.DataColumn 'MemorySizeByte', ([Long])))
    $diag.Columns.Add((New-Object System.Data.DataColumn 'MemorySizeMB', ([Long])))
    $diag.Columns.Add((New-Object System.Data.DataColumn 'ProcessorName', ([String])))
    $diag.Columns.Add((New-Object System.Data.DataColumn 'ProcessorCaption', ([String])))
    $diag.Columns.Add((New-Object System.Data.DataColumn 'ProcessorManufacturer', ([String])))
    $diag.Columns.Add((New-Object System.Data.DataColumn 'ProcessorClockSpeedMHz', ([Int])))
    $diag.Columns.Add((New-Object System.Data.DataColumn 'ProcessorLogicalCount', ([Int])))
    $diag.Columns.Add((New-Object System.Data.DataColumn 'ProcessorCoreCount', ([Int])))
    $diag.Columns.Add((New-Object System.Data.DataColumn 'ProcessorSeatCount', ([Int])))
    $diag.Columns.Add((New-Object System.Data.DataColumn 'Version', ([String])))
    $diag.Columns.Add((New-Object System.Data.DataColumn 'Arch', ([String])))

    $row = $diag.NewRow()
    $row.hostname = $computer

    function _set_property {
        Param($object,$property,$variable)
        if(Get-Member -InputObject $object -MemberType Property -Name $property) {
            $variable = $object.$property
        }
    }


    $wmi = Get-WmiObject -ComputerName $computer -Class Win32_ComputerSystem
    if(($wmi|Measure-Object).count -gt 0) {
        $row.Up = $true
        if($wmi.Domain) { $row.Domain = $wmi.Domain }
        if($wmi.Name) { $row.Hostname = $wmi.Name }
        if($wmi.TotalPhysicalMemory) { $row.MemorySizeByte = $wmi.TotalPhysicalMemory; $row.MemorySizeMB = ($wmi.TotalPhysicalMemory/1048576) }
        if($wmi.NumberOfLogicalProcessors) { $row.ProcessorLogicalCount = $wmi.NumberOfLogicalProcessors}
    }
    $wmi = Get-WmiObject -ComputerName $computer -Class Win32_OperatingSystem
    if(($wmi|Measure-Object).count -gt 0) {
        $row.Up = $true
        if($wmi.Version) { $row.Version = $wmi.Version }
        if($wmi.LastBootUpTime) { $row.BootDate = $wmi.ConvertToDateTime($wmi.LastBootUpTime).ToString() }
        if($wmi.LocalDateTime) { $row.LocalDate = $wmi.ConvertToDateTime($wmi.LocalDateTime).ToString() }
        if($row.BootDate -and($row.LocalDate)) {
            $Span = New-TimeSpan -Start $wmi.ConvertToDateTime($wmi.LastBootUpTime) -End $wmi.ConvertToDateTime($wmi.LocalDateTime)
            $row.UptimeSeconds = $Span.TotalSeconds
            $row.Uptime = ("{0}d {1}:{2}:{3}" -f $Span.Days,$Span.Hours,$Span.Minutes,$Span.Seconds)
        }
        if($wmi.OSArchitecture) { $row.Arch = $wmi.OSArchitecture }
    }

    # processor is tricky to parse
    $wmi = Get-WmiObject -ComputerName $computer -Class Win32_Processor
    if(($wmi|Measure-Object).count -gt 0) {

        # multiple seats/sockets
        if($wmi -is [Array]) {
            $row.ProcessorSeatCount = @($wmi).count
            $row.ProcessorCoreCount = 0
            $row.ProcessorLogicalCount = 0
            foreach($processor in $wmi) {
                $row.ProcessorCoreCount += $processor.NumberOfCores
                $row.ProcessorLogicalCount += $processor.NumberOfLogicalProcessors
            }

            $firstproc = $wmi[0]

            # $arch = 0
            # _set_property $firstproc 'AddressWidth' $arch
            # if($arch -eq 32) { $row.Arch = '32-bit' }
            # elseif($arch -eq 64) { $row.Arch = '64-bit' }

            # _set_property $firstproc 'Name' $row.ProcessorName
            # _set_property $firstproc 'Manufacturer' $row.ProcessorManufacturer
            # _set_property $firstproc 'CurrentClockSpeed' $row.ProcessorClockSpeedMHz
            # _set_property $firstproc 'Caption' $row.ProcessorCaption


            # if($firstproc.Name) { $row.ProcessorName = $firstproc.Name }
            # if($firstproc.AddressWidth) {
            #     if($firstproc.AddressWidth -eq 32) { $row.Arch = '32-bit' }
            #     elseif($firstproc.AddressWidth -eq 64) { $row.Arch = '64-bit' }
            # }
            # if($firstproc.Caption) { $row.ProcessorCaption = $firstproc.Caption }
            # if($firstproc.Manufacturer) { $row.ProcessorManufacturer = $firstproc.Manufacturer }
            # if($firstproc.CurrentClockSpeed) { $row.ProcessorClockSpeedMHz = $firstproc.CurrentClockSpeed }

             $row.ProcessorName = $firstproc.Name

                if($firstproc.AddressWidth -eq 32) { $row.Arch = '32-bit' }
                elseif($firstproc.AddressWidth -eq 64) { $row.Arch = '64-bit' }
            $row.ProcessorCaption = $firstproc.Caption
            $row.ProcessorManufacturer = $firstproc.Manufacturer
            $row.ProcessorClockSpeedMHz = $firstproc.CurrentClockSpeed
        }
        else {

            $row.ProcessorSeatCount = 1
            $row.ProcessorCoreCount = $wmi.NumberOfCores
            $row.ProcessorLogicalCount = $wmi.NumberOfLogicalProcessors
            $row.ProcessorManufacturer = $wmi.Manufacturer
            $row.ProcessorCaption = $wmi.Caption
            $row.ProcessorName = $wmi.Name
            $row.ProcessorClockSpeedMHz = $wmi.CurrentClockSpeed

            # $row.ProcessorCoreCount = $wmi.NumberOfCores
            # $row.ProcessorLogicalCount = $wmi.NumberOfLogicalProcessors
        }
    }

    # try ICMP Ping
    $ping = $null
    try {
        Write-Debug "[Get-Uptime] Trying PING (ICMP) $computer"
        $ping = Test-Connection -Count 1 -BufferSize 16 -ComputerName $computer -ErrorAction 0
        if(($ping|Measure-Object).Count -gt 0) {
            $row.Up = $True
            If(($ping|Get-Member|Where { $_.Name -eq 'IPV4Address' }|Measure-Object).Count -gt 0) {
                $row.ipaddr = $ping.IPV4Address.IPAddressToString
            }
            # If(($ping|Get-Member|Where { $_.Name -eq 'IPV6Address' }|Measure-Object).Count -gt 0) {
            #     $row.ipaddr6 = $ping.IPV6Address.IPAddressToString
            # }
        }
        else {
            Write-Debug ("[Get-Uptime] Ping failed {0}")
        }
    }
    catch {
        Write-Debug ("[Get-Uptime] Ping failed {0}: {1}" -f $computer,$_.Exception.Message)
    }

    # if tests above failed, make more tests to detect if server is up
    if(-not($row.Up)) {
        try {
            Write-Debug "[Get-Uptime] Trying RDP Socket $computer"
            $socket = New-Object Net.Sockets.TcpClient($computer, 3389)
            if($socket) {
                $row.Up = $True
                $socket.close()
            }
            else {
                Write-Debug "[Get-Uptime] Trying to get services on $computer"
                $service = Get-Service -computer $computer -Name Netlogon
                if($service -ne $null) {
                    $row.Up = $True
                }
                else {
                    Write-Debug "[Get-Uptime] Trying to ping $computer"
                    $ping = Test-Connection -Count 2 -computer $computer -quiet
                    if($ping) {
                        $row.Up = $true
                    }
                }
            }
        }
        catch {
            Write-Debug "[Get-Uptime] Open socket failed $computer"
        }
    }

    $diag.Rows.Add($row) | Out-Null
    return ,$diag
} # end function Get-Uptime

function _get_fillfigure {
        Param($used_pct, $free_gb)
        $f = $used_pct - [Math]::Round([Math]::Log10($free_gb/10))
        if($f -lt 0) {
                $f = 0
        }
        elseif($f -gt 100) {
                $f = 100
        }
        return $f
}

function Get-Disk {
<#
.SYNOPSIS
Get drive space information on remote servers

.DESCRIPTION
Connects to remote servers using WMI and gets disk space information
Returns a DataTable

    Columns:
        Hostname [String]
        DriveLabel [String]
        Letter [String]
        SizeGB [Long] Total Size
        SizeMb [Long]
        SizeB [Long]
        FreeGB [Long] Free Space
        FreeMB [Long]
        FreeB [Long]
        UsedGB [Long] Used Space
        UsedMB [Long]
        UsedB [Long]
        UsedPercent [Int]
        FreePercent [Int]
        FillFigure [Int] UsedPercent - Log10(FreeGB/10)


.PARAMETER Computer
    The server to connect to, defaults to localhost

.PARAMETER includeDrives
    A string with comma-separated drive letters to query, if not provided will query all existing disks

.PARAMETER excludeDrives
    A string with comma-separated drive letters to ignore, e.g. "A,B,C"

.EXAMPLE
    Get-Disk 'SRV1' -includeDrives 'C,D,E'
    Get-Disk 'SRV1' -excludeDrives 'A,B'
#>

Param(
    [string] $computer='.',
    [string] $includeDrives='',
    [string] $excludeDrives=''
)
    $included = $includeDrives.ToUpper().split(',')
    $excluded = $excludeDrives.ToUpper().split(',')

    $diag = New-Object System.Data.DataTable 'DisksSpace'
    $diag.Columns.Add((New-Object System.Data.DataColumn 'Hostname',([String])))
    $diag.Columns.Add((New-Object System.Data.DataColumn 'DriveLabel',([String])))
    $diag.Columns.Add((New-Object System.Data.DataColumn 'Letter',([String])))
    $diag.Columns.Add((New-Object System.Data.DataColumn 'SizeGB',([Long])))
    $diag.Columns.Add((New-Object System.Data.DataColumn 'SizeMb',([Long])))
    $diag.Columns.Add((New-Object System.Data.DataColumn 'SizeB',([Long])))
    $diag.Columns.Add((New-Object System.Data.DataColumn 'FreeGB',([Long])))
    $diag.Columns.Add((New-Object System.Data.DataColumn 'FreeMB',([Long])))
    $diag.Columns.Add((New-Object System.Data.DataColumn 'FreeB',([Long])))
    $diag.Columns.Add((New-Object System.Data.DataColumn 'UsedGB',([Long])))
    $diag.Columns.Add((New-Object System.Data.DataColumn 'UsedMB',([Long])))
    $diag.Columns.Add((New-Object System.Data.DataColumn 'UsedB',([Long])))
    $diag.Columns.Add((New-Object System.Data.DataColumn 'UsedPercent',([Int])))
    $diag.Columns.Add((New-Object System.Data.DataColumn 'FreePercent',([Int])))
    $diag.Columns.Add((New-Object System.Data.DataColumn 'FillFigure',([Int])))

    $data = get-wmiobject Win32_LogicalDisk -computername $computer -Filter "DriveType = 3"
    if($data -ne $null) {
        foreach($d in $data) {
            $letter = ($d.DeviceID.ToUpper())[0]
            if($excluded -notcontains $letter) {
                if((($includeDrives.Length -gt 0) -and($included -contains $letter)) `
                    -or($includeDrives.Length -eq 0)) {
                        $DriveLabel = $d.VolumeName
                        $Letter = ($d.DeviceID.ToUpper())[0]
                        $sizeb = $d.Size
                        $sizemb = [Math]::round($sizeb / 1048576)
                        $sizegb = [Math]::round($sizemb / 1024)
                        $freeb = $d.FreeSpace
                        $freemb = [Math]::round($freeb / 1048576)
                        $freegb = [Math]::round($freemb / 1024)
                        $used = $freeb/$sizeb
                        $usedb = $sizeb - $freeb
                        $usedmb = [Math]::round($usedb / 1048576)
                        $usedgb = [Math]::round($usedmb / 1024)
                        $FreePercent = [Math]::round(($used) * 100)
                        $UsedPercent = (100 - $FreePercent)
                        $fillfigure = [int] (_get_fillfigure $UsedPercent $freegb)
                        $diag.Rows.Add($computer,$DriveLabel,$letter,$sizegb,$sizemb,$sizeb,$freegb,$freemb,$freeb,$usedgb,$usedmb,$usedb,$UsedPercent,$FreePercent,$fillfigure) | Out-Null
                }
            }
        }
    }
    else {
        Write-Warning "[Get-Disk] Can't get disk info from Windows on $computer"
    }
    return ,$diag
}
