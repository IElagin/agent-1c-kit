# dump-config.ps1 — выгрузка конфигурации базы в XML в общую папку (часть 3).
# Только читает базу: конфигурацию и расширения не меняет. Пишет только в каталог
# configDump из settings.json: xml\ — выгрузка, info\ — один файл версий, map.txt — карта.
#   .\dump-config.ps1            полная выгрузка; если она уже есть — обновление (-update)
#   .\dump-config.ps1 -MapOnly   только файл версий ConfigDumpInfo.xml и карта, без модулей
# Коды выхода: 0 готово, 1 ошибка выгрузки или карты, 2 настройки или каталог, 3 тайм-аут.
param([switch]$MapOnly)
. "$PSScriptRoot\common.ps1"
Set-Location $PSScriptRoot
Need-Settings @("v8Exe", "v8User", "baseCopy")
if (-not $ConfigDump) { "ОШИБКА: в settings.json не задано configDump (см. setup/3-config.md, шаг 3.1)"; exit 2 }

# Выгрузка — вне папки проекта: в проекте её подхватили бы git, поиск агента
# и проверка кода, а одна выгрузка нужна всем обработкам по этой конфигурации.
if (-not [IO.Path]::IsPathRooted($ConfigDump)) { "ОШИБКА: configDump = $ConfigDump — нужен полный путь, например D:\1C-dumps\УТ-11.5"; exit 2 }
$root = [IO.Path]::GetFullPath($ConfigDump).TrimEnd('\')
$proj = [IO.Path]::GetFullPath($PSScriptRoot).TrimEnd('\')
if ($root -eq $proj -or $root.StartsWith($proj + '\', [StringComparison]::OrdinalIgnoreCase)) {
  "ОШИБКА: configDump внутри папки проекта ($root). Выгрузка лежит отдельно, путь спроси у человека."; exit 2 }
$xml = Join-Path $root "xml"; $info = Join-Path $root "info"
$log = "$PSScriptRoot\dump-config.log"; $res = "$PSScriptRoot\dump-config.res"
Remove-Item $log, $res -ErrorAction SilentlyContinue
$min = if (Get-Setting "configDumpTimeoutMin") { [int](Get-Setting "configDumpTimeoutMin") } else { 120 }
$t0 = Get-Date
$base = @("DESIGNER", "/F", (Q (Build-Base))) + @(Auth) + @("/DisableStartupDialogs", "/DisableStartupMessages")

if ($MapOnly) {
  # -configDumpInfoOnly выгружает только файл версий. Кладём его в свой каталог info\,
  # а не в xml\: новый файл версий в xml\ объявил бы выгрузку свежей, и следующее
  # обновление пропустило бы настоящие изменения.
  New-Item -ItemType Directory -Force $info | Out-Null
  if (Get-ChildItem $info -Force | Where-Object { $_.Name -ne "ConfigDumpInfo.xml" }) {
    "ОШИБКА: в $info есть другие файлы, кроме ConfigDumpInfo.xml. Это не каталог набора — спроси человека."; exit 2 }
  $a = $base + @("/DumpConfigToFiles", (Q $info), "-configDumpInfoOnly", "/Out", (Q $log), "/DumpResult", (Q $res))
  $code = Invoke-1C $a $min
  Show-Log $log
  if ($null -eq $code) { "ОШИБКА: конфигуратор не уложился в $min мин и снят"; exit 3 }
  $cdi = Join-Path $info "ConfigDumpInfo.xml"
  $fresh = (Test-Path $cdi) -and ((Get-Item $cdi).LastWriteTime -ge $t0.AddSeconds(-2))
  if ($code -ne 0 -or -not $fresh) { "ОШИБКА выгрузки файла версий: код $code, DumpResult $(Read-Res $res), свежий ConfigDumpInfo.xml: $fresh"; exit 1 }
  $sec = [int]((Get-Date) - $t0).TotalSeconds
  & "$PSScriptRoot\map-config.ps1" -Info $cdi
  if ($LASTEXITCODE -ne 0) { "ОШИБКА: файл версий выгружен, карта не построена (код $LASTEXITCODE)"; exit 1 }
  "Выгружено: файл версий $cdi за $sec с; модулей и XML объектов нет — для них .\dump-config.ps1 без -MapOnly"; exit 0
}

# Полная выгрузка или обновление. Обновление (-update) выгружает только то, что
# изменилось с прошлой выгрузки, по её файлу версий xml\ConfigDumpInfo.xml;
# -force — полная выгрузка, если обновить нельзя (например, сменился формат).
$cdi = Join-Path $xml "ConfigDumpInfo.xml"
$mode = "полная"; $extra = @()
if (Test-Path $cdi) { $mode = "обновление"; $extra = @("-update", "-force") }
elseif ((Test-Path $xml) -and (Get-ChildItem $xml -Force | Select-Object -First 1)) {
  "ОШИБКА: в $xml есть файлы, но нет ConfigDumpInfo.xml: прошлая выгрузка оборвалась или каталог чужой. Ничего не удаляй — спроси человека."; exit 2 }
New-Item -ItemType Directory -Force $xml | Out-Null
$a = $base + @("/DumpConfigToFiles", (Q $xml)) + $extra + @("/Out", (Q $log), "/DumpResult", (Q $res))
$code = Invoke-1C $a $min
# Журнал выгрузки конфигурации бывает пустым и при успехе: итог по коду возврата
# и по наличию Configuration.xml и ConfigDumpInfo.xml.
Show-Log $log
if ($null -eq $code) { "ОШИБКА: выгрузка не уложилась в $min мин (configDumpTimeoutMin) и снята; каталог $xml неполный — спроси человека"; exit 3 }
$ok = (Test-Path (Join-Path $xml "Configuration.xml")) -and (Test-Path $cdi)
if ($code -ne 0 -or -not $ok) { "ОШИБКА выгрузки ($mode): код $code, DumpResult $(Read-Res $res), Configuration.xml и ConfigDumpInfo.xml есть: $ok"; exit 1 }
$files = Get-ChildItem $xml -Recurse -File -Force
$mb = [math]::Round((($files | Measure-Object Length -Sum).Sum / 1MB), 1)
& "$PSScriptRoot\map-config.ps1" -Info $cdi
if ($LASTEXITCODE -ne 0) { "ОШИБКА: выгрузка есть, карта не построена (код $LASTEXITCODE)"; exit 1 }
# Время — от запуска конфигуратора до готовой карты: подсчёт файлов и карта в 5.1 идут дольше выгрузки.
$span = (Get-Date) - $t0
"Выгружено ($mode): $xml, файлов $($files.Count), $mb МБ, за {0} мин {1} с" -f [int][math]::Floor($span.TotalMinutes), $span.Seconds
exit 0
