# Generic Storage using Powershell export csv

Set-StrictMode -version Latest

New-Variable -Scope Script 'EveryUsr'
New-Variable -Scope Script 'Date'

Import-Power 'Table'

################################################
#
# Inputs
#
################################################

function StepPre {
    Param([HashTable]$usr,[HashTable]$Id)

    $Script:EveryUsr = $usr
    $Script:Date = $id['StartDateTime']
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

    $Lock = Lock-File -Name 'Storage.Store.DataSet.Internal.lock' -Timeout 1200
    If(-not($Lock['locked'])) {
        Throw "Timed out trying to acquire lock"
    }

    # $StorageDir = Join-Path $GLOBAL:_PWR['STORAGEDIR'] 'Internal'
    # New-Item -Type D -Force $StorageDir >$null

    # $MapperSchema = New-Table_TableMapper
    # $Mapper = $null
    # Try {
    #     $Mapper = Unfreeze-Table $MapperSchema.TableName $StorageDir
    # }
    # Catch {
    #     $Mapper = $MapperSchema.Clone()
    # }

    # Freeze all DS's
    Foreach($key in $Script:EveryUsr.Keys) {
        # $Converted = @{}
        if($Script:EveryUsr[$key].gettype().name -eq 'DataSet') {
            $DSName = $key
            $Script:EveryUsr[$key].DataSetName = $DSName
            Freeze-Dataset $Script:EveryUsr[$key] -Timeout 1200
            # $Converted = ConvertTo-Storage -Mapper $Mapper -Dataset $Script:EveryUsr[$key] #-Exclude IHost,IService
            # Foreach($tname in $Converted.Keys) {
            #         Write-Verbose "[Store.Database.Internal] Inserting table $tname from dataset $DSName"
            #         Freeze-Table $Converted[$tname] $StorageDir
            #     }
        }
    }

    # Update TableMapper
    # Freeze-Table $Mapper $StorageDir

    # Update special files
    # $idfn = Join-Path $StorageDir 'PROJECT_ID'
    # $keyfn = Join-Path $StorageDir 'PROJECT_KEY'
    # $datefn = Join-Path $StorageDir 'LAST_UPTDATE'
    # new-item -type f -force $idfn
    # new-item -type f -force $keyfn
    # new-item -type f -force $datefn
    # set-content $idfn $GLOBAL:_PWR['defaults']['project_id']
    # set-content $keyfn $GLOBAL:_PWR['defaults']['project_key']
    # set-content $datefn $Script:Date

    Unlock-File $Lock -Remove
}



