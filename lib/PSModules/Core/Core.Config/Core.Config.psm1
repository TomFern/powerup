# Config parser

Set-StrictMode -version Latest

Import-Power 'Temp'

function _update_path {
    if($GLOBAL:_PWR['LOCAL'].ContainsKey('paths')) {
        $path_array_add = $GLOBAL:_PWR['LOCAL']['paths']
        foreach($p in $path_array_add) {
            $env:Path += ";$p"
        }
        $path_index = @{}
        $path_pieces = @()
        foreach($p in ($env:Path -split ';')) {
            if($p.Length -and (-not ($path_index.ContainsKey($p)))) {
                $path_index[$p] = $true
                $path_pieces += $p
            }
        }
        $env:Path = $path_pieces -join ";"
    }
}

function Get-Config {
<#
.SYNOPSIS
    Read a config

.DESCRIPTION
    Search and parses a config file the config dirs.

    Config files are really powershell files with the .cfg extension. Each file must define
    one and only one Hashtable structure.

    Same namespace rules for Import-Power apply here.

    Returns HashTable.

.PARAMETER Name
    Name of the config to read, 'cfg' extension is appended automatically
.EXAMPLE
    # Reads mail.cfg
    $conf = Get-Config 'mail'

    # Reads bundle\bundle.paths.cfg
    $conf = Get-Config 'bundle.paths'

.LINK
    Search-Config
    about_Modules
    Import-Power
#>

Param(
    [Parameter(Mandatory=$true)][string] $name
    )

    $filefn,$path = ConvertTo-CannonicalName $name
    $filefn = $filefn + '.cfg'

    $config = @{}

    $found = 0
    Foreach($dir in (Get-PowerupPaths)) {
        $try = Join-Path $dir 'config'
        $try = join-path $try $path
        $try = join-path $try $filefn
        if(test-path -pathtype leaf $try) {
            $content = (Get-Content $try | Out-String)
            Try {
                $config = [HashTable](Invoke-Expression -Command $content)
            }
            Catch {
                Write-Warning ("Config Error {0}: {1}" -f $name,$_.Exception.Message)
            }
            if(($config|Measure-Object).Count -gt 0) {
                $found += 1
                break
            }
        }
    }

    if($found -eq 0) {
        Throw "[Get-Config] No valid config was found for: $name"
    }
    else {
        return $config
    }
}
Set-Alias ec Edit-Config

Function Search-Config
{
    <#
    .SYNOPSIS
        List available configs
    .DESCRIPTION
        Returns a DataTable with configs names and paths

    .PARAMETER Pattern
        (optional) Show only matching configs (regex)
    .EXAMPLE
        # Get all available
        $configs = Search-Configs

        # Get only chores
        $configs = Search-Configs 'chores'

    .LINK
        Get-Config

    #>
    [cmdletbinding()]
    Param(
        [String]$Pattern='.+'
    )
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    $ConfigTable = New-Object System.Data.Datatable 'Search-Config'
    [void]$ConfigTable.Columns.Add('Name',[String])
    [void]$ConfigTable.Columns.Add('RelativePath',[String])
    [void]$ConfigTable.Columns.Add('RelativeTo',[String])
    # [void]$ConfigTable.Columns.Add('FullPath',[String])

    $sep = $GLOBAL:_PWR.DIRECTORY_SEPARATOR

    foreach($absolute in (Get-PowerupPaths)) {
    # Get-PowerupPaths | Foreach {
        # $absolute = $path
        $path = Join-Path $absolute 'config'

        if(test-path $path) {
            foreach($dir in (get-childitem -Path $path -Recurse -Filter "*.cfg")) {
                # | Foreach {

                $CName = $dir.basename
                $CFn = $dir.fullname

                If($CName -match $Pattern) {
                    If(($ConfigTable.Select("Name = '$CName'")|Measure-Object).Count -eq 0) {
                        $row = $ConfigTable.NewRow()
                        $row['Name'] = $CName
                        # $row.FullPath = $CFn

                        If($absolute -eq $Global:_PWR['LOCALDIR']) {
                            $row['RelativeTo'] = $GLOBAL:_PWR.LOCALDIR_TAGNAME
                            $remove = $Global:_PWR.LOCALDIR + $sep
                            $row['RelativePath'] = ($CFn -replace [Regex]::Escape($remove),"")
                            $row['RelativePath'] = ($row['RelativePath'] -replace [Regex]::Escape($sep + $CName + '.cfg'))
                        }
                        If($absolute -eq $Global:_PWR['BASEDIR']) {
                            $row['RelativeTo'] = $GLOBAL:_PWR.BASEDIR_TAGNAME
                            $remove = $Global:_PWR.BASEDIR + $sep
                            $row['RelativePath'] = ($CFn -replace [Regex]::Escape($remove),"")
                            $row['RelativePath'] = ($row['RelativePath'] -replace [Regex]::Escape($sep + $CName + '.cfg'))
                        }
                        $ConfigTable.Rows.Add($row)
                    }
                }
            }
        }
    }

    return ,$ConfigTable
} # end function Search-Config


Function Reset-Config {
<#
    .SYNOPSIS
        Remove Local Config
    .DESCRIPTION
        Removes Local Config file if exists.
        If no config found throws, if file is already on BASEDIR writes a warning.
    .PARAMETER Name
        Config Name
    .EXAMPLE
        Reset-Config smtp
#>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)][String]$Name
    )
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    If(!$Global:_PWR.LOCALDIR) {
        Throw "[Reset-Config] LOCALDIR not set. You must run Install-Localdir and check initialization"
    }

    $ConfigTable = Search-Config ('^{0}$' -f $Name)
    If(($ConfigTable|Measure-Object).Count -gt 0) {
        $CNAme = $ConfigTable.Rows[0].Name
        $RelativeTo = $ConfigTable.Rows[0].RelativeTo
        $RelativePath = $ConfigTable.Rows[0].RelativePath
        If($RelativeTo -eq 'LOCALDIR') {
            $CFn= $Global:_PWR.LOCALDIR
            $CFn = Join-Path $CFn $RelativePath
            $CFn = Join-Path $CFn ('{0}.cfg' -f $CName)
            If(Test-Path -PathType Leaf $CFn) {
                "Delete: $CFn"
                Remove-Item -Force $CFn
            }
        }
        else {
            Write-Warning "[Reset-Config] $CName already in BASEDIR. Nothing done."
        }
    }
    else {
        Throw "[Reset-Config] Config '$Name' not found"
    }
} # end function Reset-Config


Function Edit-Config {
<#
    .SYNOPSIS
        Edit a config
    .DESCRIPTION
        Edits an existing config and installs it on LOCALDIR.
        This won't work to create new configs.
    .PARAMETER Name
        Name of the config
    .EXAMPLE
        Edit-Config smtp
#>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)][String]$Name
    )
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    If(-not($Global:_PWR.ENABLE_LOCALDIR)) {
        Throw "[Edit-Config] LOCALDIR not set. You must run Install-Localdir and check initialization"
    }

    If(-not($GLOBAL:_PWR.INTERACTIVE)) {
        Throw "This script should be run in an interactive console"
    }

    $ConfigTable = Search-Config ('^{0}$' -f $Name)
    If(($ConfigTable|Measure-Object).Count -gt 0) {

        $CNAme = $ConfigTable.Rows[0].Name
        write-host $CNAME

        # Paths
        $RelativeTo = $ConfigTable.Rows[0].RelativeTo
        $RelativePath = $ConfigTable.Rows[0].RelativePath
        $FullDir = ""
        $SaveDir = ""
        $SavePath = ""
        If($RelativeTo -eq 'BASEDIR') {
            $FullDir = Join-Path $Global:_PWR.BASEDIR $RelativePath
        }
        ElseIf($RelativeTo -eq 'LOCALDIR') {
            $FullDir = Join-Path $Global:_PWR.LOCALDIR $RelativePath
        }
        $FullPath = ("{0}.cfg" -f (jp $Fulldir,$Cname)) #("{0}\{1}.cfg" -f $FullDir,$CName)
        $SaveDir = (jp $GLOBAL:_PWR.LOCALDIR, $RelativePath)
        $SavePath = ("{0}.cfg" -f (jp $SaveDir,$CName))

        # Temp file edit
        $temp = New-TempFile
        Copy-Item $FullPath $temp
        Invoke-Expression ("{0} {1}" -f $GLOBAL:_PWR['LOCAL']['editor'],$temp)

        # Edit, Parse, Validate, Install
        $valid = $false
        $config = @{}
        While(!$valid) {
            Write-Host -nonewline "Press any key to continue, CTRL-C to cancel"
            $response = read-host
            $valid = $true
            Try {
                $content = (Get-Content $temp | Out-String)
                $config = [HashTable](Invoke-Expression $content)
            }
            Catch {
                $valid = $false
                Write-Warning ("[Edit-Config] Syntax error or the file is empty: {0}" -f $_.Exception.Message)
            }
            If(($config.Keys|Measure-Object).Count -eq 0) {
                Write-Warning "[Edit-Config] No valid config"
                $valid = $false
            }
        }
        Write-Host "Saving $SaveDir"
        New-Item -Force -Type d $SaveDir >$null
        Copy-Item -Force $temp $SavePath
        Remove-Item -Force $temp
        Write-Host "Update defaults"
        Update-Defaults
        Update-Local
    }
    else {
        Throw "[Edit-Config] No config file found for '$Name'"
    }

} # end function Edit-Config


function Test-Config {
<#
.SYNOPSIS
    Tests all configs

.DESCRIPTION
    Reads and parses all configs to find syntax errors.

    Writes Warnings on errors. Returns false if any errors are found.

.EXAMPLE
    If(Test-Config) {
        "ALL GOOD"
    }

.LINK
    Search-Config
    about_Modules
    Import-Power
#>

    $Configs = Search-Config

    $valid = $true
    Foreach($cfg in $Configs.Rows) {
    # $Configs.Rows | Foreach {
        $Name = $Cfg.Name
        # write-host $name
        Try {
            Get-Config $Name >$null
        }
        Catch {
            $valid = $false
            Write-Warning ("{0}: {1}" -f $Name,$_.Exception.Message)
        }
    }
    return $valid
}


Function Update-Defaults {
<#
    .SYNOPSIS
        Read defaults
    .DESCRIPTION
        Loads default configs into session
    .LINK

    .EXAMPLE
        Update-Defaults
#>
    $table = Search-Config 'defaults\.+'
    $defaults = @{}
    Foreach($r in $table.Rows) {
        Try {
            $cfg = Get-Config $r['Name']
            $defaults += $cfg
        }
        Catch {
            Write-Warning ("[Update-Defaults] Exception reading config {0}: {1}" -f $r['Name'],$_.Exception.Message)
        }
    }

    $GLOBAL:_PWR['DEFAULTS'] = $defaults
    _update_path
} # end function Update-Defaults

Function Update-Local {
<#
    .SYNOPSIS
        Read local config
    .DESCRIPTION
        Loads local config into session
    .LINK

    .EXAMPLE
        Update-Defaults
#>
    $cfg = @{}
    Try {
        $cfg = Get-Config 'local'
    }
    Catch {
        return
    }

    $GLOBAL:_PWR['LOCAL'] = $cfg
    _update_path
} # end function Update-Local

Export-ModuleMember -Function * -Alias *
