# build-tests.ps1 — загрузка расширения с тестами tests\ в копию базы (шаги 5–6 статьи):
# /LoadConfigFromFiles, затем /UpdateDBCfg. Без второй команды новый код не заработает,
# хотя загрузка «прошла».
. "$PSScriptRoot\common.ps1"
Set-Location $PSScriptRoot
Need-Settings @("v8Exe", "v8User", "baseCopy")
$ext = "ТестыОбработки"   # то же имя, что в xUnitParams.json -> filter.extensions
if (-not (Test-Path "$PSScriptRoot\tests\Configuration.xml")) { "ОШИБКА: нет tests\Configuration.xml"; exit 2 }
$log = "$PSScriptRoot\build-tests.log"; $res = "$PSScriptRoot\build-tests.res"
$base = @("DESIGNER", "/F", (Q $BaseCopy)) + @(Auth) + @("/DisableStartupDialogs", "/DisableStartupMessages")

foreach ($step in @(
    @("Загрузка", @("/LoadConfigFromFiles", (Q "$PSScriptRoot\tests"), "-Extension", (Q $ext))),
    @("Обновление базы", @("/UpdateDBCfg", "-Extension", (Q $ext))))) {
  Remove-Item $log, $res -ErrorAction SilentlyContinue
  $code = Invoke-1C ($base + $step[1] + @("/Out", (Q $log), "/DumpResult", (Q $res)))
  # Журнал у этих команд бывает пустым и при успехе: итог по коду и build-tests.res.
  Show-Log $log
  $r = Read-Res $res
  if ($code -ne 0 -or $r -ne "0") { "ОШИБКА на шаге «$($step[0])»: код $code, build-tests.res $r"; exit 1 }
  "$($step[0]): код 0"
}
"Расширение $ext загружено в копию базы"; exit 0
