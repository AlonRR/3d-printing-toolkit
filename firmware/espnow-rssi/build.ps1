# SPDX-FileCopyrightText: 2026 Alon A. Rabinowitz
# SPDX-License-Identifier: MPL-2.0

param([Parameter(Mandatory)][ValidateSet('esp32s3','esp32c3')][string]$Target,
      [string]$Root = $PSScriptRoot)
# Builds this project with the ESP-IDF that ESPHome already cached, mirroring the
# environment esphome/espidf/framework.py:get_framework_env constructs.
#
# $Root defaults to this folder. If the checkout path is deep, map a short drive
# onto it (`subst R: <this folder>`) and pass -Root R:\ - CMake warns once object
# paths approach its 250-character limit.
#
# NO OUTPUT FILTER. The first version piped idf.py through Select-String, which
# hid a compiler crash and a missing ESP_ROM_ELF_DIR and still printed EXIT 0.
# The full log goes to a file; success is judged by the .bin existing.
$C = "$env:LOCALAPPDATA\esphome\Cache\idf"
$env:IDF_TOOLS_PATH      = $C
$env:IDF_PATH            = "$C\frameworks\5.5.5"
$env:IDF_PYTHON_ENV_PATH = "$C\penvs\5.5.5"
$env:ESP_ROM_ELF_DIR     = "$C\tools\esp-rom-elfs\20241011\"
$env:PATH = @(
  "$C\penvs\5.5.5\Scripts",
  "$C\tools\cmake\3.30.2\bin",
  "$C\tools\ninja\1.12.1",
  "$C\tools\xtensa-esp-elf\esp-14.2.0_20260121\xtensa-esp-elf\bin",
  "$C\tools\riscv32-esp-elf\esp-14.2.0_20260121\riscv32-esp-elf\bin"
) -join ';' | ForEach-Object { "$_;$env:PATH" }
Set-Location $Root
$log = Join-Path $Root "build-$Target.log"
& "$C\penvs\5.5.5\Scripts\python.exe" "$env:IDF_PATH\tools\idf.py" `
    -B "build-$Target" -D "SDKCONFIG=sdkconfig.$Target" -D "IDF_TARGET=$Target" build *> $log
$rc = $LASTEXITCODE
"idf.py exit $rc"
Get-Content $log -Tail 12
$bins = Get-ChildItem (Join-Path $Root "build-$Target") -Recurse -Filter *.bin -ErrorAction SilentlyContinue |
        Select-Object -ExpandProperty FullName
if ($bins) { "BINARIES:"; $bins } else { "NO BINARIES PRODUCED" }
exit $rc
