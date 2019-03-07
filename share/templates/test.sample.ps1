# test template with data

Import-Power 'Templates'
$data = @{
'Services' = Get-Service
}
$content = Invoke-Template -TemplateName 'test' -UserData $data

$content

