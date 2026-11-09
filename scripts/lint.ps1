# lint.ps1 — проверка кода src\ анализатором BSL Language Server (шаг 4 статьи).
# Итог — строка «Замечаний: N». Если есть lint-baseline.txt, замечаний не должно стать больше.
. "$PSScriptRoot\common.ps1"
Set-Location $PSScriptRoot
Need-Env @("BSLLS_EXE")
if (-not (Test-Path $env:BSLLS_EXE)) { "ОШИБКА: нет файла BSLLS_EXE = $env:BSLLS_EXE"; exit 2 }
# Без UTF-8 для Java русские сообщения превращаются в кракозябры.
$env:JAVA_TOOL_OPTIONS = "-Dfile.encoding=UTF-8"
# Каталог отчёта создаём сами: BSL LS 1.0.7 его не создаёт, Java падает,
# а без этой строки скрипт печатал «Замечаний: 0».
New-Item -ItemType Directory -Force lint | Out-Null
$rep = "$PSScriptRoot\lint\bsl-json.json"
Remove-Item $rep -ErrorAction SilentlyContinue
$args_ = @("analyze", "-s", "src", "-o", "lint", "-r", "json", "-c", "bsl-ls.json", "-q")
# Вывод BSL LS (предупреждения Java «Picked up JAVA_TOOL_OPTIONS», WARNING) — не замечания:
# прячем его и показываем, только если отчёта нет.
if ($env:BSLLS_EXE -like "*.jar") { $out = & java -jar $env:BSLLS_EXE @args_ 2>&1 }
else { $out = & $env:BSLLS_EXE @args_ 2>&1 }
if (-not (Test-Path $rep)) {
  "ОШИБКА: BSL LS не записал отчёт lint\bsl-json.json. Это не «0 замечаний». Вывод BSL LS:"
  $out | ForEach-Object { "$_" }; exit 2
}
$r = Get-Content $rep -Raw -Encoding UTF8 | ConvertFrom-Json
$list = @()
foreach ($f in $r.fileinfos) {
  # Путь в отчёте печатается как file:///…: приводим к пути от папки проекта.
  $p = [uri]::UnescapeDataString(($f.path -replace '^file:///', '')) -replace '/', '\'
  $p = $p -replace [regex]::Escape("$PSScriptRoot\"), ''
  foreach ($d in $f.diagnostics) { $list += "$p`:$($d.range.start.line + 1) $($d.code): $($d.message)" }
}
"Замечаний: $($list.Count)"
$list | Select-Object -First 200
if ($list.Count -gt 200) { "… и ещё $($list.Count - 200), полный отчёт: lint\bsl-json.json" }
if (Test-Path "$PSScriptRoot\lint-baseline.txt") {
  $base = [int](Get-Content "$PSScriptRoot\lint-baseline.txt" -Raw).Trim()
  if ($list.Count -gt $base) { "ОШИБКА: замечаний стало больше, чем в lint-baseline.txt ($base)"; exit 1 }
}
exit 0
