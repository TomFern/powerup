# Smart Table Dump
#
# TemplateData = @{
#  'Tables' = @($Tab1,$Tab2);
#  'ReportInfo' = [HashTable];
#  ...
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
$Info = $TemplateData['ReportInfo']
$Title = 'REPORT TITLE'
# $Date = (Get-Date|Out-String)
# $Date = $Date -replace "`n","" -replace "`r",""
# $Date = $Date.Trim()
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

function _table_single_row {
    param($Title, $Table)
@'
    <table class="ui very basic collapsed celled table">
'@
'    <thead><tr><th colspan="2">{0}</th></tr></thead>' -f $Title
@'
      <tbody>
'@
        $Row = $Table.Rows[0]
        Foreach($Col in $Row.Table.Columns) {
    '        <tr>'
             If($Col.ColumnName -match '^_') { continue }
             If($Col.Caption -ne $Col.ColumnName) { $Caption = $Col.Caption } else { $Caption = '' }
             $rowvalue = (($Row.($Col.ColumnName) -replace $nl,'<br/>')|Out-String).Trim()
             If($rowvalue.Length -eq 0) { $rowvalue = "&nbsp;" }
'            <td>{0}{1}</td><td>{2}</td>' -f [String]$Col.ColumnName,[String]$Caption,[string]$rowvalue,$nl
    '        </tr>'
        }
@'
      </tbody>
    </table>
'@
}

function _table_multi_row {
    param($Title, $Table)
@'
    <table class="ui very basic collapsed celled table">
      <thead>
        <tr>
'@
        Foreach($Col in $Table.Columns) {
          If($Col.ColumnName -match '^_') { continue }
'         <th>{0}</th>' -f $Col.ColumnName
        }
@'
        </tr>
      </thead>
      <tbody>
'@
        Foreach($Row in $Table.Rows) {
'        <tr>'
           Foreach($Col in $Row.Table.Columns) {
             If($Col.ColumnName -match '^_') { continue }
             If($Col.Caption -ne $Col.ColumnName) { $Caption = $Col.Caption } else { $Caption = '' }
             $rowvalue = (($Row.($Col.ColumnName) -replace $nl,'<br/>')|Out-String).Trim()
             If($rowvalue.Length -eq 0) { $rowvalue = "&nbsp;" }
'            <td>{0}{1}</td>' -f [String]$rowvalue,[String]$Caption
           }
'        </tr>'
        }
@'
      </tbody>
    </table>
'@
}

# For each Table with at least 1 row
foreach($Table in $TemplateData['Tables']){
    # If($e.value.gettype().Name -ne 'DataTable') { continue }
    # $Table = $e.value
    $TableTitle = $Table.TableName
    $TableRowCount = ($Table.Rows|Measure).Count

    If($TableRowCount -eq 1) {
        _table_single_row $TableTitle $Table
    }
    elseif($TableRowCount -gt 1) {
        _table_multi_row $TableTitle $Table
    }
}


# REPORT INFO

@'
        <div class="ui clearing compact secondary segment">
            <table class="ui very basic table">
            <tbody>
'@
    Foreach($Name in ($Info.Keys | Sort-Object)) {
'               <tr><td>{0}</td><td>{1}</td></tr>{2}' -f $Name,$Info[$Name],$nl
    }
@'
            </tbody>
            </table>
        </div>

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
    </div>
'@

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

