# Powerup setups environment and provides basic functions

Param([Switch]$NoInteractive)

Set-StrictMode -version Latest

$ErrorActionPreference = 'STOP'

# Aliases
Set-Alias wh Write-Host


# Initialize environment when required
# if(-not(test-path variable:\_PWR) -or -not($GLOBAL:_PWR -is [HashTable])) {
#     $GLOBAL:_PWR=@{}
# }

$GLOBAL:_PWR=@{}

$GLOBAL:_PWR['LOCAL'] = @{}
if($PSVersionTable['Platform'] -eq 'unix') {
    $GLOBAL:_PWR['OSFAMILY'] = 'unix'
    $GLOBAL:_PWR['LOCAL']['editor'] = 'vi'
}
else {
    $GLOBAL:_PWR['OSFAMILY'] = 'windows'
    $GLOBAL:_PWR['LOCAL']['editor'] = 'notepad'
}

$GLOBAL:_PWR.VERSION = ''
$GLOBAL:_PWR.BASEDIR = ''
$GLOBAL:_PWR.STARTDIR = ''
$GLOBAL:_PWR.CREDENTIAL = ''
$GLOBAL:_PWR.BASEDIR_TAGNAME = 'BASEDIR'
$GLOBAL:_PWR.LOCALDIR_TAGNAME = 'LOCALDIR'

$GLOBAL:_PWR.CURRENT_HOSTNAME = [Environment]::MachineName
$GLOBAL:_PWR.POWERUP_FILE = $MyInvocation.MyCommand.Definition
$GLOBAL:_PWR.ERROR_COUNT_LAST = 0
$GLOBAL:_PWR.DIRECTORY_SEPARATOR = [IO.Path]::DirectorySeparatorChar
$GLOBAL:_PWR.POWERUP_BOOTSTRAP_FILE = ("lib{0}Powerup.ps1" -f [IO.Path]::DirectorySeparatorChar)
$GLOBAL:_PWR.VERBOSE_CHORE = $false
$GLOBAL:_PWR.INTERACTIVE=-not($NoInteractive)
if( [IntPtr]::size -eq 8) {
    $GLOBAL:_PWR.PSARCH = '64-bit'
}
else {
    $GLOBAL:_PWR.PSARCH = '32-bit'
}
Try {
    $GLOBAL:_PWR.TIMEZONE_INITIALS = ([Regex]::Replace([System.TimeZoneInfo]::Local.StandardName, '([A-Z])\w+\s*', '$1'))
}
Catch {
    $GLOBAL:_PWR.TIMEZONE_INITIALS = ""
}


# Linux vs Windows

If($GLOBAL:_PWR['OSFAMILY'] -eq 'unix') {
    $GLOBAL:_PWR['CURRENT_USER'] = $(whoami)
    $GLOBAL:_PWR['OSARCH'] = '??'
    $GLOBAL:_PWR['PSMODULEPATH_SEPARATOR'] = ':'
}
else {
    $GLOBAL:_PWR.CURRENT_USER = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    $GLOBAL:_PWR.OSARCH = (Get-WmiObject Win32_OperatingSystem).OSArchitecture
    $GLOBAL:_PWR['PSMODULEPATH_SEPARATOR'] = ';'
}

Function Test-Elevated
{
    <#
    .SYNOPSIS
        Test if running with elevated privileges
    .DESCRIPTION
        Check if running elevated/run as an administrator. No parameters.
    .EXAMPLE
        Test-Elevated
        $True

    #>
    if($GLOBAL:_PWR['OSFAMILY'] -eq 'unix') {
        # if($GLOBAL:_PWR['CURRENT_USER'] -eq 'root') {
        if($(id -u) -eq 0) {
            return $true
        }
        else {
            return $false
        }
    }
    else {
        If (([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
            return $true
        }
        else {
            return $false
        }
    }
}

$GLOBAL:_PWR.ELEVATED = Test-Elevated

Function Dump-Object
{
    <#
    .SYNOPSIS
        Dump object for debugging
    .DESCRIPTION
        Dumps the supplied object with selectable depth
    .PARAMETER Object
        Object to dump
    .PARAMETER Depth
        Depth recursion number, defaults to 1
    .EXAMPLE
        Dump-Object $Foo -Depth 2
    #>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)][Object] $Object,
        [ValidateRange(1,99)][int] $Depth = 1
    )
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    $Object | Select-Object * | Format-Custom * -Depth 2

} # end function Dump-Object

function Resolve-Error {
    <#
    .SYNOPSIS
        Extract information from an Error
    .DESCRIPTION
        Prints detailed information for an error
    .PARAMETER ErrorRecord
        Error code defaults to $error[0]
    .EXAMPLE
        Resolve-Error $error[10]
    #>
    [cmdletbinding()]
    Param(
        $ErrorInfo=$Error[0]
    )
    $hash = [Ordered]@{
      Category     = $ErrorInfo.CategoryInfo.Category
      ErrorReason  = $ErrorInfo.CategoryInfo.Reason
      Target       = $ErrorInfo.CategoryInfo.TargetName
      StackTrace   = $ErrorInfo.Exception.StackTrace
    }
    If(($ErrorInfo|Get-Member|Where {$_.Name -eq 'InvocationInfo'}|Measure-Object).Count -gt 0) {
      $hash['ScriptName']   = $ErrorInfo.InvocationInfo.ScriptName
      $hash['LineNumber']   = $ErrorInfo.InvocationInfo.ScriptLineNumber
      $hash['ColumnNumber'] = $ErrorInfo.InvocationInfo.OffsetInLine
    }
    If(($ErrorInfo|Get-Member|Where {$_.Name -eq 'Exception'}|Measure-Object).Count -gt 0) {
      $hash['ErrorMessage'] = $ErrorInfo.Exception.Message
    }
   # New-Object -TypeName PSObject -Property $hash
   return $hash
   # $ErrorRecord | Format-List * -Force
   # $ErrorRecord.InvocationInfo | Format-List *
   # $Exception = $ErrorRecord.Exception
   # for ($i = 0; $Exception; $i++, ($Exception = $Exception.InnerException))
   # {   "$i" * 80
    #    $Exception |Format-List * -Force
   # }
}

Function Clear-Errors
{
    <#
    .SYNOPSIS
        Reset $Error
    .DESCRIPTION
        Resets $Error and POWERS_ENV['ERROR_COUNT_LAST']
    .EXAMPLE
        Clear-Errors

    #>
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    $Error.Clear()
    $GLOBAL:_PWR.ERROR_COUNT_LAST = 0
} # end function Clear-Errors

# search directories upward until finding one with a tag file
function _find_dir_tag {
    Param($startdir,$tagfn)
    $WorkDir = $startdir
    While($WorkDir -and -not(test-path(join-path $WorkDir $tagfn))) {
        $WorkDir = Split-Path -parent $WorkDir
    }
    if($WorkDir) {
        "$WorkDir"
    }
    else {
        ""
    }
}

Clear-Errors


function _print_motd {
    echo @"

# ----------------------------------
# Welcome to the world of the future
# ----------------------------------
#
# Help resources:
#   help about_Powers
#   help about_Topics
#

"@
}


function _update_console_window {
    $version = $GLOBAL:_PWR.VERSION

    if(Test-Elevated) {
        $title = ("ELEVATED: ({0}) {1}" -f $version,"You got the Power!")
    }
    else {
        $title = ("({0}) {1}" -f $version,"You got the Power!")
    }

    $Shell = $Host.UI.RawUI
    $Shell.WindowTitle = $title
}

Function Invoke-Tests
{
    <#
    .SYNOPSIS
        Run test suite
    .DESCRIPTION
        Run all the Test modules. Clearing existing errors first.
        Returns a hashtable with:
        @{
            "Path" = [String]"Path\to\file\with\errors";
            "Count" = [Int]ErrorCount;
        }
    .EXAMPLE
        Invoke-Tests
    #>
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    Clear-Errors

    $OldErrorAction = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'

    $powers = Search-Power
    foreach($p in $powers){
        if($p -match '^Tests\..*') {
            Import-Power $p -Reload
        }
    }

    # $ErrorSummary = @{}
    # $Basedir = $GLOBAL:_PWR['BASEDIR']

    # $Error | Foreach {
    #     if(($_ | Select -Property InvocationInfo | Measure-Object).Count -gt 0) {

    #         $Path = ($_.InvocationInfo.ScriptName|Out-String)
    #         $Path = $Path -replace [regex]::escape($Basedir), ":B:"

    #         if($ErrorSummary.ContainsKey($Path)) {
    #             $ErrorSummary[$Path] += 1
    #         }
    #         else {
    #             $ErrorSummary[$Path] = 1
    #         }
    #     }
    # }

    $ErrorActionPreference = $OldErrorAction

    # return $ErrorSummary
} # end function Invoke-Tests


Function jp {
<#
    .SYNOPSIS
        Join paths
    .DESCRIPTION
        Join paths
    .PARAMETER Paths
        String array
    .LINK

    .EXAMPLE

#>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)][String[]]$Paths
    )
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    return ($Paths -join $GLOBAL:_PWR['DIRECTORY_SEPARATOR'])

} # end function jp


# initialize LOCALDIR, BASEDIR and related paths
function _init_directories {
    Param($START=[String](Get-Location))

    $GLOBAL:_PWR.STARTDIR = $START
    $GLOBAL:_PWR.BASEDIR = _find_dir_tag (Split-Path -parent $GLOBAL:_PWR.POWERUP_FILE) $GLOBAL:_PWR.BASEDIR_TAGNAME
    $GLOBAL:_PWR.LOCALDIR = _find_dir_tag $GLOBAL:_PWR.STARTDIR $GLOBAL:_PWR.LOCALDIR_TAGNAME
    if($GLOBAL:_PWR.LOCALDIR) {
        $GLOBAL:_PWR.DEFAULTDIR = $GLOBAL:_PWR.LOCALDIR
        $GLOBAL:_PWR.ENABLE_LOCALDIR = $true
    }
    else {
        $GLOBAL:_PWR.DEFAULTDIR = $GLOBAL:_PWR.BASEDIR
        $GLOBAL:_PWR.LOCALDIR = ""
        $GLOBAL:_PWR.ENABLE_LOCALDIR = $false
        # $GLOBAL:_PWR.LOCALDIR = Join-Path $GLOBAL:_PWR.BASEDIR 'local'
    }

    $GLOBAL:_PWR.PSMODULES_DIR = join-path $GLOBAL:_PWR.BASEDIR (Join-Path 'lib' 'PSModules')
    $GLOBAL:_PWR.PACKAGEDIR = join-path $GLOBAL:_PWR.DEFAULTDIR 'package'
    $GLOBAL:_PWR.PSASSEMBLIES_DIR = join-path $GLOBAL:_PWR.DEFAULTDIR (Join-Path 'lib' 'PSAssemblies')
    $GLOBAL:_PWR.ICONDIR = join-path $GLOBAL:_PWR.BASEDIR (Join-Path 'share' 'icons')
    $GLOBAL:_PWR.TEMPLATEDIR = join-path $GLOBAL:_PWR.BASEDIR (Join-Path 'share' 'templates')
    $GLOBAL:_PWR.EXCELDIR = join-path $GLOBAL:_PWR.BASEDIR (Join-Path 'share' 'excel')
    # $GLOBAL:_PWR.REDISTDIR = join-path $GLOBAL:_PWR.BASEDIR (Join-Path 'share' 'redist')
    $GLOBAL:_PWR.SAMPLEDIR = join-path $GLOBAL:_PWR.BASEDIR (Join-Path 'share' 'samples')
    $GLOBAL:_PWR.LOGDIR = join-path $GLOBAL:_PWR.DEFAULTDIR 'log'
    $GLOBAL:_PWR.TMPDIR = join-path $GLOBAL:_PWR.DEFAULTDIR 'tmp'
    $GLOBAL:_PWR.STORAGEDIR = Join-Path $GLOBAL:_PWR.DEFAULTDIR 'storage'
    # $GLOBAL:_PWR.REPORTDIR = join-path $GLOBAL:_PWR.DEFAULTDIR 'report'
    $GLOBAL:_PWR.RUNDIR = join-path $GLOBAL:_PWR.TMPDIR 'run'
    $GLOBAL:_PWR.VERSION = (Get-Content (Join-Path $GLOBAL:_PWR.BASEDIR 'BASEDIR') -TotalCount 1).Split()[0]

    # create some directories
    if(-not(Test-Path -PathType container $GLOBAL:_PWR['TMPDIR'])) {
        New-Item -f -type d $GLOBAL:_PWR['TMPDIR'] >$null
    }
    # if(-not(Test-Path -PathType container $GLOBAL:_PWR['TMPDIR')) {
    #     New-Item -f -type d $GLOBAL:_PWR['LOGDIR'] >$null
    # }
    # if(-not(Test-Path -PathType container $GLOBAL:_PWR['TMPDIR')) {
    #     New-Item -f -type d $GLOBAL:_PWR['RUNDIR']>$null
    # }
    if(-not(Test-Path -PathType container $GLOBAL:_PWR['STORAGEDIR'])) {
        New-Item -f -type d $GLOBAL:_PWR['STORAGEDIR'] >$null
    }

    if(-not(Test-Path $GLOBAL:_PWR['PSMODULES_DIR'] -PathType container)) { New-Item -Type d $GLOBAL:_PWR['PSMODULES_DIR'] | Out-Null }
    if(-not(Test-Path $GLOBAL:_PWR['PSASSEMBLIES_DIR'] -PathType container)) { New-Item -Type d $GLOBAL:_PWR['PSASSEMBLIES_DIR'] | Out-Null }
}

_init_directories

# Bootstap Modules
Import-Module -DisableNameChecking -Name (Join-Path $GLOBAL:_PWR['PSMODULES_DIR'] 'Core\Core.Powers\Core.Powers.psd1')
Import-Power 'Core.Config' -Reload
Import-Power 'Core.ErrorReport' -Reload
Import-Power 'Core.PackageManager' -Reload
Import-Power 'Path' -Reload

# update config and path
Core.Config\Update-Local
Core.Config\Update-Defaults

Function Set-Localdir
{
    <#
    .SYNOPSIS
        Rebases Localdir
    .DESCRIPTION
        Sets a new path as localdir, this is only active in the current session.
    .PARAMETER Path
        Directory for the new localdir
    .EXAMPLE
        New-Localdir C:\Foo\Bar
    #>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)][String] $Path
    )
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    $Path = ConvertTo-AbsolutePath $Path
    If(-not(Test-Path -PathType Container $Path)) {
        Throw "[Set-Localdir] Directory not found: $Path"
    }

    _init_directories $Path
} # end function Set-Localdir


Function Install-LocalDir
{
    <#
    .SYNOPSIS
        Create a Localdir
    .DESCRIPTION
        Creates or updates a Localdir to store customizations and configs
    .PARAMETER Path
        Path to Localdir
    .EXAMPLE
        Install-LocalDir $HOME\powers
    #>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)][String] $Path
    )
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    If(-not(Test-Path $Path)) {
        New-Item -type d -force $Path >$null
    }

    If(-not(Test-Path $Path -PathType Container)) {
        Throw "[Install-Localdir] Can't create directory: $Path"
    }

    If(-not(Test-Path -PathType container (Join-Path $Path 'config'))) {
        New-Item -type d -force (Join-Path $Path 'config') >$null
    }

    If(-not(Test-Path -PathType container (Join-Path $Path (jp 'config' 'secure')))) {
        New-Item -type d -force (Join-Path $Path (jp 'config' 'secure')) >$null
        cipher.exe /e (Join-Path $Path (jp 'config' 'secure'))
    }

    $lconfigdir = New-Item -type d -force (Join-Path $Path 'config')


    If(-not(Test-Path -PathType container (Join-Path $Path 'inventory'))) {
        New-Item -type d -force (Join-Path $Path 'inventory') >$null
    }
    If(-not(Test-Path -PathType container (Join-Path $Path 'tmp'))) {
        New-Item -type d -force (Join-Path $Path 'tmp')  >$null
    }
    If(-not(Test-Path -PathType container (Join-Path $Path 'invoke'))) {
        New-Item -type d -force (Join-Path $Path 'invoke')  >$null
    }
    If(-not(Test-Path -PathType container (Join-Path $Path 'storage'))) {
        New-Item -type d -force (Join-Path $Path 'storage')  >$null
    }
    If(-not(Test-Path -PathType container (Join-Path $Path 'lib'))) {
        New-Item -type d -force (Join-Path $Path 'lib')  >$null
    }
    If(-not(Test-Path -PathType container (Join-Path $Path (jp 'lib','PSModules')))) {
        New-Item -type d -force (Join-Path $Path (jp 'lib','PSModules'))  >$null
    }
    If(-not(Test-Path -PathType container (Join-Path $Path (jp 'lib','PSAssemblies')))) {
        New-Item -type d -force (Join-Path $Path (jp 'lib','PSAssemblies'))  >$null
    }

    function copyrename {
        param($source,$dest)
        if(Test-Path $dest) {
            If((Compare-Object (Get-Content $source) (Get-Content $dest)| Measure-Object).Count -gt 0) {
                $dest = $dest + '.new'
                "Installing new version on: $dest"
                Copy-Item -Force $source $dest
                }
        }
        else {
            Copy-Item $source $dest
        }
    }

    $basedir = $GLOBAL:_PWR['BASEDIR']
    $configdir = Join-Path $basedir 'config'
    $exampledir = (Join-Path (Join-Path $basedir 'share') 'examples')

    copyrename (Join-Path $exampledir 'launcher.cmd') (Join-Path $Path 'launcher.cmd')
    copyrename (Join-Path $exampledir 'schedule.cmd') (Join-Path $Path 'schedule.cmd')

    $ltagfile = New-Item -Type F -Force (Join-Path $Path $GLOBAL:_PWR['LOCALDIR_TAGNAME'])
    Set-Content $ltagfile ($GLOBAL:_PWR['BASEDIR']|Out-String)
    _init_directories $Path

    Write-Host -ForegroundColor Cyan "Please setup your local config"
    Edit-Config 'local'
    Write-Host "To edit this file again: Edit-Config local"

    Import-Power 'Inventory'

    $local = Get-Config 'local'
    $products = $local['products']
    Foreach($p in $products['database']) {
        $fn = jp $Path,'inventory',("instance_{0}.csv" -f $p)
        If(-not(Test-Path -PathType leaf $fn)) {
            Write-Host "Create file: $fn"
            $new = New-Table_IService
            $new.Rows.Add() >$null
            $new | Export-CSV -NoTypeInformation $fn
        }
    }

    Write-Host "If you plan to use email: 'defaults.smtp' and 'defaults.address'"
    Write-Host "For using a http proxy: 'defaults.proxy'"
    Write-Host "To configure package repository location: 'defaults.package'"
} # end function Install-LocalDir


If(-not($NoInteractive)) {

    _update_console_window
    _print_motd

    function prompt {

        $ps1 = ""
        $ps1 += $GLOBAL:_PWR['LOCAL']['project']['id']
        $here = (Get-Location).Path
        if($here -eq $GLOBAL:_PWR['BASEDIR']) {
            $ps1 += ":B:"
        }
        elseif($here -eq $GLOBAL:_PWR['LOCALDIR']) {
            $ps1 += ":L:"
        }
        $ps1 += ("[{0} {1}]" -f (Get-Date -uformat "%H:%M"),$GLOBAL:_PWR['TIMEZONE_INITIALS'])

        $ErrorCounter = ($Error|Measure-Object).Count
        if($GLOBAL:_PWR['ERROR_COUNT_LAST'] -lt $ErrorCounter) {
            $GLOBAL:_PWR['ERROR_COUNT_LAST'] = $ErrorCounter
            $ps1 += "E$ErrorCounter"
        }
        else {
            $ps1 += "E" + [char]0x263a
        }

        $ps1 += "> "
        return $ps1
    }

    # Set-ItemProperty -Path 'HKCU:\Console' -Name FontFamily -Value 72
    # Set-ItemProperty -Path 'HKCU:\Console' -Name QuickEdit -Value 1
    # Set-ItemProperty -Path 'HKCU:\Console' -Name HistoryBufferSize -Value 1000
    # Set-ItemProperty -Path 'HKCU:\Console' -Name HistoryNoDup -Value 1
}


# vim: ft=ps1
