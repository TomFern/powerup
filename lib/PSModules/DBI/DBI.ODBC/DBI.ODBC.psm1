# DBi Module for ODBC

Import-Power 'DBi.about_DBi'

Function Test-DBi
{
    <#
    .SYNOPSIS
        Check if a DBi is valid and opened
    .DESCRIPTION
        If valid, Returns 'OPEN' if opened, 'CLOSE' if closed, otherwise returns 'INVALID'
    .PARAMETER DBi
        The DBi identifier
    .EXAMPLE
        if(Test-DBi $DBi) { echo 'Connection is ready!' }
    #>
    [cmdletbinding()]
    Param([Parameter(Mandatory=$true)][HashTable]$DBi)

    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    if($DBi -and($DBi.ContainsKey('module'))) {
        if($DBi.module -ne 'DBI.ODBC') {
            Write-Error ("[Test-DBi] mismatch module, this is for {0} but DBi is {1}" -f 'DBI.ODBC',$DBi.module)
            return 'INVALID'
        }
        $connection = $DBi.object
        if($connection.State -eq 'closed') {
            return 'CLOSE'
        }
        elseif($connection.State -eq 'open') {
            return 'OPEN'
        }
        else {
            return $connection.State
        }
    }
    return 'INVALID'
} # end function Test-DBi

Function New-DBi
{
    <#
    .SYNOPSIS
        Create a new DBi Object
    .DESCRIPTION
        Creates a new DBi identifier to interact with a data source.
        A DBi must be opened with Open-DBi before being used.

        NOTE: Some ODBC drivers only work in a 32-bit environment, you may need to start a 32-bit powershell first.

    .PARAMETER ConnectionString
        A valid connection string
    .PARAMETER Driver
        ODBC Driver Name
    .EXAMPLE
        $DBi = New-DBi "dsn=FOO;db=master;na=HOSTNAME,PORT;uid=sa;pwd=BAR;" "Adaptive Server Enterprise"
    #>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)][string] $ConnectionString,
        [Parameter(Mandatory=$true)][string] $Driver
    )
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    Write-Debug ("[New-DBi] opening DBi. Driver='{0}' ConnectionString='{1}'" -f $Driver,$connectionString)
    $Connection=New-Object System.Data.Odbc.OdbcConnection
    $Connection.ConnectionString = "driver={$Driver};$ConnectionString;"
    $currentDBi = @{
        'object' = $Connection;
        'interface' = 'ODBC';
        'module' = 'DBI.ODBC';
        'provider' = 'ODBC';
        'driver' = "$Driver";
        'connectionString' = $connectionString;
        'openTime' = New-TimeSpan;
    }
    return ,$currentDBi

} # end function New-DBi

Function Open-DBi
{
    <#
    .SYNOPSIS
        Open an ODBC Datasource Connection
    .DESCRIPTION
        Open a connection, return connection object. Measures the time to connect.
        Throws exception if open fails.
    .PARAMETER DBi
        A DBi identified created with New-DBi
    .EXAMPLE
    #>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)][HashTable]$DBi
    )
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    if($DBi) {
        $confirm = DBi.ODBC\Test-DBi $DBi
        if(-not($confirm)) {
            Throw "[Open-DBi] DBi is invalid or not ready"
        }
        if($confirm -eq 'CLOSE') {
            Write-Verbose ("[Open-DBi] opening DBi: {0}" -f $DBi.connectionString)
            $Connection = $DBi.object
            $time = Measure-Command { $Connection.Open() }
            if((DBi.ODBC\Test-DBi $DBi) -eq 'CLOSE') {
                # $Connection | Write-Verbose
                Throw ("[Open-DBi]: failed to connect to datasource {0}" -f $DBi.connectionString)
            }
            # $ms = ($time.Minutes * 60 * 1000) + ($time.Seconds * 1000) + $time.Milliseconds
            $DBi.openTime = $time
        }
    }
    return $DBi
} # end function Open-DBi


Function Invoke-DBi
{
    <#
    .SYNOPSIS
        Execute a SQL Command to an ODBC datasource
    .DESCRIPTION
        Run a SQL Command in an existing (opened) connection. You must first open the connection using Open-DBi.
        Returns a DataSet if query succeeds.
    .PARAMETER DBi
        Connection object. If not provided, attempts to use POWERS_ENV['LAST_DBi']
    .PARAMETER query
        SQL Query string to execute.
    .PARAMETER Timeout
        Timeout in seconds for the query. Default is 0 (use system default)
    .EXAMPLE
        $DBi = Open-DBi $connectionString
        $dataset = Invoke-DBi $DBi "SELECT @@servername"
        $dataset.Tables[0] | Format-Table

    #>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)][HashTable]$DBi,
        [Parameter(Mandatory=$true)][string]$Query,
        [Int]$Timeout=0

    )

    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    if($DBi) {
        if(-not(DBi.ODBC\Test-DBi $DBi)) {
            Throw "[Invoke-DBi] DBi is invalid or is not ready"
        }
        $connection = $DBi.object
        $SqlCmd = New-Object System.Data.Odbc.OdbcCommand
        $SqlCmd.Connection = $connection
        $SqlCmd.CommandText = $query
        If($Timeout -gt 0) {
            $SqlCmd.CommandTimeout=$Timeout
        }

        $SqlAdapter = New-Object system.Data.odbc.odbcDataAdapter
        $SqlAdapter.SelectCommand = $SqlCmd

        $ds=New-Object system.Data.DataSet

        $DataSet = New-Object System.Data.DataSet
        $null = $SqlAdapter.Fill($DataSet)
        return ,$DataSet
    }
} # end function Invoke-DBi

Function Close-DBi
{
    <#
    .SYNOPSIS
        Close a DBi Connection
    .DESCRIPTION
        Closes connection to DB
    .PARAMETER DBi
        The DBi identifier to close, if not supplied it LAST_DBi
    .EXAMPLE
        Close-DBi $DBi
    #>
    [cmdletbinding()]
    Param([Parameter(Mandatory=$true)][HashTable]$DBi)
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    if($DBi) {
        $confirm = DBi.ODBC\Test-DBi $DBi
        if(-not($confirm)) {
            Throw "[Close-DBi] DBi is invalid or not ready"
        }
        if($confirm -eq 'OPEN') {
            Write-Verbose "[Close-DBi] closing DBi"
            $connection = $DBi.object
            $connection.Close()
        }
    }
} # end function Close-DBi
