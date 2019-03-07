#
# Simple Logging functions
#

function Write-Log{
    param(  
    $message="",
    [string] $filename="",
    [string] $severity=" ",
    [bool] $console=$false
    ) 
    process {
        $text = $message.ToString()
        $timestamp = (get-date -uformat "%Y-%m-%d %H:%M:%S").ToString()
        if($console) {
            "{0}" -f $text
        }
        if($filename) {
            if(-not(test-path $filename)) {
                New-Item -ItemType f -Path $filename | Out-Null
            }
            $append = "[{0}]{1}{2}" -f $timestamp,$severity,$text
            Add-Content -Path $filename -value $append
        }
    }
}

