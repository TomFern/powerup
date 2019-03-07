#
# Help File
#

Function about_DBI
{
    <#
    .SYNOPSIS
        Help for DBI
    .DESCRIPTION
        DBI present a standard inteface to access different Databases and Datasources. Inspired by the Perl DBI module (hence the name),
        but much more primitive and basic.

        Each connection/datasource type has it's separate DBI module. Each DBI module exports the same functions so you may reuse the code:

            New-DBI - Defines a DBI HashTable config
            Open-DBI - Attempts to connect to the datasource
            Close-DBI - Disconnects from the datasource
            Confirm-DBI - Checks DBI config and if connection is opened
            Invoke-DBI - Executes an arbitrary SQL code and returns a .NET DataSet
            Write-DBI - Receives a .NET DataTable and attempts to insert all the rows in a table

        Since all the DBIs have the same functions you may be more specific when needed with something like:

            Import-Power DBI.MSSQL
            Import-Power DBI.CSV

            $set1 = DBI.MSSQL\Invoke-DBI "SELECT * FROM master..sysdatabases"
            $set2 = DBI.CSV\Invoke-DBI "Select * from [mytable.csv]"

        DBI Lifecycle:

            A DBI starts by defining a Connection String:

                Import-Power DBI.MSSQL
                $dbi = New-DBI "Data Source=SRV1\Inst1;Trusted Connection=True"

            Once the dbi hash is defined you may try to open a connection:

                Open-DBI $dbi

            If connection is opened you'll the dbi hash has been updated:

                
            You may run SQL commands now with:

                if(Confir-DBI $dbi) { 
                    $result = Invoke-DBI "SQL BATCH"
                }

            Once work is done you should close the DBI:

                Close-DBI $dbi

        DBI Modules:

            DBI.MSSQL - For Microsoft SQL Server. Driver: ADO.NET
            DBI.CSV - For CSV Files. Driver: Microsoft Jet OLEDB
            DBI.ASE - For Sybase ASE. Driver: ODBC "Adaptive Server Enterprise"

        You need to ensure the correct drivers and libraries are installed on your system


    .LINK
        help New-DBI
        help Open-DBI
        help Confirm-DBI
        help Invoke-DBI
        help Write-DBI
        help Close-DBI
        about_Modules
    #>
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'
} # end function about_DBI


