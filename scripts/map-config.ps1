# map-config.ps1 — карта объектов конфигурации для агента (часть 3).
# Читает файл версий ConfigDumpInfo.xml из общей выгрузки и пишет map.txt рядом:
# объекты, реквизиты, табличные части, измерения, ресурсы, значения перечислений,
# формы и макеты, по строке на группу, с русскими именами видов, как в запросах.
# Базу не открывает. Обычно его вызывает dump-config.ps1; сам — после ручной выгрузки:
#   .\map-config.ps1                       источник — самый свежий ConfigDumpInfo.xml в configDump
#   .\map-config.ps1 -Info <файл.xml>      источник — этот файл
# Коды выхода: 0 карта построена, 1 файл версий не читается, 2 нет настроек или файла.
param([string]$Info)
. "$PSScriptRoot\common.ps1"
Set-Location $PSScriptRoot
Need-Settings @()
if (-not $ConfigDump) { "ОШИБКА: в settings.json не задано configDump (см. setup/3-config.md, шаг 3.1)"; exit 2 }
if (-not [IO.Path]::IsPathRooted($ConfigDump)) { "ОШИБКА: configDump = $ConfigDump — нужен полный путь"; exit 2 }
$root = [IO.Path]::GetFullPath($ConfigDump).TrimEnd('\')
$xml = Join-Path $root "xml"
if (-not $Info) {
  $cand = @((Join-Path $xml "ConfigDumpInfo.xml"), (Join-Path (Join-Path $root "info") "ConfigDumpInfo.xml")) |
    Where-Object { Test-Path $_ } | Sort-Object { (Get-Item $_).LastWriteTime } -Descending
  if (-not $cand) { "ОШИБКА: в $root нет ConfigDumpInfo.xml — сначала .\dump-config.ps1 -MapOnly или .\dump-config.ps1"; exit 2 }
  $Info = @($cand)[0]
}
if (-not (Test-Path $Info)) { "ОШИБКА: нет файла $Info"; exit 2 }
$Info = (Resolve-Path $Info).Path

# Вид объекта: имя в выгрузке -> имя в запросах и коде, каталог XML в выгрузке.
$kinds = @{
  "Catalog" = @("Справочник", "Catalogs"); "Document" = @("Документ", "Documents")
  "DocumentJournal" = @("ЖурналДокументов", "DocumentJournals"); "Enum" = @("Перечисление", "Enums")
  "Report" = @("Отчет", "Reports"); "DataProcessor" = @("Обработка", "DataProcessors")
  "ChartOfCharacteristicTypes" = @("ПланВидовХарактеристик", "ChartsOfCharacteristicTypes")
  "ChartOfAccounts" = @("ПланСчетов", "ChartsOfAccounts"); "ChartOfCalculationTypes" = @("ПланВидовРасчета", "ChartsOfCalculationTypes")
  "InformationRegister" = @("РегистрСведений", "InformationRegisters"); "AccumulationRegister" = @("РегистрНакопления", "AccumulationRegisters")
  "AccountingRegister" = @("РегистрБухгалтерии", "AccountingRegisters"); "CalculationRegister" = @("РегистрРасчета", "CalculationRegisters")
  "BusinessProcess" = @("БизнесПроцесс", "BusinessProcesses"); "Task" = @("Задача", "Tasks"); "ExchangePlan" = @("ПланОбмена", "ExchangePlans")
  "Constant" = @("Константа", "Constants"); "CommonModule" = @("ОбщийМодуль", "CommonModules"); "CommonForm" = @("ОбщаяФорма", "CommonForms")
  "CommonTemplate" = @("ОбщийМакет", "CommonTemplates"); "CommonCommand" = @("ОбщаяКоманда", "CommonCommands")
  "CommandGroup" = @("ГруппаКоманд", "CommandGroups"); "CommonAttribute" = @("ОбщийРеквизит", "CommonAttributes")
  "CommonPicture" = @("ОбщаяКартинка", "CommonPictures"); "Subsystem" = @("Подсистема", "Subsystems"); "Role" = @("Роль", "Roles")
  "SessionParameter" = @("ПараметрСеанса", "SessionParameters"); "FunctionalOption" = @("ФункциональнаяОпция", "FunctionalOptions")
  "FunctionalOptionsParameter" = @("ПараметрФункциональныхОпций", "FunctionalOptionsParameters")
  "DefinedType" = @("ОпределяемыйТип", "DefinedTypes"); "EventSubscription" = @("ПодпискаНаСобытие", "EventSubscriptions")
  "ScheduledJob" = @("РегламентноеЗадание", "ScheduledJobs"); "FilterCriterion" = @("КритерийОтбора", "FilterCriteria")
  "SettingsStorage" = @("ХранилищеНастроек", "SettingsStorages"); "XDTOPackage" = @("ПакетXDTO", "XDTOPackages")
  "WebService" = @("WebСервис", "WebServices"); "HTTPService" = @("HTTPСервис", "HTTPServices"); "WSReference" = @("WSСсылка", "WSReferences")
  "Style" = @("Стиль", "Styles"); "StyleItem" = @("ЭлементСтиля", "StyleItems"); "Language" = @("Язык", "Languages")
  "Interface" = @("Интерфейс", "Interfaces"); "Sequence" = @("Последовательность", "Sequences")
  "DocumentNumerator" = @("НумераторДокументов", "DocumentNumerators"); "ExternalDataSource" = @("ВнешнийИсточникДанных", "ExternalDataSources")
  "Bot" = @("Бот", "Bots"); "IntegrationService" = @("СервисИнтеграции", "IntegrationServices")
}
# Части объекта: имя в выгрузке -> в единственном и множественном числе.
$parts = @{
  "Attribute" = @("Реквизит", "Реквизиты"); "TabularSection" = @("ТабличнаяЧасть", "ТабличныеЧасти")
  "Dimension" = @("Измерение", "Измерения"); "Resource" = @("Ресурс", "Ресурсы"); "EnumValue" = @("Значение", "Значения")
  "Form" = @("Форма", "Формы"); "Template" = @("Макет", "Макеты"); "Command" = @("Команда", "Команды")
  "AccountingFlag" = @("ПризнакУчета", "ПризнакиУчета"); "ExtDimensionAccountingFlag" = @("ПризнакУчетаСубконто", "ПризнакиУчетаСубконто")
  "AddressingAttribute" = @("РеквизитАдресации", "РеквизитыАдресации"); "Column" = @("Графа", "Графы")
  "Recalculation" = @("Перерасчет", "Перерасчеты"); "URLTemplate" = @("ШаблонURL", "ШаблоныURL"); "Method" = @("Метод", "Методы")
  "Operation" = @("Операция", "Операции"); "Parameter" = @("Параметр", "Параметры"); "Subsystem" = @("Подсистема", "Подсистемы")
  "Table" = @("Таблица", "Таблицы"); "Field" = @("Поле", "Поля"); "Cube" = @("Куб", "Кубы"); "Function" = @("Функция", "Функции")
  "IntegrationServiceChannel" = @("КаналСервисаИнтеграции", "Каналы")
}
function Kind([string]$k) { if ($kinds.ContainsKey($k)) { $kinds[$k][0] } else { $k } }
function Part([string]$k, [int]$i) { if ($parts.ContainsKey($k)) { $parts[$k][$i] } else { $k } }

# Читаем потоком: у типовых конфигураций файл версий — десятки мегабайт.
$t0 = Get-Date
$names = New-Object System.Collections.Generic.List[string]
try {
  $rs = New-Object System.Xml.XmlReaderSettings
  $rs.IgnoreWhitespace = $true; $rs.IgnoreComments = $true
  $r = [System.Xml.XmlReader]::Create($Info, $rs)
  while ($r.Read()) {
    if ($r.NodeType -eq [System.Xml.XmlNodeType]::Element -and $r.LocalName -eq "Metadata") {
      $n = $r.GetAttribute("name"); if ($n) { $names.Add($n) } }
  }
  $r.Close()
} catch { "ОШИБКА: $Info не читается как XML: $($_.Exception.Message)"; exit 1 }
if ($names.Count -eq 0) { "ОШИБКА: в $Info нет элементов Metadata — это не файл версий выгрузки"; exit 1 }

# Имя в файле версий: Вид.Имя, затем пары «часть.имя»: Document.Реализация.TabularSection.Товары.Attribute.Сумма.
# Нечётное число частей — служебный узел (содержимое формы или макета), его пропускаем.
$objs = @{}; $cfgName = ""; $count = @{}
foreach ($n in $names) {
  $p = $n.Split('.')
  if ($p.Count -lt 2) { continue }
  if ($p[0] -eq "Configuration") { if ($p.Count -eq 2) { $cfgName = $p[1] }; continue }
  $key = (Kind $p[0]) + "." + $p[1]
  if (-not $objs.ContainsKey($key)) { $objs[$key] = [ordered]@{ "#kind" = $p[0]; "#name" = $p[1] } }
  if ($p.Count -lt 4 -or ($p.Count % 2) -ne 0) { continue }
  $prefix = @()
  for ($i = 2; $i -lt $p.Count - 2; $i += 2) { $prefix += ((Part $p[$i] 0) + "." + $p[$i + 1]) }
  $label = Part $p[$p.Count - 2] 1
  $group = (@($prefix) + @($label)) -join "."
  $o = $objs[$key]
  if (-not $o.Contains($group)) { $o[$group] = New-Object System.Collections.Generic.List[string] }
  $o[$group].Add($p[$p.Count - 1])
  if ($count.ContainsKey($label)) { $count[$label]++ } else { $count[$label] = 1 }
}

# Версия конфигурации — из Configuration.xml полной выгрузки, если она есть. Карта по
# файлу версий из info\ (после -MapOnly) берёт версию из xml\, а не теряет её.
$ver = "неизвестна"
$cx = Join-Path $xml "Configuration.xml"
if (-not (Test-Path $cx)) { $cx = Join-Path (Split-Path $Info) "Configuration.xml" }
if (Test-Path $cx) {
  $head = Get-Content $cx -TotalCount 3000 -Encoding UTF8 | Out-String
  if ($head -match '<Version>([^<]*)</Version>') { $ver = $Matches[1] }
}
$hasXml = Test-Path (Join-Path $xml "Configuration.xml")
$src = Get-Item $Info
$out = New-Object System.Collections.Generic.List[string]
$out.Add("# Карта конфигурации $cfgName, версия $ver")
$out.Add("# Источник: $Info от $($src.LastWriteTime.ToString('dd.MM.yyyy HH:mm')); карта построена $((Get-Date).ToString('dd.MM.yyyy HH:mm'))")
$out.Add("# Строка объекта: Вид.Имя [файл XML в каталоге выгрузки]. Ниже его части: Вид.Имя.Группа: имена через запятую.")
$out.Add("# Стандартных реквизитов (Ссылка, Код, Наименование, Дата, Номер, Проведен, Период, Регистратор и др.) в карте нет: их нет в файле версий.")
$out.Add("# Типы реквизитов в карте не указаны: смотри XML объекта.")
foreach ($key in ($objs.Keys | Sort-Object)) {
  $o = $objs[$key]; $line = $key
  if ($hasXml -and $kinds.ContainsKey($o["#kind"])) {
    $rel = "xml\" + $kinds[$o["#kind"]][1] + "\" + $o["#name"] + ".xml"
    if ([IO.File]::Exists((Join-Path $root $rel))) { $line += " [$rel]" }
  }
  $out.Add($line)
  foreach ($g in $o.Keys) { if (-not "$g".StartsWith("#")) { $out.Add("$key.${g}: " + ($o[$g] -join ", ")) } }
}
$map = Join-Path $root "map.txt"
# UTF-8 с BOM: так кириллицу без подсказки читают и rg, и Select-String в Windows PowerShell 5.1.
[IO.File]::WriteAllLines($map, $out.ToArray(), (New-Object System.Text.UTF8Encoding $true))
function Cnt([string]$l) { if ($count.ContainsKey($l)) { $count[$l] } else { 0 } }
$kb = [math]::Round((Get-Item $map).Length / 1KB)
"Карта: $map, $kb КБ, объектов $($objs.Count), реквизитов $(Cnt 'Реквизиты'), табличных частей $(Cnt 'ТабличныеЧасти'), измерений $(Cnt 'Измерения'), ресурсов $(Cnt 'Ресурсы'), значений перечислений $(Cnt 'Значения'), за $([int]((Get-Date) - $t0).TotalSeconds) с"
if ((Cnt 'Реквизиты') -eq 0) { "ВНИМАНИЕ: в файле версий нет реквизитов. Имена реквизитов бери из XML объектов в $xml" }
exit 0
