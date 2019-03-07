# Temp Files and Directories

Import-Power 'Path'

Function New-TempFile
{
    <#
    .SYNOPSIS
        Create a Temporary File
    .DESCRIPTION
        Create a random temp file on supplied directory
    .PARAMETER Path
        (optional) Path to parent directory, defaults to TMPDIR
    .PARAMETER Extension
        (optional) Extension for the file, defaults to .tmp
    .PARAMETER Prefix
        (optional) Prefix for file name, defaults to 'temp'
    .EXAMPLE
        $tmpfn = New-TempFile 'C:\tmp'
    #>
    [cmdletbinding()]
    Param(
        [String]$Path=$GLOBAL:_PWR['TMPDIR'],
        [String]$Extension = '.tmp',
        [String]$Prefix = 'temp'
    )
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    # if(-not($Path)) {
    #     $Path = $GLOBAL:_PWR['TMPDIR']
    # }

    if(-not($GLOBAL:_PWR.ContainsKey('TEMPFILELIST')) -or(-not($GLOBAL:_PWR['TEMPFILELIST'] -is [Array]))) {
        $GLOBAL:_PWR['TEMPFILELIST'] = @()
    }

    $tempfn = [String]($Prefix + ("{0:d5}" -f (Get-Random)).Substring(0,5))
    if($Extension) {
        $tempfn = [String]($tempfn + $Extension)
    }
    $tempfn = [String](Join-Path $Path $tempfn)
    $tempfn = [String](ConvertTo-AbsolutePath $tempfn)
    New-Item -type f -force $tempfn | Out-Null
    if(-not($tempfn)) {
        Throw "[Net-TempFile] Can't create file on dir: $Path"
    }
    $GLOBAL:_PWR['TEMPFILELIST'] += $tempfn

    return $tempfn
} # end function New-TempFile

Function New-TempDir
{
    <#
    .SYNOPSIS
        Create a Temporary Directory
    .DESCRIPTION
        Create a random temp dir on supplied directory
    .PARAMETER Path
        (optional) Path to parent directory, defaults to TMPDIR
    .PARAMETER Prefix
        (optional) Prefix for dir name, defaults to 'tempdir'
    .EXAMPLE
        $tmpfn = New-TempDir 'C:\tmp'
    #>
    [cmdletbinding()]
    Param(
        [String]$Path="",
        [String]$Prefix = 'tempdir'
    )
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    if(-not($Path)) {
        $Path = $GLOBAL:_PWR['TMPDIR']
    }

    if(-not($GLOBAL:_PWR.ContainsKey('TEMPDIRLIST')) -or(-not($GLOBAL:_PWR['TEMPDIRLIST'] -is [Array]))) {
        $GLOBAL:_PWR['TEMPDIRLIST'] = @()
    }

    $tempfn = [String]($Prefix + ("{0:d5}" -f (Get-Random)).Substring(0,5))
    $tempfn = [String](Join-Path $Path $tempfn)
    $tempfn = [String](ConvertTo-AbsolutePath $tempfn)
    New-Item -type d -force $tempfn | Out-Null
    if(-not($tempfn)) {
        Throw "[New-TempFile] Can't create dir on: $Path"
    }
    $GLOBAL:_PWR['TEMPDIRLIST'] += $tempfn

    return $tempfn
} # end function New-TempDir

Function Remove-TempFiles
{
    <#
    .SYNOPSIS
        Remove TempFiles
    .DESCRIPTION
        Deletes TempFiles created with New-TempFile
    .EXAMPLE
        $f = New-TempFile
        "foobar" | Set-Content $f
        Remove-TempFiles
        # $f has been deleted
    #>
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    if(-not($GLOBAL:_PWR.ContainsKey('TEMPFILELIST'))) {
        $GLOBAL:_PWR['TEMPFILELIST'] = @()
    }

    $TempFileList = $GLOBAL:_PWR['TEMPFILELIST']

    if($TempFileList) {
        Foreach($f in $TempFileList) {
            if(Test-Path -PathType leaf $f) {
                Write-Verbose "[Remove-TempFiles] Removing file: $f"
                Remove-Item -force $f
            }
        }
    }

    $AfterList = @()
    if($TempFileList) {
        Foreach($f in $TempFileList) {
            if(Test-Path -PathType leaf $f) {
                $AfterList += $f
            }
        }
    }

    $GLOBAL:_PWR['TEMPFILELIST'] = $AfterList
    if(($AfterList|Measure-Object).Count -gt 0) {
        Write-Error "[Remove-TempFiles] Not all Temp Files were deleted"
    }
    return $AfterList
} # end function Remove-TempFiles

Function Remove-TempDir
{
    <#
    .SYNOPSIS
        Remove Temporary Directories
    .DESCRIPTION
        Remote Directories created with New-TempDir
    .EXAMPLE
        $d = New-TempDir
        Remove-TempDir
    #>
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    if(-not($GLOBAL:_PWR.ContainsKey('TEMPDIRLIST'))) {
        $GLOBAL:_PWR['TEMPDIRLIST'] = @()
    }

    $TempFileList = $GLOBAL:_PWR['TEMPDIRLIST']

    if($TempFileList) {
        Foreach($f in $TempFileList) {
            if(Test-Path -PathType Container $f) {
                Write-Verbose "[Remove-TempDir] Removing directory: $f"
                Remove-Item -force -recurse $f
            }
        }
    }

    $AfterList = @()
    if($TempFileList) {
        Foreach($f in $TempFileList) {
            if(Test-Path -PathType leaf $f) {
                $AfterList += $f
            }
        }
    }

    $GLOBAL:_PWR['TEMPDIRLIST'] = $AfterList

    if(($AfterList|Measure-Object).Count -gt 0) {
        Write-Error "[Remove-TempFiles] Not all Temp Files were deleted"
    }

    return $AfterList
} # end function Remove-TempDir

    # testing this func
    #https://stackoverflow.com/questions/24992681/powershell-check-if-a-file-is-locked

 # function Test-FileLock {
 #      param ([parameter(Mandatory=$true)][string]$Path)

 #  $oFile = New-Object System.IO.FileInfo $Path

 #  if ((Test-Path -Path $Path) -eq $false) {
 #    return $false
 #  }

 #  try {
 #      $oStream = $oFile.Open([System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
 #      if ($oStream) {
 #        $oStream.Close()
 #      }
 #      $false
 #  }
 #  catch {
 #    return $true
 #  }
# }
