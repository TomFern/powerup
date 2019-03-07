# A probe invokes a table/dataset returning routines sanely

Import-Power 'Table'

Function New-Table_ProbeRecord {
<#
    .SYNOPSIS
        A table to store outcomes of Invoke-Probe
    .DESCRIPTION
        A table that saves the history of Invoke-Probe executions
#>
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'
    $New = New-Object System.Data.DataTable 'ProbeRecord'
    [void]$New.Columns.Add('Memo',[string])
    [void]$New.Columns.Add('Id',[string])
    [void]$New.Columns.Add('HasData',[bool])
    [void]$New.Columns.Add('ErrorMessage',[String])
    [void]$New.Columns.Add('TableCount',[int])
    [void]$New.Columns.Add('RowCount',[int])
    return ,$New
} # end function New-Table_ProbeRecord

Function New-Probe {
<#
    .SYNOPSIS
        Creates an empty probe
    .DESCRIPTION
        Creates a new probe to receive tables/datasets from functions
    .PARAMETER Memo
        Description of data returned
    .PARAMETER AllowEmpty
        (Swtich) An empty table/dataset is allowed
    .PARAMETER Record
        (optional) Table of type New-Table_ProbeRecord
    .LINK
        New-Table_ProbeRecord
        New-Probe
        Invoke-Probe
    .EXAMPLE

        $probe = New-Probe -Memo DiskInfo
        Invoke-Probe -Probe $probe -Id "DiskInfo for localhost" { Get-DiskInfo localhost }
        If($Probe.HasData) {
            Echo "Success"
            $probe.Result | Format-Table
        }
        Else {
            Write-Error ("An error occurred: {0}" -f $Probe.ErrorMessage)
        }

        # Run two probes with shared history
        $p1 = New-Probe -memo p1
        Invoke-Probe -Probe $p1 -Id id1 { FOO }
        $p2 = New-Probe -memo p2 -Record $p1.record
        Invoke-Probe -Probe $p2 -Id id2 { BAR }

        # Show history of both probes
        $p2.Record | Format-Table
#>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)][String]$Memo,
        [Object]$Record=(New-Table_ProbeRecord),
        [Switch]$AllowEmpty
    )
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    Assert-Table { New-Table_ProbeRecord } $Record -AllowEmpty

    $New = @{
        'HasData' = $false;
        'AllowEmpty' = $AllowEmpty;
        'Memo' = $Memo;
        'Result' = $null;
        'TableCount' = 0;
        'RowCount' = 0;
        'ErrorMessage' = "";
        'Record' = $Record;
    }

    return $New
} # end function New-Probe



Function Invoke-Probe {
<#
    .SYNOPSIS
        Execute a ScriptBlock and fill your probe
    .DESCRIPTION
        Invokes the supplied ScriptBlock, saving the result, status, and history.
    .PARAMETER Probe
        Created by New-Probe
    .PARAMETER ScriptBlock
        A scriptblock to execute
    .PARAMETER Id
        A string describing this instance of Invoke-Probe
    .LINK
        New-Table_ProbeRecord
        New-Probe
        Invoke-Probe
    .EXAMPLE
        $probe = New-Probe -Memo DiskInfo
        Invoke-Probe -Probe $probe -Id "DiskInfo for localhost" { Get-DiskInfo localhost }
        If($Probe.HasData) {
            Echo "Success"
            $probe.Result | Format-Table
        }
        Else {
            Write-Error ("An error occurred: {0}" -f $Probe.ErrorMessage)
        }

        # Run two probes with shared history
        $p1 = New-Probe -memo p1
        Invoke-Probe -Probe $p1 -Id id1 { FOO }
        $p2 = New-Probe -memo p2 -Record $p1.record
        Invoke-Probe -Probe $p2 -Id id2 { BAR }

        # Show history of both probes
        $p2.Record | Format-Table
#>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)][HashTable]$Probe,
        [Parameter(Mandatory=$true)][ScriptBlock]$ScriptBlock,
        [String]$Id
    )
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    $Probe.HasData = $false
    $Probe.ErrorMessage = ""
    $Probe.Result = $null
    $Probe.RowCount = 0
    $Probe.TableCount = 0
    $RecordRow = $Probe.Record.NewRow()
    $RecordRow.Id = $Id
    $RecordRow.Memo = $Probe.Memo

    $Result = $null
    $ExceptionHandled = $false
    Try {
        $Result = Invoke-Command -ScriptBlock $ScriptBlock
    }
    Catch {
        $Probe.ErrorMessage = $_.Exception.Message
        $ExceptionHandled = $true
    }

    If(-not($ExceptionHandled)) {
        If(($result -ne $null) -and(($result|measure).count -gt 0)) {
            If($Result.Gettype().Name -eq 'DataTable') {
                $Probe.TableCount = 1
                $Probe.RowCount = ($Result.Rows|Measure-Object).Count
                $Probe.Result = $Result
            }
            elseif((If($Result.Gettype().Name -eq 'DataSet'))) {
                $TableCount = 0
                $RowCount = 0
                Foreach($TableName in ($Result|Get-Table)) {
                    $TableCount += 1
                    $RowCount += ($Result.Tables[$TableName].Rows|Measure-Object).Count
                }
                $Probe.Result = $Result
            }
            else {
                $Probe.ErrorMessage = "Returned value was not a DataTable or a DataSet"
            }
        }
        else {
            $Probe.ErrorMessage = "Got a null/empty data"
        }


        If($Probe.AllowEmpty -or($Probe.RowCount -gt 0)) {
            $Probe.HasData = $true
        }
    }


    $RecordRow.HasData = $Probe.HasData
    $RecordRow.ErrorMessage = $Probe.ErrorMessage
    $RecordRow.TableCount = $Probe.TableCount
    $RecordRow.RowCount = $Probe.RowCount

    $Probe.Record.Rows.Add($RecordRow)
    return $Probe
} # end function Invoke-Probe

