# gemma-gemma-gemma

Run **Gemma 4 26B-A4B** in **GGUF** (e.g. **UD-Q2_K_XL**) with **TurboQuant+** KV cache and **multimodal** (vision) using [TheTom/llama-cpp-turboquant](https://github.com/TheTom/llama-cpp-turboquant) (the `llama.cpp` fork from [TheTom/turboquant_plus](https://github.com/TheTom/turboquant_plus)).

---

## PowerShell execution policy (one-time on Windows)

If you see *“running scripts is disabled on this system”* when using **`.\scripts\…`**, set **RemoteSigned** for your user and unblock repo scripts:

```powershell
cd D:\Source\lbsa71\gemma-gemma-gemma
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\fix-powershell-execution-policy.ps1
```

Or double-click **`scripts\fix-powershell-execution-policy.cmd`** (same effect).

After that, you can run **`.\scripts\start-llama-server.ps1`** and **`.\scripts\build-llama-turboquant-cuda.ps1`** directly. If you prefer not to change policy, keep prefixing with **`powershell -NoProfile -ExecutionPolicy Bypass -File …`**.

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

**Reproducible build:** from the repo root (after [execution policy](#powershell-execution-policy-one-time-on-windows) is fixed):

```powershell
.\scripts\build-llama-turboquant-cuda.ps1
```

If scripts are still blocked:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\build-llama-turboquant-cuda.ps1
```

The script uses **`-DCMAKE_CUDA_ARCHITECTURES=89`** (Ada / RTX 4090). For other GPUs, edit that flag in `scripts\build-llama-turboquant-cuda.ps1`.

After a successful build, start the API with **`.\scripts\start-llama-server.ps1`** (see [Quick start](#quick-start-launch-the-server)).

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

## Quick start: launch the server

From the repo root, **`scripts\start-llama-server.ps1`** prints paths, checks that `llama-server.exe` and the default GGUF exist, then starts **`llama-server`** with **TurboQuant** (`q8_0` + `turbo4`) and **`--jinja`**.

```powershell
cd D:\Source\lbsa71\gemma-gemma-gemma
.\scripts\start-llama-server.ps1
```

**Vision (multimodal):** same script with **`-Multimodal`** (adds `--mmproj` and Gemma 4 image / micro-batch flags):

```powershell
.\scripts\start-llama-server.ps1 -Multimodal
```

**Useful parameters:** `-Port 8080`, `-ListenAddress 127.0.0.1`, `-Ngl 99`, `-Context 8192`, `-Model "...\custom.gguf"`, `-Mmproj "...\mmproj.gguf"`. Run **`Get-Help .\scripts\start-llama-server.ps1 -Full`** for the full list.

**Docker Open WebUI (below):** bind **`llama-server` to the host**, not loopback-only, so the container can reach it: **`-ListenAddress 0.0.0.0`** (still use firewall rules if you expose the machine beyond localhost).

---

## Open WebUI in Docker (browser UI)

[Open WebUI](https://github.com/open-webui/open-webui) is a self-hosted web app. This repo includes **`docker-compose.yml`** that:

- Maps the UI to **`http://localhost:3000`**
- Preconfigures **OpenAI-compatible** access to **`http://host.docker.internal:8080/v1`** (your **`llama-server`** on Windows; see [Open WebUI docs — OpenAI-compatible / local](https://docs.openwebui.com/getting-started/quick-start/connect-a-provider/starting-with-openai-compatible/))
- Disables bundled **Ollama** API noise (`ENABLE_OLLAMA_API=false`) and sets a dummy **`OPENAI_API_KEY`** (many local servers accept any non-empty key)
- Sets **`WEBUI_AUTH=false`** for easy first use on a trusted machine (turn auth on for shared networks)

### Prerequisites

1. **Docker Desktop** installed and **running** (Start menu → Docker Desktop; wait until the engine is healthy). If `docker version` fails with *pipe/docker_engine*, the daemon is not up yet.
2. **`llama-server` running on the host** on port **8080** (or change **`OPENAI_API_BASE_URL`** in `docker-compose.yml` to match your port).

### Start WebUI + check connectivity

```powershell
cd D:\Source\lbsa71\gemma-gemma-gemma

# Terminal A — llama (use 0.0.0.0 so Docker can reach the host; add -Multimodal for images)
.\scripts\start-llama-server.ps1 -Multimodal -ListenAddress 0.0.0.0 -Port 8080

# Terminal B — Open WebUI
.\scripts\docker-open-webui.ps1 -Action up
.\scripts\docker-open-webui.ps1 -Action verify
```

Open **`http://localhost:3000`** in your browser.

- **First visit:** create the admin account (unless you disabled signup in newer WebUI builds).
- **Provider URL:** if models do not appear, open **Admin Panel → Connections → OpenAI** and set the URL to **`http://host.docker.internal:8080/v1`** and any non-empty API key, then save (Open WebUI may persist settings in its volume and ignore later env changes — see [troubleshooting](https://docs.openwebui.com/troubleshooting/)).

**Logs:** `.\scripts\docker-open-webui.ps1 -Action logs` — **Stop:** `.\scripts\docker-open-webui.ps1 -Action down`

---

## 3. Run — text + TurboQuant KV (manual)

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

## 4. Run — multimodal + TurboQuant KV (manual)

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

- [Open WebUI](https://github.com/open-webui/open-webui) — [OpenAI-compatible providers](https://docs.openwebui.com/getting-started/quick-start/connect-a-provider/starting-with-openai-compatible/)
- [turboquant_plus README](https://github.com/TheTom/turboquant_plus)
- [TheTom/llama-cpp-turboquant](https://github.com/TheTom/llama-cpp-turboquant) — branch `feature/turboquant-kv-cache`
- [llama.cpp multimodal docs](https://github.com/ggml-org/llama.cpp/blob/master/docs/multimodal.md)
