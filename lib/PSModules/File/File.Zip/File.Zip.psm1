# Shell Based ZIP/UNZIP

Function Zip-File {
<#
    .SYNOPSIS
        Add files to ZIP
    .DESCRIPTION
        Adds files into a ZIP. Creates ZIP if it doesn't exist.
    .PARAMETER ZIP
        Path to the zip file
    .PARAMETER Paths
        [String[]] List of file paths to add
    .LINK
        Unzip-File
    .EXAMPLE
        Zip-File Foo.Zip bar.png,fizz.txt,fuzz.csv
#>
    [cmdletbinding()]
    param(
        [Parameter(Mandatory=$true)][String]$Zip,
        [Parameter(Mandatory=$true)][String[]]$Paths
        )

    if(-not(test-path -PathType leaf $Zip)) {
        set-content $Zip ("PK" + [char]5 + [char]6 + ("$([char]0)" * 18))
        (dir $Zip).IsReadOnly = $false
    }

    $shell = new-object -com shell.application
    $zipfn = ConvertTo-AbsolutePath($Zip)
    $zipPackage = $shell.NameSpace($zipfn)

    foreach($p in $Paths) {
        $p = ConvertTo-AbsolutePath $p
        $zipPackage.CopyHere($p)
    }
}


Function Unzip-File {
<#
    .SYNOPSIS
        Decompress a zip file
    .DESCRIPTION
        Unzips a file using Windows Shell
    .PARAMETER Path
        Path to the zip file
    .PARAMETER Destination
        Destination directory
    .LINK

    .EXAMPLE
        Unzip-File "Foo.Zip" "C:\tmp"
#>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)][String]$Path,
        [Parameter(Mandatory=$true)][String]$Destination
    )
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    $fn = ConvertTo-AbsolutePath $Path
    $dn = ConvertTo-AbsolutePath $Destination
    if($fn) {
        $shell = New-Object -com Shell.Application
        $zip = $shell.NameSpace($fn)
        foreach($item in $zip.items()) {
            $shell.Namespace($dn).copyhere($item)
            sleep -milliseconds 2000
        }
    }
} # end function Unzip-File




