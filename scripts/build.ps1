# build.ps1 — сборка внешней обработки src\Обработка.xml -> out\Обработка.epf (шаг 5 статьи).
. "$PSScriptRoot\common.ps1"
Set-Location $PSScriptRoot
Need-Env @("V8_EXE", "V8_USER", "V8_BASE_COPY")
$root = "$PSScriptRoot\src\Обработка.xml"
if (-not (Test-Path $root)) { "ОШИБКА: нет src\Обработка.xml — сначала выгрузка (dump.ps1)"; exit 2 }
New-Item -ItemType Directory -Force out | Out-Null
$epf = "$PSScriptRoot\out\Обработка.epf"; $log = "$PSScriptRoot\build.log"; $res = "$PSScriptRoot\build.res"
Remove-Item $log, $res -ErrorAction SilentlyContinue
$t0 = Get-Date
# Сборочная база — с той же конфигурацией: формы ссылаются на её типы,
# на пустой базе сборка падает с исключением XDTO на форме.
$a = @("DESIGNER", "/F", (Q (Build-Base))) + @(Auth) + @("/DisableStartupDialogs", "/DisableStartupMessages",
  "/LoadExternalDataProcessorOrReportFromFiles", (Q $root), (Q $epf),
  "/Out", (Q $log), "/DumpResult", (Q $res))
$null = Invoke-1C $a
Show-Log $log
$code = Read-Res $res
# Проверяем, что файл свежий: иначе за результат сойдёт старый .epf от прошлого запуска.
if (-not (Test-Path $epf) -or (Get-Item $epf).LastWriteTime -lt $t0) {
  "ОШИБКА: out\Обработка.epf не создан или старый (build.res: $code). Смотрите build.log выше."; exit 1 }
if ($code -ne "0") { "ОШИБКА: build.res = $code"; exit 1 }
# Код 0 не доказывает, что модуль цел: битый модуль конфигуратор при сборке
# обработки не ловит. Это покажет первый тест (создание объекта) в test.ps1.
"Собрано: out\Обработка.epf, код возврата 0"; exit 0
