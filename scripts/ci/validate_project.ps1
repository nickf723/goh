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

$godot = Resolve-GodotExecutable -RequestedPath $GodotPath
Write-Host "Using Godot: $godot"
Write-Host "Repository: $repoRoot"

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
) -Label "Startup smoke test"

Write-Host "`nGodot validation passed."
