[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$mapPath = Join-Path $PSScriptRoot 'device_ui_map.json'
$runnerPath = Join-Path $PSScriptRoot 'android_ui.ps1'
$map = Get-Content -LiteralPath $mapPath -Raw -Encoding UTF8 | ConvertFrom-Json
$profile = $map.profiles.k90pro_portrait_1200x2608
$sequence = @($profile.sequences.open_pip_danmaku_settings)
$zhMenu = -join ([char[]]@(0x83DC, 0x5355))
$zhSettings = -join ([char[]]@(0x8BBE, 0x7F6E))
$zhPipDanmaku = -join ([char[]]@(0x5C0F, 0x7A97, 0x5F39, 0x5E55))
$zhStylePreview = -join ([char[]]@(0x6837, 0x5F0F, 0x9884, 0x89C8))
$zhThemeSettings = -join ([char[]]@(0x4E3B, 0x9898, 0x8BBE, 0x7F6E))
$zhPlayerEngine = -join ([char[]]@(0x64AD, 0x653E, 0x5668, 0x5185, 0x6838))
$zhCoreKernelSettings = -join ([char[]]@(0x6838, 0x5FC3, 0x5185, 0x6838, 0x8BBE, 0x7F6E))

$tokens = $null
$parseErrors = $null
$runnerAst = [Management.Automation.Language.Parser]::ParseFile(
    $runnerPath,
    [ref]$tokens,
    [ref]$parseErrors
)
if ($parseErrors.Count -gt 0) { throw 'android_ui.ps1 must parse before route contracts are checked.' }
$enterTargetApp = $runnerAst.Find({
    param($node)
    $node -is [Management.Automation.Language.FunctionDefinitionAst] -and
        $node.Name -eq 'Enter-TargetApp'
}, $true)
if ($null -eq $enterTargetApp -or
    $enterTargetApp.Extent.Text -notmatch "'start',\s*'-W',\s*'-n'" -or
    $null -eq $enterTargetApp.Body.Find({
        param($node) $node -is [Management.Automation.Language.ForStatementAst]
    }, $true)) {
    throw 'Android UI cold entry must wait for ActivityManager and poll the actual top-resumed package.'
}
Write-Output 'PASS Android UI cold entry waits for the target foreground'

$settingsProfiles = @($map.profiles.PSObject.Properties | Where-Object {
    $_.Value.sequences.PSObject.Properties['open_settings']
})
if ($settingsProfiles.Count -eq 0) { throw 'At least one device profile must define open_settings.' }
foreach ($profileProperty in $settingsProfiles) {
    $settingsSequence = @($profileProperty.Value.sequences.open_settings)
    $settingsSemanticSteps = @($settingsSequence | Where-Object { $_.PSObject.Properties['tapSemantic'] })
    if ($settingsSemanticSteps.Count -ne 2 -or
        @($settingsSequence | Where-Object { $_.PSObject.Properties['tap'] }).Count -ne 0) {
        throw "Profile '$($profileProperty.Name)' open_settings must use live semantics for Menu and Settings."
    }
    foreach ($route in @(
        [pscustomobject]@{ Step = 0; Aliases = @($zhMenu, 'Menu') },
        [pscustomobject]@{ Step = 1; Aliases = @($zhSettings, 'Settings') }
    )) {
        $actualAliases = @($settingsSemanticSteps[$route.Step].tapSemantic | ForEach-Object { [string]$_ })
        foreach ($alias in $route.Aliases) {
            if ($actualAliases -notcontains $alias) {
                throw "Profile '$($profileProperty.Name)' open_settings step $($route.Step) is missing '$alias'."
            }
        }
    }
    $settingsAssert = @($settingsSequence | Where-Object { $_.PSObject.Properties['assertSemantic'] }) |
        Select-Object -Last 1
    if ($null -eq $settingsAssert) {
        throw "Profile '$($profileProperty.Name)' open_settings must verify its destination."
    }
    $settingsAssertAliases = @($settingsAssert.assertSemantic | ForEach-Object { [string]$_ })
    foreach ($alias in @($zhThemeSettings, 'Theme Settings')) {
        if ($settingsAssertAliases -notcontains $alias) {
            throw "Profile '$($profileProperty.Name)' open_settings is missing destination alias '$alias'."
        }
    }
}
Write-Output 'PASS settings routes use live semantics and verify the destination page'

foreach ($profileProperty in $settingsProfiles) {
    $kernelProperty = $profileProperty.Value.sequences.PSObject.Properties['open_player_kernel_settings']
    if ($null -eq $kernelProperty) {
        throw "Profile '$($profileProperty.Name)' is missing open_player_kernel_settings."
    }
    $kernelSequence = @($kernelProperty.Value)
    $kernelSemanticSteps = @($kernelSequence | Where-Object { $_.PSObject.Properties['tapSemantic'] })
    if ($kernelSemanticSteps.Count -ne 3 -or
        @($kernelSequence | Where-Object { $_.PSObject.Properties['tap'] }).Count -ne 0) {
        throw "Profile '$($profileProperty.Name)' open_player_kernel_settings must use live semantics for every tap."
    }
    foreach ($route in @(
        [pscustomobject]@{ Step = 0; Aliases = @($zhMenu, 'Menu') },
        [pscustomobject]@{ Step = 1; Aliases = @($zhSettings, 'Settings') },
        [pscustomobject]@{ Step = 2; Aliases = @($zhPlayerEngine, 'Player Engine') }
    )) {
        $actualAliases = @($kernelSemanticSteps[$route.Step].tapSemantic | ForEach-Object { [string]$_ })
        foreach ($alias in $route.Aliases) {
            if ($actualAliases -notcontains $alias) {
                throw "Profile '$($profileProperty.Name)' kernel route step $($route.Step) is missing '$alias'."
            }
        }
    }
    $kernelAssert = @($kernelSequence | Where-Object { $_.PSObject.Properties['assertSemantic'] }) |
        Select-Object -Last 1
    if ($null -eq $kernelAssert) {
        throw "Profile '$($profileProperty.Name)' kernel route must verify its destination."
    }
    $kernelAssertAliases = @($kernelAssert.assertSemantic | ForEach-Object { [string]$_ })
    foreach ($alias in @($zhCoreKernelSettings, 'Core Kernel Settings')) {
        if ($kernelAssertAliases -notcontains $alias) {
            throw "Profile '$($profileProperty.Name)' kernel route is missing destination alias '$alias'."
        }
    }
}
Write-Output 'PASS player-kernel routes use live semantics and verify the destination page'

$semanticSteps = @($sequence | Where-Object { $_.PSObject.Properties['tapSemantic'] })
if ($semanticSteps.Count -ne 3) {
    throw 'open_pip_danmaku_settings must use live semantics for Menu, Settings, and the PiP settings tile.'
}
$routeAliasGroups = @(
    [pscustomobject]@{ Values = @($zhMenu, 'Menu') },
    [pscustomobject]@{ Values = @($zhSettings, 'Settings') },
    [pscustomobject]@{ Values = @($zhPipDanmaku, 'PiP Danmaku') }
)
for ($index = 0; $index -lt $semanticSteps.Count; $index++) {
    $actualAliases = @($semanticSteps[$index].tapSemantic | ForEach-Object { [string]$_ })
    foreach ($alias in $routeAliasGroups[$index].Values) {
        if ($actualAliases -notcontains $alias) {
            throw "open_pip_danmaku_settings step $index is missing route alias '$alias'."
        }
    }
}
if (@($sequence | Where-Object { $_.PSObject.Properties['tap'] }).Count -ne 0) {
    throw 'open_pip_danmaku_settings still contains a cached-coordinate tap.'
}
Write-Output 'PASS PiP settings route uses live semantics for every tap'

$assertStep = @($sequence | Where-Object { $_.PSObject.Properties['assertSemantic'] }) | Select-Object -Last 1
if ($null -eq $assertStep) {
    throw 'open_pip_danmaku_settings must assert a destination-only semantic after the tap.'
}
$assertAliases = @($assertStep.assertSemantic | ForEach-Object { [string]$_ })
foreach ($alias in @($zhStylePreview, 'Style Preview')) {
    if ($assertAliases -notcontains $alias) {
        throw "open_pip_danmaku_settings is missing destination alias '$alias'."
    }
}
Write-Output 'PASS PiP settings route verifies the destination page'

$point = $profile.points.'settings.pip_danmaku'
if ($point.x -ne 600 -or $point.y -ne 2006 -or (@($point.bounds) -join ',') -ne '48,1874,1152,2138') {
    throw 'K90 PiP settings cache does not match the measured 2026-09-12 accessibility bounds.'
}
Write-Output 'PASS K90 PiP settings cache matches measured bounds'

& $runnerPath -Validate -Profile 'k90pro_portrait_1200x2608'
Write-Output 'PASS android_ui accepts semantic route assertions'

# `python` on PATH may be an interpreter that cannot start at all; the wrapper picks one that can and returns
# its exit code, which the check below reads.
& (Join-Path $PSScriptRoot 'pythonw.ps1') (Join-Path $PSScriptRoot 'validate_device_ui_map.py')
if ($LASTEXITCODE -ne 0) {
    throw "validate_device_ui_map.py exited with code $LASTEXITCODE."
}
Write-Output 'PASS device UI map schema accepts semantic route assertions'
