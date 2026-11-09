# dump.ps1 — выгрузка в файлы (шаг 2 статьи).
#   .\dump.ps1 -Epf "C:\путь\Моя.epf"            внешняя обработка -> src\Обработка.xml и папка src\Обработка\
#   .\dump.ps1 -Extension YAXUNIT -To tmp\yaxunit расширение из копии базы -> каталог
param([string]$Epf, [string]$Extension, [string]$To)
. "$PSScriptRoot\common.ps1"
Set-Location $PSScriptRoot
Need-Settings @("v8Exe", "v8User", "baseCopy")
$log = "$PSScriptRoot\dump.log"; $res = "$PSScriptRoot\dump.res"
Remove-Item $log, $res -ErrorAction SilentlyContinue
$common = @("/DisableStartupDialogs", "/DisableStartupMessages")

if ($Epf) {
  if (-not (Test-Path $Epf)) { "ОШИБКА: нет файла $Epf"; exit 2 }
  # Первый аргумент — путь к корневому файлу, а не каталог: каталог, которого
  # ещё нет, конфигуратор принимает за имя корневого файла (src.xml рядом с src).
  $root = "$PSScriptRoot\src\Обработка.xml"
  if (Test-Path $root) { "ОШИБКА: src\Обработка.xml уже есть, повторная выгрузка затрёт правки. Спроси человека."; exit 2 }
  $a = @("DESIGNER", "/F", (Q (Build-Base))) + @(Auth) + $common + @(
    "/DumpExternalDataProcessorOrReportToFiles", (Q $root), (Q (Resolve-Path $Epf).Path),
    "/Out", (Q $log), "/DumpResult", (Q $res))
  $code = Invoke-1C $a
  Show-Log $log
  if ($code -ne 0 -or -not (Test-Path $root)) { "ОШИБКА выгрузки: код $code, src\Обработка.xml есть: $(Test-Path $root)"; exit 1 }
  "Выгружено: src\Обработка.xml, код 0"; exit 0
}

if ($Extension) {
  if (-not $To) { "ОШИБКА: укажите -To <каталог>, например tmp\$Extension"; exit 2 }
  $dir = Join-Path $PSScriptRoot $To
  if ((Test-Path $dir) -and (Get-ChildItem $dir -Force | Select-Object -First 1)) { "ОШИБКА: каталог $To не пустой"; exit 2 }
  New-Item -ItemType Directory -Force $dir | Out-Null
  $a = @("DESIGNER", "/F", (Q $BaseCopy)) + @(Auth) + $common + @(
    "/DumpConfigToFiles", (Q $dir), "-Extension", (Q $Extension), "/Out", (Q $log), "/DumpResult", (Q $res))
  $code = Invoke-1C $a
  # У выгрузки конфигурации и расширения журнал бывает пустым и при успехе:
  # итог по коду возврата и по наличию Configuration.xml.
  Show-Log $log
  $ok = Test-Path (Join-Path $dir "Configuration.xml")
  if ($code -ne 0 -or -not $ok) { "ОШИБКА выгрузки расширения ${Extension}: код $code, Configuration.xml есть: $ok"; exit 1 }
  "Выгружено расширение $Extension в $To, код 0"; exit 0
}

"Использование: .\dump.ps1 -Epf <файл.epf>  или  .\dump.ps1 -Extension <имя> -To <каталог>"; exit 2
