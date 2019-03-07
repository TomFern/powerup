# Check for SQL Server install path compression

Set-StrictMode -version Latest

New-Variable -Scope Script 'IHost'
New-Variable -Scope Script 'SystemSet'
New-Variable -Scope Script 'CheckCompress'

Import-Power 'Table'
Import-Power 'Path'


################################################
#
# Inputs
#
################################################

function StepPre {
    Param([HashTable]$usr,[HashTable]$Id)

    $Script:SystemSet = $usr['System.Windows']
    $Script:IHost = $Script:SystemSet.Tables['IHost']
    $Script:Id = $id

}


################################################
#
# Outputs
#
################################################

function StepNext {

    $Script:SystemSet.Tables['NTFS_Compress'].Rows>$null
    return @{
        'System.Windows' = $Script:SystemSet;
    }
}


################################################
#
# Process
#
################################################

function StepProcess {

    $CheckCompress = New-Object System.Data.DataTable 'NTFS_Compress'

    $CheckCompress.Columns.Add((New-Object System.Data.DataColumn 'Hostname',([String])))
    $CheckCompress.Columns.Add((New-Object System.Data.DataColumn 'Path',([String])))
    $CheckCompress.Columns.Add((New-Object System.Data.DataColumn 'FolderCompressed',([Bool])))

    function _is_compressed {
        Param($path)
        $attr = Get-Item -Path $path -Force | Select-Object -ExpandProperty Attributes
        if($attr) {
            return (($attr -band [IO.FileAttributes]::Compressed) -eq [IO.FileAttributes]::Compressed)
        }
        return $false
    }

    $RowCount = 0
    $RowTotal = ($Script:IHost|Measure-Object).Count
    Foreach($Server in $Script:IHost) {
        $RowCount += 1
        $computer = $Server.Hostname
        # write-host $computer
        Write-Progress -Activity "SQL Server Folders" -Status "Test Compressed" -CurrentOperation $computer -PercentComplete ($RowCount/$RowTotal)

        $path1 = "C:\Program Files\Microsoft SQL Server"
        $row = $CheckCompress.NewRow()
        $row.hostname = $computer
        $row.Path = $path1
        $row.FolderCompressed = $false
        if((test-path $path1) -and(_is_compressed $path1)) {
            # Write-Warning ("[Probe.System.CheckFolder.MSSQL] WARNING: Compressed folder {0}: {1}" -f $computer,$path1)
            $row.FolderCompressed = $true
        }
        $CheckCompress.Rows.Add($row)
    }

    If(($Script:SystemSet|Get-Table) -contains 'NTFS_Compress' ) {
        $Script:SystemSet.Tables.Remove('NTFS_Compress')
    }

    Write-Progress -Activity "SQL Server Folders" -Status "Complete" -Completed
    $Script:SystemSet.Tables.Add($CheckCompress)
}

