# DDL/DR Generator for Sybase ASE

Import-Power 'ASE.Uptime'
Import-Power 'Table'

Function Get-DatabaseDDL {
<#
    .SYNOPSIS
        Generate CREATE DATABASE DDL for Sybase ASE
    .DESCRIPTION
        Generate CREATE DATABASE DDL Script. Replicates supplied fragment structure.
        This can be used as part of cloning a DB, use Get-Fragment to generate source fragment table.
        Or create empty Fragment table with New-Table_Fragment and fill up the rows.
    .PARAMETER Fragment
        Table from ASE.Uptime\Get-Fragment
    .PARAMETER BatchTerminator
        Defaults to 'GO'
    .PARAMETER WithOverride
        (Switch) Enable 'WITH OVERRIDE'. Allow mixing data and log on same device
    .LINK
        ASE.Uptime\Get-Fragment
        ASE.Uptime\New-Table_Fragment
        Get-DeviceDDL
    .EXAMPLE

#>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)][Object]$Fragment,
        [String]$BatchTerminator="GO",
        [Switch]$WithOverride
    )
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    Assert-Table { ASE.Uptime\New-Table_Fragment } $Fragment

    $WithOptions = @()
    $nl = [environment]::NewLine

    If($WithOverride) {
        $WithOptions += 'OVERRIDE'
    }

    $Database = $Fragment.Rows[0].Database
    $FragmentCount = ($Fragment.Rows|Measure-Object).Count

    $ddl = "---- GENERATED WITH Get-DatabaseDDL$nl"
    $ddl += "use master$nl$BatchTerminator$nl"
    $ddl += ("CREATE DATABASE {0}$nl" -f $Database)

    # First fragment
    If($Fragment.Rows[0].UsageType -match '^data') {
        $ddl += ("  ON {0} = '{1}M'" -f $Fragment.Rows[0].DeviceLogicalName,$Fragment.Rows[0].SizeMB)
        $ddl += "$nl"
    }
    # Keep going with data fragments
    For($i=1;$i -lt $FragmentCount;$i++) {
        If($Fragment.Rows[$i].UsageType -match '^data') {
            $ddl += ("    ,{0} = '{1}M'" -f $Fragment.Rows[$i].DeviceLogicalName,$Fragment.Rows[$i].SizeMB)
            $ddl += "$nl"
        }
        Else{
            break
        }
    }

    # Switch to log only fragments
    If($i -ne $FragmentCount) {
        write-host $i $FragmentCount
        $ddl += ("  LOG ON {0} = '{1}M'" -f $Fragment.Rows[$i].DeviceLogicalName,$Fragment.Rows[$i].SizeMB)
        If($WithOptions.Count -gt 0) {
            $ddl += (" WITH {0}" -f ($WithOptions -Join ','))
        }
        $ddl += "$nl"
        $i += 1

        For(;$i -lt ($Fragment|Measure-Object).Count;$i++) {
            If($Fragment.Rows[$i].UsageType -match '^log') {
                $ddl += ("    ,{0} = '{1}M'" -f $Fragment.Rows[$i].DeviceLogicalName,$Fragment.Rows[$i].SizeMB)
                If($WithOptions.Count -gt 0) {
                    $ddl += (" WITH {0}" -f ($WithOptions -Join ','))
                }
                $ddl += "$nl"
            }
            Else{
                break
            }
        }

        For(;$i -lt ($Fragment|Measure-Object).Count;$i++) {
            $ddl += "ALTER DATABASE $Database$nl"
            If($Fragment.Rows[$i].UsageType -match '^data') {
                $ddl += ("  ON {0} = '{1}M'" -f $Fragment.Rows[$i].DeviceLogicalName,$Fragment.Rows[$i].SizeMB)
                If($WithOptions.Count -gt 0) {
                    $ddl += (" WITH {0}" -f ($WithOptions -Join ','))
                }
                $ddl += "$nl$BatchTerminator$nl"
            }
            If($Fragment.Rows[$i].UsageType -match '^log') {
                $ddl += ("  LOG ON {0} = '{1}M'" -f $Fragment.Rows[$i].DeviceLogicalName,$Fragment.Rows[$i].SizeMB)
                If($WithOptions.Count -gt 0) {
                    $ddl += (" WITH {0}" -f ($WithOptions -Join ','))
                }
                $ddl += "$nl$BatchTerminator$nl"
            }
        }
    }

    $ddl += "$BatchTerminator$nl"
    return $ddl
} # end function Get-DatabaseDDL


Function Get-DeviceDDL {
<#
    .SYNOPSIS
        Generate DISK INIT DDL for Sybase ASE
    .DESCRIPTION
        Generates DISK INIT Script for creating devices. Receives a Device table from Get-Device.
        This can be used to clone a DB. Or create an empty Table witn New-Table_Device and fill up the rows.
    .PARAMETER Device
        Table from ASE.Uptime\Get-Device
    .PARAMETER BatchTerminator
        Defaults to 'GO'
    .LINK
        ASE.Uptime\Get-Device
        ASE.Uptime\New-Table_Device
        Get-DatabaseDDL
    .EXAMPLE

#>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)][Object]$Device,
        [String]$BatchTerminator="GO"
    )
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    Assert-Table { ASE.Uptime\New-Table_Device } $Device

    $nl = [environment]::NewLine

    $ddl = "---- GENERATED WITH Get-DeviceDDL$nl"
    $ddl += "use master$nl"
    $ddl += "$BatchTerminator$nl"

    $Device | Foreach {

        # FIXME: this causes mysterious: System error
        # If(@('master','sybsystemdev','sysprocsdev','sybmgmtdev','tapedump1','tapedump2','tempdbdev') -contains $_.LogicalName) {
        #     continue
        # }

        $ddl += ( 'disk init name = "{0}",{1}' -f $_.LogicalName,$nl)
        $ddl += ( "  physname = '{0}',$nl" -f $_.PhysicalName)
        $ddl += ( '  size = "{0}M"{1}' -f $_.SizeMB,$nl )
        $ddl += "$BatchTerminator$nl"
    }

    return $ddl
} # end function Get-DeviceDDL
