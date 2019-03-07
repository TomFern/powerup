# Inventory DataSet


Import-Power 'Table'

Set-StrictMode -version Latest

Function New-Table_IHost
{
    <#
    .SYNOPSIS
        A Table for Servers / Hosts
    .DESCRIPTION
        Creates a new table for Host: inventory for Servers / Hosts

        Columns:
            Hostname - [String] Computer name
            Role - [String] Describes computer role, eg. Prod, Test, Cert, etc.

        If a table is supplied as parameter then:
            - Remove extraneous columns
            - Remove row w/o Hostname

    .PARAMETER $Table
        Copy from existing IHost
    .EXAMPLE
        $hosts = New-Table_IHost
        $hosts2 = New-Table_IHost $PreviousHosts
    #>
    [cmdletbinding()]
    Param([Object]$Table)

    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    $New = New-Table 'IHost'
    $New = New-Object System.Data.DataTable 'IHost'
    [void]$New.Columns.Add('Hostname',[String])
    [void]$New.Columns.Add('Role',[String])

    # Sanitize Input table if supplied
    if(($Table|Measure-Object).Count -gt 0) {
        $Table = Split-Table $Table Hostname,Role

        # Remove Empty Rows
        $Filtered = New-Object System.Data.DataTable 'IHost'
        [void]$Filtered.Columns.Add('Hostname',[String])
        [void]$Filtered.Columns.Add('Role',[String])

        $Table.Select("Hostname IS NOT NULL AND Hostname <> ''") | Foreach {
            if(-not([DBNull]::Value.Equals($_.Hostname))) { $_.Hostname = $_.Hostname.toUpper() }
            # if(-not([DBNull]::Value.Equals($_.Role))) { $_.Role = $_.Role.toUpper() }
            $Filtered.ImportRow($_)
        }
        $Filtered | Foreach {
            If([DBNull]::Value.Equals($_.Role)) { $_.Role = 'NOROLE' }
        }

        If(($Filtered|Measure-Object).count -gt 0) {
            $New.Merge($Filtered)
        }
    }

    return ,$New
} # end function New-Table_IHost

Function New-Table_IService
{
    <#
    .SYNOPSIS
        A table for Services/Instances
    .DESCRIPTION
        Creates a new table to describe Services or Instances of services

        Columns:
            Hostname - [String] Host computer hostname
            Servicename - [String] Main fully qualified name for the service
            Instancename - [String] Alternate or short name for the service
            Role - [String] Service role, eg. Prod, Cert, Test, etc.
            IP - [String] Ip address (optional)
            Port - [Int] Service port number (optional)

        If a table is supplied as parameter then:
            - Remove extraneous columns
            - Remove row w/o Hostname AND Servicename

    .PARAMETER $Table
        Copy from an existing IService
    .EXAMPLE
        $services = New-Table_IService
        $services2 = New-Table_IService $PreviousTable
    #>
    [cmdletbinding()]
    Param(
        [Object] $Table
    )
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    $New = New-Object System.Data.DataTable 'IService'
    [void]$New.Columns.Add('Hostname',[String])
    [void]$New.Columns.Add('Servicename',[String])
    [void]$New.Columns.Add('Instancename',[String])
    [void]$New.Columns.Add('Role',[String])
    [void]$New.Columns.Add('IP',[String])
    [void]$New.Columns.Add('Port',[Int])

    # Sanitize Input table if supplied
    if(($Table|Measure-Object).Count -gt 0) {
        $Table = Split-Table $Table Hostname,Servicename,Instancename,Role,IP,Port

        # Remove Empty Rows
        $Filtered = New-Object System.Data.DataTable 'IService'
        [void]$Filtered.Columns.Add('Hostname',[String])
        [void]$Filtered.Columns.Add('Servicename',[String])
        [void]$Filtered.Columns.Add('Instancename',[String])
        [void]$Filtered.Columns.Add('Role',[String])
        [void]$Filtered.Columns.Add('IP',[String])
        [void]$Filtered.Columns.Add('Port',[Int])

        $Table.Select("Hostname IS NOT NULL AND Hostname <> '' AND Servicename IS NOT NULL AND Servicename <> '' ") | Foreach {
            if(-not([DBNull]::Value.Equals($_.Hostname))) { $_.Hostname = $_.Hostname.toUpper() }
            if(-not([DBNull]::Value.Equals($_.Servicename))) { $_.Servicename = $_.Servicename.toUpper() }
            if(-not([DBNull]::Value.Equals($_.Instancename))) { $_.Instancename = $_.Instancename.toUpper() }
            if(-not([DBNull]::Value.Equals($_.Role))) { $_.Role = $_.Role.toUpper() }
            if([DBNull]::Value.Equals($_.Port)) { $_.Port = 0 }
            If(-not($_.Port)) { $_.Port = 0 }
            $Filtered.ImportRow($_)
        }
        $Filtered | Foreach {
            If([DBNull]::Value.Equals($_.Role)) { $_.Role = 'NOROLE' }
        }
        If(($Filtered|Measure-Object).count -gt 0) {
            $New.Merge($Filtered)
        }
    }

    return ,$New
} # end function New-Table_IService

Function New-Inventory
{
    <#
    .SYNOPSIS
        Create an Inventory
    .DESCRIPTION
        Creates a New emtpy Inventory DataSet

        The dataset will contain two tables:
            Tables[0] = Tables['IHost'] -> A New-Table_IHost
            Tables[1] = Tables['IService'] -> A New-Table_IService

        You can pass an existing IHost or IService as parameters and these will be copied into
        the new dataset.

        When a IService is supplied AND an empty or null IHost is passed as parameters, New-Inventory will
        automatically derive the IHost for you.

    .PARAMETER IHost
        Copy this table into the sets Tables['IHost']

    .PARAMETER IService
        Copy this table into the sets Tables['IService']

    .EXAMPLE
        # empty set
        $inv = New-Inventory

        # derive hosts from services
        $inv = New-Inventory -IService $Services

        # Full set
        $inv = New-Inventory -IHost $Hosts -IService $Services
    #>
    [cmdletbinding()]
    Param(
        [Object] $IHost=(New-Table_IHost),
        [Object] $IService=(New-Table_IService)
    )
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    $Set = New-Object System.Data.DataSet 'Inventory'
    $IHost = New-Table_IHost $IHost
    $IService = New-Table_IService $IService

    If(($IHost.Rows | Measure-Object).Count -eq 0) {
        If(($IService.Rows | Measure-Object).Count -gt 0) {
            $IHost = ConvertTo-Table_Host $IService
        }
    }

    $Set.Tables.Add($IHost)
    $Set.Tables.Add($IService)

    return ,$Set
} # end function New-Inventory


Function ConvertTo-Table_Host
{
    <#
    .SYNOPSIS
        Convert a IService to IHost
    .DESCRIPTION
        Returns a New-Table_IHost derived from a IService.
        Extracts unique hostnames from the source table.
    .PARAMETER Table
        A datatable created with New-Table_IService
    .EXAMPLE
        $svc = New-Table_IService
        # .. add services / rows to $svc
        $hosts = ConvertTo-Table_Host $svc

    #>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)] $Table
    )
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    $Hosts = New-Table_IHost
    $Table | Sort-Object -Property hostname -Unique | foreach {
        $row = $Hosts.NewRow()
        $row.Hostname = $_.Hostname.toUpper()
        $row.Role = $_.Role.toUpper()
        $Hosts.Rows.Add($row)
    }
    return ,$Hosts
}

# vim: ft=ps1 foldenable foldmethod=marker
