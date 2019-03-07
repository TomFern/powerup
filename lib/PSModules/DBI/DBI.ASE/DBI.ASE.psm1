# ADO.NET driver module for Sybase ASE
# When ADO.NET not available fall back to ODBC

Import-Power 'DBI.about_DBI'

$SybaseDriverMode = 'NONE'

$cfg = @{}
Try {
    $c = Get-Config 'sybase'
    if($c -is [HashTable]) { $cfg = $c }
}
Catch {
    Write-Warning ("[DBI.ASE] Invalid config 'sybase': {0}" -f $_.Exception.Message)
}

# locate $SYBASE
$envSYBASE = 'C:\Sybase'
If($cfg.ContainsKey('sybase') -and($cfg['sybase'].ContainsKey('SYBASE'))) {
    $envSYBASE = $cfg['sybase']['SYBASE']
}

# locate Ado NET Driver
$AdoNetDrvFile = ("{0}\DataAccess\ADONET\dll\Sybase.AdoNet2.AseClient.dll" -f $envSYBASE)
If(Test-Path -PathType leaf $AdoNetDrvFile) {
    $SybaseDriverMode = 'ADO.NET'
}
else {
    $SybaseDriverMode = 'ODBC'
}

If($SybaseDriverMode -eq 'ADO.NET') {
    Try {
        [System.Reflection.Assembly]::LoadFrom($AdoNetDrvFile)
    }
    Catch {
        Write-Warning ("[DBI.ASE] Failed to load ADO.NET")
        $SybaseDriverMode = 'ODBC'
    }
}


If($SybaseDriverMode -eq 'ADO.NET') {

    Function Test-DBI
    {
        <#
        .SYNOPSIS
            Check if a DBI is valid and opened
        .DESCRIPTION
            If valid, Returns 'OPEN' if opened, 'CLOSE' if closed, otherwise returns 'INVALID'
        .PARAMETER dbi
        .EXAMPLE
            if(Test-DBI $dbi) { echo 'Connection is ready!' }
        #>
        [cmdletbinding()]
        Param([Parameter(Mandatory=$true)][HashTable]$dbi)

        $verbose = $VerbosePreference -ne 'SilentlyContinue'
        $debug = $DebugPreference -ne 'SilentlyContinue'

        if($dbi -and($dbi.ContainsKey('module'))) {
            if($dbi.module -ne 'DBI.ASE') {
                Write-Error ("[Test-DBI] mismatch module, this is for {0} but dbi is {1}" -f 'DBI.ASE',$dbi.module)
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
        #>
        [cmdletbinding()]
        Param(
            [Parameter(Mandatory=$true)][string] $ConnectionString
        )
        $verbose = $VerbosePreference -ne 'SilentlyContinue'
        $debug = $DebugPreference -ne 'SilentlyContinue'

        Write-Verbose ("[New-DBI] opening dbi: connection string='{0}'" -f $connectionString)

        $SybaseConn = New-Object Sybase.Data.AseClient.AseConnection
        $SybaseConn.ConnectionString = $ConnectionString

        $currentdbi = @{
            'object' = $SybaseConn;
            'interface' = 'ASE';
            'module' = 'DBI.ASE';
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
            Open a connection to Sybase ASE
        .DESCRIPTION
            Open a connection, return connection object. Measures the time to connect.
            Throws exception if open fails.
        .PARAMETER dbi
            A dbi identified created with New-DBI
        .EXAMPLE
        #>
        [cmdletbinding()]
        Param(
            [Parameter(Mandatory=$true)][HashTable]$DBi
        )
        $verbose = $VerbosePreference -ne 'SilentlyContinue'
        $debug = $DebugPreference -ne 'SilentlyContinue'

        if($DBi) {
            $confirm = DBI.ASE\Test-DBI $DBi
            if(-not($confirm)) {
                Throw "[Open-DBI] dbi is invalid or not ready"
            }
            if($confirm -eq 'CLOSE') {
                Write-Verbose ("[Open-DBI] opening dbi: {0}" -f $DBi.connectionString)
                $SybaseConn = $DBi.object
                $time = Measure-Command { $SybaseConn.Open() }
                if((DBI.ASE\Test-DBI $DBi) -eq 'CLOSE') {
                    $SybaseConn | Write-Verbose
                    Throw ("[Open-DBI]: failed to connect to datasource {0}" -f $DBi.connectionString)
                }
                # $ms = ($time.Minutes * 60 * 1000) + ($time.Seconds * 1000) + $time.Milliseconds
                $DBi.openTime = $time
            }
        }
        return $DBi
    } # end function Open-DBI


    Function Invoke-DBI
    {
        <#
        .SYNOPSIS
            Execute a SQL Command on Sybase ASE
        .DESCRIPTION
            Run a SQL Command in an existing (opened) connection. You must first open the
            connection using Open-DBI.
            Returns a DataSet if query succeeds.
        .PARAMETER dbi
        .PARAMETER query
        .PARAMETER Timeout
            Timeout in seconds for the query. Default is 0 (use system default)
        .EXAMPLE
            $DBi = Open-DBI $connectionString
            $dataset = Invoke-DBI $DBi "SELECT @@servername"
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
            if(-not(DBI.ASE\Test-DBI $DBi)) {
                Throw "[Invoke-DBI] dbi is invalid or is not ready"
            }
            $connection = $DBi.object
            $SybCmd = New-Object Sybase.Data.AseClient.AseCommand
            $SybCmd.Connection = $connection
            $SybCmd.CommandText = $Query
            If($Timeout -gt 0) {
                $SybCmd.CommandTimeout=$Timeout
            }

            $SybAdapter = New-Object Sybase.Data.AseClient.AseDataAdapter
            $SybAdapter.SelectCommand = $SybCmd

            $DataSet = New-Object System.Data.DataSet
            $null = $SybAdapter.Fill($DataSet)
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
        .EXAMPLE
            Close-DBI $dbi
        #>
        [cmdletbinding()]
        Param([Parameter(Mandatory=$true)][HashTable]$dbi)
        $verbose = $VerbosePreference -ne 'SilentlyContinue'
        $debug = $DebugPreference -ne 'SilentlyContinue'

        if($dbi) {
            $confirm = DBI.ASE\Test-DBI $dbi
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

}
ElseIf($SybaseDriverMode -eq 'ODBC') {

    Write-Warning ("[DBI.ASE] Using ODBC Driver. If you have problems, check if you are using a 32-bit version of powershell")

    Import-Power 'DBI.ODBC'

    Function New-DBi
    {
        <#
        .SYNOPSIS
            Create a new DBi Object
        .DESCRIPTION
            SEE DBI.ODBC\New-DBI
        .LINK
            DBI.ODBC\New-DBI
        #>
        [cmdletbinding()]
        Param(
            [Parameter(Mandatory=$true)][string] $ConnectionString
        )
        $verbose = $VerbosePreference -ne 'SilentlyContinue'
        $debug = $DebugPreference -ne 'SilentlyContinue'

        $DBi = DBI.ODBC\New-DBI -ConnectionString $ConnectionString "Adaptive Server Enterprise"
        return $DBi

    } # end function New-DBi


    Function Test-DBi
    {
        <#
        .SYNOPSIS
            Check if a DBi is valid and opened
        .DESCRIPTION
            SEE DBI.ODBC\Test-DBi
        .LINK
            DBI.ODBC\Test-DBi
        #>
        [cmdletbinding()]
        Param([Parameter(Mandatory=$true)][HashTable]$DBi)
        return (DBI.ODBC\Test-DBI $DBi)
    } # end function Test-DBi


    Function Open-DBi
    {
        <#
        .SYNOPSIS
            Open an ODBC Datasource Connection
        .DESCRIPTION
            SEE DBI.ODBC\Open-DBI
        .LINK
            DBI.ODBC\Open-DBI
        #>
        [cmdletbinding()]
        Param(
            [Parameter(Mandatory=$true)][HashTable]$DBi
        )
        $verbose = $VerbosePreference -ne 'SilentlyContinue'
        $debug = $DebugPreference -ne 'SilentlyContinue'

        return (DBI.ODBC\Open-DBI $DBi)
    } # end function Open-DBi


    Function Invoke-DBi
    {
        <#
        .SYNOPSIS
            Execute a SQL Command to an ODBC datasource
        .DESCRIPTION
            SEE DBI.ODBC\Invoke-DBI
        .LINK
            DBI.ODBC\Invoke-DBI

        #>
        [cmdletbinding()]
        Param(
            [Parameter(Mandatory=$true)][HashTable]$DBi,
            [Parameter(Mandatory=$true)][string]$Query,
            [Int]$Timeout=0

        )

        $verbose = $VerbosePreference -ne 'SilentlyContinue'
        $debug = $DebugPreference -ne 'SilentlyContinue'

        return (DBI.ODBC\Invoke-DBi -DBI $DBi -Query $Query)
    } # end function Invoke-DBi

    Function Close-DBi
    {
        <#
        .SYNOPSIS
            Close a DBi Connection
        .DESCRIPTION
            SEE DBI.ODBC\Close-DBI
        .LINK
            DBI.ODBC\Close-DBI
        #>
        [cmdletbinding()]
        Param([Parameter(Mandatory=$true)][HashTable]$DBi)
        $verbose = $VerbosePreference -ne 'SilentlyContinue'
        $debug = $DebugPreference -ne 'SilentlyContinue'

        return (DBI.ODBC\Close-DBi $DBi)
    } # end function Close-DBi
}
