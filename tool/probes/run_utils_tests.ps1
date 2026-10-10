$env:PATH = 'D:\flutter\flutter\flutter\bin;C:\Windows\System32;C:\Windows;C:\Windows\System32\WindowsPowerShell\v1.0;C:\Program Files\Git\cmd;C:\Program Files\Git\usr\bin;' + $env:PATH
Set-Location D:\flutter\pure_live\packages\foundation\utils
Write-Host '===ANALYZE==='
& dart.bat analyze 2>&1
Write-Host '===TEST==='
& dart.bat test 2>&1
