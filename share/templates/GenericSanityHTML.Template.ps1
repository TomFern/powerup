# Example/Generic Sanity Report. HTML Version
#
# TemplateData = @{
#   'Counters' = [DataTable];    # Special: [Int]_Ord
#   'Data' = [DataTable];        # Special: [String]_GID, [String]_Role, [Bool]_Attention
#   'Summary' = [DataTable];     # Special: [String]_GID, [String]_Role, [Int]_AttentionCount, [String]_SummaryMessage
#   'DataMissing' = [DataTable]; # Special: [String]_GID
#   'ReportInfo' = [HashTable];
# }
#
# TemplateParameters = @{
#   'Title' = [String];     # Title for the report
#   'Date' = [String];      # Date string for the report
#   'GraphUrl' = [String];  # A URL or CID for counter's graph eg. a pie graph
#   'LinkCss' = [Bool];     # When true: use css linkref. When false or undef, embed css in <style> tags (eg. for email)
#   'MinAttentionCount' = [Int]; # Minimun AttentionCount for showing GID detail warning table, defaults to 1
#
# }
#
# SPECIAL COLUMNS
#
# Summary:
# _GID = [String] Group ID. Logically groups 1 row in summary with many rows in 'Data'. eg Hostname or Instance or Service Name ...
# _Role = [String] Server/Service Role. eg Prod, Test, UAT, DEV ...
# _AttentionCount = [Int] How many warnings/errors for the GID
# _SummaryMessage = [String] A string that describes the GID information
#
# Data:
# _GID = [String] Group ID. Logically groups 1 row in summary with many rows in 'Data'. eg Hostname or Instance or Service Name ...
# _Role = [String] Server/Service Role. eg Prod, Test, UAT, DEV ...
# _Attention = [Bool] When true row shows different colors

# DataMissing:
# _GID = [String] Group ID. Logically groups 1 row in summary with many rows in 'Data'. eg Hostname or Instance or Service Name ...
#


# TemplateData import values
$Info = $TemplateData['ReportInfo']
$Counters = $TemplateData['Counters']
$Summary = $TemplateData['Summary']
$Data = $TemplateData['Data']
$Missing = $TemplateData['DataMissing']
$Params = $TemplateParameters
$GraphUrl = $Params['GraphUrl']
$LinkCss = $false
if($Params.ContainsKey('LinkCss')) {
    $LinkCss = $Params['LinkCss']
}

$TemplateDir = $TemplateMeta['TemplateDir']

$Title = 'REPORT TITLE'
$Date = (Get-Date|Out-String)
$Date = $Date -replace "`n","" -replace "`r",""
$Date = $Date.Trim()
If($Params.ContainsKey('Title')) { $Title = ($Params['Title'] | Out-String).Trim() }
If($Params.ContainsKey('Date')) { $Date = ($Params['Date']|Out-String).trim() }

$MinAttentionCount = 1
If($Params.ContainsKey('MinAttentionCount')) { $MinAttentionCount = $TemplateParameters['MinAttentionCount'] }

$nl = [Environment]::NewLine
$br = '<br/>'

# css stylesheets
$CSSFiles = @()
$CSSFiles += Join-Path $TemplateDir 'css/email_semanticui_min.css'
$CSSFiles += Join-Path $TemplateDir 'css/common.css'


# DOCUMENT START

"<html>$nl"
"<head>$nl"
"<title>$Title</title>$nl"
if($LinkCss) {
    $CSSFiles | Foreach {
'   <link rel="stylesheet" type="text/css" href="{0}"/>{1}' -f $_,$nl
    }
}
else {
'   <style type="text/css">'+$nl
    $CSSFiles | Foreach {
        Get-Content $_
    }
    $nl
"   </style>$nl"
}
@'
</head>
<body>

    <div id="PAGE">
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


# COUNTERS & GRAPH

@'
        <table style="width:100%">
            <tbody>
                <tr>
                    <td>
                        <table class="ui very basic table">
                        <thead>
                            <tr>
'@
                            Foreach($Col in $Counters.Columns) {
                                If($Col.ColumnName -match '^_') { continue }
                                # If($Col.ColumnName -eq '_Ord') { continue }
'                                <th class="right aligned">{0}</th>{1}' -f $Col.ColumnName,$nl
                            }
@'
                            </tr>
                            </thead>
                            <tbody>
'@
                            Foreach($Row in $Counters.Select("","_Ord ASC")) {
"                                <tr>$nl"
                                Foreach($Col in $Row.Table.Columns) {
                                If($Col.ColumnName -match '^_') { continue }
                                    # if($Col.ColumnName -eq 'Ord') { continue }
                                    If($Col.Caption -ne $Col.ColumnName) { $Caption = $Col.Caption } else { $Caption = '' }
'                                    <td class="right aligned">{0} {1}</td>{2}' -f [String]$Row.($Col.ColumnName),[String]$Caption,$nl
                                }
"                                </tr>$nl"
                            }
@'
                            </tbody>
                        </table>
                </td>
                <td>
'@
                    '<img class="ui medium image centered" src="'+[string]$GraphUrl+'" alt="Graph for Counters"/>'
@'
                </td>
            </tr>
        </table>
'@


# MISSING DATA

If(($Missing|Measure-Object).Count -gt 0) {
'   <div class="ui clearing compact secondary segment">'+$nl
'       <strong>Warning!</strong> Missing Data. Service might be down:'+$br+$nl
'       <p>'
            Foreach($Row in $Missing) {
"          <em>{0}</em>{1}" -f $Row['_GID'],$br
            }
'       </p>'
"   </div>"
}


# DETAILS FOR SERVERS WITH WARNINGS

$NumCols = ($Data.Columns|Measure-Object).Count
Foreach($Group in $Summary.Select("_AttentionCount >= $MinAttentionCount","_Role DESC,_GID ASC")) {

    # 2 columns used on header (GID,Role) + 2 columns hidden (GID, Attention)
    $colspan = $NumCols-2
    if($colspan -le 0) { $colspan = 1}

@'
        <table class="ui single line table striped">
        <thead>
            <tr>
'@
'               <th>{0} <span class="badged-grey">{1}</span></th>{2}' -f $Group['_GID'],$Group['_Role'],$nl
'               <th colspan="{0}" class="right aligned">{1}</th>{2}' -f ($colspan),$Group['_SummaryMessage'],$nl
@'
            </tr>
        </thead>
        <tbody>
'@
    Foreach($Row in $Data.Select(("_GID = '{0}'" -f $Group['_GID']))) {
        If($Row['_Attention'] -eq $true) {
'           <tr class="negative">'+$nl
        }
        else {
'           <tr>'+$nl
        }
        Foreach($Col in $Row.Table.Columns) {
            If($Col.ColumnName -match '^_') {
                continue
            }
'               <td class="right aligned">{0}</td>{1}' -f [String]$Row.($Col.ColumnName),$nl
        }
'           </tr>'+$nl
    }
@'
        </tbody>
    </table>
'@
}

# SUMMARY TABLE

        $NumCols = ($Summary.Columns|Measure-Object).Count

        # 2 columns hidden (AttentionCount, SummaryMessage)
        $colspan = $NumCols - 2

        if($colspan -le 0) { $colspan = 1 }
@'
        <table class="ui very basic collapsed celled table">
            <thead>
                <tr>
'@
'                   <th colspan="{0}">Summary</th>{1}' -f $colspan,$nl
@'
                </tr>
            </thead>
            <tbody>
'@
        Foreach($Row in $Summary.Select("","_AttentionCount DESC, _Role Desc, _GID ASC")) {
            If($Row['_AttentionCount'] -gt 0) {
'             <tr class="negative">'+$nl
            }
            else {
'             <tr>'+$nl
            }
            Foreach($Col in $Row.Table.Columns) {
                If($Col.Caption -ne $Col.ColumnName) { $Caption = $Col.Caption } else { $Caption = '' }
                if($Col.ColumnName -eq '_GID') {
    '               <td class="left aligned">{0} {1}</td>{2}' -f [String]$Row.($Col.ColumnName),[String]$Caption,$nl
                }
                elseif($Col.ColumnName -eq '_Role') {
    '               <td class="right aligned"><span class="badged-grey">{0}</span></td>{1}' -f [String]$Row.($Col.ColumnName),$nl
                }
                elseif($Col.ColumnName -match '^_') {
                    continue
                }
                else {
    '               <td class="right aligned">{0} {1}</td>{2}' -f [String]$Row.($Col.ColumnName),[String]$Caption,$nl
                }
            }
'             </tr>'+$nl
        }
@'
            </tbody>
        </table>
'@


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

</body>
</html>
'@
