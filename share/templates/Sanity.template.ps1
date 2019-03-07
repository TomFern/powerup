# Sanity report template

@'
<html>
<head>
    <title>
'@
        $TemplateData['ReportInfo']['ReportTitle']
@'
    </title>
    <style type="text/css">
'@
        Get-Content (Join-Path $TemplateDir 'email_semanticui_min.css')
        Get-Content (Join-Path $TemplateDir 'email_body.css')
        Get-Content (Join-Path $TemplateDir 'email_extra.css')
'@
    </style>
</head>
<body>

    <div id="PAGE">
    <div class="ui container">

        <div class="ui clearing secondary segment">
            <h3 class="ui right floated header blue">
'@
            $TemplateData['ReportInfo']['ReportGenerationDateTime']
@'
            </h3>
            <h3 class="ui left floated header">
'@
            $TemplateData['ReportInfo']['ReportTitle']
'@
            </h3>
        </div>

        <table style="width:100%">
            <tbody>
                <tr>
                    <td>
                        <table class="ui very basic table">
                            <thead>
                                <tr>
                                    <th>Role</th>
                                    <th>Total</th>
                                    <th>Missing</th>
                                    <th>Success %</th>
                                </tr>
                            </thead>
                            <tbody>
                                <tr>
                                    <td class="left aligned">Prod</td>
                                    <td class="center aligned">{{data.BackupCounters.DatabaseCountProduction}}</td>
                                    <td class="center aligned">{{data.BackupCounters.MissedProduction}}</td>
                                    {% if data.BackupCounters.DatabaseCountProduction > 0 %}
                                    <td class="center aligned">{{(data.BackupCounters.DatabaseCountProduction-data.BackupCounters.MissedProduction)*100/data.BackupCounters.DatabaseCountProduction|round}}%</td>
                                    {% else %}
                                    <td class="center aligned">N/A</td>
                                    {% endif %}
                                </tr>
                                <tr>
                                    <td class="left aligned">Non-Prod</td>
                                    <td class="center aligned">{{data.BackupCounters.DatabaseCountNonProduction}}</td>
                                    <td class="center aligned">{{data.BackupCounters.MissedNonProduction}}</td>
                                    {% if data.BackupCounters.DatabaseCountNonProduction > 0 %}
                                    <td class="center aligned">{{(data.BackupCounters.DatabaseCountNonProduction-data.BackupCounters.MissedNonProduction)*100/data.BackupCounters.DatabaseCountNonProduction|round}}%</td>
                                    {% else %}
                                    <td class="center aligned">N/A</td>
                                    {% endif %}
                                </tr>
                                <tr>
                                    <td class="left aligned">Total</td>
                                    <td class="center aligned">{{data.BackupCounters.DatabaseCount}}</td>
                                    <td class="center aligned">{{data.BackupCounters.MissedTotal}}</td>
                                    {% if data.BackupCounters.DatabaseCount > 0 %}
                                    <td class="center aligned">{{(data.BackupCounters.DatabaseCount-data.BackupCounters.MissedTotal)*100/data.BackupCounters.DatabaseCount|round}}%</td>
                                    {% else %}
                                    <td class="center aligned">N/A</td>
                                    {% endif %}
                                </tr>
                            </tbody>
                        </table>
                </td>
                <td>

                <img class="ui medium image centered" src="cid:GraphPie" alt="Pie Graph"/>
                </td>
            </tr>
        </table>

        {% for instance in data.BackupMissedIndex %}
        <table class="ui single line table striped">
        <thead>
            <tr>
                <th>
                    {{ data.BackupDataPerInstance[instance].ServiceName }}
                    <span class="badged-grey">{{ data.BackupDataPerInstance[instance].Role }}</span>
                </th>
                <th colspan="3" class="right aligned collapsing">
                    {{ data.BackupDataPerInstance[instance].DatabaseCount }} DBs ~
                    {{ data.BackupDataPerInstance[instance].BackupSizeMB / 1024|round }} GB total backup ~
                    Duration {{ data.BackupDataPerInstance[instance].BackupDurationSeconds / 60 / 60 | round(2,'common') }}h ~
                    Backup finished @ {{ data.BackupDataPerInstance[instance].BackupStopDateTime }}
                </th>
            </tr>
        </thead>
        <tbody>
            {% for db in data.BackupDataPerInstance[instance].BackupData %}
            <tr>
                <td class="left aligned">{{ db.DatabaseName }}</td>
                <td class="center aligned">{{ db.RecoveryModel }}</td>
                <td class="center aligned">{{ db.BackupSizeMB / 1024 | round }}GB</td>
                <!-- FIXME -->
                {% if db.BackupStatus != "OK" %}
                <td class="right aligned collapsing  warning">{{ db.BackupStatus }}</td>
                {% else %}
                <td class="right aligned collapsing">{{ db.BackupStatus }}</td>
                {% endif %}
            </tr>
            {% endfor %}
        </tbody>
        </table>
        {% endfor %}


        <table class="ui single line table striped">
            <thead>
                <tr>
                    <th colspan="6">SQL Server Instances</th>
                </tr>
            </thead>
            <tbody>
                {% for instance in data.BackupDataPerInstance %}
                {% if data.BackupDataPerInstance[instance].MissedBackups > 0 %}
                <tr class="negative">
                {% else %}
                <tr>
                {% endif %}
                <td class="left aligned">{{ data.BackupDataPerInstance[instance].ServiceName }}</td>
                <td><span class="badged-grey">{{ data.BackupDataPerInstance[instance].Role }}</span></td>
                <td class="">{{ data.BackupDataPerInstance[instance].DatabaseCount }} databases</td>
                <!-- FIXME -->
                <td class="">{{ data.BackupDataPerInstance[instance].BackupSizeMB / 1024 | round(3,'common') }} GB backup size</td>
                <td class="">{{ data.BackupDataPerInstance[instance].BackupDurationSeconds / 60 / 60|round }}h duration</td>
                {% if data.BackupDataPerInstance[instance].MissedBackups > 0 %}
                <td class="right aligned">{{ data.BackupDataPerInstance[instance].MissedBackups }} backups missing</td>
                {% else %}
                <td class="right aligned">OK</td>
                {% endif %}
                </tr>
                {% endfor %}
            </tbody>
        </table>

@'
        <div class="ui clearing compact secondary segment">
            <table class="ui very basic table">
'@
            Foreach($key in $TemplateData['ReportInfo'].Keys) {
                "<tr><td>"
                $key
                "</td><td>"
                $TemplateData['ReportInfo'][$key]
                "</td></tr>"
                }
                {% for key in data.ReportInfo %}
'@
            </table>
        </div>

        <div class="ui divider"></div>

        <div class="ui basic segment">
            <h4 class="ui right floated header blue">
                {{data.ReportInfo.ReportGenerationDateTime}}
            </h4>
            <h4 class="ui left floated header">
                COMPANY NAME
            </h4>
        </div>

    </div>

</body>
</html>
'@
