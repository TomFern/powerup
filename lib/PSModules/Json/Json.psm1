# Json Parser

Import-Power 'Assemblies.WebExtensions'

# powershell 2.0 doesn't have json builtin
# but we can workaround that using System.Web.Extension

Function ConvertTo-Json20
{
    <#
    .SYNOPSIS
        Convert Objects to JSON
    .DESCRIPTION
        Converts Powershell Objects to JSON
        
        Conversion will fail if the object can't be serialized.
    .PARAMETER Object
        The object to convert.
    .EXAMPLE
       $foo = @{ "Hello"="World";}
       ConvertTo-Json20 $foo
       {
        "Hello": "World"
       }
    #>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)][Object] $Object
    )
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'
    
    Add-Type -assembly system.web.extensions
    $ps_js=New-Object system.web.script.serialization.javascriptSerializer
    $ps_js.recursionlimit = 100
    return $ps_js.Serialize($Object) 
}

If((Get-Command | Where { $_.Name -eq 'ConvertTo-Json' } | Measure-Object).Count -eq 0) {
    Set-Alias ConvertTo-Json ConvertTo-Json20
}

Function ConvertFrom-Json20
{
    <#
    .SYNOPSIS
        Read a JSON String
    .DESCRIPTION
        Convert a JSON String into a Powershell Object
    .PARAMETER String
        The string to parse
    .EXAMPLE
    $a = @'
    { 
        "Hola": "Mundo"; 
    }
    '@
    ConvertFrom-Json20 $a
    @{ "Hola"="Mundo"; }
    #>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)][String] $String
    )
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'
    
    add-type -assembly system.web.extensions 
    $ps_js=new-object system.web.script.serialization.javascriptSerializer
    return $ps_js.DeserializeObject($String) 
}

If((Get-Command | Where { $_.Name -eq 'ConvertFrom-Json' } | Measure-Object).Count -eq 0) {
    Set-Alias ConvertFrom-Json ConvertFrom-Json20
}

Export-ModuleMember -Function * -Alias *
