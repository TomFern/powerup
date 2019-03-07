# PSRemoteRegistry needs: Remote Registry Service, Adminitrator Elevated, Administrator on remote machine, PS v2
#https://psremoteregistry.codeplex.com/
#https://stackoverflow.com/questions/24871891/powershell-v2-psremoteregistry-getting-information-from-default-vaules

if(-NOT($GLOBAL:_PWR.ELEVATED)) {
    Throw("Not ELEVATED, you must run in a elevated (run as administrator) session")
}

Set-StrictMode -Version Latest

#Import-Power 'PoshRegistry'
Import-Power 'PSRemoteRegistry'
Import-Power 'Table'

Function New-Table_Install_Package {
<#
    .SYNOPSIS
        Table for Windows.Installer\Get-Install
    .DESCRIPTION
            Hostname - [String] Target computer hostname
            InstallType - [String] 'Patch' for patches. Otherwise 'Product'
            InstallDate - [String] Date for the most current install.
            ProductCode - [String] Product internal code. For patches is empty.
            ProductVersion - [String] Product version. For patches is empty.
            ProductName - [String] Product full name. Patches share this name
            PatchName - [String] For patches, the patch name. Otherwise empty.
            PackageName - [String] Original installer File, typically an msi/msp filename
            PackageLastUsedSource - [String] Directory where the original installer file was located
            PackageLastUsedPath - [String] Full path to the original installer file, ie LastUsedSource + PackageName
            CacheFilePath - [String] Full path to the Windows Cache File, eg. C:\Windows\Installer\foo.msi
    .LINK
        Get-Install
#>
    $Table = New-Object System.Data.DataTable 'Get-Install'
    [void]$Table.Columns.Add('Hostname',[String])
    [void]$Table.Columns.Add('InstallDate',[String])
    [void]$Table.Columns.Add('InstallType',[String])
    [void]$Table.Columns.Add('ProductCode',[String])
    [void]$Table.Columns.Add('ProductVersion',[String])
    [void]$Table.Columns.Add('ProductName',[String])
    [void]$Table.Columns.Add('PatchName',[String])
    [void]$Table.Columns.Add('PackageName',[String])
    [void]$Table.Columns.Add('PackageLastUsedSource',[String])
    [void]$Table.Columns.Add('PackageLastUsedPath',[String])
    [void]$Table.Columns.Add('CacheFilePath',[String])
    [void]$Table.Columns.Add('Key',[String])
    [void]$Table.Columns.Add('KeyPath',[String])
    # Add-TableColumn $Table 'MoreInfo' 'String'
    # Add-TableColumn $Table 'PackageMedia' 'String'
    return ,$Table

} # end function New-Table_Install_Packages

Function Get-Install
{
    <#
    .SYNOPSIS
        Get Windows Installer Cache Packages

    .DESCRIPTION
        Remotely retrieves from the Windows Registry the contents and packages of installed products and it's
        associated cache data.

        This information can be used to find installed products, required installer cache files and repair missing
        files in the cache.

        Requirements:
            * You must be running on an elevated/adminitrator sesssion
            * The remote machine needs to have the Registry Service running
            * The local session and remote machine must have compatible architecture
              i.e. Local=32 bit and Remote=64bit won't work

        Return table is defined in New-Table_Install_Package

    .PARAMETER Computer
        Computer name
    .PARAMETER FilterProduct
        (optional) Regex string to filter by ProductName, eg. 'sql'
    .LINK
        New-Table_Install_Package
    .EXAMPLE
        $cache = Get-Install Foo 'sql'

    #>
    [cmdletbinding()]
    Param(
        [String]$Computer=$GLOBAL:_PWR['CURRENT_HOSTNAME'],
        [String]$FilterProduct = ""
    )
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    $Table = New-Table_Install_Package

    Write-Progress -Activity "Read Registry" -Status $computer -currentOperation "Initial Product List" -PercentComplete 0

    $GetRegProducts = $null
    Try {
        $GetInstalledProductKeys = Get-RegKey -computername $Computer -Hive ClassesRoot -Key 'Installer\Products\'
    }
    Catch {
        Throw ("[Get-Install] Registry read error on: {0}. Error was: {1}" -f $Computer,$_.Exception.Message)
    }
    If(($GetInstalledProductKeys|Measure-Object).Count -eq 0) {
        Throw ("[Get-Install] No installed products found on registry for: {0}" -f $computer)
    }

    $ProductTotal = ($GetInstalledProductKeys|Measure-Object).Count
    $ProductCounter = 0

    Foreach ($KeyObj in $GetInstalledProductKeys) {
        $ProductCounter += 1

        If(($KeyObj|Measure-Object).Count -eq 0) {
            Throw "[Get-Install] Empty Registry Key on: $Computer"
        }

        If($KeyObj.ValueCount -eq 0) {
            Write-Debug ("[Get-Install] No Values HKCR\{0}, ignoring key" -f $Key.Key)
            continue
        }
        If($KeyObj.SubKeyCount -eq 0) {
            Write-Debug ("[Get-Install] No Subkeys under HKCR\{0}, ignoring key" -f $Key.Key)
            continue
        }

        $ProductReg = @{}
        $ProductReg['Path'] = $KeyObj.Key
        $ProductReg['Key'] = (($KeyObj.Key -split '\\') | Select -Last 1)

        Write-Progress -Activity "Read Registry" -Status $computer -currentOperation $ProductReg['Path'] -PercentComplete ($ProductCounter*100/$ProductTotal)

        $Product = @{}
        Get-RegValue -ComputerName $Computer -Hive ClassesRoot -Key $ProductReg['Path'] -Type String | Foreach {
            $Product[$_.Value] = $_.Data
        }

        # filter by ProductName, skip not matching Products
        If($FilterProduct -ne "") {
            If(-not($Product['ProductName'] -match $FilterProduct)) {
                Write-Debug ("[GetInstalledProductKeys] Skip {0} since it doesn't match filter." -f $Product['ProductName'])
                continue
            }
        }

        Write-Progress -Activity "Read Registry" -Status $computer -currentOperation $Product['ProductName'] -PercentComplete ($ProductCounter*100/$ProductTotal)

        $ProductRow = $Table.NewRow()
        $ProductRow.Hostname = $Computer
        $ProductRow.InstallType = "Product"
        $ProductRow.ProductName = $Product['ProductName']
        $ProductRow.ProductCode = $Product['PackageCode']

        $Sourcelist = @{}
        Get-RegValue -ComputerName $Computer -Hive ClassesRoot -Key ("{0}\SourceList\" -f $ProductReg['Path']) -Type String,ExpandString | Foreach {
            $Sourcelist[[String]($_.Value).Trim()] = [String]($_.Data).Trim()
            # Write-Host $_.Value
        }
        $ProductRow.PackageName = $Sourcelist['PackageName']
        $LastUsedSource =[String]$Sourcelist['LastUsedSource']
        If($LastUsedSource -gt 4) {
            $ProductRow.PackageLastUsedSource = $LastUsedSource.Substring(4).Trim()
            $ProductRow.PackageLastUsedPath = ("{0}\{1}" -f $ProductRow.PackageLastUsedSource,$Sourcelist['PackageName'])
        }
        else {
            Write-Warning ("[Get-Install] Product {0}. Last used source is invalid: {1}" -f $ProductRow.ProductName, $LastUsedSource)
        }


        # $Media = @{}
        # Get-RegValue -ComputerName $Computer -Hive ClassesRoot -Key ("{0}\SourceList\Media" -f $ProductReg['Path']) -Type String,ExpandString | Foreach {
        #     $Media[[String]($_.Value).Trim()] = [String]($_.Data).Trim()
        # }
        # $ProductRow.PackageMedia = $Media['MediaPackage']

        $InstallProperties = @{}
        Get-RegValue -ComputerName $Computer -Hive LocalMachine -Key ("SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\UserData\S-1-5-18\Products\{0}\InstallProperties\" -f $ProductReg['Key']) -Type String,ExpandString | Foreach {
            $InstallProperties[[String]($_.Value).Trim()] = [String]($_.Data).Trim()
        }
        $ProductRow.ProductVersion = $InstallProperties['DisplayVersion']
        $ProductRow.CacheFilePath = $InstallProperties['LocalPackage']
        $ProductRow.InstallDate = $InstallProperties['InstallDate']
        $ProductRow.KeyPath = $ProductReg['Path']
        $ProductRow.Key = $ProductReg['Key']
        # $ProductRow.MoreInfo = $InstallProperties['MoreInfoURL'] # FIXME maybe not needed

        $Table.Rows.Add($ProductRow) | Out-Null

        # Patches Installed. A new Row is added for each patch
        $GetRegInstalledPatchesKeys = $null
        Try {
            # Write-Host ('SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\UserData\S-1-5-18\Products\{0}\Patches\' -f $ProductReg['Key'])
            $GetRegInstalledPatchesKeys = Get-RegKey -ComputerName $Computer -Hive LocalMachine -Key ('SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\UserData\S-1-5-18\Products\{0}\Patches\' -f $ProductReg['Key'])
        }
        Catch {
            Write-Debug ("[Get-Install] No regkeys found patches for {0}" -f $Product['ProductName'])
        }

        If(($GetRegInstalledPatchesKeys|Measure-Object).Count -gt 0) {
            Foreach($KeyObj in $GetRegInstalledPatchesKeys) {
                $PatchRow = $Table.NewRow()
                $PatchRow.Hostname = $Computer
                $PatchRow.InstallType = 'Patch'
                $PatchRow.ProductName = $Product['ProductName']

                $PatchReg = @{}
                $PatchReg['Path'] = $KeyObj.Key
                $PatchReg['Key'] = (($KeyObj.Key -split '\\') | Select -Last 1)

                $Patch = @{}
                Get-RegValue -ComputerName $Computer -Hive LocalMachine -Key ("SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\UserData\S-1-5-18\Products\{0}\patches\{1}" -f $ProductReg['Key'],$PatchReg['Key']) -Type String,ExpandString | Foreach {
                    $Patch[[String]($_.Value).Trim()] = [String]($_.Data).Trim()
                }

                $PatchRow.PatchName = $Patch['DisplayName']
                $PatchRow.InstallDate = $Patch['Installed']
                $PatchRow.Key = $PatchReg['Key']
                $PatchRow.KeyPath = $PatchReg['Path']

                $PatchSourcelist = @{}
                Get-RegValue -ComputerName $Computer -Hive ClassesRoot -Key ("Installer\Patches\{0}\Sourcelist" -f $PatchReg['Key']) -Type String,ExpandString | Foreach {
                    $PatchSourcelist[[String]($_.Value).Trim()] = [String]($_.Data).Trim()
                }

                $PatchRow.PackageName = $PatchSourcelist['PackageName']
                $PatchLastUsedSource = ($PatchSourcelist['LastUsedSource']|Out-String).Trim()
                If($PatchLastUsedSource.Length -gt 4) {
                    $PatchRow.PackageLastUsedSource = ([String]$PatchSourcelist['LastUsedSource']).Substring(4).Trim()
                    $PatchRow.PackageLastUsedPath = ("{0}\{1}" -f $PatchRow.PackageLastUsedSource,$PatchSourcelist['PackageName'])
                }

                $PatchInstallProperties = @{}
                Get-RegValue -ComputerName $Computer -Hive LocalMachine -Key ("SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\UserData\S-1-5-18\Patches\{0}" -f $PatchReg['Key']) -Type String,ExpandString | Foreach {
                    $PatchInstallProperties[[String]($_.Value).Trim()] = [String]($_.Data).Trim()
                }
                $PatchRow.CacheFilePath = $PatchInstallProperties['LocalPackage']

                $Table.Rows.Add($PatchRow)
            }
        }
    } # Foreach GetRegProducts

    Write-Progress -Activity "Read Registry" -Status $computer -Completed

    return ,$Table
} # end function Get-Install


##function Repair-SQLInstall {
##    <#
##    .SYNOPSIS
##        Check and Repair Windows Installer cache files for a SQL Server installation
##
##    .DESCRIPTION
##
##        An enhanced version of Microsoft's FindSQLInstallsOnly.vbs
##        Check Windows Installer cache files for missing SQL Server package/patches files.
##
##        SQL Server products will not install/uninstall/upgrade when there are missing msi/msp files on %windir%\Installer
##
##        This function can check for missing files remotely, for this you need:
##            * Be running in an elevated PS Session (Run as Administrator)
##            * Have Adminitrator privileges on the remote system
##            * The Remote Registy service must be running on the remote system
##
##        Repair-SQLInstall will return a DataTable with the following columns:
##
##            * Hostname: hostname of the remote machine, or '.' if running local
##            * Type: Either Product (installed products) or Patch (for hotfixes, CU, SPs)
##            * Name: Product or Patch name
##            * KB: The KB number (if present)
##            * LastUsedSource: The directory path of the installer media
##            * PackageName: The original file name on the installer media
##            * CacheFileExists: True when file exists on the Installer cache, False otherwise
##            * ErrorCode:
##                NULL - No error
##                NO_SOURCE_FOUND - Original install media not found, unable to repair cache.
##                NO_REPAIR - Original install media found, but the -NoRepair option was set
##
##            By default only the packages where CacheFileExists is False are returned.
##            Use the -ReturnAll option to get all the packages.
##
##        Output Files:
##            By default the following files are written. If not found it will create them and write csv header line.
##                checkinstall.log -> activity log and summary
##
##    .PARAMETER Computer
##        The computer name to check, this will affect all installed SQL packages and instances there, defaults to local machine (.)
##
##    .PARAMETER OutSummary
##        Filename to write log, default = checkinstall.log
##
##    .PARAMETER NoRepair
##        Don't attempt to repair anything, default = False
##
##    .PARAMETER ReturnAll
##        Return all packages, including FOUND and NOTFOUND packages
##
##    .EXAMPLE
##        # Check SQL Installation on localhost
##        Repair-SQLInstall
##
##        # Change report files and print a lot of information
##        Repair-SQLInstall 'SERVER1' -outmissing missing.csv -outinfo info.csv -Verbose:w
##
##        # Get all the packages
##        $packages = Repair-SQLInstall -Computer 'Server1' -ReturnAll
##        # check out which packages were repaired on last invokation
##        $packages.Select("Status = 'FOUND_REPAIRED'")
###>
##    [cmdletbinding()]Param(
##        [string] $Computer = '.',
##        [string] $LogFile = 'checkinstall.log',
##        [Switch] $NoRepair,
##        [Switch] $ReturnAll
##    )
##
##    # get verbosity level from CmdLet
##    $verbose = $VerbosePreference -ne 'SilentlyContinue'
##    $debug = $DebugPreference -ne 'SilentlyContinue'
##
##    # output files selectors
##    $log = ''
##    if(test-path -PathType leaf -Path $LogFile) {
##        $log = Get-ChildItem $LogFile
##    }
##    else {
##        $log = New-Item -type f -force $LogFile
##    }
##
##    # report tables
##    $tableSummary = @()
##    $nl = [Environment]::NewLine
##    $tableResults =  New-Object System.Data.DataTable 'CheckInstall'
##    $tableResults = New-Object System.Data.DataTable 'CheckInstall'
##    $tableResults.Columns.Add((New-Object System.Data.DataColumn 'Hostname',([String])))
##    $tableResults.Columns.Add((New-Object System.Data.DataColumn 'Type',([String])))
##    $tableResults.Columns.Add((New-Object System.Data.DataColumn 'Name',([String])))
##    $tableResults.Columns.Add((New-Object System.Data.DataColumn 'KB',([String])))
##    $tableResults.Columns.Add((New-Object System.Data.DataColumn 'PackageName',([String])))
##    $tableResults.Columns.Add((New-Object System.Data.DataColumn 'LastUsedSource',([String])))
##    $tableResults.Columns.Add((New-Object System.Data.DataColumn 'CacheFileExists',([Bool])))
##    $tableResults.Columns.Add((New-Object System.Data.DataColumn 'ErrorCode',([String])))
##
##    # print to console only when verbose
##    function vinfo {
##        Param($text)
##        if($verbose) {
##            $text = $text.trim()
##            "[{0}] {1}" -f $computer,$text
##        }
##    }
##
##    # print to log, if verbose also to console
##    function vlog {
##        Param($text)
##        $text = $text.trim()
##        if($verbose) {
##            "[{0}] {1}" -f $computer,$text
##        }
##        "[{0}] {1}" -f $computer,$text | Out-File -append $log
##    }
##
##    # print to console and log
##    function vsay {
##        Param($text)
##        $text = $text.trim()
##        "{0}" -f $text
##        "{0}" -f $text | Out-File -append $log
##    }
##
##    # see if we can get a KB code from name ... (KBxxxxxx) ...
##    function _get_kb {
##        Param($text)
##        $kb = [regex]::match($text,'\((KB[^\)]+)\)').Groups[1].Value
##        $kb = $kb.Trim()
##        if($kb) {
##            return $kb
##        }
##        else {
##            return $null
##        }
##    }
##
##    # check if session is elevated/administrator
##    vinfo("Checking if running elevated")
##    if(-NOT($GLOBAL:_PWR.ELEVATED)) {
##        Throw("Not ELEVATED, you must run in a elevated (run as administrator) session")
##    }
##
##    # check architecture compatibility
##    vinfo ("Checking architecture compatibility" )
##    #$archLocal = (Get-WmiObject Win32_OperatingSystem).OSArchitecture
##    $archLocal = $GLOBAL:_PWR.PSARCH
##    $archRemote = (Get-WmiObject Win32_OperatingSystem -computername $computer).OSArchitecture
##    if(($archLocal -eq '32-bit') -and($archRemote -eq '64-bit')) {
##        Throw ("Incompatible Architecure, remote system ({0}) is 64 bit and local process is 32 bit" -f $computer)
##    }
##
##    # Get one Value from RegValues object
##    function _get_value {
##        Param($reg, $value)
##        #if($reg -and(get-member -inputobject $reg -name "Value" -MemberType Properties)){
##        #if($reg.PSObject.Properties.Match('Value').Count) {
##        if($reg) {
##            $t = $reg | Where { $_.Value -eq $value}
##            if($t -and $t.Data) {
##                $ret = $t.Data | Out-String
##                $ret = $ret.Trim()
##                return $ret
##            }
##        }
##    }
##
##    # Convert C:\Path to \\$computer\C$\Path
##    # be aware of local vs remote
##    function _convert_path {
##        Param($path)
##        # local machine or remote machine?
##        if(($computer -eq '.') -or($computer -eq 'localhost') -or($computer -eq 'local') -or($computer -eq $GLOBAL:_PWR.CURRENT_HOSTNAME)) {
##            return $path
##        }
##        else {
##            $path = $path.replace(':','$')
##            $path = "\\{0}\{1}" -f $computer,$path
##            return $path
##        }
##    }
##
##    vlog ("Repair-SQLInstall Starts")
##
##    # HKCR: Get Installer\Products regkeys
##    $installerProductsPath = 'Installer\Products\'
##    vinfo ("Read HKCR:{0}" -f $installerProductsPath)
##    $installerProductsData = Get-RegKey -computername $computer -Hive ClassesRoot -Key $installerProductsPath
##    if(-NOT($installerProductsData)) {
##        Throw ("Can't fetch data from remote registry on {0}" -f $computer)
##    }
##
##    # counters for progress bar
##    $pgsCounter = 0
##    $pgsTotal = $installerProductsData.Length
##
##    # for each installed product
##    foreach ($product in $installerProductsData) {
##        $pgsCounter += 1
##        $pgsPct = ($pgsCounter * 100 / $pgsTotal)
##
##        Write-Progress -Id 20 -Activity "Repair-SQLInstall" -Status $computer -currentOperation "Check Installed Products & Patches" -PercentComplete $pgsPct
##
##        # define hashtable for product
##        $p = @{}
##        $p.regkey = ''
##        $p.regkeyAbs = ''
##        $p.regkeyBase = ''
##        $p.name = ''
##        $p.kb = ''
##        $p.productCode = '{}'
##        $p.infoUrl = ''
##        $p.cachedFile = ''
##        $p.lastUsedSource = ''
##        $p.installDate = ''
##        $p.version = ''
##        $p.targetLocation = ''
##
##        # start working
##        $p.regkeyAbs = ($product.key | Out-String).replace('\\','\').Trim()
##        $p.regkeyBase = $installerProductsPath
##        $p.regkey = $p.regkeyAbs.replace($p.regkeyBase, '').Trim()
##
##        #"base={0}" -f $p.regkeyBase
##        #"abs={0}" -f $p.regkeyAbs
##        #"key={0}" -f $p.regkey
##
##        # read HKCR each regkey product, check is this is a SQL product or skip
##        vinfo ("Read HKCR:{0}{1}" -f $installerProductsPath, $p.regkey)
##        $data = Get-RegValue -computername $computer -Hive ClassesRoot -Key ("{0}{1}" -f $installerProductsPath, $p.regkey)
##
##        # get some data for the product, filter out non-sql products
##        $name = _get_value $data 'ProductName' | Out-String
##        if($name -and -NOT($name.tolower().contains("sql"))) {
##            continue
##        }
##        $p.name = $name.trim()
##        $p.kb = _get_kb $p.name
##        $p.version = _get_value $data 'Version'
##
##        # read HKLM InstallProperties for each regkey product
##        $installerProductsPropertiesPath = ("SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\UserData\S-1-5-18\Products\{0}\InstallProperties\" -f $p.regkey)
##        vinfo ("Read HKLM:{0}" -f $installerProductsPropertiesPath)
##        #$installSource = "SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\UserData\S-1-5-18\Products\{0}\InstallProperties" -f $p.regkey
##        $data = Get-RegValue -computerName $computer -Hive LocalMachine -Key $installerProductsPropertiesPath
##        $p.productCode = _get_value $data 'UninstallString'
##        $p.productCode = "{" + [regex]::match($p.productCode,'\{([^\)]+)\}').Groups[1].Value + "}"
##        $p.installDate = _get_value $data 'InstallDate'
##        $p.targetLocation = _get_value $data 'MoreInfoURL'
##        $p.cachedFile = _get_value $data 'LocalPackage'
##        if($p.cachedFile) {
##            $p.cachedFile = _convert_path $p.cachedFile
##        }
##
##        # read HKCR SourceList for each regkey product
##        $installerProductsSourceListPath = ("Installer\Products\{0}\SourceList\" -f $p.regkey)
##        vinfo ("Read HKCR:{0}" -f $installerProductsSourceListPath)
##        $data = Get-RegValue -computer $computer -hive ClassesRoot -Key $installerProductsSourceListPath
##        if($data) {
##            $p.packageName = _get_value $data 'PackageName'
##            $p.lastUsedSource = _get_value $data 'LastUsedSource'
##            $p.lastUsedSource = ($p.lastUsedSource.split(';'))[-1]
##            $p.lastUsedSource = _convert_path $p.lastUsedSource
##        }
##
##        # Get Media data from HKCR
##        #$media = Get-RegValue -computer $computer -hive ClassesRoot -Key ("Installer\Products\{0}\SourceList\Media" -f $p.regkey)
##        #if($media) {
##            #$p.mediaPackage = _get_value $media 'MediaPackage'
##        #}
##
##        # Package Info
##        if($verbose) {
##            " "
##            $p
##            " "
##        }
##
##        # check files; try to fix missing cache files
##        $tableRow = $tableResults.NewRow()
##        $tableRow.Hostname = $computer
##        $tableRow.Name = $p.name
##        $tableRow.Type = 'Product'
##        $tableRow.KB = $p.kb
##        $tableRow.PackageName = $p.PackageName
##        $tableRow.LastUsedSource = $p.lastUsedSource
##        $tableRow.CacheFileExists = $false
##        $tableRow.ErrorCode = $null
##
##        if($p.cachedFile) {
##            if(test-path -PathType leaf -path $p.cachedFile) {
##                vinfo("OK: Found cached file {0}" -f $p.cachedFile)
##                $tableRow.CacheFileExists = $true
##            }
##            else {
##                $tryrepair = join-path $p.lastUsedSource $p.packageName
##                Write-Verbose "[TRYREPAIR] $tryrepair"
##                if(test-path -path $tryrepair -pathtype leaf) {
##                    if($NoRepair) {
##                        vlog ("FATAL: Found missing cache file: {0} but you choose not to *repair*" -f $p.cachedFile)
##                        $tableRow.CacheFileExists = $false
##                        $tableRow.ErrorCode = 'NO_REPAIR'
##                    }
##                    else {
##                        Copy-Item -path $tryrepair -destination $p.cachedFile
##                        vlog ("WARN: fixed cache on {0} from {1}" -f $p.cachedFile,$tryrepair)
##                        $tableRow.CacheFileExists = $true
##                    }
##                }
##                else {
##                    vlog ("FATAL: missing cache file on {0}" -f $p.cachedFile)
##                    $tableRow.CacheFileExists = $false
##                    $tableRow.ErrorCode = 'NO_SOURCE_FOUND'
##                }
##            }
##        }
##        else {
##            vinfo("WARN: can't find cache file value for {0}" -f $p.name)
##        }
##        $tableResults.Rows.Add($tableRow)
##        $tableRow = $null
##
##        # Get Patches data from  HKLM
##        vinfo ("Checking installed patches for {0}" -f $p.name)
##        $installerPatchesPath = ("SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\UserData\S-1-5-18\Products\{0}\patches\" -f $p.regkey)
##        vinfo ("Read HKLM:{0}" -f $installerPatchesPath)
##        Get-RegKey -computerName $computer -Hive LocalMachine -Key $installerPatchesPath | foreach {
##
##            $h = @{}
##            $h.regkey = ''
##            $h.regkeyAbs = ''
##            $h.name = ''
##            $h.kb = ''
##            $h.productCode = '{}'
##            $h.uninstallable = ''
##            $h.cachedFile = ''
##            $h.infoUrl = ''
##            $h.lastUsedSource = ''
##            $h.installDate = ''
##            $h.version = ''
##            $h.targetLocation = ''
##
##            # start working
##            $h.regkeyAbs = ($_.Key | Out-String).replace('\\','\').Trim()
##            $h.regkeyBase = $installerPatchesPath
##            $h.regkey = $h.regkeyAbs.replace($h.regkeyBase, '').Trim()
##
##            #"regkeyAbs={0}" -f $h.regkeyAbs
##            #"replace={0}" -f $h.regkeyBase
##            #"regkey={0}" -f $h.regkey
##
##            $patchesPath = ("{0}\{1}" -f $installerPatchesPath, $h.regkey)
##            vinfo ("Read HKLM:{0}" -f $patchesPath)
##            $data = Get-RegValue -computerName $computer -Hive LocalMachine -Key $patchesPath
##
##            $h.name = _get_value $data 'DisplayName'
##            $h.kb = _get_kb $h.name
##            $h.uninstallable = _get_value $data 'Uninstallable'
##            $h.packageName = _get_value $data 'PackageName'
##            $h.infoUrl = _get_value $data 'MoreInfoURL'
##
##            $patchesDetailsPath = ("SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\UserData\S-1-5-18\Patches\{0}\" -f $h.regkey)
##            vinfo("Read HKLM:{0}" -f $patchesDetailsPath)
##            $data = Get-RegValue -computer $computer -Hive LocalMachine -Key $patchesDetailsPath
##            $h.cachedFile = _get_value $data 'LocalPackage'
##            if($h.cachedFile) {
##                $h.cachedFile = _convert_path $h.cachedFile
##            }
##
##            $patchesSourcelistPath = ("Installer\Patches\{0}\SourceList" -f $h.regkey)
##            vinfo("Read HKCR:{0}" -f $patchesSourcelistPath)
##            $data = Get-RegValue -computer $computer -Hive ClassesRoot -Key $patchesSourcelistPath
##
##            $h.lastUsedSource = _get_value $data 'LastUsedSource'
##            if($h.lastUsedSource) {
##                $h.lastUsedSource = ($h.lastUsedSource |out-string).split(';')[-1].trim()
##                $h.lastUsedSource = _convert_path $h.lastUsedSource
##            }
##
##
##            if($verbose) {
##                " "
##                $h
##                " "
##            }
##
##            # check files; try to fix missing cache files
##            $tableRow = $tableResults.NewRow()
##            $tableRow.Hostname = $computer
##            $tableRow.Name = $h.name
##            $tableRow.Type = 'Patch'
##            $tableRow.KB = $h.kb
##            $tableRow.PackageName = $h.PackageName
##            $tableRow.LastUsedSource = $h.lastUsedSource
##            $tableRow.CacheFileExists = $false
##            $tableRow.ErrorCode = $null
##
##            # check files; try to fix missing cache files
##            if($h.cachedFile) {
##                if(test-path -pathtype leaf -path $h.cachedFile) {
##                    vinfo("OK: found cached file {0}" -f $h.cachedFile)
##                    $tableRow.CacheFileExists = $true
##                    $tableRow.ErrorCode = $null
##                }
##                else {
##                    $tryrepair = join-path $h.lastUsedSource $h.packageName
##                    if(test-path -path $tryrepair -pathtype leaf) {
##                        if($NoRepair) {
##                            vlog ("FATAL: Found missing cache file: {0} but you choose not to *repair*" -f $h.cachedFile)
##                            $tableRow.CacheFileExists = $false
##                            $tableRow.ErrorCode = 'NO_REPAIR'
##                        }
##                        else {
##                            Copy-Item -path $tryrepair -destination $h.cachedFile
##                            vlog ("WARN: fixed cache on {0} from {1}" -f $h.cachedFile,$tryrepair)
##                            $tableRow.CacheFileExists = $true
##                        }
##                    }
##                    else {
##                        vlog ("FATAL: missing cache file on {0}" -f $h.cachedFile)
##                        $tableRow.CacheFileExists = $false
##                        $tableRow.ErrorCode = 'NO_SOURCE_FOUND'
##                    }
##                }
##            }
##            else {
##                vinfo("WARN: can't find cached file value for {0}" -f $h.name)
##            }
##
##            $tableResults.Rows.Add($tableRow)
##            $tableRow = $null
##        }
##    }
##
##    $cntPackages = ($tableResults|Measure-Object).Count
##    $cntMissing = ($tableResults.Select("CacheFileExists = FALSE")|Measure-Object).Count
##    vlog ("Repair-SQLInstall complete. Results: {0} SQL packages found, {1} missing files" -f $cntPackages,$cntMissing)
##
##    # return results datatable
##    if($ReturnAll) {
##        vlog($tableResults|Out-String)
##        return ,$tableResults
##    }
##    else {
##        vlog($tableResults.Select("CacheFileExists = FALSE")|Out-String)
##        return ,($tableResults.Select("CacheFileExists = FALSE"))
##    }
##}
