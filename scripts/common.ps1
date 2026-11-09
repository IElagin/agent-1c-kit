# common.ps1 — общие функции скриптов набора. Сам по себе не запускается:
# остальные скрипты подключают его строкой  . "$PSScriptRoot\common.ps1"

# Вывод в UTF-8, иначе агент читает русские сообщения как мусор.
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$OutputEncoding = [Text.Encoding]::UTF8

# Настройки проекта — settings.json рядом со скриптами, в корне папки проекта.
# Его заполняет агент в части 1 (setup/1-machine.md); в git файл не попадает:
# там пути этой машины и пароль. Переменные окружения набор не читает.
$SettingsFile = Join-Path $PSScriptRoot "settings.json"
$Settings = $null
$SettingsError = ""
if (Test-Path $SettingsFile) {
  $json = Get-Content $SettingsFile -Raw -Encoding UTF8
  # PowerShell 7 прощает запятую перед } или ], а 5.1 нет: отвергаем её сразу,
  # иначе файл, проверенный в pwsh, сломается у человека в Windows PowerShell.
  if ($json -match ',\s*[}\]]') { $SettingsError = "лишняя запятая перед } или ]" }
  else {
    try { $Settings = $json | ConvertFrom-Json }
    # В 5.1 текст ошибки содержит весь файл вместе с паролем после «(позиция):».
    catch { $SettingsError = (("$($_.Exception.Message)" -split "`r?`n")[0] -replace '\s*\(\d+\):.*$', '') }
  }
}
# exit здесь вышел бы только из common.ps1, а вызвавший скрипт пошёл бы дальше
# без функций. Поэтому ошибку разбора сообщает Need-Settings: exit в функции
# завершает весь скрипт.
function Get-Setting([string]$name) {
  if ($Settings -and $Settings.PSObject.Properties[$name]) { "$($Settings.$name)".Trim() } else { "" }
}
$V8Exe = Get-Setting "v8Exe"
$V8User = Get-Setting "v8User"
$V8Password = Get-Setting "v8Password"
$BaseCopy = Get-Setting "baseCopy"
$BuildBase = Get-Setting "buildBase"
$BslLsExe = Get-Setting "bslLsExe"

# Start-Process не берёт аргументы в кавычки сам: путь с пробелом или имя
# пользователя без кавычек разваливаются на несколько аргументов.
function Q([string]$s) { '"' + $s + '"' }

# Проверка настроек. Пути к платформе и базе берутся только из settings.json,
# а не из аргументов: агент меняет их только после «да» человека.
function Need-Settings([string[]]$names) {
  if ($SettingsError) { Write-Output "ОШИБКА: settings.json не читается как JSON: $SettingsError"; exit 2 }
  if (-not $Settings) { Write-Output "ОШИБКА: нет settings.json в папке проекта (см. setup/1-machine.md)"; exit 2 }
  foreach ($n in $names) {
    if (-not (Get-Setting $n)) { Write-Output "ОШИБКА: в settings.json не задано $n (см. setup/1-machine.md)"; exit 2 }
  }
  if ($V8Exe -and -not (Test-Path $V8Exe)) {
    Write-Output "ОШИБКА: нет файла v8Exe = $V8Exe"; exit 2
  }
  foreach ($b in @($BaseCopy, $BuildBase)) {
    if ($b -and -not (Test-Path (Join-Path $b "1Cv8.1CD"))) {
      Write-Output "ОШИБКА: в каталоге $b нет 1Cv8.1CD — это не файловая база"; exit 2
    }
  }
}

# Пользователь базы. Без /N в базе с пользователями конфигуратор пишет
# «Пользователь ИБ не идентифицирован» и ничего не делает, а клиент выходит молча.
function Auth {
  $a = @("/N", (Q $V8User))
  if ($V8Password) { $a += @("/P", (Q $V8Password)) }
  $a
}

# База для выгрузки и сборки: buildBase, если задана, иначе копия для тестов.
function Build-Base { if ($BuildBase) { $BuildBase } else { $BaseCopy } }

# Запуск 1cv8.exe с ожиданием. Оператор & оконное приложение не ждёт: скрипт
# пошёл бы дальше, пока журнала ещё нет. Возвращает код возврата или $null,
# если процесс не уложился в $minutes и был снят.
function Invoke-1C([string[]]$a, [int]$minutes = 0) {
  $p = Start-Process -FilePath $V8Exe -ArgumentList $a -PassThru
  $null = $p.Handle
  if ($minutes -gt 0) {
    if (-not $p.WaitForExit($minutes * 60000)) { try { $p.Kill() } catch {}; return $null }
  } else { $p.WaitForExit() }
  $p.ExitCode
}

# Журнал /Out. Без него агент видит только «команда завершилась».
function Show-Log([string]$log) {
  if (Test-Path $log) { Get-Content $log -Encoding UTF8 } else { Write-Output "(журнала $log нет)" }
}

# Файл /DumpResult: 0 — успех, 1 — ошибка.
function Read-Res([string]$res) {
  if (Test-Path $res) { (Get-Content $res -Raw).Trim() } else { "нет файла" }
}
