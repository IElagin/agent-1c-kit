# install-ext.ps1 — установка расширения из файла .cfe в копию базы (часть 1, YAxUnit):
# /LoadCfg -Extension, затем /UpdateDBCfg -Extension.
#   .\install-ext.ps1 -Cfe tmp\downloads\YAxUnit-25.12.cfe -Name YAXUNIT
param([string]$Cfe, [string]$Name)
. "$PSScriptRoot\common.ps1"
Set-Location $PSScriptRoot
Need-Env @("V8_EXE", "V8_USER", "V8_BASE_COPY")
if (-not $Cfe -or -not $Name) { "Использование: .\install-ext.ps1 -Cfe <файл.cfe> -Name <имя расширения>"; exit 2 }
if (-not (Test-Path $Cfe)) { "ОШИБКА: нет файла $Cfe"; exit 2 }
$cfePath = (Resolve-Path $Cfe).Path
$log = "$PSScriptRoot\install-ext.log"; $res = "$PSScriptRoot\install-ext.res"
$base = @("DESIGNER", "/F", (Q $env:V8_BASE_COPY)) + @(Auth) + @("/DisableStartupDialogs", "/DisableStartupMessages")

foreach ($step in @(
    @("Загрузка", @("/LoadCfg", (Q $cfePath), "-Extension", (Q $Name))),
    @("Обновление базы", @("/UpdateDBCfg", "-Extension", (Q $Name))))) {
  Remove-Item $log, $res -ErrorAction SilentlyContinue
  $code = Invoke-1C ($base + $step[1] + @("/Out", (Q $log), "/DumpResult", (Q $res)))
  Show-Log $log
  $r = Read-Res $res
  if ($code -ne 0 -or $r -ne "0") { "ОШИБКА на шаге «$($step[0])»: код $code, install-ext.res $r"; exit 1 }
  "$($step[0]): код 0"
}
"Расширение $Name установлено в копию базы."
"Новое расширение встаёт с включёнными «Безопасный режим» и «Защита от опасных действий»: попроси человека снять."
exit 0
