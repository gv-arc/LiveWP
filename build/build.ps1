$ErrorActionPreference = "Stop"

$project = Join-Path $PSScriptRoot "..\src\LiveWP\LiveWP.csproj"
$outputDir = Join-Path $PSScriptRoot "..\src\LiveWP\bin\Release\net8.0-windows"

Write-Host "Building LiveWP..."
dotnet build $project -c Release -p:Platform=x64

if (-not (Test-Path (Join-Path $outputDir "mpv.exe"))) {
    Write-Host "mpv.exe not found in the output folder. Download it from https://mpv.io/installation/ and copy it into the app directory before creating the installer."
}

Write-Host "Build complete: $outputDir"
