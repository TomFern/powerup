# Powershell-based templates

Function Invoke-Template
{
    <#
    .SYNOPSIS
        Run a template
    .DESCRIPTION
        Run a powershell template script with user supplied data. The result is retured.

        The template name is mapped to a file like:

            $TemplateDir\${TemplateName}.Template.ps1

        You can supply data to the template in a hashtable with $UserData

        You can supply parameters to the template with the hashtable $TemplateParameters
    .PARAMETER TemplateName
        The template name. The actual file name is $TemplateDir\${TemplateName}.template.ps1
    .PARAMETER UserData
        A HashTable that maps variables to data for the template.
    .PARAMETER TemplateParameters
        A HashTable with Parameters to pass to the template
    .PARAMETER TemplateDir
        Path to directory with templates. Defaults to $_PWR.TEMPLATEDIR
    .EXAMPLE
        $data = @{
            'foo' = 'bar';
        }
        $content = Invoke-Template 'Example' -TemplateName mytemplate -UserData $data
    #>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)][String] $TemplateName,
        [HashTable] $UserData = @{},
        [HashTable] $TemplateParameters = @{},
        [String] $TemplateDir = $GLOBAL:_PWR['TEMPLATEDIR']
    )
    $verbose = $VerbosePreference -ne 'SilentlyContinue'
    $debug = $DebugPreference -ne 'SilentlyContinue'

    $templatefn = ("{0}.Template.ps1" -f $TemplateName)
    $tpath = Join-Path $TemplateDir $templatefn
    if(-not(Test-Path $tpath)) {
        Throw "[Invoke-Template] File not found: $tpath"
    }

    $errorfn = New-TempFile $GLOBAL:_PWR['TMPDIR']

    $TemplateMeta = @{
        'TemplateDir' = $TemplateDir;
    }
    $TemplateData = $UserData

    $content = &$tpath 2>$errorfn

    $errors = Get-Content $errorfn
    if($errors) {
        Throw "[Invoke-Template] Errors found while running template: $errors"
    }
    Remove-Item $errorfn

    return $content
} # end function Invoke-Template
