# Cleanup sybsecurity archive

Set-StrictMode -version Latest

New-Variable -Scope Script 'IService'
New-Variable -Scope Script 'Config'

Import-Power 'DBI.ASE'
# Import-Power 'PShould'


################################################
#
# Inputs
#
################################################

function StepPre {
    Param([HashTable]$usr,[HashTable]$Id)

    $Script:IService = $usr['Service.ASE'].Tables['IService']

    $Script:Config = $Id['Config']['sybase']
    $Script:Config['audit']['archive_database']>$null
    $Script:Config['audit']['archive_table_owner']>$null
    $Script:Config['audit']['archive_table']>$null
    $Script:Config['audit']['cleanup_days']>$null

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

    $auditdb = $Script:Config['audit']['archive_database']
    $auditowner = $Script:Config['audit']['archive_table_owner']
    $audittable = $Script:Config['audit']['archive_table']
    $days = $Script:Config['audit']['cleanup_days']

    $batch = 10000

    $sql = @"
use $auditdb;
"@


    Foreach($Service in $Script:IService) {

        $Hostname = $Service['Hostname']
        $Instance = $Service['Instancename']
        $Port = $Service['Port']

        # Get password from config
        $cfg = $Script:Config['sybase']['login']
        $Username = ''
        $Password = ''
        if($cfg.containskey($Hostname) -and($cfg[$Hostname].containskey($Instancename)) {
            $username = $cfg[$Hostname][$Instancename]['username']
            $password = $cfg[$Hostname][$Instancename]['password']
        }
        else {
            $username = $cfg['_DEFAULT']['username']
            $password = $cfg['_DEFAULT']['password']
        }

        # Try to open a connection to server
        $DBi = DBI.ASE\New-DBI "dsn=$Instance;db=master;na=$Hostname,$Port;uid=$Username;pwd=$Password"

        try {
            DBI.ASE\Open-DBI $dbi
        }
        catch {
            Write-Warning ("[Maintenance.Audit.ASE] Connection to failed for: {0}. Error was: {1}" -f $instance,$_.Exception.Message)
        }

        # Execute Dump if connected
        If((DBI.ASE\Test-DBI $dbi) -eq 'OPEN') {
            Try {
                DBI.ASE\Invoke-DBI -DBI $DBi -Query $sql
            }
            Catch {
                Write-Warning ("[Maintenance.Audit.ASE] Query had an error on {0}: {1}" -f $instance,$_.Exception.Message)
            }
        }
        Else {
            Write-Warning ("[Maintenance.Audit.ASE] Connection to {0} is not open" -f $instance)
        }
    }
}


