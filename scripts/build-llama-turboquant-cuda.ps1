#Requires -Version 5.1
<#
  Configure and build TheTom/llama-cpp-turboquant with CUDA on Windows (VS 2022 Build Tools + CMake).
  Edit $CudaRoot or MSVC path if your install differs.
#>
$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path $PSScriptRoot -Parent
$LlamaDir = Join-Path $RepoRoot "llama-cpp-turboquant"
$Vcvars = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat"
$Cmake = "${env:ProgramFiles}\CMake\bin\cmake.exe"
$CudaRoot = if ($env:CUDA_PATH) { $env:CUDA_PATH.TrimEnd('\') } else { "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v13.2" }
$Ml64 = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2022\BuildTools\VC\Tools\MSVC\14.44.35207\bin\Hostx64\x64\ml64.exe"

if (-not (Test-Path $LlamaDir)) {
    Write-Error "Missing $LlamaDir - clone: git clone --depth 1 --branch feature/turboquant-kv-cache https://github.com/TheTom/llama-cpp-turboquant.git"
}
if (-not (Test-Path $Vcvars)) { Write-Error "Missing VS Build Tools: $Vcvars" }
if (-not (Test-Path $Cmake)) { Write-Error "Missing CMake: $Cmake" }
if (-not (Test-Path (Join-Path (Join-Path $CudaRoot 'bin') 'nvcc.exe'))) { Write-Error "Missing CUDA nvcc under $(Join-Path $CudaRoot 'bin')" }

if (-not (Test-Path $Ml64)) {
    $cand = Get-ChildItem "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2022\BuildTools\VC\Tools\MSVC\*\bin\Hostx64\x64\ml64.exe" -ErrorAction SilentlyContinue |
        Sort-Object FullName -Descending | Select-Object -First 1
    if (-not $cand) { Write-Error "Could not find ml64.exe under VS Build Tools" }
    $Ml64 = $cand.FullName
}

$CudaFwd = ($CudaRoot -replace "\\", "/")
$Ml64Fwd = ($Ml64 -replace "\\", "/")
$NvccFwd = "$CudaFwd/bin/nvcc.exe"

Write-Host "CUDA: $CudaRoot"
Write-Host "ml64: $Ml64"

# Single-quoted format string avoids PowerShell parsing `&&` / `\b` inside "-strings.
$cmdConfigure = 'call "{0}" && set "CUDA_PATH={1}" && set "CUDA_PATH_V13_2={1}" && set "PATH=%PATH%;{1}\bin" && cd /d "{2}" && "{3}" -S . -B build -G "Visual Studio 17 2022" -A x64 -DCMAKE_ASM_COMPILER="{4}" -DCMAKE_CUDA_COMPILER="{5}" -DCUDAToolkit_ROOT="{6}" -DCMAKE_CUDA_ARCHITECTURES=89 -DGGML_CUDA=ON -DGGML_NATIVE=ON -DCMAKE_VS_GLOBALS="CudaToolkitDir={6}"' -f @(
    $Vcvars, $CudaRoot, $LlamaDir, $Cmake, $Ml64Fwd, $NvccFwd, $CudaFwd
)
cmd /c $cmdConfigure
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$cmdBuild = 'call "{0}" && cd /d "{1}" && "{2}" --build build --config Release --parallel 16 --target llama-server llama-cli llama-mtmd-cli' -f $Vcvars, $LlamaDir, $Cmake
cmd /c $cmdBuild
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "Built: $(Join-Path $LlamaDir 'build\bin\Release\llama-server.exe')"
