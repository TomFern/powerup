# Test Path

Import-Power 'Pester'
Import-Power 'Path' -Reload

Describe "Path" {
    It "Join-Path2 #1" {
        Join-Path2 "a","b","c","d" | Should Be "a\b\c\d"
    }
    It "Join-Path2 #2" {
        Join-Path2 "C:\Program Files\Microsoft SQL Server" | Should Be "C:\Program Files\Microsoft SQL Server"
    }
    It "ConvertTo-AbsolutePath #1" {
        ConvertTo-AbsolutePath (Join-Path $GLOBAL:_PWR['DEFAULTDIR'] 'log') | Should Be $GLOBAL:_PWR['LOGDIR']
    }
    It "ConvertTo-AbsolutePath #2" {
        ConvertTo-AbsolutePath (Join-Path $GLOBAL:_PWR['DEFAULTDIR'] 'tmp') | Should Be $GLOBAL:_PWR['TMPDIR']
    }
    It "ConvertTo-RemotePath #1" {
        ConvertTo-RemotePath "C:\Windows" "FOO" | Should Be "\\FOO\C$\Windows"
    }
    It "ConvertTo-RemotePath #2" {
        ConvertTo-RemotePath "D:\Program Files\Microsoft" "BAR" | Should Be "\\BAR\D$\Program Files\Microsoft"
    }
    It "ConvertTo-LocalPath #1" {
        ConvertTo-LocalPath "\\FOO\C$\Windows" | Should Be "C:\Windows"
    }
    It "ConvertTo-LocalPath #2" {
        ConvertTo-LocalPath "\\BAR\D$\Program Files\Microsoft" | Should Be "D:\Program Files\Microsoft"
    }
}
