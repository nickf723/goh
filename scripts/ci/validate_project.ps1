param(
    [string]$GodotPath = ""
)

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path

function Resolve-GodotExecutable {
    param([string]$RequestedPath)

    if ($RequestedPath) {
        if (-not (Test-Path $RequestedPath)) {
            throw "Godot executable was not found at '$RequestedPath'."
        }
        return (Resolve-Path $RequestedPath).Path
    }

    foreach ($commandName in @("godot", "godot4")) {
        $command = Get-Command $commandName -ErrorAction SilentlyContinue
        if ($command) {
            return $command.Source
        }
    }

    throw "Godot was not found on PATH. Run this script with -GodotPath 'C:\path\to\Godot.exe'."
}

function Resolve-PythonExecutable {
    foreach ($commandName in @("python", "py")) {
        $command = Get-Command $commandName -ErrorAction SilentlyContinue
        if ($command) {
            return $command.Source
        }
    }

    throw "Python was not found on PATH. Feature-registry validation requires Python 3."
}

function Invoke-GodotCheck {
    param(
        [string]$Executable,
        [string[]]$Arguments,
        [string]$Label
    )

    Write-Host "`n== $Label =="
    & $Executable @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$Label failed with exit code $LASTEXITCODE."
    }
}

function Invoke-PythonCheck {
    param(
        [string]$Executable,
        [string[]]$Arguments,
        [string]$Label
    )

    Write-Host "`n== $Label =="
    & $Executable @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$Label failed with exit code $LASTEXITCODE."
    }
}

$godot = Resolve-GodotExecutable -RequestedPath $GodotPath
$python = Resolve-PythonExecutable
Write-Host "Using Godot: $godot"
Write-Host "Using Python: $python"
Write-Host "Repository: $repoRoot"

Invoke-PythonCheck -Executable $python -Arguments @(
    (Join-Path $repoRoot "scripts/ci/validate_feature_registry.py"),
    "--repo-root", $repoRoot
) -Label "Feature registry validation"

Invoke-GodotCheck -Executable $godot -Arguments @(
    "--headless",
    "--path", $repoRoot,
    "--editor",
    "--quit"
) -Label "Import and parse smoke test"

Invoke-GodotCheck -Executable $godot -Arguments @(
    "--headless",
    "--path", $repoRoot,
    "--quit-after", "5"
) -Label "Main startup smoke test"

Invoke-PythonCheck -Executable $python -Arguments @(
    (Join-Path $repoRoot "scripts/ci/run_feature_registry.py"),
    "--repo-root", $repoRoot,
    "--godot", $godot
) -Label "Registered feature scenes and tests"

Write-Host "`nGodot validation passed."
