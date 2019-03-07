#
# DBI for MS SQL Server
#

Import-Power 'DBI.about_DBI'

Function Test-DBI
{
    <#
    .SYNOPSIS
        Check if a DBI is valid and opened
    .DESCRIPTION
        If valid, Returns 'OPEN' if opened, 'CLOSE' if closed, otherwise returns 'INVALID'
    .PARAMETER dbi
        The dbi identified, defaults to value on LAST_ENV env var
    .EXAMPLE
        if(Test-DBI $dbi) { echo 'Connection is ready!' }
    #>
    [cmdletbinding()]
    Param([Parameter(Mandatory=$true)][HashTable]$dbi)

    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    if($dbi -and($dbi.ContainsKey('module'))) {
        if($dbi.module -ne 'DBI.MSSQL') {
            Write-Error ("[Test-DBI] mismatch module, this is for {0} but dbi is {1}" -f 'DBI.MSSQL',$dbi.module)
            return 'INVALID'
        }
        $connection = $dbi.object
        if($connection.State -eq 'Closed') {
            return 'CLOSE'
        }
        elseif($connection.State -eq 'OPEN') {
            return 'OPEN'
        }
        else {
            return $connection.State
        }
    }
    return 'INVALID'
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
    .EXAMPLE
        $b = New-Object System.Data.SqlClient.SqlConnectionStringBuilder;
        $b["Data Source"]="(local)"
        $b["Integrated Security"]=$true
        $dbi = New-DBI $b.ConnectionString
    #>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)][string] $ConnectionString
    )
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    Write-Verbose ("[New-DBI] opening dbi: connection string='{0}'" -f $connectionString)
    $SqlConnection = New-Object System.Data.SqlClient.SqlConnection
    $SqlConnection.ConnectionString = $connectionString
    $currentdbi = @{
        'object' = $SqlConnection;
        'interface' = 'MSSQL';
        'module' = 'DBI.MSSQL';
        'provider' = 'ADO.NET';
        'driver' = 'ADO.NET;'
        'connectionString' = $connectionString;
        'openTime' = New-TimeSpan;
    }
    return ,$currentdbi

} # end function New-DBI

Function Open-DBI
{
    <#
    .SYNOPSIS
        Open a connection to MSSQL
    .DESCRIPTION
        Open a connection, return connection object. Measures the time to connect.
        Throws exception if open fails.
    .PARAMETER dbi
        A dbi identified created with New-DBI
    .EXAMPLE
        $b = New-Object System.Data.SqlClient.SqlConnectionStringBuilder;
        $b["Data Source"]="(local)"
        $b["Integrated Security"]=$true
        $dbi = New-DBI $b.ConnectionString
    #>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)][HashTable]$dbi
    )
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    if($dbi) {
        $confirm = DBI.MSSQL\Test-DBI $dbi
        if(-not($confirm)) {
            Throw "[Open-DBI] dbi is invalid or not ready"
        }
        if($confirm -eq 'CLOSE') {
            Write-Verbose ("[Open-DBI] opening dbi: {0}" -f $dbi.connectionString)
            $SqlConnection = $dbi.object
            $time = Measure-Command { $SqlConnection.Open() }
            if((DBI.MSSQL\Test-DBI $dbi) -eq 'CLOSE') {
                $SqlConnection | Write-Verbose
                Throw ("[Open-DBI]: failed to connect to datasource {0}" -f $dbi.connectionString)
            }
            # $ms = ($time.Minutes * 60 * 1000) + ($time.Seconds * 1000) + $time.Milliseconds
            $dbi.openTime = $time
        }
    }
    return $dbi
} # end function Open-DBI


Function Invoke-DBI
{
    <#
    .SYNOPSIS
        Execute a SQL Command
    .DESCRIPTION
        Run a SQL Command in an existing (opened) connection. You must first open the
        connection using Open-DBI.
        Returns a DataSet if query succeeds.
    .PARAMETER dbi
        Connection object. If not provided, attempts to use POWERS_ENV['LAST_DBI']
    .PARAMETER query
        SQL Query string to execute.
    .PARAMETER Timeout
        Timeout in seconds for the query. Default is 0 (use system default)
    .EXAMPLE
        $dbi = Open-DBI $connectionString
        $dataset = Invoke-DBI $dbi "SELECT @@servername"
        $dataset.Tables[0] | Format-Table

    #>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)][HashTable]$dbi,
        [Parameter(Mandatory=$true)][string]$query,
        [Int]$Timeout=0
    )

    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    if($dbi) {
        if(-not(DBI.MSSQL\Test-DBI $dbi)) {
            Throw "[Invoke-DBI] dbi is invalid or is not ready"
        }
        $connection = $dbi.object
        $SqlCmd = New-Object System.Data.SqlClient.SqlCommand
        $SqlCmd.Connection = $connection
        $SqlCmd.CommandText = $query
        If($Timeout -gt 0) {
            $SqlCmd.CommandTimeout=$Timeout
        }

        $SqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter
        $SqlAdapter.SelectCommand = $SqlCmd

        $DataSet = New-Object System.Data.DataSet
        $null = $SqlAdapter.Fill($DataSet)
        return ,$DataSet
    }
} # end function Invoke-DBI

Function Close-DBI
{
    <#
    .SYNOPSIS
        Close a DBI Connection
    .DESCRIPTION
        Closes connection to DB
    .PARAMETER dbi
        The dbi identifier to close, if not supplied it LAST_DBI
    .EXAMPLE
        Close-DBI $dbi
    #>
    [cmdletbinding()]
    Param([Parameter(Mandatory=$true)][HashTable]$dbi)
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    if($dbi) {
        $confirm = DBI.MSSQL\Test-DBI $dbi
        if(-not($confirm)) {
            Throw "[Close-DBI] dbi is invalid or not ready"
        }
        if($confirm -eq 'OPEN') {
            Write-Verbose "[Close-DBI] closing dbi"
            $connection = $dbi.object
            $connection.Close()
        }
    }
} # end function Close-DBI
