# common.ps1 — общие функции скриптов набора. Сам по себе не запускается:
# остальные скрипты подключают его строкой  . "$PSScriptRoot\common.ps1"

# Вывод в UTF-8, иначе агент читает русские сообщения как мусор.
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$OutputEncoding = [Text.Encoding]::UTF8

# Переменная, заданная после запуска агента (setx, «Переменные среды»), видна только
# новым процессам. Если её нет в процессе, берём из настроек пользователя или машины.
foreach ($n in @("V8_EXE", "V8_USER", "V8_PASSWORD", "V8_BASE_COPY", "V8_BUILD_BASE", "BSLLS_EXE", "V8_TEST_TIMEOUT_MIN")) {
  if (-not [Environment]::GetEnvironmentVariable($n)) {
    $v = [Environment]::GetEnvironmentVariable($n, "User")
    if (-not $v) { $v = [Environment]::GetEnvironmentVariable($n, "Machine") }
    if ($v) { Set-Item "env:$n" $v }
  }
}

# Start-Process не берёт аргументы в кавычки сам: путь с пробелом или имя
# пользователя без кавычек разваливаются на несколько аргументов.
function Q([string]$s) { '"' + $s + '"' }

# Проверка переменных окружения. Пути к платформе и базе задаются только ими,
# а не аргументами: так агенту труднее подставить чужую базу.
function Need-Env([string[]]$names) {
  foreach ($n in $names) {
    if (-not [Environment]::GetEnvironmentVariable($n)) {
      Write-Output "ОШИБКА: не задана переменная окружения $n (см. README.md)"; exit 2
    }
  }
  if ($env:V8_EXE -and -not (Test-Path $env:V8_EXE)) {
    Write-Output "ОШИБКА: нет файла V8_EXE = $env:V8_EXE"; exit 2
  }
  foreach ($b in @($env:V8_BASE_COPY, $env:V8_BUILD_BASE)) {
    if ($b -and -not (Test-Path (Join-Path $b "1Cv8.1CD"))) {
      Write-Output "ОШИБКА: в каталоге $b нет 1Cv8.1CD — это не файловая база"; exit 2
    }
  }
}

# Пользователь базы. Без /N в базе с пользователями конфигуратор пишет
# «Пользователь ИБ не идентифицирован» и ничего не делает, а клиент выходит молча.
function Auth {
  $a = @("/N", (Q $env:V8_USER))
  if ($env:V8_PASSWORD) { $a += @("/P", (Q $env:V8_PASSWORD)) }
  $a
}

# База для выгрузки и сборки: V8_BUILD_BASE, если задана, иначе копия для тестов.
function Build-Base { if ($env:V8_BUILD_BASE) { $env:V8_BUILD_BASE } else { $env:V8_BASE_COPY } }

# Запуск 1cv8.exe с ожиданием. Оператор & оконное приложение не ждёт: скрипт
# пошёл бы дальше, пока журнала ещё нет. Возвращает код возврата или $null,
# если процесс не уложился в $minutes и был снят.
function Invoke-1C([string[]]$a, [int]$minutes = 0) {
  $p = Start-Process -FilePath $env:V8_EXE -ArgumentList $a -PassThru
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
