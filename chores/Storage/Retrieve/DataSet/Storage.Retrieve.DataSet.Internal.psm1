# Generic Retrieve using Powershell export csv

Set-StrictMode -version Latest

# New-Variable -Scope Script 'EveryUsr'
New-Variable -Scope Script 'Retrieve'

Import-Power 'TableMapper'
Import-Power 'Table'
Import-Power 'File.Lock'

################################################
#
# Inputs
#
################################################

function StepPre {
    Param([HashTable]$usr,[HashTable]$Id)
    $Script:EveryUsr = $usr
}


################################################
#
# Outputs
#
################################################

function StepNext {
    return $Script:Retrieve
}


################################################
#
# Process
#
################################################

function StepProcess {

    $Lock = Lock-File -Name 'Storage.Retrieve.DataSet.Internal.lock' -Timeout 1200
    If(-not($Lock['locked'])) {
        Throw "Timed out trying to acquire lock"
    }

    $StorageDir = Join-Path $GLOBAL:_PWR['STORAGEDIR'] 'Internal'
    New-Item -Type D -Force $StorageDir >$null

    $MapperSchema = New-Table_TableMapper
    $Mapper = $null
    Try {
        $Mapper = Unfreeze-Table $MapperSchema.TableName $StorageDir
    }
    Catch {
        $Mapper = $MapperSchema.Clone()
    }

    $DataSetAvailable = ($Mapper|Select -Property DataSetName -Unique)
    $Script:Retrieve = @{}
    Foreach($DSObj in $DataSetAvailable) {
        If($Script:EveryUsr.ContainsKey($DSObj.DataSetName) -and($Script:EveryUsr[$DSObj.DataSetName].Gettype().Name -eq 'DataSet')) {
            $TableAvailable = ($Mapper.Select(("DataSetName = '{0}'" -f $DSObj.DataSetName)))
            Foreach($TableObj in $TableAvailable) {
                $TableStorage = Unfreeze-Table -Name $TableObj.MapName -Path $StorageDir
                $Table = ConvertFrom-Storage -Mapper $Mapper -Table $TableStorage

                If(-not($Script:Retrieve.ContainsKey($DSObj.DataSetName))) {
                    $Script:Retrieve[$DSObj.DataSetName] = New-Object System.Data.DataSet $DSObj.DataSetName
                }
                $Script:Retrieve[$DSObj.DataSetName].tables.add($Table)
            }
        }
    }
    Unlock-File $Lock -Remove
}




