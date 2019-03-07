# Send all DataTables/DataSets by email as attached CSV Files

Set-StrictMode -version Latest

Import-Power 'Templates'
Import-Power 'Email'
Import-Power 'Table'
Import-Power 'MSSQL.BulkCopy'

New-Variable -Scope Script 'Date'
New-Variable -Scope Script 'EveryVariable'
New-Variable -Scope Script 'Params'
New-Variable -Scope Script 'Info'
# New-Variable -Scope Script 'Config'


################################################
#
# Inputs
#
################################################

function StepPre {
    Param([HashTable]$usr,[HashTable]$id)

    $Script:EveryVariable = $usr;
    $Script:Date = $id['StartDateTime']
    $Script:Config = $id['Config']
    $script:Info = $usr['ReportInfo']

    # Optional Parameters/Config

    $Script:Params = @{}
    $Script:Params['Recipients'] = ''
    $Script:Params['Title'] = 'Storage.Email.DataSet.CSV';

    $Script:Info['Date']>$null
    If($usr.ContainsKey('Recipients')) { $Script:Params['Recipients'] = $usr['Recipients'] }
    If($usr.ContainsKey('Title')) { $Script:Params['Title'] = $usr['Title'] }
}


################################################
#
# Outputs
#
################################################

function StepNext {
    return @{
    }
}


################################################
#
# Process
#
################################################

function StepProcess {

    $templatedir = $GLOBAL:_PWR['TEMPLATEDIR']
    $tmpdir = $GLOBAL:_PWR['TMPDIR']

    $SaveCSVDir = Join-Path $GLOBAL:_PWR['STORAGEDIR'] $Script:Params['Title']
    New-Item -type d -Force $SaveCSVDir >$null

    $EveryTable = ComputeDatasets $Script:EveryVariable

    # Generate CSV Files
    $EveryCSVFn = @{}
    Foreach($Key in $EveryTable.Keys) {
        $EveryCSVFn[$Key] = New-TempFile -Extension '.csv'
        $EveryTable[$Key] | Export-CSV -NoTypeInformation $EveryCSVFn[$Key]
    }

    $ContentText = ($Script:Info|Out-String).Trim()

    # Email

    If($Script:Params['Recipients']) {
        $Message = New-Email -Subject $Script:Params['Title'] -To ($Script:Params['Recipients'] -split ',')

        $BodyText = New-Body ($ContentText|Out-String).Trim()  "text/plain"
        Add-Body $Message $BodyText

        $EveryAttachment = @{}
        Foreach($key in $EveryCSVFn.Keys) {
            $Name = ($Key -replace ':','_')
            $Name = ($Key -replace ' ','_')
            $Name = ("{0}.csv" -f $Name)
            $EveryAttachment[$Key] = New-Attachment $EveryCSVFn[$Key] 'text/csv' -Name $Name
            Add-Attachment $Message $EveryAttachment[$Key]
        }

        Try {
            Send-Email $Message
       }
        Catch {
            Write-Warning ("Error sending email: {0}" -f $_.Exception.Message)
        }
        Finally {
            Foreach($key in $EveryAttachment.Keys) {
                $EveryAttachment[$Key].Dispose()
            }
            $BodyText.Dispose()
            $Message.Dispose()
        }
    }

    # Save Report
    Foreach($key in $EveryCSVFn.Keys) {
        Copy-Item $EveryCSVFn[$key] $SaveCSVDir
    }

}


# Flatten datasets, return a hashtable with all datatables, except inventory
function ComputeDatasets {
    Param([HashTable]$All)

    $PlainTables = @{}
    Foreach($key in $All.Keys) {
        If(($All[$key] | Measure-Object).Count -gt 0) {
            If($All[$key].gettype().name -eq 'DataTable') {
                $PlainTables[$key]=$All[$key]
            }
            elseif($All[$key].gettype().name -eq 'DataSet') {
                $All[$key]|Get-Table|Foreach {
                    If(($_ -ne 'IHost') -and($_ -ne 'IService')) {
                        $newkey = ("{0}::{1}" -f [string]$key,[string]$_)
                        $PlainTables[$newkey]=$All[$key].Tables[$_]
                    }
                }
            }
        }
    }
    return $PlainTables
}


