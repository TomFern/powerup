# Generate HTML Table for each DataTable (recurse DataSets) and email

Set-StrictMode -version Latest

Import-Power 'Templates'
Import-Power 'Email'
Import-Power 'Table'

New-Variable -Scope Script 'Date'
New-Variable -Scope Script 'EveryVariable'
New-Variable -Scope Script 'Params'
# New-Variable -Scope Script 'Info'
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
    # $script:Info = $usr['ReportInfo']

    # Optional Parameters/Config

    $Script:Params = @{}
    $Script:Params['Recipients'] = ''
    $Script:Params['Title'] = 'MultiTableHTML';

    # $Script:Info['Date']>$null
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

    $SaveHtml = Join-Path $GLOBAL:_PWR['REPORTDIR'] ("{0}.html" -f $Script:Params['Title'])

    $EveryTable = ComputeDatasets $Script:EveryVariable

    # Template

    $Params = @{
        'Title' = $Script:Params['Title'];
        }

    $ContentHtml = Invoke-Template 'MultiTableHTML' -UserData $EveryTable -TemplateParameters $Params


    # Email

    If($Script:Params['Recipients']) {
        $Message = New-Email -Subject $Script:Params['Title'] -To ($Script:Params['Recipients'] -split ',')

        $BodyHtml = New-Body ($ContentHtml|Out-String).Trim()  "text/html"
        Add-Body $Message $BodyHtml

        Try {
            Send-Email $Message
        }
        Catch {
            Write-Warning ("Error sending email: {0}" -f $_.Exception.Message)
        }
        Finally {
            $BodyHtml.Dispose()
            $Message.Dispose()
        }
    }


    # Save Report

    $ContentHtml | Out-File $SaveHtml
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


