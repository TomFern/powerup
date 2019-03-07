# Baseline Excep Report

New-Variable -Scope Script 'DBSet'
New-Variable -Scope Script 'SystemSet'
New-Variable -Scope Script 'ServiceSet'
New-Variable -Scope Script 'Info'

Import-Power 'ExcelTemplates'
Import-Power 'Temp'
Import-Power 'Email'


################################################
#
# Inputs
#
################################################

function StepPre {
    Param([HashTable]$usr,[HashTable]$id)
    $Script:ServiceSet = $usr['Service.MSSQL']
    $Script:SystemSet = $usr['System.Windows']
    $Script:DBSet = $usr['Database.MSSQL']

    # $Script:ServiceSet.Tables['SanityDisk'].Rows[0]>$null
    # $Script:ServiceSet.Tables['SanityService'].Rows[0]>$null
    # Assert-Table { New-Table_IService } $Script:ServiceSet.Tables['IService']

    $Script:Info = @{}
    $Script:Info['Date'] = $Id['StartDateTime']
    $Script:Info['Host'] = $GLOBAL:_PWR['CURRENT_HOSTNAME']
    $Script:Info['Version'] = $GLOBAL:_PWR['VERSION']
    $Script:Info['Chore'] = $Id['ChoreName']

    If($Usr.ContainsKey('Title')) {
        $Script:Info['Title'] = $Usr['Title']
    }

    If($Usr.ContainsKey('Recipients')) {
        $Script:Info['Recipients'] = $Usr['Recipients']
    }

    If($GLOBAL:_PWR['TIMEZONE_INITIALS']) {
        $Script:Info['Timezone'] = $GLOBAL:_PWR['TIMEZONE_INITIALS'];
    }
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

    $SaveXLSX = Join-Path $GLOBAL:_PWR['STORAGEDIR'] 'MSSQL_Baseline.xslx'

    $Baseline = ComputeBaseline $Script:ServiceSet.Tables['Get-Uptime'] $Script:ServiceSet.Tables['IService']

    If(-not($Script:Info.ContainsKey('Title'))) {
        $Script:Info['Title'] = "Baseline for SQL Server"
    }

    $UserData = @{
        'Baseline' = $Baseline;
        'Disk' = $Script:SystemSet.Tables['Get-Disk'];
        'Database' = $Script:DBSet.Tables['Get-Database'];
        'Server' = $Script:SystemSet.Tables['Get-Uptime'];
    }

    $TempXLSX = New-TempFile -Extension '.xslx'
    ExcelTemplates\Invoke-Template -TemplateName 'MSSQL_Baseline' -UserData $UserData -Path $TempXLSX

    $ContentEmailText = "Please find attached spreadsheet."

    # Email
    If($Script:Info['Recipients']) {
        $Message = New-Email -Subject $Script:Info['Title'] -To ($Script:Info['Recipients'] -split ',')
        $BodyText = New-Body ($ContentEmailText|Out-String).Trim() "text/plain"
        Add-Body $Message $BodyText | Out-Null
        $Att = New-Attachment -Path $TempXLSX -Mime 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' -Name 'Baseline.xlsx'
        Add-Attachment $Message $Att

        Try {
            Send-Email $Message
        }
        Catch {
            Write-Warning ("Error sending email: {0}" -f $_.Exception.Message)
        }
        Finally {
            $BodyText.Dispose()
            $Message.Dispose()
        }
    }

    # Save Report
    Copy-Item $TempXLSX $SaveXLSX
    Remove-Item -Force $TempXLSX
}


function ComputeBaseline {
    Param($Uptime, $Inventory)

    $Baseline = $Uptime.Copy()
    [void]$Baseline.Columns.Add('Role',[String])

    foreach($b in $Baseline.rows) {
        $find = $Inventory.Select(("Servicename = '{0}'" -f $b['Servicename']))
        if(($find|measure).count -gt 0) {
            $b['Role'] = $find[0]['Role']
        }
    }

    return ,$Baseline
}
