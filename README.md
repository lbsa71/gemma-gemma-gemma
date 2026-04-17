# gemma-gemma-gemma

Run **Gemma 4 26B-A4B** in **GGUF** (e.g. **UD-Q2_K_XL**) with **TurboQuant+** KV cache and **multimodal** (vision) using [TheTom/llama-cpp-turboquant](https://github.com/TheTom/llama-cpp-turboquant) (the `llama.cpp` fork from [TheTom/turboquant_plus](https://github.com/TheTom/turboquant_plus)).

---

## Current setup (verified 2026-04-17)

| Item | Value |
|------|--------|
| OS | Windows 11 Home (build 22631) |
| CPU | Intel Core i9-14900HX |
| System RAM | ~32 GB |
| GPU | NVIDIA GeForce RTX 4090 Laptop (16 GB VRAM) |
| **CUDA Toolkit** | **13.2** (`nvcc` 13.2.78) at `C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v13.2` |
| **`CUDA_PATH` (machine)** | Same path (set by NVIDIA installer) |
| CMake | 4.3.1 (`C:\Program Files\CMake\bin\cmake.exe`) |
| VS 2022 Build Tools | MSVC 14.44, Windows SDK 10.0.26100 |
| Python | 3.12.10 |
| **Fork clone** | `llama-cpp-turboquant/` (branch `feature/turboquant-kv-cache`) |
| **Binaries (CUDA Release)** | `llama-cpp-turboquant\build\bin\Release\` — `llama-server.exe`, `llama-cli.exe`, `llama-mtmd-cli.exe` |
| TurboQuant KV in `--help` | `turbo2`, `turbo3`, `turbo4` listed for cache-type flags |

CMake configure step reported **NCCL** not installed (optional; only matters for multi-GPU) and **OpenSSL** not found (server HTTPS off unless you add OpenSSL and rebuild).

---

## Windows CUDA build notes (why a script exists)

1. **MASM (`ml64`)** — CMake must see an assembler for `ggml`’s `ASM` language. Pass **`-DCMAKE_ASM_COMPILER=<path-to-ml64.exe>`** (or run from a **“x64 Native Tools”** prompt where `ml64` is on `PATH`).
2. **`CudaToolkitDir` empty in MSBuild** — If CUDA is installed but VS integration does not set MSBuild’s `CudaToolkitDir`, CUDA compiler id fails with: *“The CUDA Toolkit directory '' does not exist”*. Fix by passing **`CMAKE_VS_GLOBALS=CudaToolkitDir=<CUDA root with forward slashes>`**, plus **`-DCMAKE_CUDA_COMPILER=.../nvcc.exe`** and **`-DCUDAToolkit_ROOT=...`**, and set **`CUDA_PATH`** in the same `cmd` session before CMake.

**Reproducible build:** from the repo root, run:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build-llama-turboquant-cuda.ps1
```

The script uses **`-DCMAKE_CUDA_ARCHITECTURES=89`** (Ada / RTX 4090). For other GPUs, edit that flag in `scripts\build-llama-turboquant-cuda.ps1`.

---

## 1. Clone the fork (if you do not have it yet)

```powershell
cd D:\Source\lbsa71\gemma-gemma-gemma
git clone --depth 1 --branch feature/turboquant-kv-cache https://github.com/TheTom/llama-cpp-turboquant.git
```

Then run the build script above (or replicate its CMake arguments by hand).

---

## 2. Download GGUF + multimodal projector

**Repo:** [unsloth/gemma-4-26B-A4B-it-GGUF](https://huggingface.co/unsloth/gemma-4-26B-A4B-it-GGUF)

```powershell
pip install -U huggingface_hub
mkdir D:\Source\lbsa71\gemma-gemma-gemma\models\gemma-4-26B-A4B-it-GGUF -Force
hf download unsloth/gemma-4-26B-A4B-it-GGUF `
  --local-dir D:\Source\lbsa71\gemma-gemma-gemma\models\gemma-4-26B-A4B-it-GGUF `
  --include "gemma-4-26B-A4B-it-UD-Q2_K_XL.gguf" `
  --include "mmproj-BF16.gguf"
```

(`huggingface-cli` is deprecated; the `hf` CLI ships with current `huggingface_hub`. Use `hf auth login` if the repo requires a token.)

Confirm exact filenames on the model card if they change.

---

## 3. Run — text + TurboQuant KV

For very low bit weights, start with **high K precision** and **turbo on V** (e.g. **`q8_0` + `turbo4`**).

```powershell
$Root = "D:\Source\lbsa71\gemma-gemma-gemma"
$Exe = Join-Path $Root "llama-cpp-turboquant\build\bin\Release\llama-server.exe"
$M   = Join-Path $Root "models\gemma-4-26B-A4B-it-GGUF\gemma-4-26B-A4B-it-UD-Q2_K_XL.gguf"

& $Exe -m $M -ngl 99 -fa on --jinja `
  --cache-type-k q8_0 --cache-type-v turbo4 `
  --host 127.0.0.1 --port 8080
```

---

## 4. Run — multimodal + TurboQuant KV

```powershell
$Root = "D:\Source\lbsa71\gemma-gemma-gemma"
$Exe = Join-Path $Root "llama-cpp-turboquant\build\bin\Release\llama-server.exe"
$M   = Join-Path $Root "models\gemma-4-26B-A4B-it-GGUF\gemma-4-26B-A4B-it-UD-Q2_K_XL.gguf"
$P   = Join-Path $Root "models\gemma-4-26B-A4B-it-GGUF\mmproj-BF16.gguf"

& $Exe -m $M --mmproj $P -ngl 99 -fa on --jinja `
  --cache-type-k q8_0 --cache-type-v turbo4 `
  --image-min-tokens 1120 --image-max-tokens 1120 -ub 2048 `
  --host 127.0.0.1 --port 8080
```

Use `llama-mtmd-cli.exe` from the same folder for CLI image tests. See upstream [multimodal.md](https://github.com/ggml-org/llama.cpp/blob/master/docs/multimodal.md).

---

## 5. Optional: turboquant_plus (Python)

[turboquant_plus](https://github.com/TheTom/turboquant_plus) holds benchmarks and the NumPy reference; GGUF serving still uses **`llama-server`** from this fork.

---

## References

- [turboquant_plus README](https://github.com/TheTom/turboquant_plus)
- [TheTom/llama-cpp-turboquant](https://github.com/TheTom/llama-cpp-turboquant) — branch `feature/turboquant-kv-cache`
- [llama.cpp multimodal docs](https://github.com/ggml-org/llama.cpp/blob/master/docs/multimodal.md)
