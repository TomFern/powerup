# Table Mapper for Storage

Function New-Table_TableMapper {
<#
    .SYNOPSIS
        A table for TableMapper
    .DESCRIPTION

    .LINK

    .EXAMPLE

#>
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    $New = New-Object System.Data.DataTable 'TableMapper'
    [void]$New.Columns.Add('DataSetName',[String])
    [void]$New.Columns.Add('TableName',[String])
    [void]$New.Columns.Add('MapName',[String])
    [void]$New.Columns.Add('LastGenID',[Int])
    [void]$New.Columns.Add('LastGenDate',[DateTime])
    return ,$New
} # end function New-Table_TableMapper


Function ConvertTo-Storage {
<#
    .SYNOPSIS
        Convert DataSet to Storage/Database Tables
    .DESCRIPTION

            @{
                'Converted_TableName' = (ConvertedTable);
            }

    .PARAMETER Mapper
        A New-Table_TableMapper table
    .PARAMETER DataSet
        Dataset Object
    .PARAMETER Exclude
        Table names to exclude from conversion
    .LINK

    .EXAMPLE

#>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)][Object]$Mapper,
        [Parameter(Mandatory=$true)][Object]$DataSet,
        [String[]]$Exclude
    )
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    # ?
    $DSName = $DataSet.DataSetName
    $AllTables = @{}
    # write-host "DS=$DSName"
    $DataSet.Tables | Foreach {
        If(-not($Exclude -contains $_.Tablename)) {
            $Table = $_.Copy()
            $TName = $Table.TableName

            $MapRow = $Mapper.Select("DataSetName = '$DSName' and TableName = '$TName'")
            # Update or add row in TableMapper
            If(($MapRow|Measure-Object).Count -eq 0) {
                # write-host "NEWROW MAPPER"
                $MapRow = $Mapper.NewRow()
                $MapRow.LastGenId = 0

                $MapRow.DataSetName = $DSName
                $MapRow.TableName = $TName

                $ConvDSName = ($DSName -replace ':','_')
                $ConvTName = ($TName -replace ':','_')
                $MapRow.MapName = ("{0}___{1}" -f $ConvDSName,$ConvTName)
                $Mapper.Rows.add($MapRow)
            }
            else {
                $MapRow = $MapRow[0]
            }
            $MapRow.LastGenId = ([Int]$MapRow.LastGenId) + 1
            $MapRow.LastGenDate = [DateTime](Get-Date)

            # add special column on table
            [void]$Table.Columns.Add('__GenId__',[Int])
            $Table | Foreach { $_['__GenId__'] = $MapRow.LastGenId }
            $Table.TableName = $MapRow.MapName
            $AllTables[$MapRow.MapName] = $Table
        }
    }
    return ,$AllTables
} # end function ConvertTo-Storage


Function ConvertFrom-Storage {
<#
    .SYNOPSIS
        Convert Storage tables back into DataSet
    .DESCRIPTION

    .PARAMETER Mapper
        A New-Table_TableMapper table
    .PARAMETER Table
        A table retrieved from storage, its TableName must be valid
    .LINK

    .EXAMPLE

#>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)][Object]$Mapper,
        [Parameter(Mandatory=$true)][Object]$Table
    )
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    $TName = $Table.TableName
    $MapRow = $Mapper.Select("MapName = '$TName'")[0]
    If(($MapRow|Measure-Object).Count -eq 0) {
        Throw ("[ConvertFrom-Storage] No mapping found for name: {0}" -f $TName)
    }

    [void]$Table.Columns.Remove('__GenId__')
    $Table.TableName = $MapRow.TableName
    # $Imported[$MapRow.DataSetName] = $Table
    return ,$Table



} # end function ConvertFrom-Storage

