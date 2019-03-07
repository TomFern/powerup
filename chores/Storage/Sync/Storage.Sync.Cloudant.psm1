﻿# Upload/Download from IBM Cloudant

Set-StrictMode -version Latest

New-Variable -Scope Script 'Now'

Import-Power 'Table'
Import-Power 'PSCX'
Import-Power 'IBM.Cloudant'
Import-Power 'File.Lock'

################################################
#
# Inputs
#
################################################

function StepPre {
    Param([HashTable]$usr,[HashTable]$Id)

    $Script:Now = $id['StartDateTime']
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

    $Lock = Lock-File -Name 'Storage.Sync.Cloudant.lock' -Timeout 1200
    If(-not($Lock['locked'])) {
        Throw "Timed out trying to acquire lock"
    }

    $InternalDir = Join-Path $GLOBAL:_PWR['STORAGEDIR'] 'Internal'
    $StorageDir = $GLOBAL:_PWR['STORAGEDIR']
    # $SyncDir = ('{0}\{1}' -f $GLOBAL:_PWR['STORAGEDIR'],'SyncCloudant.csv')
    # $SyncFn = ('{0}\{1}' -f $GLOBAL:_PWR['STORAGEDIR'],'SyncCloudant.csv')

    $SyncTable = ''
    Try {
        $SyncTable = Unfreeze-Table 'SyncCloudant' $StorageDir
    }
    Catch {
    # If(test-path -pathtype leaf $SyncFn) {
    #     $SyncTable = Unfreeze-Table $SyncFn
    # }
    # else {
        $SyncTable = New-Object System.Data.DataTable 'SyncCloudant'
        [void]$SyncTable.Columns.Add('BundleName',[String])
        [void]$SyncTable.Columns.Add('SourceModifyDate',[DateTime])
        [void]$SyncTable.Columns.Add('SyncDate',[DateTime])
        # write-host "new table has risen"
    }

    # Upload Internal snapshot
    $bundlename = 'internal'
    # $db = $client['db']
    $now = $Script:Now
    $lastfn = (Get-ChildItem $InternalDir -Filter '*.csv' | Sort { $_.LastWriteTime } | Select -Last 1)
    $last = $lastfn.LastWriteTime
    # write-host ("last mod: {0}" -f $last)
    $hrows = $SyncTable.select(("BundleName = '{0}' AND SourceModifyDate < '{1}'" -f $bundlename,$last))
    $upload = $false
    if((($SyncTable.Rows|measure).count -eq 0) -or(($hrows|measure).count -gt 0)) {
        $upload = $true
        $zipfn = New-TempFile -Extension '.zip'
        # write-host $zipfn
        $filelist = @()
        Get-ChildItem $InternalDir -Filter '*.csv' | Write-Zip -OutputPath $zipfn -FlattenPaths

        $doc = @{
            "origin" = "powerup";
            "hostname" = $GLOBAL:_PWR['CURRENT_HOSTNAME'];
        }

        $form = @()
        foreach($k in $doc.keys) {
            $form += ("{0}={1}" -f $k,$doc[$k])
        }
        $data = $form -join '&'

        # open client session
        if($upload) {
            # write-host REQUEST SESSION
            $client = Request-Session
            # write-host CREATE DOC
            $response = Invoke-Request -Client $client -RequestMethod 'POST' -Location '%d/_design/handler/_update/new_bundle/' -Data $data
            if(-not($response['ok'])) {
                Throw ("Request failed POST: {0}" -f $response['reason'])
            }
            # write-host $response
            # write-host get REV
            $response = Invoke-Request -Client $client -RequestMethod 'GET' -Location ('%d/{0}' -f $response['_id'])
            if(-not($response['_id'])) {
                Throw ("Failed to get _id")
            }
            # write-host $response
            # write-host upload attachment
            $options = @()
            $options += ('-H Content-Type: application/zip')
            $options += ('--data-binary `@"{0}"' -f $zipfn)
            Invoke-Request -Client $client -RequestMethod 'PUT' -Location ('%d/{0}/bundle.zip?rev={1}' -f $response['_id'],$response['_rev']) -CurlOptions $options >$null
            # write-host $response
            # write-host ($response|fc -force)
            $newrow = $SyncTable.NewRow()
            $newrow['BundleName'] = $bundlename
            $newrow['SourceModifyDate'] = $last
            $newrow['SyncDate'] = $now
            $SyncTable.Rows.Add($newrow)
            Freeze-Table -Table $SyncTable -Path $StorageDir
        }
    }
    Unlock-File $Lock -Remove
}
