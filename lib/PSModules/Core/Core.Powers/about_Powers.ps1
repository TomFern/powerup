# Help File

Function about_Powers
{
    <#
    .SYNOPSIS
        Core help for Powerup ABOUT_POWERS
    .DESCRIPTION
        Powerup is a framework intended to help with database and system administration tasks.
        Currently the main focus is MS SQL Server, and Sybase ASE is planned in the future.
        Powerup is written in Powershell v2 and it's recommended that .NET 3.5 is installed.

        Requirements:
            * Powershell v2
            * Run unsigned scripts on powershell

        Features:
            * Separate Config files
            * Reusable scripts/jobs (we call them chores)
            * Portable installation: everything needed is bundled in one convenient package
            * Local overrides for configs, modules and scripts
            * Powershell based online help
            * Online documentation
            * Extensible: adding or replacing modules is simple
            * Unit tested: supports unit testing coverage with [Pester](https://github.com/pester/Pester)

        The first thing is to load the Powerup library:

            cd path\to\installation
            . lib\Powerup.ps1

        This will load the required modules, create the environment variables and load the core functions.

        Once this is complete you may check the state of the _PWR variable:

            $GLOBAL:_PWR

        Will show the initalized values.

        Powers ships with an online help, to get started with the most important ones:

            help about_Topics   - index of important functions and topics
            help about_Modules  - how modules work in Powers
            help about_Hier     - describes the directory structure
            help about_Config   - how config files work

        Some modules have they own separate config files, e.g. to see the chores help:

            Import-Power chores
            help about_Chores

    .LINK
        about_Topics
        about_Modules
        about_Hier
        about_Config
    #>
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'
} # end function about_Powers


Function about_Topics
{
    <#
    .SYNOPSIS
        Main topics for Powers
    .DESCRIPTION
        Please see the RELATED LINKS. To read about a topic type:
            help <about_topic>

        Example:
            help about_Modules

    .LINK
        about_Powers
        about_Modules
        about_Hier
        about_Config
    #>
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'
} # end function about_Powers

Function about_Modules
{
    <#
    .SYNOPSIS
        Powershell Modules for Powers
    .DESCRIPTION
        The Powerup suite ship with a number of Powershell modules that perform different tasks.

        The recommended way of loading a module is using [Import-Power]. This is a wrapper around the built-in
        [Import-Module] that automatically locates and loads the appropiate module files.
        [Import-Power] also extends the namespace by using the dot (.) sign. This works like python (or perl's :: sign).
        [Import-Power] is aliased to [Use] so you may use that instead.

        To remove a module use [Remove-Power] or [NoUse]

        Writing a Module

            Because [Import-Power] extends the namespace you need to consider how the dot translates to subdirectories.
            So the module called A.B.C would have the following directory structure:

            PSMODULES_DIR/
                A/
                  B/
                    A.B.C/
                         A.B.C.psm1

            This is because the name of the module is the full name including the dots.

            [Import-Power] respects the LOCALDIR so you may write your own module overrides outside and load them instead.

    .LINK
        about_Topics
        about_Hier
        Import-Power
        Remove-Power
    #>
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'
} # end function about_Powers


Function about_Hier
{
    <#
    .SYNOPSIS
        Describes directory structure

    .DESCRIPTION

        The starting point of a Powerup installation marked by the BASEDIR file. This file is used to locate the working directory
        so it should not be removed.

        Directories end with /

       BASEDIR
        |
        +-- BASEDIR            -- file that marks the starting point of the hierarchy
        +-- lib/
        |   +-- PSModules/     -- starting location for modules (PSMODULES_DIR)
        |   +-- PSAssemblies/  -- starting location for assemblies (PSASSEMBLIES_DIR)
        +-- config/            -- config files (*.cfg)
        |   +-- chores/        -- config/setup files for chores (*.cfg)
        +-- chores/            -- scripts/steps for chores (*.psm1)
        +-- share/             -- shared data
        |   +-- examples/      -- example scripts
        |   +-- redist/        -- redistributable modules/assemblies/icons (REDISTDIR)
        |   +-- samples/       -- sample data/tables for testing (SAMPLEDIR)
        |   +-- templates/     -- templates (TEMPLATEDIR)
        |   +-- icons/         -- image/icons (ICONDIR)
        +-- tmp/               -- temporary files (TMPDIR)
        |   +-- run/           -- runtime files (RUNDIR)
        +-- log/               -- log files / errorlogs (LOGDIR)
        +-- storage/           -- persistent arbitrary data and reports (STORAGEDIR)


        About LOCALDIR

            A localdir contains site specific configs, modules, and chore steps that override the Powerup release files.
            The localdir also is a place to store log, temp and storage files. It's recommended to always use a localdir
            to upgrading/replacing the Powerup release is easier and no customizations are lost.

            To create a localdir you can use Install-Localdir. You can activate an existing localdir with ". Set-Localdir" or by
            initializing powerup from an existing localdir.

       LOCALDIR
        |
        +-- LOCALDIR            -- file that marks the starting point of the hierarchy
        +-- lib/
        |   +-- PSModules/     -- Local override for modules
        +-- config/            -- Local override for config
        |   +-- chores/        -- Local override for chores config
        +-- chores/            -- Local override for chores step
        +-- storage/           -- Local override for storage (STORAGEDIR) and reports
        +-- invoke/            -- Local scripts
        +-- tmp/               -- temporary files and dir (TMPDIR)
        +-- log/               -- log files (LOGDIR)


    .LINK
        about_Topics
        about_Modules
        about_Config
        Install-Localdir
        Set-Localdir
    #>
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'
} # end function about_Powers


Function about_Config
{
    <#
    .SYNOPSIS
        Config files in Powers
    .DESCRIPTION
        Config files in Powers are just JSON files. These are stored on the 'config' directory.

        A list of configs can be found with [List-Configs].

        In order to read a config you may use the [Get-Config] function that will deserialize the file and return
        a hashtable/array structure.

        The same namespace rules from Modules apply to configs (see about_Modules), so you may use the dot sign to
        organize the configs:

            Get-Config My.Big.Config

        Will look for the file:

            ./config/My/Big/My.Big.Config.json

        Some modules will look for a config when imported, e.g. Inventory will do Get-Config Inventory on load.

        Powerup.ps1 will do a "Get-Config config" when starting to initialize things suchs as PATH, etc.

    .LINK
        about_Topics
        about_Modules
        about_Config
        Get-Config
        List-Configs
    #>
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'
} # end function about_Powers
Export-ModuleMember -Alias * -Function * -Cmdlet *
