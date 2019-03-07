# Path utilities

Function Join-Path2 {
    <#
    .SYNOPSIS
        Join-Path for n paths
    .DESCRIPTION
        Join all paths from an Array
    .PARAMETER paths
        Array containing paths to join, must have at least 2 paths
    .EXAMPLE
        Join-Path2 @('a','b','c','d')
        a\b\c\d
    #>
    [cmdletbinding()]
    Param([Parameter(Mandatory=$true)][String[]] $Paths)

    $Clean = $Paths | Where { $_ } | Foreach { $_.trim() }
    return ($Clean -Join '\')
}

Function ConvertTo-AbsolutePath
{
    <#
    .SYNOPSIS
        Convert to Absolute Path
    .DESCRIPTION
        Convert/Normalize Local Relative Path to Absolute Path
    .PARAMETER path
        Local Path
    .EXAMPLE
        ConvertTo-AbsolutePath ..\libs\file
        C:\Program Files\dba\libs\file
    #>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)] $path
    )
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    if([System.IO.Path]::IsPathRooted($path)) {
        return $path
    }
    else {
        return [System.Io.Path]::GetFullPath((Join-Path (pwd) $path))
    }
}

Function ConvertTo-RemotePath
{
    <#
    .SYNOPSIS
        Returns the remote UNC path
    .DESCRIPTION
        Returns a FileInfo object with the remote path
    .PARAMETER path
        The path to convert
    .PARAMETER computer
        The remote computer, defaults to localhost
    .EXAMPLE
        $mypath = ConvertTo-RemotePath -path C:\Path\To\Dir -computer MYSERVER1
        $mypath.fullname
        \\MYSERVER1\C$\Path\To\Dir
    #>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)] $path,
        [string] $computer=$null
    )
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    if(-not($computer)) { $computer = hostname }

    $p = $path
    $p = ($p -replace ':','$')
    $p = ("\\{0}\{1}" -f $computer,$p)
    $r = ([System.IO.FileInfo]$p)
    return $r
} # end function Get-RemotePath

Function ConvertTo-LocalPath
{
    <#
    .SYNOPSIS
        Get local path from a remote path
    .DESCRIPTION
        Returns the local path from a remote UNC
    .PARAMETER path
        The remote path to convert to local
    .EXAMPLE
        ConvertTo-LocalPath '\\MYSERVEr1\C$\Path\To\Dir"
        # Gets: C:\Path\To\Dir
        
    #>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)] $path
    )
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'
   
    if($path -is [Object]) {
        if([bool]($path.psobject.Properties | where { $_.Name -eq "FullName"})) {
            $path = $path.fullname
        }
    }

    $p = $path
    $p = $p.Replace('$',':')
    $p = $p.Replace('\\','')
    $l = $p.IndexOf('\')
    $p = $p.SubString($l+1,($p.Length-$l-1))
    $r = ([System.IO.FileInfo]$p)
    return $r
} # end function ConvertTo-LocalPath
