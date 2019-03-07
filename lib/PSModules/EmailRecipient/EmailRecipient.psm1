# Email Recipient sorter

Function Get-Recipient {
<#
    .SYNOPSIS
        Get recipients based on config
    .DESCRIPTION
        Get, filters and sorts recipients (email address) based on config.

        Configuration is on address.cfg (edit-config address)

        When a list of email groups is passed, it grabs the emails from each group, removes duplicates and
        returns a string with all the addresses separated by comma.

    .PARAMETER Groups
        [String[]] A list of groups
    .LINK
        Email
    .EXAMPLE
        $recipients = Get-Recipient ($MyInvocation.MyCommand.Name),dbastaff

#>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)][String[]]$Groups
    )
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    $config = Get-Config 'address'
    $address = @()
    foreach($g in $Groups) {

        $e = [string]($config[$g])
        if($e.length -gt 0) {
            $address += ($e -split ',')
        }
    }
    $address = [string](($address | sort -unique) -join ',')
    return $address
} # end function Get-Recipient
