#
# DBI for CSV Text Files
#

Import-Power 'DBI.about_DBI'

Function Test-DBI
{
    <#
    .SYNOPSIS
        Check if a DBI is valid and opened
    .DESCRIPTION
        If valid, Returns 'open' if opened, 'close' if closed, otherwise returns null
    .PARAMETER dbi
        The dbi object created with New-DBI
    .EXAMPLE
        if(Test-DBI $dbi) { echo 'Connection is ready!' }
    #>
    [cmdletbinding()]
    Param([Parameter(Mandatory=$true)] $dbi)

    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    if($dbi) {
        if($dbi.module -ne 'DBI.CSV') {
            Write-Error ("[Test-DBI] mismatch module, this is for {0} but dbi is {1}" -f 'DBI.CSV',$dbi.module)
            return $null
        }
        $connection = $dbi.object
        if($connection.State -eq 'Closed') {
            return 'close'
        }
        elseif($connection.State -eq 'Open') {
            return 'open'
        }
        else {
            return $connection.State
        }
    }
    return $null
} # end function Test-DBI

Function New-DBI
{
    <#
    .SYNOPSIS
        Create a new DBI Object
    .DESCRIPTION
        Creates a new DBI identifier to interact with a data source.
        A DBI must be opened with Open-DBI before being used.
    .PARAMETER ConnectionString
        A valid connection string
        If null, it will default to Data Source='current directory'
    .EXAMPLE
        $dbi = New-DBI "Data Source='C:\Path\Directory'"
        # or to work with current location
        $dbi = New-DBI
    #>
    [cmdletbinding()]
    Param(
        $ConnectionString=$null
    )
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    if(-not($connectionString)) {
        $connectionString = ('Data Source="{0}"' -f (Get-Location))
    }


    # find a suitable provider
    $provider = (New-Object System.Data.OleDb.OleDbEnumerator).GetElements() | Where-Object { $_.SOURCES_NAME -like "Microsoft.Jet.OLEDB.*" }
    if($provider -eq $null) {
        Throw "[Open-DBI] can't find suitable provider for text files (Jet OLEDB). could you try a 32 bit shell also?"
    }
    elseif($provider -is [system.array]) {
        $provider = $provider[$provider.GetUpperBound(0)].SOURCES_NAME
    }
    else {
        $provider = $provider.SOURCES_NAME
    }
    $connString = ('Provider={0};Extended Properties="text;HDR=yes;FMT=Delimited";{1}' -f $provider, $connectionString)
    Write-Verbose ("[New-DBI] creating dbi: connection string='{0}'" -f $connString)
    $conn = new-object System.Data.OleDb.OleDbConnection($connString)

    $currentdbi = @{
        'object' = $conn;
        'interface' = 'CSV';
        'module' = 'DBI.CSV';
        'provider' = $provider;
        'driver' = "Microsoft.Jet.OLEDB";
        'connectionString' = $connString
        'openTime' = -1;
    }

    return ,$currentdbi
} # end function New-DBI

Function Open-DBI
{
    <#
    .SYNOPSIS
        Open a connection to a text file

    .DESCRIPTION
        Open a connection, return connection object.

        Uses MS Text driver, you don't need to supply the provider or driver name
        we do it for you.

        This also automatically sets required extended properties, so you dont' need to supply them.
        Stores connection in POWERS_ENV variable for convenience

        Throws exception if open fails.

    .PARAMETER connectionString
        A valid connection string.

        A particular note is that Data Source must be DIR
        and the specific csv file is on the WHERE clause of the query.

        If this parameter is not supplied, uses current directory.

    .EXAMPLE
        $dbi = Open-DBI 'Data Source="C:\Path\To\Dir"'
        Invoke-DBI $dbi "select * from [myfile.csv]"

    #>
    [cmdletbinding()]
    Param([Parameter(Mandatory=$true)] [HashTable]$dbi)

    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    if($dbi) {
        $confirm = DBI.CSV\Test-DBI $dbi
        if(-not($confirm)) {
            Throw "[Open-DBI] dbi is invalid or not ready"
        }
        if($confirm -eq 'close') {
            Write-Verbose ("[Open-DBI] opening dbi: {0}" -f $dbi.connectionString)
            $conn = $dbi.object
            $time = Measure-Command { $conn.Open() }
            if((DBI.CSV\Test-DBI $dbi) -eq 'close') {
                $conn | Write-Verbose
                Throw ("[Open-DBI]: failed to connect to datasource {0}" -f $dbi.connectionString)
            }
            $ms = ($time.Minutes * 60 * 1000) + ($time.Seconds * 1000) + $time.Milliseconds
            $dbi.openTime = $ms
        }
    }
    return $dbi
}

Function Invoke-DBI
{
    <#
    .SYNOPSIS
        Execute a SQL Command
    .DESCRIPTION
        Run a SQL Command in an existing (opened) connection. You must first open the
        connection using Open-DBI

        Returns a DataSet if query succeeds.

    .PARAMETER dbi
        Connection object.

    .PARAMETER query
        SQL Query string to execute.

        The query must mention the CSV file in the WHERE clause

    .PARAMETER Timeout
        Timeout in seconds for the query. Default is 0 (use system default)

    .EXAMPLE
        $dbi = Open-DBI $connectionString
        $dataset = Invoke-DBI "SELECT * FROM [myfile.csv]" $dbi
        $dataset.Tables[0]

    #>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)] [HashTable]$dbi,
        [Parameter(Mandatory=$true)][string]$query,
        [Int]$Timeout=0
    )
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    if($dbi) {
        if(-not(DBI.CSV\Test-DBI $dbi)) {
            Throw "[Invoke-DBI] dbi is invalid or is not ready"
        }
        $connection = $dbi.object

        $SqlCmd = new-object System.Data.OleDb.OleDbCommand($query, $connection)
        If($Timeout -gt 0) {
            $SqlCmd.CommandTimeout=$Timeout
        }
        $SqlAdapter = new-object System.Data.OleDb.OleDbDataAdapter($SqlCmd)
        $DataSet = New-Object System.Data.DataSet
        $null = $SqlAdapter.fill($DataSet)
    }

    return ,$DataSet
} # end function Invoke-DBI

Function Close-DBI
{
    <#
    .SYNOPSIS
        Close a DBI Connection
    .DESCRIPTION
        Closes connection to data source
    .PARAMETER dbi
        The db object to close.

    .EXAMPLE
        Close-DBI $dbi

    #>
    [cmdletbinding()]
    Param([Parameter(Mandatory=$true)] $dbi)
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    if($dbi) {
        $confirm = DBI.CSV\Test-DBI $dbi
        if(-not($confirm)) {
            Throw "[Close-DBI] dbi is invalid or not ready"
        }
        if($confirm -eq 'open') {
            Write-Verbose "[Close-DBI] closing dbi"
            $connection = $dbi.object
            $connection.Close()
        }
    }
} # end function Close-DBI

Function Write-DBI
{
    <#
    .SYNOPSIS
        Write to a DataSource from a DataTable
    .DESCRIPTION
        Write-DBI takes a .NET datatable and writes the data into a CSV datasource
        This function throw an exception if the csv file doesn't exist unless -create is set to True

    .PARAMETER DataTable
        The input datatable source to use
    .PARAMETER table
        The name of the table to create (in this case a csv file). If not supplied defaults to the DataTable name.
    .PARAMETER create
        If true, and the csv file doesn't exist it will create it
    .PARAMETER dbi
        The dbi object returned by Open-DBI
    .EXAMPLE
        $i = Get-Inventory
        $dbi = New-DBI
        $dbi = Open-DBI $dbi
        Write-DBI $i $dbi -table inventory

    #>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)] $dbi,
        [Parameter(Mandatory=$true)] $datatable,
        [string] $table=$null,
        [switch] $create
    )
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    if($dbi) {
        $confirm = DBI.CSV\Test-DBI $dbi
        if(-not($confirm)) {
            Throw "[Write-DBI] dbi is invalid or not ready"
        }

        # write csv
        $path = $dbi.object.DataSource
        if(-not($table)) {
            $table = $DataTable.TableName
        }
        $file = (join-path $path $table)
        if(-not(test-path $file)) {
            if(-not($create)) {
                Throw "[Write-DBI] file not found $file, use -create to create it"
            }
            $DataTable | Export-CSV $file -notypeinformation
        }
        else {
            $DataTable | ConvertTo-Csv -notypeinformation | Select -skip 1 | Add-Content $file
        }
    }
} # end function Write-DBI

