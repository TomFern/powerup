# test template for Invoke-Template
Set-StrictMode -Version latest

@'
<html>
<head>
<title>Test Template</title>
</head>
<body>
<h1>Current Services</h1>
<table>
    <tr><th>Status</th><th>Name</th></tr>
'@

$tableSvc = {
     $status = $_.Status
    $name = $_.DisplayName

    if ($status -eq 'Running')
    {
        '<tr>'
        '<td bgcolor="#00FF00">{0}</td>' -f $status
        '<td bgcolor="#00FF00">{0}</td>' -f $name
        '</tr>'
    }
    else
    {
        '<tr>'
        '<td bgcolor="#FF0000">{0}</td>' -f $status
        '<td bgcolor="#FF0000">{0}</td>' -f $name
        '</tr>'
    }
}

$Svc = $TemplateData['Services']
$Svc | Foreach-Object -Process $tableSvc | Out-String

@'
</table>
</body>
</html>
'@

