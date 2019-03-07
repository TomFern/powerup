# Package Manager

# ppm file format primer
#
# a csv file with columns:
#   PACKAGE_NAME -> String, unique for each package name
#   PARAMETER -> String
#   VALUE -> String
#
#
# PARAMETERS:
#
#   version an [int] or a string like [int].[int].[int]
#           the . are stripped, the ints concatenated
#           and a normal -ge comparison
#
#   archive_container_type is "zip" or "single"
#           for powerup is must be zip
#           single is a single file (eg. inventory table)
#   repository_dir relative path to ppm on the repository, if empty use same directory
#   archive_filename name of the zip or single file
#
#   the following appear multiple times per package when using zip:
#
#   archive_subdir only for "zip" subdir inside the zip, ignore the others
#   install_dir destination dir relative to DEFAULTDIR (eg lib\PSAssemblies\Charts)
#

Import-Power 'Temp'
Import-Power 'Table'
Import-Power 'File.Zip'


Function Install-Powerup {
<#
    .SYNOPSIS
        Install Powerup
    .DESCRIPTION
        Installs powerup in destination directory.
        Use -Computer to install in another machine.
    .PARAMETER Package
        Path to powerup ppm
    .PARAMETER Destination
        Path to destination
    .PARAMETER Computer
        Computer hostname to install, defaults to localhost

    .LINK

    .EXAMPLE
        Update-Powerup -Path 'package\powerup.ppm'
#>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)][String]$Package,
        [Parameter(Mandatory=$true)][String]$Destination,
        [String]$Computer=""
    )
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    $pkgdir = $GLOBAL:_PWR.PACKAGEDIR
    $ppmfn = ""
    if(test-path $Package) {
        $ppmfn = $Package
    }
    elseif(test-path -PathType leaf ("{0}{1}{2}" -f $pkgdir,$ds,$Package)) {
        $ppmfn = ("{0}{1}{2}" -f $pkgdir,$ds,$Package)
    }
    else {
        Throw "[Install-Package] File not found $Package.ppm"
    }

    $pkg = Read-Package $ppmfn
    if(-not($pkg['PACKAGE_NAME'] -eq 'powerup')) {
        Throw ("[Install-Powerup] Not a powerup package ({0})" -f $pkg['PACKAGE_NAME'])
    }
    $version = ($pkg['version'] -replace '\.','').trim()
    $tmpdir = New-TempDir

    $pkgdir = $GLOBAL:_PWR.PACKAGEDIR
    $archiveFn = join-path $pkgdir $pkg['archive_filename']
    Try {
        Unzip-File $archiveFn $tmpdir
    }
    Catch {
        Throw ("[Install-Powerup] Can't unzip package: {0}" -f $_.exception.message)
    }

    If($Computer) {
        $Destination = ConvertTo-RemotePath -Computer $Computer -Path $Destination
    }

    New-Item -Force -type d $Destination >$null
    Copy-Item -Recurse -Force ("{0}\*" -f $tmpdir) $Destination
    Remove-Item -Force -Recurse $tmpdir
} # end function Install-Powerup


Function Update-Powerup {
<#
    .SYNOPSIS
        Update Powerup
    .DESCRIPTION
        Updates powerup from a package.

        This will overwrite/delete the current version.

        Reloads powerup using the new version
    .PARAMETER Package
        Path to powerup ppm
    .PARAMETER Confirm
        [Switch] Don't prompt for confirmation

    .LINK

    .EXAMPLE
        Update-Powerup -Path 'package\powerup.ppm'
#>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)][String]$Package,
        [Switch]$Confirm
    )
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    $pkgdir = $GLOBAL:_PWR.PACKAGEDIR
    $ppmfn = ""
    if(test-path $Package) {
        $ppmfn = $Package
    }
    elseif(test-path -PathType leaf ("{0}{1}{2}" -f $pkgdir,$ds,$Package)) {
        $ppmfn = ("{0}{1}{2}" -f $pkgdir,$ds,$Package)
    }
    else {
        Throw "[Install-Package] File not found $Package.ppm"
    }

    $pkg = Read-Package $ppmfn
    if(-not($pkg['PACKAGE_NAME'] -eq 'powerup')) {
        Throw ("[Update-Powerup] Not a powerup package ({0})" -f $pkg['PACKAGE_NAME'])
    }

    $version = ($pkg['version'] -replace '\.','').trim()

    if(-not($Confirm)) {
        Write-Host -ForegroundColor Cyan ("--> This will OVERWRITE current version with '{0}'. To continue type 'YES'" -f $pkg['version'])
        $response = Read-Host
        If(-not($response -eq 'YES')) {
            return
        }
    }

    $archiveFn = join-path $pkgdir $pkg['archive_filename']
    $tmpdir = New-TempDir
    Try {
        Unzip-File $archiveFn $tmpdir
    }
    Catch {
        Throw ("[Update-Powerup] Can't unzip package: {0}" -f $_.exception.message)
    }

    # Delete current version
    Remove-Power *
    Get-ChildItem -Path $GLOBAL:_PWR.BASEDIR | Remove-Item -Recurse

    # install and switch
    Copy-Item -Recurse ("{0}\*" -f $tmpdir) $GLOBAL:_PWR.BASEDIR
    Remove-Item -Recurse -Force $tmpdir
    Rebase-Powerup $GLOBAL:_PWR.BASEDIR
}

Function Retrieve-Package {
<#
    .SYNOPSIS
        Copy package file locally
    .DESCRIPTION
        Search for package files, checks version and if needed copies the new version into PACKAGEDIR
        Returns a string to the path of the downloaded version, or empty string if nothing happened.

    .PARAMETER Name
        Package Name
    .PARAMETER SearchIn
        [String[]] Search paths (defaults to config value)
    .PARAMETER Force
        [Switch] If set don't check version, always get package
    .LINK

    .EXAMPLE
        # supply paths for search
        Retrieve-Package -name foo -Path '\\software\packages','\\tsclient\packages'

        # or use the ones on defaults.cfg
        Retrieve-Package -Name foo

        # once copied to package dir, install with with:
        Install-Package "package\foo.ppm"
#>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)][String]$Name,
        [String[]]$SearchIn=$GLOBAL:_PWR.DEFAULTS['package_manager']['package_repository_path'],
        [Switch]$Force
    )
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    $ds= $GLOBAL:_PWR.DIRECTORY_SEPARATOR
    $pkgdir = $GLOBAL:_PWR.PACKAGEDIR
    New-Item -Type d -Force $pkgdir >$null
    $isfound = $false
    $localpath = ""
    foreach($repodir in $SearchIn) {

        $ppmfn = ("{0}{1}{2}.ppm" -f $repodir,$ds,$name)
        if(test-path -PathType leaf $ppmfn) {

            # get ppm file
            Write-Host "Get: $ppmfn"
            copy-item $ppmfn $pkgdir
            $ppmfn = join-path $pkgdir ("{0}.ppm" -f $name)
            $pkg = Read-Package $ppmfn
            $version = [int]($pkg['version'] -replace '\.','').trim()

            # check packages directory first, check version
            if(-not($Force)) {
                if(test-path -PathType leaf ("{0}{1}{2}" -f $pkgdir,$ds,$pkg['archive_filename'])) {
                    $previouspkgFn = ("{0}{1}{2}.ppm" -f $pkgdir,$ds,$Name)
                    if(test-path $previouspkgFn -PathType leaf) {
                        $previouspkg = Read-Package $previouspkgFn
                        $previousversion = [int]($previouspkg['version'] -replace '\.','').trim()
                        if($previousversion -ge $version) {
                            Write-Host "No new version found for $Name"
                            return
                        }
                    }
                }
            }

            # get actual zip with package
            $archiveFn = ("{0}{1}{2}{3}{4}" -f $repodir,$ds,$pkg['repository_dir'],$ds,$pkg['archive_filename'])
            If(test-path -PathType leaf $archiveFn) {
                $isfound = $true
                Write-Host "Get: $archiveFn"
                copy-item -force $archiveFn $pkgdir
                $localpath = $ppmfn
            }
            else {
                throw ("[Retrieve-Package] File not found: $archiveFn")
            }
        }
    }

    if(-not($isfound)) {
        Write-Host "Package not found"
    }

} # end function Retrieve-Package
Set-Alias rpkg Retrieve-Package


Function Read-Package {
<#
    .SYNOPSIS
        Read package file
    .DESCRIPTION
        Parses a ppm file, returns a hashtable
    .PARAMETER Path
        Path to the file
    .PARAMETER

    .LINK

    .EXAMPLE
        $pkg = Read-Package "Foo.ppm"

#>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)][String]$Path
    )
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    Try {
        $pkginfo = New-TableFromCSV $Path
    }
    Catch {
        throw ("[Read-Package] Can't read file: {0}" -f $_.exception.message)
    }

    $pkg = @{
        'index' = @();
    }
    foreach($row in $pkginfo.Rows) {
        if($row.PARAMETER -eq 'archive_subdir') {
            $pkg['index'] += @{
                'archive_subdir' = $row.VALUE
            }
        }
        elseif($row.PARAMETER -eq 'install_dir') {
            $last = ($pkg['index'].count - 1)
            $pkg['index'][$last]['install_dir'] = $row.VALUE
        }
        else {
            $pkg[$row.PARAMETER] = $row.VALUE
        }
    }
    $pkg['PACKAGE_NAME'] = $pkginfo.Rows[0]['PACKAGE_NAME']
    return $pkg
} # end function Read-Package


Function Install-Package {
<#
    .SYNOPSIS
        Install a Package for Powerup
    .DESCRIPTION
        Installs a Package in your LOCALDIR or BASEDIR.
    .PARAMETER Path
        Path to package file
    .PARAMETER

    .LINK

    .EXAMPLE
        Install-Package Foo.ppm
#>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)][String]$Path
    )
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    $ds= $GLOBAL:_PWR.DIRECTORY_SEPARATOR
    $pkg = Read-Package $Path

    $pkgdir = $GLOBAL:_PWR.PACKAGEDIR
    New-Item -Type d -Force $pkgdir >$null
    $archiveFn = join-path $pkgdir $pkg['archive_filename']

    If($pkg['archive_container_type'] -eq 'zip') {

        $tmpdir = New-TempDir
        Try {
            Unzip-File $archiveFn $tmpdir
        }
        Catch {
            Throw ("[Install-Package] Can't unzip package: {0}" -f $_.exception.message)
        }

        $pkg['index'] | foreach {
            $destdir = ("{0}{1}{2}" -f $GLOBAL:_PWR.DEFAULTDIR,$ds,$_.install_dir)
            $archiveSubDir = ($_.archive_subdir|out-string).trim()
            $archiveCopyDir = $tmpdir
            if($archiveSubDir.length -gt 0) {
                $archiveCopyDir = Join-Path $tmpdir $archiveSubDir
            }
            try {
                New-Item -Force -Type D $destdir >$null
            }
            catch {}
            Copy-Item -Force -Recurse ("{0}\*" -f $archiveCopyDir) $destdir
        }
        Remove-Item -Recurse -force $tmpdir
    }
    elseif($pkg['archive_filename'] -eq 'single') {

        $destdir = ("{0}{1}{2}" -f $GLOBAL:_PWR.DEFAULTDIR,$ds,$pkg['index'][0]['install_dir'])
        Copy-Item -Force $archiveFn $destdir
    }
    else {
        Throw ("[Install-Package] archive_container_type is unknown {0}" -f $pkg['archive_container_type'])
    }
}
New-Alias ipkg Install-Package


