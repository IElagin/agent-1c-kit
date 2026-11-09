# inventory.ps1 — опись машины для части 1 «Настройка». Только читает:
# ничего не ставит, не меняет и 1С не запускает.
. "$PSScriptRoot\common.ps1"
function Line($name, $state, $detail) { "{0,-24} {1,-5} {2}" -f $name, $state, $detail }
function Has($cmd) { [bool](Get-Command $cmd -ErrorAction SilentlyContinue) }
function First($cmd, [string[]]$a) {
  try { $o = & $cmd @a 2>&1 | Select-Object -First 1; "$o".Trim() } catch { "ошибка: $_" }
}

"== Машина"
$os = Get-CimInstance Win32_OperatingSystem
Line "Windows" "ЕСТЬ" "$($os.Caption) $($os.Version)"
Line "Память" "" ("свободно {0:N1} ГБ из {1:N1} ГБ" -f ($os.FreePhysicalMemory / 1MB), ($os.TotalVisibleMemorySize / 1MB))
Line "PowerShell (этот)" "ЕСТЬ" "$($PSVersionTable.PSEdition) $($PSVersionTable.PSVersion)"
if (Has "pwsh") { Line "PowerShell 7 (pwsh)" "ЕСТЬ" (First "pwsh" @("-NoProfile", "-Command", '$PSVersionTable.PSVersion.ToString()')) }
else { Line "PowerShell 7 (pwsh)" "НЕТ" "" }

"== Ядро"
$plats = @()
foreach ($root in @("$env:ProgramFiles\1cv8", "${env:ProgramFiles(x86)}\1cv8")) {
  if ($root -and (Test-Path $root)) {
    Get-ChildItem $root -Directory | ForEach-Object {
      $e = Join-Path $_.FullName "bin\1cv8.exe"; if (Test-Path $e) { $plats += $e } }
  }
}
if ($V8Exe -and (Test-Path $V8Exe) -and ($plats -notcontains $V8Exe)) { $plats += $V8Exe }
if ($plats.Count -eq 0) { Line "Платформа 1С" "НЕТ" "в Program Files не найдена, v8Exe в settings.json не задан" }
foreach ($p in $plats) {
  $v = (Get-Item $p).VersionInfo.FileVersion
  $mark = if ($v -like "8.3.27.*") { "(8.3.27 — подходит для Unica)" } else { "" }
  Line "Платформа 1С" "ЕСТЬ" "$v $p $mark"
}
if ($SettingsError) { Line "settings.json" "ОШИБКА" "не читается как JSON: $SettingsError" }
elseif (-not $Settings) { Line "settings.json" "НЕТ" "файла нет — заполни по setup/1-machine.md, шаг 1.1" }
if ($V8Exe) {
  $ok = Test-Path $V8Exe
  Line "v8Exe" $(if ($ok) { "ЕСТЬ" } else { "НЕТ" }) "$V8Exe$(if (-not $ok) { ' — файла нет' })"
  $hbk = Join-Path (Split-Path $V8Exe) "shcntx_ru.hbk"
  Line "Справка платформы" $(if (Test-Path $hbk) { "ЕСТЬ" } else { "НЕТ" }) $hbk
} else { Line "v8Exe" "НЕТ" "не задан" }
Line "v8User" $(if ($V8User) { "ЕСТЬ" } else { "НЕТ" }) "$V8User"
Line "v8Password" $(if ($V8Password) { "ЕСТЬ" } else { "—" }) "(значение не печатается)"
if ($BaseCopy) {
  $ok = Test-Path (Join-Path $BaseCopy "1Cv8.1CD")
  Line "baseCopy" $(if ($ok) { "ЕСТЬ" } else { "НЕТ" }) "$BaseCopy$(if (-not $ok) { ' — нет 1Cv8.1CD' })"
} else { Line "baseCopy" "НЕТ" "не задан" }
if (Has "git") {
  Line "git" "ЕСТЬ" (First "git" @("--version"))
  $un = (& git config user.name 2>$null); $ue = (& git config user.email 2>$null)
  Line "git: имя и почта" $(if ($un -and $ue) { "ЕСТЬ" } else { "НЕТ" }) "$un <$ue>"
} else { Line "git" "НЕТ" "" }
Line "YAxUnit" "?" "проверяется выгрузкой: dump.ps1 -Extension YAXUNIT -To tmp\yaxunit"

"== Конфигурация (часть 3)"
if ($ConfigDump) {
  Line "configDump" $(if (Test-Path $ConfigDump) { "ЕСТЬ" } else { "НЕТ" }) $ConfigDump
  $cx = Join-Path $ConfigDump "xml\Configuration.xml"
  Line "Выгрузка конфигурации" $(if (Test-Path $cx) { "ЕСТЬ" } else { "НЕТ" }) $cx
  $mp = Join-Path $ConfigDump "map.txt"
  if (Test-Path $mp) { Line "Карта объектов" "ЕСТЬ" "$mp, $((Get-Content $mp -TotalCount 1 -Encoding UTF8) -replace '^# ', '')" }
  else { Line "Карта объектов" "НЕТ" $mp }
} else { Line "configDump" "НЕТ" "не задан — нужен для части 3 (setup/3-config.md)" }
if (Has "rg") { Line "ripgrep (rg)" "ЕСТЬ" (First "rg" @("--version")) }
else { Line "ripgrep (rg)" "НЕТ" "искать по выгрузке можно инструментом поиска агента или Select-String" }

"== Путь «Свои инструменты»"
if ($BslLsExe) {
  Line "BSL Language Server" $(if (Test-Path $BslLsExe) { "ЕСТЬ" } else { "НЕТ" }) $BslLsExe
} else { Line "BSL Language Server" "НЕТ" "bslLsExe в settings.json не задан" }
if (Has "java") { Line "Java" "ЕСТЬ" (First "java" @("-version")) } else { Line "Java" "НЕТ" "нужна только для BSL LS в виде .jar" }

"== Сервер справки (путь «Свои инструменты»), агент и Unica (путь «Unica»)"
if (Has "docker") {
  $srv = First "docker" @("version", "--format", "{{.Server.Version}}")
  $cmp = First "docker" @("compose", "version")
  Line "Docker" "ЕСТЬ" "сервер: $srv; $cmp"
} else { Line "Docker" "НЕТ" "" }
$port = Get-NetTCPConnection -LocalPort 8000 -State Listen -ErrorAction SilentlyContinue
Line "Порт 8000" $(if ($port) { "ЗАНЯТ" } else { "СВОБ" }) "нужен серверу справки"
if (Has "claude") {
  Line "Claude Code" "ЕСТЬ" (First "claude" @("--version"))
  $mcp = @(& claude mcp list 2>&1 | ForEach-Object { "$_" } | Where-Object { $_ -match "1c-syntax|:8000/mcp" })
  if ($mcp.Count -gt 0) { foreach ($m in $mcp) { Line "MCP справки" "ЕСТЬ" $m.Trim() } }
  else { Line "MCP справки" "НЕТ" "нет сервера 1c-syntax или с адресом :8000/mcp" }
  $pl = (& claude plugin list 2>&1 | Out-String)
  if ($pl -match "unica") {
    # Плагин может стоять для другого проекта: смотрим, где он включён.
    $where = @()
    foreach ($f in @(".claude\settings.local.json", ".claude\settings.json")) {
      $fp = Join-Path $PSScriptRoot $f
      if ((Test-Path $fp) -and ((Get-Content $fp -Raw) -match '"unica@unica"\s*:\s*true')) { $where += "в этом проекте ($f)" } }
    $uf = Join-Path $env:USERPROFILE ".claude\settings.json"
    if ((Test-Path $uf) -and ((Get-Content $uf -Raw) -match '"unica@unica"\s*:\s*true')) { $where += "для всех проектов" }
    if ($where.Count -gt 0) { Line "Unica (Claude Code)" "ЕСТЬ" ($where -join "; ") }
    else { Line "Unica (Claude Code)" "НЕТ" "плагин установлен на машине, но в этом проекте не включён" }
  } else { Line "Unica (Claude Code)" "НЕТ" "" }
} else { Line "Claude Code" "НЕТ" "" }
if (Has "codex") {
  Line "Codex" "ЕСТЬ" (First "codex" @("--version"))
  $pl = (& codex plugin list 2>&1 | Out-String)
  Line "Unica (Codex)" $(if ($pl -match "unica") { "ЕСТЬ" } else { "НЕТ" }) ""
} else { Line "Codex" "НЕТ" "" }
exit 0
