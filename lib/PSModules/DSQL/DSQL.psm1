# dsql - SQL Functions to live dangerously

Import-Power 'Inventory'
Import-Power 'Extra.InvokeParallel'


# Function New-DSQL {
# <#
#     .SYNOPSIS
#         Create an DSQL Handle
#     .DESCRIPTION

#     .PARAMETER IService
#     .PARAMETER Module
#     .LINK

#     .EXAMPLE

# #>
#     [cmdletbinding()]
#     Param(
#         [Parameter(Mandatory=$true)][Object]$IService,
#         [Parameter(Mandatory=$true)][String]$Module
#     )
#     $verbose = $VerbosePreference -ne 'SilentlyContinue'
#     $debug = $DebugPreference -ne 'SilentlyContinue'

#     # Import-Power "DBI.$Module" -Prefix "dsql" -Reload
#     Import-Power "DBI.$Module" -Reload

#     $AllConnections = Get-ConnectionString -IService $IService -Module $Module

#     $Handle = @{
#         'DBi' = @{};
#         'Module' = $Module;
#         'ConnectionString' = @{};
#         'ResultSet' = @{};
#     }


#     Foreach($Servicename in $AllConnections.Keys) {

#         $Handle['ConnectionString'][$Servicename] = $AllConnections[$Servicename]

#         $DBi = @{}
#         $DBi = Invoke-Expression ('DBI.{0}\New-DBI -ConnectionString "{1}"' -f $Module,$AllConnections[$Servicename])

#         $Handle['DBi'][$Servicename] = $DBi
#     }

#     return $Handle

# } # end function New-DSQL

# Function Open-DSQL {
# <#
#     .SYNOPSIS
#         Open multiple DBi connections
#     .DESCRIPTION
#         When you supply an Inventory\IService table, tries to open a DBi connection to each service

#     .PARAMETER IService
#     .PARAMETER Module
#     .LINK
#
#     .EXAMPLE
#         $iserv = New-TableFromCSV MyInstances.csv

#         # open a DBi for each row using DBI.MSSQL
#         $dsql = Open-DSQL $iserv MSSQL
# #>
#     [cmdletbinding()]
#     Param(
#         [Parameter(Mandatory=$true)][Object]$IService,
#         [Parameter(Mandatory=$true)][String]$Module
#     )
#     $verbose = $VerbosePreference -ne 'SilentlyContinue'
#     $debug = $DebugPreference -ne 'SilentlyContinue'

#     Import-Power "DBI.$Module" -Prefix "dsql" -Reload

#     $AllConnections = Get-ConnectionString -IService $IService -Module $Module

#     $Handles = @{}
#     Foreach($Servicename in $AllConnections.Keys) {
#         $dbi = New-dsqlDBI $AllConnections[$Servicename]
#         $Handles[$Servicename] = $dbi

#         $errormessage = ''
#         Try{
#             Open-dsqlDBI -DBI $Handles[$Servicename]
#         }
#         Catch {
#             $errormessage = $_.Exception.Message
#             $Handles.Remove($Servicename)
#             Write-Warning ("[Open-DSQL] Open-DBI error: {0}" -f $errormessage)
#         }

#     }

#     # FIXME: this doesn't work, mix hash with array, 2 rows in iserv add 4 items in handles
#     return $Handles
# } # end function Open-DSQL


# Function Invoke-DSQL {
# <#
#     .SYNOPSIS
#         Execute Query on Multiple Servers
#     .DESCRIPTION

#     .PARAMETER dsql
#         A hashtable created with Open-DSQL
#     .PARAMETER Query

#     .LINK

#     .EXAMPLE

# #>
#     [cmdletbinding()]
#     Param(
#         [Parameter(Mandatory=$true)][HashTable]$Handle,
#         [String]$Query=""
#     )
#     $verbose = $VerbosePreference -ne 'SilentlyContinue'
#     $debug = $DebugPreference -ne 'SilentlyContinue'

#     $Module = $Handle['Module']

#     Import-Power "DBI.$Module" -Reload

#     $NoInteractive = $false

#     function PromptUser {
#         Param([String]$servicename)

#         If($NoInteractive) { return $true }

#         Write-Host "--> $Servicename" -ForegroundColor Cyan

#         $title = "Interactive Prompt"
#         $message = "Continue running query?"

#         $yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", `
#             "Continue with next service"

#         $no = New-Object System.Management.Automation.Host.ChoiceDescription "&No", `
#             "Exit"

#         $all = New-Object System.Management.Automation.Host.ChoiceDescription "&All", `
#             "Continue with all services, do not prompt again"

#         $options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no, $all)

#         $result = $host.ui.PromptForChoice($title, $message, $options, 0)

#         switch ($result)
#             {
#                 0 {return $true}
#                 1 {return $false}
#                 2 {$NoInteractive = $true; return $true}
#             }
#     }


#     $ResultRowCount = New-Object System.Data.DataTable 'ResultRowCounts'
#     [void]$ResultRowCount.Columns.Add('Servicename',[String])
#     [void]$ResultRowCount.Columns.Add('#Tables',[Int])
#     [void]$ResultRowCount.Columns.Add('#Row',[Int])

#     Foreach($Servicename in $Handle['DBi'].Keys) {

#         $DBi = $Handle['DBi'][$Servicename]

#         $errormessage = ''
#         Try{
#             Invoke-Expression ('DBI.{0}\Open-DBI -DBi $DBI' -f $Module)
#         }
#         Catch {
#             $errormessage = $_.Exception.Message
#             Write-Warning ("[Open-DSQL] Open-DBI error for {0}: {1}" -f $Servicename,$errormessage)
#         }

#         $DBi_State = Invoke-Expression ('DBI.{0}\Test-DBI -DBi $DBI' -f $Module,$DBi)
#         $KeepGoing = $true
#         If($KeepGoing -and($DBi_State -eq 'OPEN')) {
#             $rs = New-Object System.Data.Dataset "Invoke-DSQL"
#             $errormessage = ''
#             Try {
#                 Invoke-Expression ('$rs = DBI.{0}\Invoke-DBI -DBi $DBI -Query "{1}"' -f $Module,$Query)
#             }
#             Catch {
#                 $errormessage = $_.Exception.Message
#                 Write-Warning ("[Invoke-DSQL] Query error on {0}: {1}" -f $Servicename, $errormessage)
#                 If(-not(PromptUser $Servicename)) {
#                     $KeepGoing = $false
#                 }
#             }

#             # FIXME, save result in Handle, use additional function to merge datasets
#             if($errormessage -eq '') {
#                 $Handle['ResultSet'][$Servicename] = $rs.Copy()
#                 $RowCount = $ResultRowCount.NewRow()
#                 $RowCount.Servicename = $Servicename
#                 $RowCount['#Tables'] = ($Handle['ResultSet'][$Servicename].Tables|Measure-Object).Count
#                 $Handle['ResultSet'][$Servicename].Tables|Foreach {
#                     $RowCount['#Rows'] = ($_.Rows|Measure-Object).Count
#                 }
#                 $ResultRowCount.Rows.Add($RowCount)
#             }

#         }
#     }
# } # end function Invoke-DSQL


# Function Group-DSQL {
# <#
#     .SYNOPSIS
#         Group together ResultSets
#     .DESCRIPTION
#     .PARAMETER Handle
#     .LINK

#     .EXAMPLE

# #>
#     [cmdletbinding()]
#     Param(
#         [Parameter(Mandatory=$true)][HashTable]$Handle
#     )
#     $verbose = $VerbosePreference -ne 'SilentlyContinue'
#     $debug = $DebugPreference -ne 'SilentlyContinue'

#     $RS = New-Object System.Data.Dataset 'Group-DSQL'
#     Foreach($Servicename in $Handle['ResultSet'].Keys) {
#         Foreach($Table in $Handle['ResultSet'][$Servicename]) {
#             $T = $Table.Copy()
#             [void]$T.Columns.Add('__SERVICENAME',[STRING])
#             $T | Foreach { $_['__SERVICENAME'] = $Servicename } >$null
#             $RS.Tables.Add($T)>$null
#         }
#     }
#     return ,$RS
# } # end function Group-DSQL

Function Get-ConnectionString {
<#
    .SYNOPSIS
        A hackish connection string builder for DSQL
    .DESCRIPTION
        Returns a HashTable with connection strings.
    .PARAMETER Path
        Path to CSV file with IService format
    .PARAMETER Module
        DBI Module name to use, if not provided guessed from CSV path.
    .LINK

    .EXAMPLE

#>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)][String]$Path,
        [String]$Module=''
    )
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    $AllConnections = @{}

    If(-not($Module)) {
        if($Path -match 'ase') {
            $Module = 'ASE'
        }
        elseif($Path -match 'mssql') {
            $Module = 'MSSQL'
        }
    }

    $IService = (New-Table_IService (New-TableFromCSV $Path))

    Foreach($Row in $IService) {
        $cs = ''
        $key = ''
        Switch($Module) {
            "ASE" {
                $cfg = (Get-Config 'Sybase')['sybase']['login']

                $Hostname = $Row['Hostname']
                $Instance = $Row['Instancename']
                $Port = $Row['Port']
                $key = $Instance

                $Username = ''
                $Password = ''
                if($cfg.containskey($Hostname) -and($cfg[$Hostname].containskey($Instancename))) {
                    $username = $cfg[$Hostname][$Instancename]['username']
                    $password = $cfg[$Hostname][$Instancename]['password']
                }
                else {
                    $username = $cfg['_DEFAULT']['username']
                    $password = $cfg['_DEFAULT']['password']
                }

                $cs += ("pooling=false;na={0},{1};dsn={2}" -f $Hostname,$Port,$Instance)
                If($Username) { $cs += (";uid={0}" -f $Username) }
                If($Password) { $cs += (";password={0}" -f $Password) }
            }

            "MSSQL" {
                $cs += ("Server={0}" -f $Row['Servicename'])
                $cs += ";Trusted_Connection=True"
                $key = $Row['Servicename']
            }
        }
        if($cs) {
            $AllConnections[$key] = $cs
        }
        else {
            Write-Warning ("[Get-ConnectionString] Failed generation Connection String for {0}" -f $Row['Servicename'])
        }
    }

    return $AllConnections
} # end function Get-ConnectionString


Function New-PQ {
<#
    .SYNOPSIS
        Create a Parallel Query handle
    .DESCRIPTION
        PQuery is the work unit for running paralells querys on DBIs
    .PARAMETER Id
        An id for the Query. Recommended to be unique.
    .PARAMETER DBi
        A DBi object
    .LINK

    .EXAMPLE

#>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)][String]$Id,
        [Parameter(Mandatory=$true)][HashTable]$DBi
    )
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    $pq = @{
        'ID' = $Id;
        'DBi' = $DBi;
        'QueryList' = @();
        'ResultList' = @();
        'ErrorList' = @();
        'Executed' = $false;
        'Ok' = $null;
    }

    return $pq
} # end function New-PQuery


Function Invoke-PQ {
<#
    .SYNOPSIS
        Run queries in parallel
    .DESCRIPTION

    .PARAMETER PQList
        An Array of PQs
    .PARAMETER QueryList
        An Array of Query strings
    .PARAMETER Timeout
        Timeout in seconds
    .LINK

    .EXAMPLE

#>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)][Array]$PQList,
        [Parameter(Mandatory=$true)][Array]$QueryList,
        [Int]$Timeout=0
    )
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    $Script = {
        If(Test-DBI $_['DBI'] -ne 'OPEN') {
            Write-Debug 'Open DBI'
            Open-DBI $_['DBI']
        }

        foreach ($Query in $_['QueryList']) {
            $r = New-Object System.Data.Dataset 'EmptyDataset'
            Try {
                Write-Debug ('Invoke DBI {0}' -f $Query)
                $r = Invoke-Dbi -DBI $_['DBI'] -Query $Query
                $_['Ok'] = $true
                $_['ResultList'] += $r
            }
            Catch {
                $_['ErrorList'] += $_.Exception.Message
                $_['Ok'] = $false
            }
        }

        $_['Executed'] = $true

        Write-Debug 'Close DBI'
        Close-DBI $_['DBI']
    }

    Foreach($PQ in $PQList) {
        $PQ['QueryList'] = $QueryList
        $PQ['ResultList'] = @()
        $PQ['ErrorList'] = @()
        $PQ['Executed'] = $false
        $PQ['Ok'] = $false
    }

    if($Timeout) {
        $PQList | Invoke-Parallel -RunspaceTimeout $Timeout -ImportModules -ImportVariables -ScriptBlock $Script
    }
    else {
        $PQList | Invoke-Parallel -ImportModules -ImportVariables -ScriptBlock $Script
    }
} # end function Invoke-PQ


# Function Open-PQ {
# <#
#     .SYNOPSIS
#         Open all DBis in parallel
#     .DESCRIPTION
#         Calls Open-DBi for PQs DBi
#     .PARAMETER PQList
#         A list of PQs
#     .PARAMETER

#     .LINK

#     .EXAMPLE

# #>
#     [cmdletbinding()]
#     Param(
#         [Parameter(Mandatory=$true)][Array]$PQList
#     )
#     $verbose = $VerbosePreference -ne 'SilentlyContinue'
#     $debug = $DebugPreference -ne 'SilentlyContinue'

#     # $PQHandles = @()

#     $Session = [system.management.automation.runspaces.initialsessionstate]::CreateDefault()
#     $Session.Variables.Add(
#         (New-Object System.Management.Automation.Runspaces.SessionStateVariableEntry ('Boostrap', $GLOBAL:_PWR['POWERUP_FILE'], $null))
#     )
#     $Session.Variables.Add(
#         (New-Object System.Management.Automation.Runspaces.SessionStateVariableEntry ('PQList', $PQList, $null))
#     )

#     $RunPool = [runspacefactory]::CreateRunspacePool(1, 2, $Session, $Host)
#     $RunPool.Open()

#     $threads = @()

#     $i = 0
#     foreach($pq in $PQList) {

#         $PowerShell = [powershell]::Create()
#         $PowerShell.RunspacePool = $RunPool

#         [void]$PowerShell.AddScript({
#             Param($Index)

#             $DBI = $PQList[$Index]['DBi']
#             . $Bootstrap >$null

#             Import-Power $DBi['module']
#             If(-not(Test-DBI $DBI -eq 'OPEN')) {
#                 Open-DBI $DBI
#             }
#         }).AddArgument($i)

#         # $PSCollector = New-Object 'System.Management.Automation.PSDataCollection[psobject]'
#         # $handle = $PowerShell.BeginInvoke() #$PSCollector,$PSCollector)
#         $threads += @{
#             'Job' = $PowerShell;
#             'Result' = $PowerShell.BeginInvoke();
#         }
#         # $PQHandles += $handle
#         $i += 1
#     }

#     return $threads
# } # end function Open-PQ


# Function Join-PQ {
# <#
#     .SYNOPSIS
#         Wait until Paralell Query is complete
#     .DESCRIPTION
#         Blocks until all PQs are completek
#     .PARAMETER PQHandles

#     .PARAMETER

#     .LINK

#     .EXAMPLE

# #>
#     [cmdletbinding()]
#     Param(
#         [Parameter(Mandatory=$true)][Array]$Threads,
#         [String]$Activity='Waiting'
#     )
#     $verbose = $VerbosePreference -ne 'SilentlyContinue'
#     $debug = $DebugPreference -ne 'SilentlyContinue'

#     $total = ($Threads|Measure).count
#     $count = 0
#     foreach ($thread in $Threads) {
#         Write-Progress -Activity $Activity -Status $Activity -PercentComplete ($count*100/$total)
#         while(-not($thread['Result'].IsCompleted)) {
#             Sleep 1
#         }
#         $count += 1
#     }
#     Write-Progress -Activity $Activity -Status $Activity -PercentComplete 100 -Complete

#     foreach($thread in $Threads) {
#         $thread['Job'].EndInvoke($thread['Result'])
#     }
# } # end function Wait-PQ


# Function InvokeWIP-PQ {
# <#
#     .SYNOPSIS
#         Open all DBis in parallel
#     .DESCRIPTION
#         Calls Open-DBi for PQs DBi
#     .PARAMETER PQList
#         A list of PQs
#     .PARAMETER

#     .LINK

#     .EXAMPLE

# #>
#     [cmdletbinding()]
#     Param(
#         [Parameter(Mandatory=$true)][Array]$PQList
#     )
#     $verbose = $VerbosePreference -ne 'SilentlyContinue'
#     $debug = $DebugPreference -ne 'SilentlyContinue'

#     $activity = 'hola'

#     # $PQHandles = @()

#     $Session = [system.management.automation.runspaces.initialsessionstate]::CreateDefault()
#     $Session.Variables.Add(
#         (New-Object System.Management.Automation.Runspaces.SessionStateVariableEntry ('Boostrap', $GLOBAL:_PWR['POWERUP_FILE'], $null))
#     )
#     $Session.Variables.Add(
#         (New-Object System.Management.Automation.Runspaces.SessionStateVariableEntry ('PQList', $PQList, $null))
#     )

#     $RunPool = [runspacefactory]::CreateRunspacePool(1, 2, $Session, $Host)
#     $RunPool.Open()

#     write-host "Available runspaces: $($RunPool.GetAvailableRunspaces())"

#     $threads = @()

#     $i = 0
#     foreach($pq in $PQList) {

#         $PowerShell = [powershell]::Create()
#         $PowerShell.RunspacePool = $RunPool

#         [void]$PowerShell.AddScript({
#             Param($Index)

#             $DBI = $PQList[$Index]['DBi']
#             . $Bootstrap >$null

#             Import-Power $DBi['module']

#             If(-not(Test-DBI $DBI -eq 'OPEN')) {
#                 Open-DBI $DBI
#             }

#             $PQList[$Index]['Ok'] = $False
#             $PQList[$Index]['Executed'] = $True
#             $DS = New-Object System.Data.DataSet 'EmptyDataset'
#             try {
#                 $DS = Invoke-Dbi -DBI $DBI -Query 'SELECT @@SERVERNAME as "svc"' -Timeout 10
#                 $PQList[$Index]['ResultList'] = $DS
#                 $PQList[$Index]['Ok'] = $True
#             }
#             Catch {
#                 $PQList[$Index]['ErrorList'] = $_.Exception.Message
#                 $PQList[$Index]['Ok'] = $False
#             }

#             # Close-DBI $DBI
#         }).AddArgument($i)

#         # $PSCollector = New-Object 'System.Management.Automation.PSDataCollection[psobject]'
#         # $handle = $PowerShell.BeginInvoke() #$PSCollector,$PSCollector)
#         $threads += @{
#             'PowerShell' = $PowerShell;
#             'WaitHandle' = $PowerShell.AsyncWaitHandle;
#             'Result' = $PowerShell.BeginInvoke();
#         }
#         # $PQHandles += $handle
#         $i += 1
#     }


#     # WAIT #1
#     # $total = ($Threads|Measure).count
#     # $count = 0
#     # foreach ($thread in $Threads) {
#     #     Write-Progress -Activity $Activity -Status $Activity -PercentComplete ($count*100/$total)
#     #     while(-not($thread['Result'].IsCompleted)) {
#     #         Sleep 1
#     #     }
#     #     $count += 1
#     # }
#     # Write-Progress -Activity $Activity -Status $Activity -PercentComplete 100 -Complete

#     # WAIT #2 (with timeout)
#     $WaitAll = @()
#     Foreach($thread in $Threads) { $WaitAll += $thread['WaitHandle'] }
#     $success = [System.Threading.WaitHandle]::WaitAll($WaitAll, 20000)

#     #  Collect results?
#     foreach($thread in $Threads) {
#         $thread['PowerShell'].EndInvoke($thread['Result'])
#         $info = $thread['Powershell'].InvocationStateInfo
#         write-host "State: $($info.state) ; Reason: $($info.reason)"
#         $thread['PowerShell'].Dispose()
#     }

#     write-host "Available runspaces: $($RunPool.GetAvailableRunspaces())"

#     # return $PQList
#     # return $threads
# } # end function Open-PQ
