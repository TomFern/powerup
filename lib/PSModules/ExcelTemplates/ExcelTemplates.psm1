# Excel Template Tables

Import-Assembly "EPPlus"

Function Invoke-Template
{
    <#
    .SYNOPSIS
        Generate an Excel from template
    .DESCRIPTION
        Excecutes an powershell template that generates an excel file

        The template name is mapped to a file like:

            $TemplateDir\${TemplateName}.Template.ps1

        You can supply data to the template in a hashtable with $UserData

        You can supply parameters to the template with the hashtable $TemplateParameters
    .PARAMETER TemplateName
        The template name. The actual file name is $TemplateDir\${TemplateName}.template.ps1
    .PARAMTER Path
        Path to output file, should have '.xslx' extension
    .PARAMETER UserData
        A HashTable that maps variables to data for the template.
    .PARAMETER TemplateDir
        Path to directory with templates. Defaults to $_PWR['EXCELDIR']
    .EXAMPLE
        $data = @{
            'foo' = 'bar';
        }
        $content = Invoke-Template 'Example' -TemplateName mytemplate -UserData $data
    #>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)][String] $TemplateName,
        [Parameter(Mandatory=$true)][String] $Path,
        [HashTable] $UserData = @{},
        [String] $TemplateDir = $GLOBAL:_PWR['EXCELDIR']
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
        'OutputPath' = ConvertTo-AbsolutePath $Path;
    }

    $TemplateMeta
    $TemplateData = $UserData

    # $content = &$tpath 2>$errorfn
    &$tpath 1>$null 2>$errorfn

    $errors = Get-Content $errorfn
    if($errors) {
        Throw "[Invoke-Template] Errors found while running template: $errors"
    }
    Remove-Item $errorfn

    # return $content
} # end function Invoke-Template

