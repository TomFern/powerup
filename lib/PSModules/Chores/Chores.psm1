
# Chore Manager

Set-StrictMode -version Latest

Import-Power 'Temp'
Import-Power 'Email'
Import-Power 'Path'
Import-Power 'Table'

# function _write_output {
#     Param([string]$message)
#     If($GLOBAL:_PWR['VERBOSE_CHORE']) {
#         Write-Output $message
#     }
# }


# Return formatted string to print w/results
# function __chore_result_message{
#     Param([HashTable]$Handle)
#     $name = $Handle['Id']['ChoreName']
#     $start = $Handle['Id']['StartDateTime']
#     $stop = $Handle['Id']['StopDateTime']
#     $duration = $Handle['Id']['DurationTime']
#     $workflow = $Handle['Control']['ChoreWorkflow']
#     $lasterror = $Handle['Control']['LastErrorMessage']
#     $errorcode = $Handle['Control']['ErrorCode']

# @"
# --------------------------------------------------------
# Name: $name
# Start on: $start
# Stop on: $stop          Duration: $duration
# Status: $workflow
# ErrorCode: $errorcode
# LastErrorMessage: $lasterror
# --------------------------------------------------------
# "@
# }

# Log a single entry on history csv file
# function __chore_log_history {
#     Param([HashTable]$Handle,[String]$Event)

#     $date = Get-Date -uformat "%Y-%m-%d %H:%M:%S"

#     $name = $Handle['Id']['ChoreName']
#     $historyfn = $Handle['Control']['HistoryFile']
#     $workflow = $Handle['Control']['ChoreWorkflow']
#     $index = $Handle['Control']['StepCurrentIndex']

#     ("$name,$Event,$index,$workflow,$date") | Out-File -Append -Encoding UTF8 $historyfn
# }


# Execute one single step script by Index number
function __chore_invoke_step_by_index {
    Param([Hashtable]$Handle,[Int]$Index)

    $stepfn = ($Handle['Control']['StepFilesList'])[$index]
    $stepname = ($Handle['Control']['StepList'])[$index]

    # _write_output ("Step [{0}] {1}"  -f $index,$stepname)

    $StepScript = Import-Module -Name $stepfn -AsCustomObject -Force

    # __chore_log_history $Handle 'StepStart'

    $StepStatus = 'STEP_OK'
    $StepError = ''
    $ErrorActionThis = $Handle['Control']['ErrorActionThis']

    Write-Debug "Invoke StepPre file: $stepfn"

    If($StepStatus -eq 'STEP_OK') {
        # Try {
            $Global:ErrorActionPreference = 'STOP'
            $StepScript.StepPre.Invoke($Handle['User'],$Handle['Id'])
        # }
        # Catch {
            # $StepStatus = 'STEP_ERROR_PRE'
            # $StepError = $_.Exception.Message
        # }
    }

    Write-Debug "Invoke StepProcess file: $stepfn"

    If($StepStatus -eq 'STEP_OK') {
        # Try {
            $Global:ErrorActionPreference = $ErrorActionThis
            $StepScript.StepProcess.Invoke()
        # }
        # Catch {
            # $StepStatus = 'STEP_ERROR_PROCESS'
            # $StepError = $_.Exception.Message
        # }
    }

    Write-Debug "Invoke StepNext file: $stepfn"

    $Return = @{}
    If($StepStatus -eq 'STEP_OK') {
        # Try {
            $Global:ErrorActionPreference = 'STOP'
            $Return = $StepScript.StepNext.Invoke()
        # }
        # Catch {
        #     $StepStatus = 'STEP_ERROR_POST'
        #     $StepError = $_.Exception.Message
        # }
    }

    If($StepStatus -eq 'STEP_OK') {
        If(-not($Return -is 'Hashtable')) {
            $StepStatus = 'STEP_ERROR_POST'
            $StepError = "Returned Object is not a HashTable"
        }
        else {
            If(($Return|Measure-Object).Count -gt 0) {
                $Keys = $Return.Keys
                Foreach($v in $Keys) {
                    $Handle['User'][$v] = $Return[$v]
                }
            }
        }
    }

    Remove-Variable 'StepScript'

    $Handle['Control']['LastErrorMessage'] = $StepError

    return $StepStatus
}


# Start from a given Index number and keep going a Step returns error, or we are out of steps
function __chore_follow_steps {
    Param([Hashtable]$Handle,[Int]$StartingIndex)

    # __chore_log_history $Handle 'ChoreStart'

    $LastStepIndex = (($Handle['Control']['StepFilesList']) | Measure-Object).Count

    $ChoreStatus = 'CHORE_OK'

    For($i=$StartingIndex; $i -lt $LastStepIndex; $i++) {

        $Percent = [Math]::Floor($i*100/$Handle['Control']['StepList'].Length)
        Write-Progress -Id 1 -Activity $Handle['Id']['ChoreName'] -Status $Handle['Control']['StepList'][$i] -PercentComplete $Percent

        $StepLastStatus = (__chore_invoke_step_by_index $Handle $i)

        If($StepLastStatus -match "^STEP_ERROR_") {
            $Handle['Control']['ChoreWorkflow'] = 'ERROR'
            $Handle['Control']['ErrorCode'] = $StepLastStatus
            $ChoreStatus = 'CHORE_ERROR'
            Write-Progress -Id 1  -Activity $Handle['Id']['ChoreName'] -Status 'Error' -PercentComplete 100
            break
        }

    }

    $Handle['Control']['StepCurrentIndex'] = $i

    If($ChoreStatus -eq 'CHORE_OK') {
        $Handle['Control']['ChoreWorkflow'] = 'STOP'
        Write-Progress -Id 1 -Activity $Handle['Id']['ChoreName'] -Status 'Done' -PercentComplete 100
    }

    # __chore_log_history $Handle 'ChoreStop'
}


Function New-Chore {
    <#
    .SYNOPSIS
        Create a new Chore
    .DESCRIPTION
        Reads supplied config, validates steps files and required configs
        Returns a handle: HashTable that identifies this chore instance.
    .PARAMETER Config
         A HashTable contaning a chore configuration
    .EXAMPLE
        $Cfg = Get-Config 'chores.Foo'
        $chore = New-Chore $Cfg
        Try {
            Invoke-Chore $chore
        }
        Catch {
            ... oops the chore has failed!
            Send-ErrorReport ....
        }
    .LINK
        New-Chore
        Invoke-Chore
        Get-Config
        Search-Chore
        about_Chores
        about_Chores_Config

    #>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)][HashTable]$ChoreConfig
    )
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'


    if(-not($ChoreConfig.ContainsKey('steps'))) {
        Throw "[New-Chore] No steps on chore defintion."
    }

    $logdir = $GLOBAL:_PWR['LOGDIR']
    $storagedir = $GLOBAL:_PWR['STORAGEDIR']
    # $historyfn = Join-Path $storagedir "chores_history.csv"
    $OutFn = Join-Path $logdir ("{0}.out" -f $ChoreConfig['name'])

    # New-Item -type f -force $logfn | Out-Null
    # If(-not(Test-Path $historyfn)) {
    #     Write-Verbose "[Invoke-Chore] Initialize History CSV: $historyfn"
    #     "name,event,workflow,date" | Out-File -Encoding UTF8 $historyfn
    # }

    $Handle = @{
        'User' = @{};
        'Id' = @{
            'ChoreName' = $ChoreConfig['name'];
            'Description' = $ChoreConfig['description'];
            'Config' = @{};
            'StartDateTime' = '';
            'StopDateTime' = '';
            'DurationTime' = '';
        };
        'Requires' = @{
            'ConfigsToLoad' = $ChoreConfig['requires']['configs'];
            'MustBeElevated' = [Bool] $ChoreConfig['requires']['elevated'];
            'RequiresArchitecture' = $ChoreConfig['requires']['arch'];
        };
        'Control' = @{
            'ChoreWorkflow' = 'INITIALIZE';
            'ErrorActionPrevious' = ($Global:ErrorActionPreference|Out-String).Trim();
            'ErrorActionThis' = 'Stop';
            'ErrorCode' = '';
            # 'HistoryFile' = $historyfn;
            'LastErrorMessage' = '';
            'OutFile' = $outfn;
            'StepCurrentFile' = '';
            'StepCurrentIndex' = -1;
            'StepFilesList' = @();
            'StepList' = @();
        };
    }

    if($Handle['Requires']['MustBeElevated']) {
        if(-not($GLOBAL:_PWR['ELEVATED'])){
            Throw "[New-Chore] Requires Elevated session. You must Run as an Administrator"
        }
    }

    If(-not(@('any','all') -contains $Handle['Requires']['RequiresArchitecture'])) {
        If($Handle['Requires']['RequiresArchitecture'] -ne $GLOBAL:_PWR['PSARCH']) {
            Throw ("[New-Chore] Required architecture not met: {0} is not {1}" -f $Handle['Requires']['RequiresArchitecture'],$GLOBAL:_PWR['PSARCH'])
        }
    }

    # load configs from chore definition
    if($Handle['Requires']['ConfigsToLoad']) {
        $Append = @{}
        Foreach($cfgname in $Handle['Requires']['ConfigsToLoad']) {

            $hash = $null
            $keys = $null
            # Try {
                # Write-Debug "[Invoke-Chore] Loading config '$cfgname'"
                $hash = Get-Config $cfgname
                $keys = $hash.Keys
            # }
            # Catch {
                # Throw "[New-Chore] No config file found: $cfgname"
            # }
            if($keys) {
                $Append = $Append + $hash
            }
        }
        $Handle['Id']['Config'] = $Append
    }
    # convert steps name into actual files, preserving powerup namespaces
    function __chore_find_step_files {
        Param($StepName)
        $Stepfn, $StepPath = ConvertTo-CannonicalName $StepName
        $Stepfn += '.psm1'
        Get-PowerupPaths | Foreach {
            $BasePath = Join-Path $_ 'chores'
            $Testfn = ConvertTo-AbsolutePath (Join-Path $BasePath "$StepPath\$Stepfn")
            Write-Debug  "[New-Chore] Looking for file: $Testfn"
            if(Test-Path -PathType Leaf $Testfn) {
                return $Testfn
            }
        }
        return ""
    }
    Foreach($StepName in $ChoreConfig['steps']) {
        $FindFile = (__chore_find_step_files $StepName|Out-String).Trim()

        If($FindFile) {
            Write-Debug "[New-Chore] Verify file: $FindFile"
            # Try {
                $ScriptObject = Import-Module -Name $FindFile -AsCustomObject
                Remove-Variable 'ScriptObject'
            # }
            # Catch {
                # Throw ("[New-Chore] File failed to load: $FindFile. Error was: " -f $_.Exception)
            # }

            Write-Debug ("[New-Chore] Add Step: {0} with file: {1}" -f $StepName,$FindFile)
            $Handle['Control']['StepFilesList'] += $FindFile
            $Handle['Control']['StepList'] += $StepName
        }
        else {
            Throw "[New-Chore] Can't find file for: $StepName"
        }

    }
    if(($Handle['Control']['StepFilesList']|Measure-Object).Count -ne
            ($ChoreConfig['steps']|Measure-Object).Count) {
        Throw "[New-Chore] Some files are missing"
    }
    return $Handle
} # end function New-Chore


Function Invoke-Chore
{
    <#
    .SYNOPSIS
        Start a Chore
    .DESCRIPTION
        Starts to execute a Chore.

        The default behaviour is to stop the chore on error. You may change this with the -OnError parameter.
        (this only affects the StepProcess execution

        You may wish to restart a Chore from a different Step number, you may use -From paramater for this.

        For more information about chores use:

            help about_Chores
            help about_Config_Chores

    .PARAMETER Handle
        Handle for chore instance. Created with New-Chore
    .PARAMETER OnError
        (optional) Set ErrorActionPreference for the duration of the Chore, default is 'Stop'
    .PARAMETER From
        Step Index number, counting from 0. Defaults to 0 (first step)
    .EXAMPLE
        $Cfg = Get-Config 'chores.Foo'
        $chore = New-Chore $Cfg
        Try {
            Invoke-Chore $chore
        }
        Catch {
            ... oops the chore has failed!
            Send-ErrorReport ....
        }
    .LINK
        New-Chore
        Invoke-Chore
        Get-Config
        Search-Chore
        about_Chores
        about_Chores_Config
    #>

    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)][HashTable] $Handle,
        [ValidateSet('Stop','Continue','SilentlyContinue')][String] $OnError = 'Stop',
        [ValidateRange(0,99)][Int]$From=0
    )

    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'


    # Try {
        $OutFn = $Handle['Control']['OutFile']
        # $HistoryFn = $Handle['Control']['HistoryFile']
        $Handle['Control']['ErrorActionPrevious'] = ($Global:ErrorActionPreference|Out-String).Trim();
    # }
    # Catch {
    #     Throw "[Invoke-Chore] The provided handle is invalid."
    # }

    # If(-not(Test-Path $HistoryFn)) {
    #     Write-Verbose "[Invoke-Chore] Initialize History CSV: $historyfn"
    #     "name,event,workflow,date" | Out-File -Encoding UTF8 $historyfn
    # }
    If($OnError) {
        $Handle['Control']['ErrorActionThis'] = $OnError
    }

    if($From -gt (($Handle['Control']['StepFilesList']|Measure-Object).Count -1)) {
        Throw "[Invoke-Chore] -From step index out of bounds."
    }

    $Handle['Control']['ChoreWorkflow'] = 'ACTIVE'
    $Handle['Control']['StepCurrentIndex'] = ($From - 1)
    $Handle['Id']['StartDateTime'] = (Get-Date -uformat "%Y-%m-%d %H:%M:%S")

    # Try {
    #     Stop-Transcript
    # }
    # Catch {
    #     $null
    # }

    Clear-Errors

    # Start-Transcript $OutFn

    # __chore_log_history $Handle 'ChoreStart'

    # _write_output ("--> Chore: {0} | Start: {1}" -f $Handle['Id']['ChoreName'], $Handle['Id']['StartDateTime'] )

    Write-Progress -Id 1 -Activity $Handle['Id']['ChoreName'] -Status 'Starting' -PercentComplete 0

    $ChoreStatus = (__chore_follow_steps $Handle $From)

    $Handle['Id']['StopDateTime'] = (Get-Date -uformat "%Y-%m-%d %H:%M:%S")
    $Handle['Id']['DurationTime'] = New-TimeSpan -Start $Handle['Id']['StartDateTime'] -End $Handle['Id']['StopDateTime']

    # _write_output ("--> Chore: {0} | Stop: {1}" -f $Handle['Id']['ChoreName'], $Handle['Id']['StopDateTime'] )

    # __chore_log_history $Handle 'ChoreStop'

    # _write_output (__chore_result_message $Handle)

    # Stop-Transcript

    $Error | Out-File -Append $OutFn

    $Global:ErrorActionPreference = $Handle['Control']['ErrorActionPrevious']

    If($Handle['Control']['ChoreWorkflow'] -eq 'ERROR') {
        Throw ("[Invoke-Chore] Chore stopped with ERROR state. Last error message was: " -f $Handle['Control']['LastErrorMessage'])
    }

    Write-Progress -Id 1 -Activity $Handle['Id']['ChoreName'] -Status $Handle['Control']['ChoreWorkflow'] -Complete

} # end function Invoke-Chore


Function Search-Chore
{
    <#
    .SYNOPSIS
        List available chores
    .DESCRIPTION
        List available chores from config
    .EXAMPLE
        Search-Chore
    .LINK
        New-Chore
        Invoke-Chore
        Resume-Chore
        Get-Config
        Search-Chore
        about_Chores
        about_Chores_Config
    #>
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    $seen = @{}
    $configs = Search-Config 'chores'
    foreach($k in $configs.GetEnumerator()) {
        if(-not($seen.ContainsKey($k.Name))) {
            $cfg = $null
            # Try {
                $cfg = Get-Config $k.Name
            # }
            # Catch {
                # Write-Warning ("[Search-Chores] Error reading config {0}" -f $k.Name)
                # $cfg = $null
            # }
            $seen[$k.Name]=$cfg['description']
        }
    }
    return $seen
} # end function Search-Chore


Function Debug-Step {
<#
    .SYNOPSIS
        Debug a single step file
    .DESCRIPTION
        Invokes a single step file with provided variables,
        Passes the values returned by StepNext
    .PARAMETER Path
        Path to the step file
    .PARAMETER UserVariables
        UserVariables. Defaults to empty HashTable
    .PARAMETER IdVariables
        Id Variables. Defaults to tests values.
    .EXAMPLE
        $return = Debug-Step 'chores\Foo.psm1' @{'Foo' = 'bar'} @{'ChoreName' = 'MyTest' }
#>
    [cmdletbinding()]
    Param(
            [Parameter(Mandatory=$true)][String]$Path,
            [HashTable] $UserVariables = @{},
            [HashTable] $IdVariables = @{
                'ChoreName' = 'Debug-Step';
                'Description' = 'Debug-Step';
                'Config' = @{};
                'StartDateTime' = [DateTime](Get-Date);
                'StopDateTime' = '';
                'DurationTime' = '';
            }
        )

    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    $StepScript = Import-Module -Name $Path -AsCustomObject -Force

    $StepStatus = 'STEP_OK'
    $StepError = ''

    If($StepStatus -eq 'STEP_OK') {
        # Try {
            $StepScript.StepPre.Invoke($UserVariables,$IdVariables) | Out-Null
        # }
        # Catch {
            # $StepStatus = 'STEP_ERROR_PRE'
            # $StepError = $_.Exception.Message
        # }
    }


    If($StepStatus -eq 'STEP_OK') {
        # Try {
            $StepScript.StepProcess.Invoke() | Out-Null
        # }
        # Catch {
        #     $StepStatus = 'STEP_ERROR_PROCESS'
        #     $StepError = $_.Exception.Message
        # }
    }


    # $Return = @{}
    If($StepStatus -eq 'STEP_OK') {
        # Try {
            $Return = $StepScript.StepNext.Invoke()
        # }
        # Catch {
            # $StepStatus = 'STEP_ERROR_POST'
            # $StepError = $_.Exception.Message
        # }
    }

    Remove-Variable 'StepScript'

    If($StepStatus -eq 'STEP_OK') {
        return $Return
    }
    else {
        Write-Error ("[Debug-Step] Step ended in error. Step Status: {0}. Step Error: {1}" -f $StepStatus, $StepError)
    }
} # end function Debug-Step


Function Start-Chore {
<#
    .SYNOPSIS
        Start a chore in background as Job
    .DESCRIPTION
        Starts a chore in background, returning control of the console immedately.

        A totally separated session of Powerup will be initalized.

    .PARAMETER Handle
        Handle for chore instance. Created with New-Chore
    .PARAMETER OnError
        (optional) Set ErrorActionPreference for the duration of the Chore, default is 'Stop'
    .PARAMETER From
        Step Index number, counting from 0. Defaults to 0 (first step)
    .LINK
        New-Chore
        Invoke-Chore
        about_Chores
    .EXAMPLE
#>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)][HashTable] $Handle,
        [ValidateSet('Stop','Continue','SilentlyContinue')][String] $OnError = 'Stop',
        [ValidateRange(0,99)][Int]$From=0
        )
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    $JobScriptBlock = {
        Param($JobArg)
        $PowerupFile = $JobArb[0]
        $Handle = $JobArb[1]
        $OnError = $JobArb[2]
        $From = $JobArb[3]

        . $PowerupFile | Out-Null

        Import-Power 'Chores'
        Invoke-Chore -Handle $Handle -OnError $OnError -From $From
    }

    #&$JobScriptBlock $_PWR['POWERUP_FILE'] $Handle $OnError $From
    # Start-job -ScriptBlock $JobScriptBlock -ArgumentList $_PWR['POWERUP_FILE'],$Handle,$OnError,$From

    $JobArg=@($_PWR['POWERUP_FILE'],$Handle,$OnError,$From)

    # Invoke background process
    $Powershell = [PowerShell]::Create()
    $Powershell.AddScript($JobScriptBlock).AddArgument($JobArg) >$null
    $ThisJob = $Powershell.BeginInvoke()

    # Save process invocation for tracking
    $AsyncHandle = @{
        'Process'=$Powershell;
        'Job'=$Thisjob;
        'Arguments'=$JobArg;
    }

    return $AsyncHandle
} # end function Start-Chore


Function Receive-Chore {
<#
    .SYNOPSIS
        Wait and receive Chore
    .DESCRIPTION
        Waits for Chore completion and receives the chore handle
    .PARAMETER AsyncHandle
        Value returned by Start-Chore
    .EXAMPLE
        <`8:Example`>
#>
    [cmdletbinding()]
    Param([Parameter(Mandatory=$true)][HashTable] $AsyncHandle)
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    $done = $AsyncHandle['Job'].AsyncWaitHandle.WaitOne()
    $AsyncHandle['Process'].EndInvoke($AsyncHandle['Job'])
    $Handle = $AsyncHandle['Arguments'][1]

    return $Handle
} # end function Receive-Chore
