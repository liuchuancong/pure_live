param(
    [int]$Throttle    = 30,
    [int]$TimeoutApi  = 10,
    [int]$TimeoutAsset = 15
)

$apiUrl   = "https://api.github.com/"
$assetUrl = "https://github.com/git/git/archive/refs/tags/v2.43.0.tar.gz"

$proxies = @(
    # ===== 你指定的 =====
    "https://gh-proxy.org/"
    "https://gh.h233.eu.org/"
    "https://git.yylx.win/"
    "https://ghproxy.cc/"
    "https://cdn.gh-proxy.org/"
    "https://wget.la/"
    "https://github.ednovas.xyz/"
    "https://down.npee.cn/?"
    "https://slink.ltd/"
    "https://gitproxy.click/"

    # ===== 之前实测可用 =====
    "https://edgeone.gh-proxy.org/"
    "https://hk.gh-proxy.org/"
    "https://gh.noki.eu.org/"
    "https://gh-proxy.com/"
    "https://gh-proxy.eu.org/"
    "https://gh.con.sh/"
    "https://gh-proxy.net/"
    "https://gh-proxy.pages.dev/"
    "https://ghproxy.link/"
    "https://tvv.tw/"
    "https://v6.gh-proxy.org/"
    "https://ghfile.geekertao.top/"
    "https://ghm.078465.xyz/"
    "https://ghproxy.cxkpro.top/"
    "https://proxy.gitwarp.top/"
    "https://gh.catmak.name/"
    "https://fastgit.cc/"
    "https://ghpxy.hwinzniej.top/"
    "https://ghproxy.net/"
    "https://ghp.keleyaa.com/"
    "https://ghproxy.monkeyray.net/"
    "https://g.blfrp.cn/"
    "https://gh.ddlc.top/"
    "https://gh.xxooo.cf/"
    "https://ghproxy.imciel.com/"
    "https://github.geekery.cn/"
    "https://gitproxy.mrhjx.cn/"
)

# 若存在 ghproxy.txt，则从文件读取
if (Test-Path "ghproxy.txt") {
    $proxies = Get-Content "ghproxy.txt" |
        Where-Object { $_ -notmatch '^\s*#' -and $_ -notmatch '^\s*$' } |
        ForEach-Object { $_.Trim() }
}

$probeScript = {
    param($proxy, $apiUrl, $assetUrl, $timeoutApi, $timeoutAsset)
    $base  = $proxy.TrimEnd('/')
    $api   = "$base/$apiUrl"
    $asset = "$base/$assetUrl"
    $apiCode   = & curl.exe -L -s -o NUL -w "%{http_code}" --max-time $timeoutApi $api 2>$null
    $assetCode = & curl.exe -L -s -o NUL -w "%{http_code}" --max-time $timeoutAsset -r 0-0 $asset 2>$null
    [PSCustomObject]@{
        Proxy = $proxy
        Api   = "$apiCode"
        Asset = "$assetCode"
    }
}

$isPS7 = $PSVersionTable.PSVersion.Major -ge 7
Write-Host "PowerShell $($PSVersionTable.PSVersion) - 并发数 $Throttle" -ForegroundColor Cyan

$sw = [System.Diagnostics.Stopwatch]::StartNew()

if ($isPS7) {
    $results = $proxies | ForEach-Object -Parallel {
        & $using:probeScript $_ $using:apiUrl $using:assetUrl $using:TimeoutApi $using:TimeoutAsset
    } -ThrottleLimit $Throttle
}
else {
    $pool = [runspacefactory]::CreateRunspacePool(1, $Throttle)
    $pool.Open()
    $jobs = foreach ($p in $proxies) {
        $ps = [powershell]::Create()
        $ps.RunspacePool = $pool
        [void]$ps.AddScript($probeScript.ToString()).
            AddArgument($p).AddArgument($apiUrl).AddArgument($assetUrl).
            AddArgument($TimeoutApi).AddArgument($TimeoutAsset)
        [PSCustomObject]@{ PowerShell = $ps; Handle = $ps.BeginInvoke() }
    }
    $results = foreach ($j in $jobs) {
        try   { $j.PowerShell.EndInvoke($j.Handle) }
        finally { $j.PowerShell.Dispose() }
    }
    $pool.Close(); $pool.Dispose()
}

$sw.Stop()

function Get-CodeColor([string]$code) {
    switch ($code) {
        { $_ -in 200,206 }         { return 'Green' }
        { $_ -in 301,302,307,308 } { return 'Yellow' }
        default                    { return 'Red' }
    }
}

Write-Host ""
Write-Host ("{0,-45} {1,-5} {2,-5}" -f "代理", "api", "asset") -ForegroundColor White
Write-Host ("{0,-45} {1,-5} {2,-5}" -f "----", "---", "-----") -ForegroundColor DarkGray

foreach ($r in ($results | Sort-Object Proxy)) {
    Write-Host ("{0,-45} " -f $r.Proxy) -NoNewline
    Write-Host ("{0,-5} " -f $r.Api)   -NoNewline -ForegroundColor (Get-CodeColor $r.Api)
    Write-Host ("{0,-5}"   -f $r.Asset)             -ForegroundColor (Get-CodeColor $r.Asset)
}

Write-Host ""
Write-Host ("共 {0} 个代理，耗时 {1:N1}s" -f $proxies.Count, $sw.Elapsed.TotalSeconds) -ForegroundColor Cyan

Write-Host ""
Read-Host "按 Enter 键退出"