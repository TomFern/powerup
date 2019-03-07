
Function about_Chores
{
    <#
    .SYNOPSIS
        Help about using Chores module

    .DESCRIPTION

        Workflow Chart

        Event     (Invoke-Chore)  (Oops! Error)                    (Last Step)
        Status        ACTIVE         ERROR      ACTIVE     ACTIVE     STOP
                       +---+         +---+      +---+       +---+    +---+
        Index          | 0 |-> ..  ->| i |      | m |-----> | n |--->| g |
                       +---+         +---+      +---+       +---+    +---+
                         ^             |          ^                    |
                         |             |          |                    |
                         |       (Invoke-Chore) --+              (Invoke-Chore)
                         |          -From m                         -From 0
                         +---------------------------------------------+


        The chores module let's you write reusable scripts that can tied togheter to execute more complex tasks.

        A chore is composed of:

            - A config file with the chore description and steps to run (see help about_Config_Chores)
            - One or several scripts which are called steps and live on the chores/ directory.

        The chores and config names share the Import-Power naming scheme, so you can override them using a LOCALDIR (see about_Powers for more info)


        WORKFLOW

            INTIALIZE - the state the chore is after New-Chore
            ACTIVE - the chore is running
            STOP - the chore completed w/o error
            ERROR - the chore stopped due to an error


        HANDLE

            New-Chore will return a HashTable composed of:
            @{
                'User' = [HashTable] - User Variables for steps
                'Id' = @{
                    'ChoreName' = [String] Chore name
                    'Description' = [String] Chore description
                    'Config' = [HashTable] Configurations loaded at start
                    'StartDateTime' = [DateTime] Chore start time
                    'StopDateTime' = [DateTime] Chore stop time
                    'DurationTime' = [TimeSpan] Chore duration
                };
                'Requires' = @{
                    'ConfigsToLoad' = [Array] Configs to be loaded at start
                    'MustBeElevated' = [Bool] True if the sessions needs to be elevated to run
                    'RequiresArchitecture' = [String] Required architecture '32-bit', '64-bit' or 'any'
                };
                'Control' = @{
                    'ChoreWorkflow' = [String] Workflow status keyword
                    'ErrorActionPrevious' = [String] The value of $ErrorActionPreference before the chore started
                    'ErrorActionThis' = [String] ErrorAction to use during the chore execution
                    'ErrorCode' = [String] Keyword for the terminating error
                    'HistoryFile' = [String] Path to the history csv file
                    'LastErrorMessage' = [String] Contents of terminating error
                    'OutFile' = [String] Path to transcript size
                    'StepCurrentFile' = [String] Current step file in execution
                    'StepCurrentIndex' = [Int] Current step index in execution
                    'StepFilesList' = [Array] Paths to all step files in correct order
                    'StepList' = [Array] Step names in order
                }
            }




        CONTROL

            New-Chore - Parses configuration, searches and validates steps, and returns a handle.
            Invoke-Chore - Starts the chore, can be used to resume an chore that had errors
            Start-Chore - Same as Invoke-Chore but runs in background as a PS Job.


        A typical invokation of chores:

            Import-Power 'Chores'

            $cfg = Get-Config 'chores.foo'
            $handle = New-Chore $cfg
            Try {
                Invoke-Chore $handle
            }
            Catch {
                Write-Error "Ooops!"
            }


        STEPS

            The steps are just powershell module scripts (extension .psm1). Any exceptions or terminating errors will cause the chore to stop
            in ERROR state thus careful planning and exception trapping is required. Alternatively you can use the $ErrorActionPreference
            (or the -OnError parameter in Invoke-Chore which does the same) to continue after errors.

            Steps should be written in a re-usable way. For example a step can retrieve information from a database and store it in a DataTable
            that is passed along. Other steps can process the table in different ways and do different things.

            The following functions MUST be defined:

            StepPre - Input Params([HashTable]$User,[HashTable]$Id)
                Receives two HashTables: the first is $User which may be used to retrieve user variables;
                the second is contains metadata about the chore such as the chore name, the current index number, etc

            StepProcess
                No input parameters. The main code block of the step should be here

            StepNext
                No input parameters. Should return a single HashTable, the keys will be added to _CO automatically thus be
                available for the following steps. The names of the return variables should be descriptive and coherent.


        EXAMPLE STEP

            New-Variable -Scope Script 'Foo'
            New-Variable -Scope Script 'Bar'

            function StepPre {
                Param([HashTable]$Usr,[HashTable]$Id)
                $Script:Foo = $Usr['Foo']
            }

            function StepProcess {

                # Main Script Block

                # Results
                $Script:Bar = ....
            }

            function StepNext {
                return {
                    'Bar' = $Script:Bar;
                }
            }


        OTHER FUNCTIONS

            Search-Chore - Finds configs under the chore namespace and returns all available chores
            Debug-Step - Runs a single step file with provided variables


    .LINK
        about_Chores_Config
        Invoke-Chore
        Start-Chore
    #>
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'
} # end function about_Chores

Function about_Config_Chores
{
    <#
    .SYNOPSIS
        Help about Setup for for Chores

    .DESCRIPTION

        Chore setup file contains information about the chore including the steps
        to run.

        The chore namespace is used for these files so they located on "config/chores/chores.<name>.cfg"

        Format for file is (ps1):

            @{
                "name"= "chore name";
                "description" = "short description about the chore";
                "requires" = @{
                    "configs"= @("config name"; "more configs to merge");
                    "arch" = "any";
                    "elevated"=$false;
                }
                "steps"= @(
                    "Partial.Path.To.Step";
                    "Relative.To.chores";
                    "Order.Is.Important";
                );
            };

        REMARKS:

        -> "configs" is an array with configs names to load. [Invoke-Chore] will call [Get-Config] for each word in the array.
            All the keys/values will be merged into [$GLOBAL:CHORE['config']] so order matters.

        -> "elevated" is a bool, when true the session elevation state is checked (run as administrator) and the chore fails if not elevated

        -> "arch" can be 'any', '32-bit' or '64-bit'

    .LINK
        help about_Chores
        help about_Powers
        help about_Topics

    #>
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'
} # end function about_Config_Chores

Function about_Chore_Names {
<#
    .SYNOPSIS
        Naming guide for chore steps and variables

    .DESCRIPTION

        CHORE STEPS NAMING GUIDE

            - Use between 2 and 5 namespaces separated by dot (.)

            - Always use single names, not plural

            - If a step covers different level functions, use the more specific level as name.

            - 1st namespace is high level task/function:
                * Probe: Read-only, low-impact, wide-coverage query. eg. get uptime, get disks
                * Execute: Run programs, invoke high-impact tasks. eg. backup/restore
                * Install: Copy programs/tools, create procedures, tables, databases
                * Filter: Process in-memory datatables. eg. Probe Database -> Backup Filter
                * Store: Save results to datasource
                * Retrieve: Read results from datasource
                * Report: Generate text/html reports, send notification emails
                * Debug: For debugging and testing
                * Maintenance: For housekeeping

            - 2nd namespace is for component level:
                * System: operating system level action eg a windows server
                * Service: service level action. eg. SQL Server instance
                * Database: database level action

            - 3rd a one-word description of action performed or information collected

            - 4th and 5th if required, for disambiguation, maybe platform, brand or product, etc.

            Examples:
                Probe.System.Uptime.Windows - Get Windows server level information
                Probe.Service.Uptime.MSSQL - Get SQL Server instance level information
                Probe.Database.Uptime.MSSQL - Get SQL Server database level information
                Execute.Database.Backup.ASE - Start a Sybase ASE database dump/backup
                Filter.Database.Backup.MSSQL - Process database information into backup tables
                Report.Database.Backup - Generate a database backup report


        CHORE USER VARIABLES NAMING GUIDE

            - Some well known names are:
                * Config: [HashTable] merged configuration
                * Inventory: [DataSet] Inventory host/service data (see New-Inventory)
                * Recipients: [String] Comma separated list of emails
                * Title: [String] A title for report or subject for email

            - Most of the variables will probably be DataTables: Use between 2 to 5 names separated by colon (:)

            - Always use single names, not plural

            - 1st name for component level:

                * System: Operating system level, one row per host, eg. Windows
                * Service: Service level, such as SQL Server instance, one row per service, eg. MSSQL
                * Database: Database level, one row per database, eg. master

            - 2nd name for type of data contained on datatable:

                * Uptime: State information
                * Backup: Backup information
                * Disk: Disk information
                * etc...

            - 3rd name for component type, platform, product or brand. eg Windows, MSSQL, etc

            - 4th and 5th name for disambiguation when required, eg. Filter for processed data

            Examples:
                System:Uptime:Windows - State information for Windows
                System:Disk:Windows - Disk information for Windows
                Service:Disk:MSSQL - Disk information for SQL Server
                Database:Uptime:MSSQL - Database state information for SQL Server
                Database:Backup:MSSQL:Filter - Processed backup information, eg. converted from Database:Uptime:MSSQL
                Service:Backup:MSSQL:Filter - Instance level backup information
        <`7`>
    .LINK
        about_Chores
        about_Config_Chores
#>
} # end function about_Chore_Names

