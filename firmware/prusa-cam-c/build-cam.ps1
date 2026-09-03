# Build (and optionally flash) the ESP32-S3 camera firmware.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File build-cam.ps1 [COMport]
#
# Lives in the repo rather than a scratchpad on purpose: it encodes the IDF
# cache paths, the unified xtensa-esp-elf PATH fix and the set-target guard,
# all of which took several iterations to get right and none of which is
# recoverable from the README alone.
#
# Derived from build-c.ps1, with one change that matters: the tool list adds
# xtensa-esp-elf. That script globs a FIXED set of tool directories, and its
# list is RISC-V only because everything before this targeted the C3. Without
# the xtensa entry the compiler is installed but not on PATH, and the build
# fails with "compiler not found" while the toolchain sits right there.
#
# Note the name: IDF 5.5 installs ONE unified xtensa toolchain, xtensa-esp-elf,
# not the older per-chip xtensa-esp32s3-elf.

param([string]$Port = "")

# Continue, not Stop: ESP-IDF writes progress to stderr, and Stop turns that
# into a terminating NativeCommandError that hides the real traceback.
$ErrorActionPreference = 'Continue'

$env:MSYSTEM = $null
$env:MINGW_PREFIX = $null
$env:MSYSTEM_PREFIX = $null
$env:PATH = [Environment]::GetEnvironmentVariable('PATH', 'Machine')

$cache = Join-Path $env:LOCALAPPDATA 'esphome\Cache\idf'
$env:IDF_PATH = Join-Path $cache 'frameworks\5.5.5'
$env:IDF_TOOLS_PATH = $cache
$env:IDF_PYTHON_ENV_PATH = Join-Path $cache 'penvs\5.5.5'

$py = Join-Path $env:IDF_PYTHON_ENV_PATH 'Scripts\python.exe'
$idf = Join-Path $env:IDF_PATH 'tools\idf.py'

$toolBins = @(
    (Join-Path $cache 'tools\xtensa-esp-elf'),
    (Join-Path $cache 'tools\riscv32-esp-elf'),
    (Join-Path $cache 'tools\cmake'),
    (Join-Path $cache 'tools\ninja'),
    (Join-Path $cache 'tools\idf-exe'),
    (Join-Path $cache 'tools\ccache'),
    (Join-Path $cache 'tools\dfu-util'),
    (Join-Path $cache 'tools\esp-rom-elfs')
) | Where-Object { Test-Path $_ } | ForEach-Object {
    Get-ChildItem -Path $_ -Recurse -Filter '*.exe' -ErrorAction SilentlyContinue |
        Select-Object -ExpandProperty DirectoryName -Unique
} | Sort-Object -Unique

foreach ($b in $toolBins) { $env:PATH = "$b;$env:PATH" }

if (-not (Get-Command 'xtensa-esp32s3-elf-gcc.exe' -ErrorAction SilentlyContinue)) {
    "WARNING: xtensa-esp32s3-elf-gcc not on PATH after setup"
}

Set-Location $PSScriptRoot

# set-target regenerates sdkconfig AND wipes the build directory, so running it
# unconditionally turns every rebuild into a full rebuild of the whole IDF. Only
# run it when the target is not already esp32s3.
$needTarget = $true
if (Test-Path 'sdkconfig') {
    if (Select-String -Path 'sdkconfig' -Pattern '^CONFIG_IDF_TARGET="esp32s3"' -Quiet) {
        $needTarget = $false
    }
}
if ($needTarget) { & $py $idf set-target esp32s3 2>&1 } else { "set-target: already esp32s3, skipping" }
& $py $idf build 2>&1
"BUILD-EXIT $LASTEXITCODE"

if ($Port -ne "") {
    & $py $idf -p $Port flash 2>&1
    "FLASH-EXIT $LASTEXITCODE"
}
