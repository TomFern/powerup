# Module Manager

Function ConvertTo-CannonicalName
{
    <#
    .SYNOPSIS
        Convert a String into Cannonical Powerup Names
    .DESCRIPTION
        Returns Cannonical Name for an input string following Powerup name convention for
        Powers (Modules) names and Config names.

        Returns an Array such as @(FULLNAME,PATH)
    .PARAMETER Name
        The input name, eg. A.B.C
    .EXAMPLE
        ConvertTo-CannonicalName 'A.B.C'
        A.B.C
        A\B
        # So full path is A\B\A.B.C
    #>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)][String]$Name
    )
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    $parts = ($name -split '\.')
    $module_path = $null
    if($parts.Length -gt 1) {
        $module_path = ($parts[0..($parts.Length-2)] -join '\')
    }
    return @($name,$module_path)
} # end function ConvertTo-CannonicalName


Function Rebase-Powerup {
<#
    .SYNOPSIS
        Changes location of Powerup's BASEDIR and loads new version
    .DESCRIPTION
        Switches to another Powerup version. Updates localdir.
    .PARAMETER Path
        Path to Powerup installation directory
    .LINK
        Install-Localdir
        Rebase-Powerup
    .EXAMPLE
        Rebase-Powerup C:\Powerup
#>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)][String]$Path
    )

    If(-not(Test-Path -PathType container $Path)) {
        Throw "[Rebase-Powerup] Directory not found: $Path"
    }

    $BootStrapfile = (Join-Path $Path $GLOBAL:_PWR.POWERUP_BOOTSTRAP_FILE)

    If(-not(Test-Path -PathType Leaf $BootStrapfile)) {
        Throw ("[Rebase-Powerup] File not found {0}" -f $GLOBAL:_PWR.POWERUP_BOOTSTRAP_FILE)
    }

    If($GLOBAL:_PWR.ENABLE_LOCALDIR) {
      Set-Content (Join-Path $GLOBAL:_PWR.LOCALDIR $GLOBAL:_PWR.LOCALDIR_TAGNAME) $Path
    }

    Remove-Power *

    . $BootStrapfile
}


function Search-Power {
<#
.SYNOPSIS
    List installed modules
.DESCRIPTION
    List existing modules
.PARAMETER Name
    (optional) Search for exact Power
.EXAMPLE
    Search-Power
.LINK
    about_Modules
    Import-Power
#>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$false)][String]$Name
    )


    # update env:PSModulePath with Powerup libs
    $dirs = ($env:PSModulePath -split $GLOBAL:_PWR['PSMODULEPATH_SEPARATOR'])
    Get-PowerupPaths | Foreach {
        $moddir = (Join-Path $_ (jp 'lib','PSModules') | Out-String).Trim()
        If(-not($dirs -contains $moddir)) {
            $dirs += $moddir + $GLOBAL:_PWR['PSMODULEPATH_SEPARATOR']
        }
    }
    $env:PSModulePath = (($dirs -join $GLOBAL:_PWR['PSMODULEPATH_SEPARATOR']) | Out-String).Trim()

    $table = Get-Module -ListAvailable
    If(($Table|Measure-Object).Count -eq 0) {
        Throw "[Search-Power] Ooops. No powers available. Something went wrong!"
    }

    If($Name) {
        return ($table | Where { $_.Name -eq $Name })
    }
    else {
        return $table
    }
}

Function Get-PowerupPaths
{
    <#
    .SYNOPSIS
        Returns Search paths for this session
    .DESCRIPTION
        Get the paths for searching based on current session environment

        Returns array such as: @( LOCALDIR, BASEDIR )
    .EXAMPLE

    #>
    # [cmdletbinding()]
    # Param(
    #     [Parameter(Mandatory=$true)][type] name1,
    #     [type] name2 = default
    # )
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    if($GLOBAL:_PWR.ENABLE_LOCALDIR) {
        return @($GLOBAL:_PWR['LOCALDIR'],$GLOBAL:_PWR['BASEDIR'])
    }
    return @($GLOBAL:_PWR['BASEDIR'])
} # end function Get-PowerupPaths

function Import-Power {
<#
.SYNOPSIS
    Import Powershell Modules
.DESCRIPTION

    Works like Perl's "use" clause, but using Powershell Import-Module

    (In fact, this function is aliased to Use, so you may type that instead)

    Temporarily changes $env:PSModulePath to search in directories
    local\lib\psmod\$path and lib\psmod\$path. The first file found is loaded.
    If no module is found an exception is thrown

    The Path part is optional.

    When, Importing a loaded module, it removes and loads it again.

    For further information on how this program use modules read the provided documentation.

.PARAMETER Name
    The module name to import. Name is mapped to module as:
        - "." is replaced with directory separator "\" and used as Path
.PARAMETER Prefix
    Import the module using -Prefix. eg. Get-Process -> Get-MyProcess
.PARAMETER ArgumentList
.PARAMETER Reload
    [Switch] When set, force reload the module to memory.
.EXAMPLE

    # Load MyMod\MyMod.psm1
    Import-Power 'MyMod'

    # load Bundle\Bundle.MyMod\Bundle.MyMod.psm1
    Import-Power 'Bundle.MyMod'

.LINKS
    about_Modules
    Search-Power
    Remove-Power

#>
Param(
    [Parameter(Mandatory=$true)][string] $name,
    [String]$Prefix="",
    [Object]$ArgumentList=@(),
    [Switch]$Reload
    )

    If($Name -eq 'Core.Powers') {
        Throw "[Import-Power] Import-Power cannot be used with module Core.Powers"
    }

    If($Reload) {
        If((Get-Module | Where { $_.Name -eq $Name } | Measure-Object).Count -gt 0) {
            Remove-Module $Name | Out-Null
        }
    }

    $FullName,$Path = ConvertTo-CannonicalName $Name
    If($Path) {
        $FullName = Join-Path $Path $FullName
    }


    If(-not(Search-Power $Name)) {
        Throw "[Import-Power] Power not found: $Name"
        # Import-Power 'Core.Redist'
        # If(Test-Redist $Name) {
        #     Install-Redist $Name -Type 'module'
        # }
    }

    # FIXME
    If(Search-Power $Name) {
        If(($Prefix|Measure-Object).Count -gt 0) {
            Import-Module -Global $FullName -Prefix $Prefix -DisableNameChecking -ArgumentList $ArgumentList
        }
        else {
            Import-Module -Global $FullName -DisableNameChecking -ArgumentList $ArgumentList
        }
    }
    else {
        Throw "[Import-Power] Power not found: $Name"
    }
}

Function Reload-Power
{
    <#
    .SYNOPSIS
        Call Import-Power -Reload
    .DESCRIPTION
        A proxy function that calls Import-Power -Reload
    .PARAMETER Name
        Module Name to reload
    .EXAMPLE


    #>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)][String] $Name,
        [Object]$ArgumentList=@()
    )
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    Import-Power -Reload $Name -ArgumentList $ArgumentList
} # end function Reload-Power

Set-Alias Use Reload-Power


function Remove-Power {
<#
.SYNOPSIS
    Unload powershell modules

.DESCRIPTION
    Works like Perl's 'no' clause, but using PowerShell Remove-Module.
    If module is not loaded, nothing happens.

    This function is aliased to NoUse

.PARAMETER name
    The module name to import. Use * to remove all possible modules.

.EXAMPLE
    # Remove MyMod\MyMod.psm1
    Remove-Power 'MyMod'

    # Unload Bundle\MyMod\MyMod.psm1
    Remove-Power 'Bundle.MyMod'

.LINK
    about_Modules
    Import-Power
#>
Param(
    [Parameter(Mandatory=$true)][string] $name
    )

    # removing this module crashes powershell
    If($Name -eq 'Core.Powers') {
        Throw "[Remove-Power] Remove-Power cannot be used with module Core.Powers"
    }

    If($Name -eq '*') {
        # Remove all but core modules
        foreach($module in (Get-Module)) {
            if(-not($Module.Name -match '^Core\.')) {
                Remove-Module $module.name >$null
            }
        }
    }
    elseIf((Get-Module | Where { $_.Name -eq $Name } | Measure-Object).Count -gt 0) {
        Remove-Module $Name >$null
    }
}
Set-Alias NoUse Remove-Power



Function Import-Assembly
{
    <#
    .SYNOPSIS
        Load an assembly
    .DESCRIPTION
        Imports an assembly into memory.

        When using a Name this looks for a matching folder on PSASSEMBLIES_DIR
        When using PartialName it tries to use the system path.
        When using both it tries first PartialName and then Name

        Throws an exception if nothing is loaded.

    .PARAMETER Name
        Name of the assembly (eg. MSCharts)
    .PARAMETER PartialName
        (optional) Partial Name of the assembly (eg. System.Windows.Forms.DataVisualization)
    .EXAMPLE
        # Load from LOCALDIR
        Import-Assembly -Name 'MSCharts'

        # Same but try system path first
        Import-Assembly -Name 'MSCharts' -PartialName 'System.Windows.Forms.DataVisualization'
    #>
    [cmdletbinding()]
    Param(
        [String]$Name="",
        [String]$PartialName=""
    )
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    $isloaded = $false
    If($PartialName) {
        Try {
            if([Reflection.Assembly]::LoadWithPartialName($PartialName)) {
                $isloaded = $true
            }
        }
        Catch {
            Write-Warning ("[Import-Assembly] Error importing assembly: {0}. Error: {1}" -f $PartialName,$_.Exception.Message)
        }
        if(-not($isloaded)) {
            Write-Warning ("[Import-Assembly] Assembly not found installed in system: {0}" -f $PartialName)
        }
    }
    If(-not($isloaded)) {
        If($name.length -eq 0) {
            Throw ("[Import-Assembly] PartialName failed to load and -Name was not supplied")
        }
        $path = Join-Path $GLOBAL:_PWR.PSASSEMBLIES_DIR $Name
        If(test-path -PathType Container $Path) {
            Get-ChildItem -Recurse -Filter "*.dll" $path | Foreach {
                Add-Type -Path $_.fullname
            }
            $isloaded = $true
        }
    }

    If(-not($isloaded)) {
        Throw ("[Import-Assembly] Assembly not loaded: {0} {1}" -f $Name,$PartialName)
    }
}

Export-ModuleMember -Alias * -Function * -Cmdlet *
