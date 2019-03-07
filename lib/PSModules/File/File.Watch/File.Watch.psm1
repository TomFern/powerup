#  $E = Register-WatchFolder ...
# Unregister-Event -SubscriptionId 2
# Unregister-Event -SourceIdentified $E.Name
#
Function Register-WatchFolder {
<#
    .SYNOPSIS
        Monitor folder for changes and execute code
    .DESCRIPTION
        Monitors a folder and executes code each time a file changes
        Returns Register-ObjectEvent decriptor

        The ScriptBlock code will receive an $Event object, for example:
            $Event.SourceEventArgs.FullPath
            $Event.SourceEventArgs.Name
            $Event.SourceEventArgs.ChangeType
            $Event.TimeGenerated

    .PARAMETER Path
        Folder to monitor
    .PARAMETER ScriptBlock
        Code to execute on file change
    .PARAMETER Filter
        Filter using mask, default is "*.*"
    .PARAMETER Recurse
        [Switch] Recurse folders
    .LINK
        Register-WatchFile
        Register-WatchFolder

    .EXAMPLE
        $RegEvent = Register-WatchFolder "C:\Temp" { Write-Host $Event.SourceEventArgs.FullPath "was modified" }
        Unregister-Event $RegEvent.Name

#>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)][String]$Path,
        [Parameter(Mandatory=$true)][ScriptBlock]$ScriptBlock,
        [String]$Filter="",
        [Switch]$Recurse
    )
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    $watcher = New-Object IO.FileSystemWatcher $Path, $Filter -Property @{
        IncludeSubdirectories = $Recurse
        EnableRaisingEvents = $true
        NotifyFilter = "LastWrite"
        # NotifyFilter = "LastWrite,DirectoryName,Filename"
    }


    Register-ObjectEvent $Watcher "Changed" -Action $ScriptBlock
} # end function Register-WatchFolder



Function Register-WatchFile {
<#
    .SYNOPSIS
        Monitor file for changes and execute code
    .DESCRIPTION
        Monitors a single file and executes code each time it changes
        Returns Register-ObjectEvent decriptor

        The ScriptBlock code will receive an $Event object, for example:
            $Event.SourceEventArgs.FullPath
            $Event.SourceEventArgs.Name
            $Event.SourceEventArgs.ChangeType
            $Event.TimeGenerated

    .PARAMETER Path
        File to monitor
    .PARAMETER ScriptBlock
        Code to execute on file change
    .LINK
        Register-WatchFile
        Register-WatchFolder

    .EXAMPLE
        $RegEvent = Register-WatchFile "C:\Temp\Foo.txt" { Write-Host $Event.SourceEventArgs.FullPath "was modified" }
        Unregister-Event $RegEvent.Name

#>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)][String]$Path,
        [Parameter(Mandatory=$true)][ScriptBlock]$ScriptBlock
    )
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    $PathItem = [System.IO.FileInfo]$Path

    Register-WatchFolder -Path $PathItem.DirectoryName -Filter $PathItem.Name -ScriptBlock $ScriptBlock

} # end function Register-WatchFile

# Register-Watcher "c:\temp"

    # $changeAction = [scriptblock]::Create('
    #     # This is the code which will be executed every time a file change is detected
    #     $path = $Event.SourceEventArgs.FullPath
    #     $name = $Event.SourceEventArgs.Name
    #     $changeType = $Event.SourceEventArgs.ChangeType
    #     $timeStamp = $Event.TimeGenerated
    #     Write-Host "The file $name was $changeType at $timeStamp"
    # ')
