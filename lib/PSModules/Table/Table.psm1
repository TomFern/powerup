# Syntax Candy for DataTables

Import-Power 'TableMapper'
Import-Power 'File.Lock'

Function New-Table
{
    <#
    .SYNOPSIS
        Create a DataTable
    .DESCRIPTION
        Creates a new datatable with the specified columns and types.
    .PARAMETER TableName
        The name of the table. Defaults to 'New-Table'
    .PARAMETER Copy
        Create a copy of this table
    .EXAMPLE
        $tab = New-Table 'People'
        Add-TableColumn $tab 'Name' "String"
        Add-TableColumn $tab 'Age' "Int"
        Add-TableColumn $tab 'Manager' "Bool"

        $copy = New-Table 'MyCopy' $tab
    #>
    [cmdletbinding()]
    Param(
        [String]$TableName = 'New-Table',
        [Object]$Copy = ""
    )
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    # Copy Schema and Data
    # if($Copy -ne "") {
    #     $TableCopy = $Copy.Copy()
    # }

    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    $New = $null
    if($Copy -eq "") {
        $New = New-Object System.Data.DataTable $TableName
    }
    else {
        $New = $Copy.Copy()
    }
    return ,$New
} # end function New-Table

Function Add-TableColumn
{
    <#
    .SYNOPSIS
        Add a Column to a Table
    .DESCRIPTION
        Adds a column to a DataTable created with New-Table
    .PARAMETER Table
        Datatable
    .PARAMETER Name
        Column name
    .PARAMETER DataType
        Column datatype
    .EXAMPLE
        $tab = New-Table $coldesc 'People'
        Add-TableColumn $tab 'Name' "String"
        Add-TableColumn $tab 'Age' "Int"
        Add-TableColumn $tab 'Manager' "Bool"

    #>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)][Object] $Table,
        [Parameter(Mandatory=$true)][String] $Name,
        [Parameter(Mandatory=$true)][Type] $DataType
    )
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'
    $Table.Columns.Add((New-Object System.Data.DataColumn $Name,($DataType)))
} # end function Add-TableColumn

Function Split-Table
{
    <#
    .SYNOPSIS
        Copy a subset of a table
    .DESCRIPTION
        Returns a copy of a datatable with the supplied column names
    .PARAMETER Table
        The Source datatable
    .PARAMETER Columns
        A string array with the column names
    .EXAMPLE
        $copy = Split-Table $Tab Name,Age
    #>
   [cmdletbinding()]
   Param(
       [Parameter(Mandatory=$true)][Object] $Table,
       [Parameter(Mandatory=$true)][String[]] $Columns
   )
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    $Copy = New-Table -Copy $Table

    # Remove extra columns
    Foreach($colobj in $Table.Columns) {
        if(-not($Columns -contains $colobj.ColumnName)) {
            $Copy.Columns.Remove($colobj.ColumnName)
        }
    }

    return ,$Copy
} # end function Split-Table

Function Join-TableRows
{
    <#
    .SYNOPSIS
        Join the rows of 2 tables into a new one
    .DESCRIPTION
        Creates a New table with the concatenated rows of two supplied tables
    .PARAMETER TableA
        First table
    .PARAMETER TableB
        Second table, if not empty then it should match the columns of TableA
    .EXAMPLE
        $Copy = Join-TableRows $Foo $Bar
    #>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)][Object] $TableA,
        [Parameter(Mandatory=$true)][Object] $TableB
    )
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    $Copy = New-Table -Copy $TableA

    If(($TableB|Measure-Object).Count -gt 0) {
        $Copy.Merge($TableB)
    }

    return ,$Copy
} # end function Join-TableRows

Function New-TableFromCSV
{
    <#
    .SYNOPSIS
        Create a new table from a CSV File
    .DESCRIPTION
        Creates a new DataTable from a CSV File
    .PARAMETER Path
        Path to the CSV File
    .PARAMETER TableName
        The name for the new table, defaults to 'New-TableFromCSV'
    .PARAMETER Delimiter
        CSV Delimiter, defaults to ','
    .EXAMPLE
        $tab = New-TableFromCSV 'foo.csv'
    #>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)][String] $Path,
        [String]$TableName = 'New-TableFromCSV',
        [String]$Delimiter = ','
    )
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    $New = New-Table -TableName $TableName

    Import-CSV $Path -Delimiter $Delimiter | Foreach {
        $rowobj = $_
        $newrow = $New.NewRow()
        $RowStringLength = 0

        $rowobj.PSObject.Properties | Foreach {
            $colname = $_.Name
            $colvalue = $rowobj.$colname

            # create column on new?
            if($New.Columns[$colname] -eq $null) {
                Add-TableColumn $New $colname "String"
            }

            $newrow.$colname = $colvalue
            $RowStringLength += ($colvalue|Out-String).Trim().Length
        }

        If($RowStringLength -gt 0) {
            $New.Rows.Add($newrow)
        }
        Remove-Variable 'newrow'
    }

    return ,$new
} # end function New-TableFromCSV

Function New-TableFromList
{
    <#
    .SYNOPSIS
        Creates a table from a list
    .DESCRIPTION
        Creates a new table from a plain text file with a list
    .PARAMETER Path
        Path to the list file
    .PARAMETER ColumnName
        The name for the column on the new datatable, defaults to 'New-TableFromList'
    .PARAMETER TableName
        The name of the new table, defaults to 'New-TableFromList'
    .EXAMPLE

    #>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)][String] $Path,
        [String] $ColumnName = 'New-TableFromList',
        [String] $TableName = 'New-TableFromList'
    )
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    $New = New-Table -TableName $TableName
    Add-TableColumn $New $ColumnName "String"
    Get-Content $Path | Foreach {
        $line = $_
        $line = $line.Trim()
        if($line -ne "") {
            $row = $New.NewRow()
            $row.$ColumnName = $line
            $New.Rows.Add($row)
        }
    }

    return ,$New
} # end function New-TableFromList

Function Invoke-Table
{
    <#
    .SYNOPSIS
        Iterates a rutine over a table
    .DESCRIPTION
        Executes an ScriptBlock over each row in a table.

        The original table is not modified. A copy, possibly modified by the ScriptBlock, is returned instead.

        The ScriptBlock passed as parameter will be supplied with the following parameters.
            $RowObject - The RowObject from the table. Use this if you want to modify the table.
            $RowData - HashTable with Key = Column Name ; Value = Column Value
            $RowColumns - Array with the Column Names
            $RowNumber - Current Row Number (starts from 0)
            $RowCount - Total Rows in table
        The scriptblock needs to receive these with Param(..)

    .PARAMETER Table
        A DataTable
    .PARAMETER ScriptBlock
        An scriptblock or function to call on each iteration.
    .EXAMPLE
        # show some text for the table
        Invoke-Table $Table {
            Param($RowObj,$RowData,$TableColumns,$RowNum,$RowCount)
            "Total columns are $Count"
            "Current row is $Num"
            "Columns Names are: " + ($Columns -join ',')
        }

        # change the table contents
        $copy = Invoke-Table $Table {
            Param($Row)
            $Row['Foo'] = 'Bar'
        }
    #>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$True)][Object]$Table,
        [Parameter(Mandatory=$true)][ScriptBlock] $ScriptBlock
    )
        # [parameter(Position=0,Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)][Object]$Table,
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'


    $Copy = $Table.Copy()

    $RowCount = ($Table.Rows | Measure-Object).Count
    # If($RowCount -eq $null) { $RowCount = 0 }
    $RowNumber = -1

    For($RowNumber=0;$RowNumber -lt $RowCount;$RowNumber++) {
        $RowColumns = @()
        $RowData = @{}
        Get-Member -InputObject ($Copy.Rows[$RowNumber]) -MemberType Property | Foreach {
            $ColName = $_.Name
            $RowColumns += $ColName
            $RowData[$_.Name] = $Copy.Rows[$RowNumber].$ColName
        }
        $ScriptBlock.Invoke($Copy.Rows[$RowNumber],$RowData,$RowColumns,$RowNumber,$RowCount)
    }
    return ,$Copy
} # end function Invoke-Table


Function Get-Table {
<#
    .SYNOPSIS
        List tables in Dataset
    .DESCRIPTION
        Returns table names in a Dataset, as an array
    .PARAMETER Dataset
        Dataset Object
    .EXAMPLE
        $names = Get-Table $Dataset
#>
    [cmdletbinding()]
    Param(
        [parameter(Position=0,Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)][Object]$Dataset
    )
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    # If($Dataset.Gettype().name -ne 'DataSet') {
    #     Throw "[Get-Table] Not a dataset"
    # }
    $names = @()
    $Dataset.Tables | Foreach { $names += $_.TableName }
    return ,$names
} # end function Get-Table


Function Test-Table {
<#
    .SYNOPSIS
        Check if variable is a table
    .DESCRIPTION
        Returns $true when argument is a datatable and false if not
    .PARAMETER Table
        Variable to test
    .PARAMETER

    .LINK

    .EXAMPLE

#>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)][Object]$Table
    )
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    If(($Table -is [Object]) -and($Table.Gettype().Name -eq 'DataTable')) {
        return $true
    }
    else {
        return $false
    }
} # end function Test-Table


Function Test-Table {
<#
    .SYNOPSIS
        Test Table is not empty
    .DESCRIPTION
        Tests input object is a table and not empty.
    .PARAMETER Table
        Test table
    .LINK

    .EXAMPLE

#>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)][Object]$Table
    )
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    $name = $null
    Try {
        $Table.gettype().Name
    }
    Catch {
        return $false
    }

    if($name -eq "DataTable")  {
        If(($Table.Rows|Measure-Object).count -gt 0) {
            return $true
        }
    }
    return $false
} # end function Test-Table


Function Assert-Table {
<#
    .SYNOPSIS
        Assert for DataTables
    .DESCRIPTION
        Checks table columns throw an exception if not valid.

            Tests performed:
                - Table not empty (0 rows)
                - Table have at least the same columns as the reference
                - Table column types match with the reference

    .PARAMETER ScriptBlock
        A script block that creates the REFERENCE Table
    .PARAMETER Table
        The table to check
    .PARAMETER AllowEmpty
        Allow supplied table to be empty
    .LINK
        Test-Table
    .EXAMPLE
        # Test matching table from scripblock
        Assert-Table { New-TableFromCSV '..path..' } $MyTable

        # If you already have the reference table
        Assert-Table { return ,$reftable } $MyTable

#>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)][ScriptBlock]$ScriptBlock,
        [Object]$Table,
        [Switch]$AllowEmpty

    )
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    $Reference = &$ScriptBlock
    If(-not(Test-Table $Reference)) {
        Throw "[Assert-Table] Reference object it not a DataTable"
    }
    If(-not(Test-Table $Table)) {
        Throw "[Assert-Table] Test object it not a DataTable"
    }

    If(-not($AllowEmpty) -and (($Table|Measure-Object).Count -eq 0)) {
        Throw "[Assert-Table] Test Table is empty"
    }

    $ResultColumnsMissing = @()
    Foreach($RefCol in $Reference.Columns) {
        If(-not($Table.Columns[$RefCol])) {
            $ResultColumnsMissing += $RefCol
        }
        elseif($Table.Columns[$RefCol].GetType().Name -ne $Reference.Columns[$RefCol].GetType().Name) {
            write-host "mismatch $RefCol"
            $ResultColumnsMissing += $RefCol
        }
    }

    If($ResultColumnsMissing.Count -gt 0) {
        Throw ("[Assert-Table] Some columns are missing or have mismatch Type on Test Table: {0}" -f ($ResultColumnsMissing -join ','))
    }
} # end function Assert-Table


Function  Import-TableFromCSV {
<#
    .SYNOPSIS
        Populate an existing table from a CSV file
    .DESCRIPTION
        Reads a CSV file and imports the row into an existing table
    .PARAMETER Table
        A DataTable
    .PARAMETER Path
        Path to CSV File
    .LINK

    .EXAMPLE
        $Foo = New-Object System.Data.Datatable
        .... add columns ...

        Import-TableFromCSV $Foo 'myfile.csv'
#>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)][Object]$Table,
        [Parameter(Mandatory=$true)][String]$Path
    )
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    If(-not(Test-Path -PathType leaf $Path)) {
        Throw ("[Import-TableFromCSV] File not found: {0}" -f $Path)
    }

    $content = New-TableFromCSV $Path
    $content | Foreach {
        $Table.ImportRow($_)
    }
} # end function  Import-TableFromCSV


Function Freeze-Table {
<#
    .SYNOPSIS
        Save a table to disk with column definitions
    .DESCRIPTION
        Saves a table as a csv file and a definition file. Use Unfreeze to load the table back to memory.
        Definition file is saved as Path+'.def'
    .PARAMETER Table
        Table to save
    .PARAMETER Path
        Path to the output directory
    .LINK

    .EXAMPLE
        Freeze-Table -Table $Foo -Path 'C:\Tmp\foo.csv'
        $Bar = Unfreeze -Path 'C:\Tmp\foo.csv'
#>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)][Object]$Table,
        [Parameter(Mandatory=$true)][String]$Path
    )
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    If(-not(Test-Path -PathType container $Path)) {
        Throw "[Freeze-Table] Not a directory: $Path"
    }
    $TableName = $Table.TableName
    $TableFn = ("{0}\{1}.csv" -f $Path,$TableName)

    $Table | Export-CSV -NoTypeInformation $TableFn
    $DefFn = ("{0}\{1}.def" -f $Path,$TableName)

    $DefTable = New-Object System.Data.DataTable 'TableDefinition'
    Foreach($Col in $Table.Columns) {
        $DefTable.Columns.Add($Col.ColumnName,[String])>$null
    }
    $row = $DefTable.NewRow()
    Foreach($Col in $Table.Columns) {
        $row[$Col.ColumnName] = $Col.DataType.Name
    }
    $DefTable.Rows.Add($row)
    $DefTable | Export-CSV -NoTypeInformation $DefFn
} # end function Freeze-Table


Function Unfreeze-Table {
<#
    .SYNOPSIS
        Load a table from a file created with Freeze-Table
    .DESCRIPTION
        Loads a csv file and definitions to a memory table
    .PARAMETER Name
        Table Name
    .PARAMETER Path
        Directory where to look for the file
    .LINK

    .EXAMPLE

#>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)][String]$Name,
        [Parameter(Mandatory=$true)][String]$Path
    )
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    If(-not(Test-Path -PathType container $Path)) {
        Throw "[Unfreeze-Table] Not a directory: $Path"
    }

    $TableName = $Name
    $TableFn = ("{0}\{1}.csv" -f $Path,$TableName)
    $DefFn = ("{0}\{1}.def" -f $Path,$TableName)
    If(-not(Test-Path -PathType leaf $TableFn)) {
        Throw "[Unfreeze-Table] File not found: $TableFn"
    }
    If(-not(Test-Path -PathType leaf $DefFn)) {
        Throw "[Unfreeze-Table] File not found: $DefFn"
    }

    $temp = New-TableFromCSV $TableFn
    $Def = New-TableFromCSV $DefFn

    $Table = New-Object System.Data.DataTable
    $Table.TableName = $TableName
    $Type = $Def.Rows[0]
    Set-StrictMode -off
    Foreach($col in $Def.Columns) {
        [Void]$Table.Columns.Add($Col.ColumnName,$Type[$Col.ColumnName])
    }
    Foreach($row in $temp) {
        Foreach($col in $Def.Columns) {
            if($row[$Col.ColumnName] -eq '') {
                $row[$Col.ColumnName] = [DBNUll]::Value
            }
        }
        $Table.ImportRow($row)
    }
    return ,$Table
} # end function Unfreeze-Table


Function Unfreeze-Dataset {
<#
    .SYNOPSIS
        Stores a dataset on csv files
    .DESCRIPTION
        Freezes all tables on a dataset
    .PARAMETER DataSet
        DataSet object. Must have a non-emtpy DataSetName.
    .PARAMETER Path
        Directory for storage defaults to STORAGEDIR
    .PARAMETER Timeout
        Timeout in seconds for lock, defaults to 1200 s
    .LINK

    .EXAMPLE

#>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)][String]$Name,
        [String]$Directory=("{0}{1}{2}" -f $GLOBAL:_PWR['STORAGEDIR'],$GLOBAL:_PWR['DIRECTORY_SEPARATOR'],'Internal'),
        [Int]$Timeout=1200
    )
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    New-Item -Type D -Force $Directory >$null

    $Lock = Lock-File -Name 'TableMapper.lock' -Timeout $Timeout -Directory $Directory
    If(-not($Lock['locked'])) {
        Throw ("[Freeze-Dataset] Timed out trying to acquire lock: {0}" -f $Lock['path'])
    }

    $MapperSchema = New-Table_TableMapper
    $Mapper = $null
    Try {
        $Mapper = Unfreeze-Table $MapperSchema.TableName $Directory
    }
    Catch {
        $Mapper = $MapperSchema.Clone()
    }

    Unlock-File $Lock -Remove >$null

    $Lock = Lock-File -Name $Name -Timeout $Timeout -Directory $Directory
    If(-not($Lock['locked'])) {
        Throw ("[Unfreeze-Dataset] Timed out trying to acquire lock: {0}" -f $Lock['path'])
    }

    $DS = New-Object System.Data.DataSet $Name
    Try {
        $TablesInSet = $Mapper.Select("DataSetName = '$Name'")
        Foreach($TM in $TablesInSet) {
            $Stored = Unfreeze-Table -Name $TM.MapName -Path $Directory
            $Table = ConvertFrom-Storage -Mapper $Mapper -Table $Stored
            $DS.Tables.Add($Table) >$null
        }
    }
    Catch {
        Write-Warning ("[Unfreeze-Dataset] Table failed to load: {0}" -f $_.Exception.Message)
    }
    Finally {
        Unlock-File $Lock -Remove >$null
    }

    If(($DS|Get-Table|Measure).count -eq 0) {
        Throw ("[Unfreeze-Dataset] DataSet not found or empty: $Name")
    }

    return ,$DS
} # end function Unfreeze-Dataset

Function Freeze-Dataset {
<#
    .SYNOPSIS
        Stores a dataset into csv files
    .DESCRIPTION
        Freezes all tables on a dataset
    .PARAMETER DataSet
        Dataset object
    .PARAMETER Path
        Directory for storage defaults to STORAGEDIR
    .PARAMETER Timeout
        Timeout in seconds for lock, defaults to 60s
    .LINK
        Freeze-Dataset
        Freeze-Table
        Unfreeze-Dataset
        Unfreeze-Table
    .EXAMPLE
        Freeze-Dataset -Dataset $DS

#>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)][Object]$DataSet,
        [String]$Directory=("{0}{1}{2}" -f $GLOBAL:_PWR['STORAGEDIR'],$GLOBAL:_PWR['DIRECTORY_SEPARATOR'],'Internal'),
        [Int]$Timeout=60
        # [Object]$Mapper=$null
    )
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    New-Item -Type D -Force $Directory >$null

    $Lock = Lock-File -Name 'TableMapper.lock' -Timeout $Timeout -Directory $Directory
    If(-not($Lock['locked'])) {
        Throw ("[Freeze-Dataset] Timed out trying to acquire lock: {0}" -f $Lock['path'])
    }


    # if(-not($Mapper)) {
        $MapperSchema = New-Table_TableMapper
        $Mapper = $null
        Try {
            $Mapper = Unfreeze-Table $MapperSchema.TableName $Directory
        }
        Catch {
            $Mapper = $MapperSchema.Clone()
        }
    # }

    Try {
        $Converted = ConvertTo-Storage -Mapper $Mapper -Dataset $DataSet
        Foreach($TN in $Converted.Keys) {
            Freeze-Table $Converted[$TN] $Directory >$null
        }
        Freeze-Table $Mapper $Directory >$null
    }
    Catch {
        Write-Warning ("[Freeze-Dataset] Error while freezing DataSet: {0}" -f $_.Exception.Message)
    }
    Finally {
        Unlock-File $Lock -Remove >$null
    }
} # end function Freeze-Dataset


Function Select-Table {
<#
    .SYNOPSIS
        Run select on table
    .DESCRIPTION
        Runs SELECT on a DataTable, returns DataTable with a copy of the results
    .PARAMETER Table
        Source DataTable
    .PARAMETER Select
        [String] Select String
    .PARAMETER Limit
        [Int] Row number limit if <> 0
    .LINK

    .EXAMPLE
        $t = Select-Table $Foo ("Name = '{0}'" -f $bar)
#>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)][Object]$Table,
        [String]$Select,
        [Int]$Limit=0
    )
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    $Result = $Table.Clone()
    Foreach($row in ($Table.Select($Select))) {
        if(($Limit -gt 0) -and(($Result.Rows|Measure).count -ge $Limit)) {
            break
        }
        $Result.ImportRow($row)
    }
    return ,$Result
} # end function Select-Table
