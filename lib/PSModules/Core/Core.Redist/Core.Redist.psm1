# Redistributable Installer

Import-Power 'Path'
Import-Power 'Temp'

Function Test-Redist
{
    <#
    .SYNOPSIS
        Test if redist archive exist for unpacking
    .DESCRIPTION
        Test if the redist zip file is found
    .PARAMETER Name
        Module name
    .PARAMETER Type
        Type can be 'module' or 'assembly'. Default is module.
    .EXAMPLE
        Test-Redist -Name 'Foo' -Type 'module'.
        
    #>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)][String] $Name,
        [ValidateSet('module','assembly')][String] $Type = 'module'
    )
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'
    
    $ArchiveDir = Join-Path $GLOBAL:_PWR['REDISTDIR'] 'lib\PSModules'
    If($Type -eq 'assembly') {
        $ArchiveDir = Join-Path $GLOBAL:_PWR['REDISTDIR'] 'lib\PSAssemblies'
    }

    $zipfn = Join-Path $ArchiveDir ($Name+'.zip')
    If(Test-Path -PathType Leaf $zipfn) {
        return $true
    }
    else {
        return $false
    }
} # end function Test-Redist

Function Install-Redist
{
    <#
    .SYNOPSIS
        Unpacks a Redist Module/Assembly
    .DESCRIPTION
        Unzips and installs redist archive in the correct Powerup subdirectory.

        CAVEATS:

            - Install-Redist can only install modules/assemblies on PSMODULES_DIR/PSASSEMBLIES_DIR directory,
              installing on deeper directories (eg. Foo.Bar -> Foo\Foo.Bar) is not supported. This is not normally an issue
              because the dot naming scheme is used in Powerup only, not on 3rd party redist modules.

            - The source zip file must have all it's relevant files on a subdir inside the archive.

    .PARAMETER Name
        Name of the redist module
    .PARAMETER Type
        Type can be: 'module', 'assembly'. Default is 'module'
    .PARAMETER Index
        Subdir index inside the zip file. Defaults to 0 (first subdir)
    .EXAMPLE
        Install-Redist -Name 'Foo' -Type 'module' -Index 0
    #>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)][String] $Name,
        [ValidateSet('module','assembly')][String] $Type = 'module',
        [ValidateRange(0,99)][Int] $Index = 0
    )
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    If(-not(@('module','assembly') -contains $Type)) {
        Throw "[Install-Redist] Invalid type: $Type"
    }

    $DestDir = Join-Path $GLOBAL:_PWR['PSMODULES_DIR'] $Name
    $ArchiveDir = Join-Path $GLOBAL:_PWR['REDISTDIR'] 'lib\PSModules'
    If($Type -eq 'assembly') {
        $DestDir = $GLOBAL:_PWR['PSASSEMBLIES_DIR']
        $ArchiveDir = Join-Path $GLOBAL:_PWR['REDISTDIR'] 'lib\PSAssemblies'
    }

    $zipfn = Join-Path $ArchiveDir ($Name+'.zip')
    If(-not(Test-Path -PathType Leaf $zipfn)) {
        Throw "[Install-Redist] File not found: $zipfn"
    }

    $tmpdir = New-TempDir
    _unzip $zipfn $tmpdir
    if($Index -ge 0) {
        $subdir = (,(Get-ChildItem $tmpdir | ?{$_.PSIsContainer}))[$Index].Name
        $tmpdir = Join-Path $tmpdir $subdir
    }
    Move-Item $tmpdir $DestDir
    If(Test-Path -PathType Container $tmpdir) {
        Remove-Item -force $tmpdir
    }

} # end function Install-Redist

# unzip helper using Shell
function _unzip {
    Param($file,$dest)
    $fn = ConvertTo-AbsolutePath $file
    $dn = ConvertTo-AbsolutePath $dest
    if($fn) {
        $shell = New-Object -com Shell.Application
        $zip = $shell.NameSpace($fn)
        foreach($item in $zip.items()) {
            $shell.Namespace($dn).copyhere($item)
        }
    }
}

