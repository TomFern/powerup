# Load System.Web.Extension assembly

# Try system's first
Try {
    Add-Type -assembly system.web.extensions
}
Catch {
    Write-Verbose "Can't load system.web.extensions. Trying workaround"
    If(-not(Test-Path -PathType Container (Join-Path $GLOBAL:_PWR['PSASSEMBLIES_DIR'] 'WebExtensions'))) {
        Import-Power 'Core.Redist'
        If(Test-Redist -Type 'Assembly' 'WebExtensions') {
            Install-Redist -Type 'Assembly' 'WebExtensions'
        }
        else {
            Throw "[Asemblies.WebExtensions] Assembly not installed, and redist package not found."
        }
    }
    Get-ChildItem -Recurse -Filter "*.dll" (Join-Path $GLOBAL:_PWR['PSASSEMBLIES_DIR'],'WebExtensions') | Foreach { 
        Add-Type -Path $_.fullname
    }
}

