# Email Sending Functions

# Quick SYNOPSIS
#
# $Message = New-Email -Subject "MYSUBJECT" -From "dbastaff@example.com" -To "dbastaff@example.com"
# $Body = New-Body "This is a plain text" "text/plain"
# Add-Body $Message $Body
# $Html = New-Body "<html>this is html</html>" "text/html"
# $Image = New-EmbededImage 'pie.png' 'image/png' 'CidPIE'
# Add-EmbeddedImage $Html $Image
# Add-Body $Message $Html
# Send-Email $Message 'smtp.example.com'
# $Image.Dispose()

Function New-Attachment
{
    <#
    .SYNOPSIS
        Create attachment for Email
    .DESCRIPTION
        Create a new object to be attached to an Email
    .PARAMETER Path
        Path to the file to be attached
    .PARAMETER Mime
        The mime type for the object, e.g. 'text/plain'
    .PARAMETER Name
        Attachment name, defaults the file name
    .PARAMETER Inline
        (Switch) If set attach the contents of the file inline.
    .EXAMPLE
        $At = New-Attchment 'file.csv' 'text/plain'
        Add-Attachment $Message $At
    #>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)][String]$Path,
        [Parameter(Mandatory=$true)][String]$Mime,
        [String] $Name="",
        [Switch] $Inline
    )
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    $AbsPath = ConvertTo-AbsolutePath $Path
    if(-not(Test-Path $AbsPath)) {
        Throw "[New-Attachment] File not found $AbsPath"
    }

    $Attachment = New-Object Net.Mail.Attachment($AbsPath)
    $Attachment.ContentDisposition.Inline = $False
    if($Inline) {
        $Attachment.ContentDisposition.Inline = $True
    }
    If($Name) {
        $Attachment.Name = $Name
    }
    $Attachment.ContentType.MediaType = $Mime

    return $Attachment

} # end function New-Attachment

Function Add-Attachment
{
    <#
    .SYNOPSIS
        Add Attachment to a message
    .DESCRIPTION
        Adds an attachment object to a Email message object
    .PARAMETER Message
        The Email message created with New-Email
    .PARAMETER Attachment
        The Attachment object created with New-Attachment
    .EXAMPLE
        $At = New-Attchment 'file.csv' 'text/plain'
        Add-Attachment $Message $At
    #>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)][Object] $Message,
        [Parameter(Mandatory=$true)][Object] $Attachment
    )
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    $Message.Attachments.Add($Attachment)
    return $Message
} # end function Add-Attachment

Function New-Email
{
    <#
    .SYNOPSIS
        Create an Email Message
    .DESCRIPTION
        Creates an Email object, you'll need to add a body with Add-Body afterwards.
        You may use Add-Attachment and Add-EmbeddedImage to add files to the Email.
    .PARAMETER Subject
        The Subject Line of the Email
    .PARAMETER To
        A String[] with Recipient email addresses: a@a.com,b@b.com
    .PARAMETER From
        The email address for the From field
    .PARAMETER CC
        Like To but for Carbon Copy
    .PARAMETER BCC
        Like To but for Blind Carbon Copy
    .EXAMPLE
        $Message = New-Email -To a@a.com -From b@b.com -Subject "Hello B"
        $Body = New-Body "This is the body text" 'text/plain'
        Add-Body $Message $Body
        Send-Email $Message 'smtp.example.com'
    #>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)][String] $Subject,
        [Parameter(Mandatory=$true)][String[]] $To,
        [String]$From=$GLOBAL:_PWR['DEFAULTS']['smtp']['from'],
        [String[]]$CC=$null,
        [String[]]$BCC=$null
    )
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    $Message = New-Object System.Net.Mail.MailMessage
    $Message.Subject = $Subject
    $Message.From = (New-Object System.Net.Mail.MailAddress $From)
    Foreach($rcpt in $To) {
        $Message.To.Add((New-Object System.Net.Mail.MailAddress $rcpt.Trim()))
    }
    if($CC -ne $null) {
        Foreach($rcpt in $CC) {
            $Message.CC.Add((New-Object System.Net.Mail.MailAddress $rcpt.Trim()))
        }
    }
    if($BCC -ne $null) {
        Foreach($rcpt in $BCC) {
            $Message.BCC.Add((New-Object System.Net.Mail.MailAddress $rcpt.Trim()))
        }
    }
    return $Message
} # end function New-Email

Function New-Body
{
    <#
    .SYNOPSIS
        Create a Body object
    .DESCRIPTION
        Creates a Body object to be inserted in an Email Message.
        For plain text emails use Mime='text/plain'
        For html emails use Mime='text/html'
        You may add both types of content.
    .PARAMETER Body
        A String with the body of the email, may be plain text or html code
    .PARAMETER Mime
        The mime type of the content, use either 'text/plain' or 'text/html'
    .EXAMPLE
        $Message = New-Email -To a@a.com -From b@b.com -Subject "Hello B"
        $Body = New-Body "This is the body text" 'text/plain'
        Add-Body $Message $Body
        Send-Email $Message 'smtp.example.com'
    #>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)][String] $Body,
        [Parameter(Mandatory=$true)][String] $Mime
    )
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    $Content = [System.Net.Mail.AlternateView]::CreateAlternateViewFromString($Body, $null, $Mime)
    return $Content
} # end function New-Body

Function Add-Body
{
    <#
    .SYNOPSIS
        Add a body object to an Email Message
    .DESCRIPTION
        Adds a body object created with New-Body to an Email message created with New-Email
    .PARAMETER Message
        Message object created with New-Email
    .PARAMETER Body
        Body content created with New-Body
    .EXAMPLE
        $Message = New-Email -To a@a.com -From b@b.com -Subject "Hello B"
        $Body = New-Body "This is the body text" 'text/plain'
        Add-Body $Message $Body
        Send-Email $Message 'smtp.example.com'
    #>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)][Object] $Message,
        [Parameter(Mandatory=$true)][Object] $Body
    )
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    $Message.AlternateViews.Add($Body)
    return $Message
} # end function Add-Body

Function New-EmbeddedImage {
    <#
    .SYNOPSIS
        Create embedded image object
    .DESCRIPTION
        Creates an embedded image to be added inline to an body object
        You'll need to add an html body and provide matching src for the supplied ContentId

        <img src="cid:MyCustomId"/>

        You'll need to add the Image to the Body using Add-EmbeddedImage

    .PARAMETER Path
        Path to the image file
    .PARAMETER Mime
        The mime type of the image, e.g. 'image/png'
    .PARAMETER ContentId
        The content id string for the image. To be useful it should match the html cid string.
    .EXAMPLE
        $img = New-EmbededImage 'pie.png' 'image/png' 'MyPieGraph'
        $Body = New-Body '<html><body><img src="cid:MyPieGraph"/></body></html>' 'text/html'
        Add-EmbeddedImage $Body $img
        # Send Email ... then release lock
        $img.Dispose()

    #>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)][String] $Path,
        [Parameter(Mandatory=$true)][String] $Mime,
        [Parameter(Mandatory=$true)][String] $ContentId
    )
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    $AbsPath = ConvertTo-AbsolutePath $Path
    if(-not(Test-PAth $AbsPath)) {
        Throw "[New-EmbeddedImage] File not found: $AbsPath"
    }

    $resource = New-Object System.Net.Mail.LinkedResource($AbsPath,$mime)
    $resource.ContentId = $ContentId
    return $resource
} # end function New-EmbeddedImage

Function Add-EmbeddedImage
{
    <#
    .SYNOPSIS
        Add an embedded image object to an Body object
    .DESCRIPTION
        Add an embedded image to a body.

        You'll need to add an html body and provide matching src for the supplied ContentId

        <img src="cid:MyCustomId"/>

        You'll need to add the Image to the Body using Add-EmbeddedImage
    .PARAMETER Body
        The Body object created with New-Body, should be of 'text/html' type to work correctly.
    .PARAMETER Img
        The Image object created with New-EmbededImage
    .EXAMPLE
        $img = New-EmbededImage 'pie.png' 'image/png' 'MyPieGraph'
        $Body = New-Body '<html><body><img src="cid:MyPieGraph"/></body></html>' 'text/html'
        Add-EmbeddedImage $Body $img
        # send email .. then release lock
        $img.Dispose()

    #>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)][Object] $Body,
        [Parameter(Mandatory=$true)][Object] $Img
    )
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    $Body.LinkedResources.Add($Img)
    return $Body
} # end function Add-EmbeddedImage

Function Send-Email
{
    <#
    .SYNOPSIS
        Send an Email
    .DESCRIPTION
        Send an email message created with New-Email.

        SMTP Server parameters default to defaults.smtp config

    .PARAMETER Message
        The Email Message
    .PARAMETER SMTPServer
        The SMTP Server hostname of IP Address
    .PARAMETER Port
        The SMTP Server Port (defaults to 25)
    .PARAMETER Username
        Username when using authenticated connections.
    .PARAMETER Password
        Password when using authenticated connections.
    .EXAMPLE
        $Message = New-Email -Subject "MYSUBJECT" -From "a@a.com" -To "b@b.com"
        $Body = New-Body "This is a plain text" "text/plain"
        Add-Body $Message $Body
        $Html = New-Body "<html>this is html</html>" "text/html"
        Add-Body $Message $Html
        Send-Email $Message 'smtp.example.com'
    #>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)][Object] $Message,
        [String] $SMTPServer=$GLOBAL:_PWR['DEFAULTS']['smtp']['server'],
        [Int] $Port=$GLOBAL:_PWR['DEFAULTS']['smtp']['port'],
        [String] $Username=$GLOBAL:_PWR['DEFAULTS']['smtp']['auth_username'],
        [String] $Password=$GLOBAL:_PWR['DEFAULTS']['smtp']['auth_password']
    )
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'
    $Client = New-Object System.Net.Mail.SmtpClient $SMTPServer
    if($Port) {
        $Client.Port = $Port
    }
    if($Username -and($Password)) {
        $Client.Credentials = New-Object System.Net.NetworkCredential($Username,$Password)
    }
    $Client.Send($Message)
} # end function Send-Email
