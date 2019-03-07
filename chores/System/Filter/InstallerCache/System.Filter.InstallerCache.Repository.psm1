# Filter Valid Windows Installer Packages

Set-StrictMode -version Latest

New-Variable -Scope Script 'IHost'
New-Variable -Scope Script 'SystemSet'

Import-Power 'Table'
Import-Power 'Path'


################################################
#
# Inputs
#
################################################

function StepPre {
    Param([HashTable]$usr,[HashTable]$Id)

    $Script:SystemSet = $usr['System.Windows']

}


################################################
#
# Outputs
#
################################################

function StepNext {

    $Script:SystemSet.Tables['Get-Install__CacheFileRepository'].Rows[0]>$null

    return @{
        'System.Windows' = $Script:SystemSet;
    }
}


################################################
#
# Process
#
################################################

function StepProcess {

    $CheckCache = $Script:SystemSet.Tables['Get-Install__CacheFileExists']
    $ValidCache = $CheckCache.Clone()
    $ValidCache.TableName = 'Get-Install__CacheFileRepository'
    $CheckCache.Select("CacheFileExists = $true") | Foreach {
        $ValidCache.ImportRow($_)
    }

    If(($Script:SystemSet|Get-Table) -contains 'Get-Install__CacheFileRepository') {
        $Script:SystemSet.Tables.Remove('Get-Install__CacheFileRepository')
    }
    $Script:SystemSet.Tables.Add($ValidCache)
}

