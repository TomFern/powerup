# Yet another SQL Client

# Import-Power 'File.Watch'
Import-Power 'Path'
Import-Power 'Table'

Function New-Yasql {
<#
    .SYNOPSIS
        Create a Yasql handle
    .DESCRIPTION
        Returns a Yasql Handle
    .PARAMETER DBi
        A DBi object
    .PARAMETER Name
        A memorable name for the session or datasource
    .LINK
        <`8`>
    .EXAMPLE
        Import-Power 'DBI.MSSQL'
        $DBi = New-DBi '..connection string..'
        Open-DBI $Dbi
        $ya = New-Yasql $DBi
        Open-Yasql $ya
        # execute queries
        Close-Yasql $ya
        <`7`>
        <`7`>
#>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)][HashTable]$DBi,
        [String]$Name=""
    )
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    $Id = [String]("{0:d5}" -f (Get-Random)).Substring(0,5)

    If($Name -eq '') {
        $Name = "Yasql"
    }

    $Name = [string]("{0}{1}" -f $Name,$Id)

    $tmpdir = $GLOBAL:_PWR['TMPDIR']

    $Handle = @{
        'DBi' = $DBi;
        'SessionName' = $Name;
        'InputFile' = ("{0}{1}.sql" -f $Name,$Id);
        'InputFilePath' = ConvertTo-AbsolutePath (Join-Path $tmpdir ("{0}{1}.sql" -f $Name,$Id));
        'LastResutDate' = '';
        'LastResultSet' = New-Object System.Data.Dataset;
        'Query' = @();
    }

    return $Handle
} # end function New-Yasql


Function Open-Yasql {
<#
    .SYNOPSIS
        Start a Yasql session
    .DESCRIPTION
        Opens a connection to the datasource, opens a text file for user input.

        Use Invoke-Yasql to enter the main execution loop
    .PARAMETER Handle
        A handle returned by New-Yasql
    .LINK
        <`8`>
    .EXAMPLE
        <`9`>
#>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)][HashTable]$Handle
    )
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    Import-Power $Handle['DBi']['module'] -Prefix 'YA'

    Open-YADBI $Handle['DBi']
    If((Test-YADBI $Handle['DBi']) -ne 'OPEN') {
        Throw ("[Open-Yasql] DBi not open")
    }

    New-Item -Type f -Force $Handle['InputFilePath'] >$null
    Set-Content $Handle['InputFilePath'] (__yasql_banner $Handle['SessionName'])

    notepad $Handle['InputFilePath']

    # $Handle['RegisterEvent'] = Register-WatchFile $Handle['InputFilePath'] { __yasql_callback @($GLOBAL:_PWR['POWERUP_FILE'],$h) }
} # end function Open-Yasql


Function Invoke-Yasql {
<#
    .SYNOPSIS
        Main loop for Yasql
    .DESCRIPTION
        Starts a foreground wait loop. Upon write on the Input File the query is executed and results output into the console.

        To exit the loop HOLD Control+C
    .PARAMETER Handle
        Handle returned by New-Yasql
    .PARAMETER <`6`>
        <`7`>
    .LINK
        <`8`>
    .EXAMPLE
        <`9`>
#>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)][HashTable]$Handle
    )
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    Import-Power $Handle['DBi']['module'] -Prefix 'YA'
    $LastModDate = (Get-Item $Handle['InputFilePath']).LastWriteTime
    [console]::TreatControlCAsInput = $true

    Write-Host -ForegroundColor Cyan " --- HOLD CONTROL+C to exit ---"
    Write-Host " --- Waiting for Input. Save your file to run the query."
    While($true) {

        $CurrentModDate = (Get-Item $Handle['InputFilePath']).LastWriteTime
        If($CurrentModDate -gt $LastModDate) {
            $LastModDate = $CurrentModDate

            $Query = (Get-Content $Handle['InputFilePath'] | Out-String)
            $Handle['Query'] += $Query

            Write-Verbose ("[Invoke-Yasql] Run query: [{0}]" -f $Query)
            # FIXME: GO breaks, newlines?

            $ReturnSet = New-Object System.Data.DataSet
            Try {
                $ReturnSet = Invoke-YADBI -DBi $Handle['DBi'] -Query $Query
            }
            Catch {
                Write-Warning $_.Exception.Message
            }
            If(($ReturnSet|Get-Table|Measure-Object).Count -gt 0) {
                $Handle['LastResultSet'] = $ReturnSet
                $Handle['LastResutDate'] = [DateTime](Get-Date)
                $ReturnSet | Get-Table | Foreach {
                    $ReturnSet.Tables[$_] | Format-Table
                    $ReturnSet.Tables[$_] | Out-Gridview -Title "Result $_"
                }
            }

        }

        if($Host.UI.RawUI.KeyAvailable -and (3 -eq[int]$Host.UI.RawUI.ReadKey("AllowCtrlC,IncludeKeyUp,NoEcho").Character)) {
            break
        }

        Sleep 1

        if($Host.UI.RawUI.KeyAvailable -and (3 -eq[int]$Host.UI.RawUI.ReadKey("AllowCtrlC,IncludeKeyUp,NoEcho").Character)) {
            break
        }
    }

    [console]::TreatControlCAsInput = $false

} # end function Invoke-Yasql


Function Close-Yasql {
<#
    .SYNOPSIS
        Close a Yasql session
    .DESCRIPTION
        Closes connection to datasource, and cleans up.
    .PARAMETER Handle
        A handle returned by New-Yasql
    .LINK
        <`8`>
    .EXAMPLE
        <`9`>
#>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)][HashTable]$Handle
    )
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    Import-Power $Handle['DBi']['module'] -Prefix 'YA'

    Close-YADBI $Handle['DBi']
    Remove-Item -Force $Handle['InputFilePath']

} # end function Close-Yasql

function __yasql_banner {
    Param($Name)

    $nl=[Environment]::Newline
    $b = "-- $Name $nl"
    $b+= "-- format:table $nl"
    $b+=$nl
    return $b
}

