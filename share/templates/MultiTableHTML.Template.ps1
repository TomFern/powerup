# Simple Table Dump: Dump all datatables
# Intended for simple technical or debug reports
#
# TemplateData = @{
#  .. All supplied variables should be datatables ..
# }
#
# TemplateParameters = @{
#   'Title' = [String];     # Title for the report
#   'Date' = [String];      # Date string for the report
# }
#
# All columns starting with _ are skipped
#

$TemplateDir = $TemplateMeta['TemplateDir']

$Params = $TemplateParameters
$Title = 'REPORT TITLE'
$Date = (Get-Date|Out-String)
$Date = $Date -replace "`n","" -replace "`r",""
$Date = $Date.Trim()
If($Params.ContainsKey('Title')) { $Title = ($Params['Title'] | Out-String).Trim() }
If($Params.ContainsKey('Date')) { $Date = ($Params['Date']|Out-String).trim() }

$nl = [Environment]::NewLine
$br = '<br/>'

# css stylesheets
$CSSFiles = @()
$CSSFiles += Join-Path $TemplateDir 'css/email_semanticui_min.css'


# DOCUMENT START

"<html>$nl"
"<head>$nl"
"<title>$Title</title>$nl"
'   <style type="text/css">'+$nl
    $CSSFiles | Foreach {
        Get-Content $_
    $nl
    }
"   </style>$nl"

# HEADER
@'
</head>
<body>

<table class="ui single line table">
<thead>
    <th class="left aligned">
'@
        $Title
@'
    </th>
    <th class="right aligned">
'@
        $Date
@'
    </th>
</thead
</table>
'@


Foreach($ThisKey in $TemplateData.Keys) {
    $ThisTable = $TemplateData[$ThisKey]
'<h3>{0}</h3>' -f $ThisTable.TableName
@'
    <table class="ui very basic collapsed celled table">
      <thead>
        <tr>
'@
        Foreach($Col in $ThisTable.Columns) {
          If($Col.ColumnName -match '^_') { continue }
'         <th>{0}</th>{1}' -f $Col.ColumnName,$nl
        }
@'
        </tr>
      </thead>
      <tbody>
'@
        Foreach($Row in $ThisTable.Rows) {
'        <tr>'+$nl
           Foreach($Col in $Row.Table.Columns) {
             If($Col.ColumnName -match '^_') { continue }
             If($Col.Caption -ne $Col.ColumnName) { $Caption = $Col.Caption } else { $Caption = '' }
             $rowvalue = (($Row.($Col.ColumnName) -replace $nl,'<br/>')|Out-String).Trim()
             If($rowvalue.Length -eq 0) { $rowvalue = "&nbsp;" }
'            <td>{0}{1}</td>{2}' -f [String]$rowvalue,[String]$Caption,$nl
           }
'        </tr>'+$nl
        }
@'
      </tbody>
    </table>
'@
}

# FOOTER
@'
    <div class="ui divider"></div>
    <table class="ui single line table">
    <thead>
        <th class="left aligned">DBA Team</th>
        <th class="right aligned">
'@
          $Date
@'
        </th>
    </thead
    </table>
</body>
</html>
'@
