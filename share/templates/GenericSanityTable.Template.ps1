# Example/Generic Sanity Report. Formatted Text Table Version
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
#   'LinkCss' = [Bool];     # When true: use css linkref. When false or undef, embed css in <style> tags (eg. for email) (DOESNT APPLY TO TEXT)
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

$Title = 'REPORT TITLE'
$Date = (Get-Date|Out-String)
$Date = $Date -replace "`n","" -replace "`r",""
$Date = $Date.Trim()
If($Params.ContainsKey('Title')) { $Title = ($Params['Title']|Out-String).trim() }
If($Params.ContainsKey('Date')) { $Date = ($Params['Date']|Out-String).trim() }

$MinAttentionCount = 1
If($Params.ContainsKey('MinAttentionCount')) { $MinAttentionCount = $TemplateParameters['MinAttentionCount'] }

$nl = [Environment]::NewLine


"-----------------------------------------------------------------------------"
" Title: " + $Title
" Date: " + $Date
""
""
"== Counters =="
""

$Counters | Format-Table -Autosize | Out-String


# ---- Missing Data & Summary
If(($Missing|Measure-Object).Count -gt 0) {
    ""
    ""
    "== Missing Data =="
    ""

    $Missing | Format-Table -Autosize | Out-String
}


""
""
"== Issues Found =="
""


# ---- Data with AttentionCount

Foreach($Group in $Summary.Select("_AttentionCount >= $MinAttentionCount","_Role DESC,_GID ASC")) {
    "" + $Group._GID + " ---------- " + [String]$Group._SummaryMessage
    ""
    $Group | Format-Table -Autosize | Out-String

    ""
}


""
""
"== Summary =="
""


# ---- Summary

$Summary | Format-Table -Autosize | Out-String


""
""
"== Info =="
""


# ---- ReportInfo

Foreach($Name in ($Info.Keys | Sort-Object)) {
    "   {0} =  {1}" -f $Name,$Info[$Name]
}
"-----------------------------------------------------------------------------"
