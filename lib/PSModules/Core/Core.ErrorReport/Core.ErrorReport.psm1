# Send Report Module

Import-Power 'Email'

Function Send-ErrorReport
{
    <#
    .SYNOPSIS
        Send Error Report by Email
    .DESCRIPTION
        Sends an Email with relevant error information and an optional message
    .PARAMETER Message
        Optional Message to send in email body
    .PARAMETER Recipients
        Email address separated by commas, defaults to operator in (Get-Config 'address')
    .EXAMPLE
        # Simple Report
        Send-ErrorReport

        # Add custom message and change recipient
        Try{
            Foo
        }
        Catch{
            Send-ErrorReport -Message $_.Exception.Message -Recipients 'op@example.com'
        }

    #>
    [cmdletbinding()]
    Param(
        [String]$Message="NO MESSAGE",
        [String]$Recipients=""
    )
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    If($Recipients.Length -eq 0) {
        Try{
            $Recipients = (Get-Config 'address')['operator']
        }
        Catch {
            Write-Warning "[Send-ErrorReport] No -Recipients supplied and no operator found in config. I give up."
            return
        }
    }

    $Subject = ("Error Report from {0}" -f $GLOBAL:_PWR['CURRENT_HOSTNAME'])

    $nl = [Environment]::Newline
    $Text  =       ("Error Report from {0}{1}" -f $GLOBAL:_PWR['CURRENT_HOSTNAME'],$nl)
    $Text +=       "---------------------------------------------------------------------$nl"
    $Text +=       ("{0}{1}" -f $Message,$nl)
    $Text +=       "---------------------------------------------------------------------$nl"
    $Text +=       "ENVIRONMENT$nl$nl"
    $Text +=       (" BASEDIR={0}$nl LOCALDIR={1}$nl PSARCH={2}$nl VERSION={3}" -f $GLOBAL:_PWR['BASEDIR'],$GLOBAL:_PWR['LOCALDIR'],$GLOBAL:_PWR['PSARCH'],$GLOBAL:_PWR['VERSION'])
    $Text +=       $nl
    $Text +=       "---------------------------------------------------------------------$nl"
    $Text +=       "ERROR$nl$nl"
    $Text +=       ($error|Out-String).Trim()
    $Text +=       "---------------------------------------------------------------------$nl"
    $Text +=       "END OF REPORT"

    # return text in interactive mode
    if($GLOBAL:_PWR['INTERACTIVE']) {
        return $Text
    }

    Try {
        $EmailMessage = New-Email -Subject $Subject -To ($Recipients -split ',')
        $BodyText = New-Body ($Text|Out-String).Trim() "text/plain"
        Add-Body $EmailMessage $BodyText | Out-Null
        Send-Email $EmailMessage $SMTP['smtp_server']
    }
    Catch {
        Write-Warning ("[Send-ErrorReport] Error send email: {0}" -f $_.Exception.Message)
    }
    Finally {
        $BodyText.Dispose()
        $EmailMessage.Dispose()
    }
} # end function Send-ErrorReport
