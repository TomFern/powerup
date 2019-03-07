# Report checkout Sybase. Send an email for each recovered Instance

Set-StrictMode -version Latest

Import-Power 'Templates'
Import-Power 'Charts.Pie'
Import-Power 'Email'
Import-Power 'Inventory'

New-Variable -Scope Script 'Info'
New-Variable -Scope Script 'Checkout'


################################################
#
# Inputs
#
################################################

function StepPre {
    Param([HashTable]$usr,[HashTable]$id)

    $Script:Checkout = $usr['Checkout.ASE']

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
    return @{}
}


################################################
#
# Process
#
################################################

function StepProcess {

    $templatedir = $GLOBAL:_PWR['TEMPLATEDIR']
    $tmpdir = $GLOBAL:_PWR['TMPDIR']

    If(-not($Script:Info.ContainsKey('Title'))) {
        $Script:Info['Title'] = "Checkout"
    }


    foreach($row in $Script:Checkout.Tables['IService']) {

        $Servicename = $row['Servicename']

        $ReportTitle = ('{0} {1}' -f $Script:Info['Title'], $Servicename)

        $Params = @{
            'Title' = $ReportTitle;
            'Date' = $Script:Info['Date'];
            }

        $Uptime = Select-Table -Table $Script:Checkout.Tables['Get-Uptime'] -Select ("Servicename = '{0}'" -f $Servicename) -Limit 1
        $Uptime.Tablename = $Servicename

        $Databases = New-Object System.Data.Datatable 'Databases'
        Try {
            $Databases = Select-Table -Table $Script:Checkout.Tables['Get-Database'] -Select ("Servicename = '{0}'" -f $Servicename)
            $Databases = Split-Table -Table $Databases -Columns Hostname,Servicename,Database,IsOnline,DataSizeMB,DataFreeMB,DataUsedPercent
        }
        Catch {}
        $Databases.Tablename = 'Databases'

        # $Devices = New-Object System.Data.Datatable
        # Try {
        #     $Devices = Select-Table -Table $Script:Checkout.Tables['Get-Device'] -Select ("Servicename = '{0}'" -f $Servicename)
        # }
        # Catch {}
        # $Devices.Tablename = 'Devices'
        $ErrorLog = New-Object System.Data.DataTable 'ErrorLog'
        Try {
            $ErrorLog = Select-Table -Table $Script:Checkout.Tables['Get-ErrorLog'] -Select ("Servicename = '{0}'" -f $Servicename)
            $ErrorLog = Split-Table -Table $ErrorLog -Columns Time,ErrorMessage
        }
        Catch {}
        $ErrorLog.TableName = 'ErrorLog'

        $UserData = @{
            'ReportInfo' = $Script:Info;
            'Tables' = @($Uptime,$Databases,$ErrorLog);
        }

        $ContentHTML = Invoke-Template 'SmartTable' -UserData $UserData -TemplateParameters $Params

        # Email
        If($Script:Info['Recipients']) {
            $Message = New-Email -Subject $ReportTitle -To ($Script:Info['Recipients'] -split ',')

            $BodyHtml = New-Body ($ContentHTML|Out-String).Trim()  "text/html"
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
    }

}

