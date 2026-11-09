# test.ps1 — тесты YAxUnit на копии базы (шаг 6 статьи).
# Зелёный только так: junit.xml свежий, тестов больше нуля, упавших и ошибок ноль,
# пропущены не все, exitcode.txt = 0. Коды выхода: 0 зелёный, 1 красный, 2 нет итога, 3 тайм-аут.
. "$PSScriptRoot\common.ps1"
# Относительные пути в xUnitParams.json YAxUnit считает от текущей папки,
# а не от JSON: без этой строки junit.xml и exitcode.txt лягут в чужую папку.
Set-Location $PSScriptRoot
Need-Settings @("v8Exe", "v8User", "baseCopy")
$epf = "$PSScriptRoot\out\Обработка.epf"
if (-not (Test-Path $epf)) { "ОШИБКА: нет out\Обработка.epf — сначала build.ps1"; exit 2 }
# Тест открывает обработку из каталога временных файлов под тем же именем:
# КаталогВременныхФайлов() + "Обработка.epf".
Copy-Item $epf "$env:TEMP\Обработка.epf" -Force
# Старые итоги убираем: иначе файл прошлого прогона сойдёт за результат этого.
Remove-Item "exitcode.txt", "junit.xml", "yaxunit.log" -ErrorAction SilentlyContinue
$cfg = "$PSScriptRoot\xUnitParams.json"
# /L ru: клиент 8.3.20 без него запустился по-английски, YAxUnit не нашёл ни одного теста.
$a = @("ENTERPRISE", "/F", (Q $BaseCopy)) + @(Auth) + @("/DisableStartupDialogs",
  "/DisableStartupMessages", "/L", "ru", "/VLru_RU", "/C", (Q "RunUnitTests=$cfg"))
$min = if (Get-Setting "testTimeoutMin") { [int](Get-Setting "testTimeoutMin") } else { 10 }
# Если yaxunit.log не появился за testStartMin минут (по умолчанию 3), клиент
# не дошёл до тестов: обычно ждёт человека в окне, которого может не быть на экране.
$startMin = if (Get-Setting "testStartMin") { [int](Get-Setting "testStartMin") } else { 3 }
$t0 = Get-Date
$p = Start-Process -FilePath $V8Exe -ArgumentList $a -PassThru; $null = $p.Handle
$state = "done"; $logAt = $null
while (-not $p.WaitForExit(5000)) {
  $el = ((Get-Date) - $t0).TotalMinutes
  if (-not $logAt -and (Test-Path "yaxunit.log")) { $logAt = [int]((Get-Date) - $t0).TotalSeconds }
  if (-not $logAt -and $el -ge $startMin) { $state = "nostart"; break }
  if ($el -ge $min) { $state = "timeout"; break }
}
if ($state -ne "done") {
  try { $p.Kill() } catch {}
  if ($state -eq "nostart") {
    "ТАЙМ-АУТ: клиент не дошёл до тестов за $startMin мин (нет yaxunit.log), процесс снят."
    "Частая причина — флажки безопасности: у расширений YAXUNIT и ТестыОбработки"
    "«Безопасный режим» и «Защита от опасных действий», у пользователя «Предупреждать об опасных действиях»."
  } else {
    "ТАЙМ-АУТ: тесты не закончились за $min мин, процесс снят."
    "Частая причина — модальное окно без человека: «Предупреждение безопасности» при открытии файла"
    "или «Переход на новую версию платформы»."
  }
  "Данные копии могли остаться изменёнными."
  exit 3
}
"Клиент завершился за $([int]((Get-Date) - $t0).TotalSeconds) с"
if (-not (Test-Path "exitcode.txt")) { "НЕТ ИТОГА: exitcode.txt не появился, тесты не дошли до конца. Смотрите yaxunit.log."; exit 2 }
if (-not (Test-Path "junit.xml")) { "НЕТ ИТОГА: нет junit.xml"; exit 2 }
$exit = (Get-Content "exitcode.txt" -Raw).Trim()
[xml]$j = Get-Content "junit.xml" -Raw -Encoding UTF8
$cases = @($j.SelectNodes("//testcase"))
$bad = @($cases | Where-Object { $_.SelectSingleNode("failure|error") })
$skip = @($cases | Where-Object { $_.SelectSingleNode("skipped") })
"Тестов: $($cases.Count), упало или с ошибкой: $($bad.Count), пропущено: $($skip.Count), exitcode.txt: $exit"
foreach ($c in $bad) {
  $n = $c.SelectSingleNode("failure|error")
  $text = "$($n.message) $($n.InnerText)".Trim()
  if ($text.Length -gt 600) { $text = $text.Substring(0, 600) + " …" }
  "  КРАСНЫЙ $($c.classname).$($c.name): $text"
}
# Пустой результат — не зелёный: ноль тестов бывает, когда клиент запустился
# не на том языке или не нашёл расширение тестов.
if ($cases.Count -eq 0) { "НЕТ ИТОГА: ни одного теста. Проверьте имя расширения в xUnitParams.json и yaxunit.log."; exit 2 }
if ($skip.Count -eq $cases.Count) { "НЕТ ИТОГА: все тесты пропущены"; exit 2 }
if ($bad.Count -gt 0 -or $exit -ne "0") { "КРАСНЫЙ"; exit 1 }
"ЗЕЛЁНЫЙ"; exit 0
