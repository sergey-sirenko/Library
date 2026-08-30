[CmdletBinding()]
param(
  [string]$Version = '',
  [string]$LazBuild = 'C:\Users\Sergey\AppData\Local\lazarus\lazbuild.exe',
  [switch]$AllowDirty
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Add-Type -AssemblyName System.IO.Compression.FileSystem

$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$typesFile = Join-Path $repoRoot 'src\uTypes.pas'
$typesText = Get-Content -LiteralPath $typesFile -Raw
$match = [regex]::Match($typesText, "APP_VERSION\s*=\s*'(?<version>\d+\.\d+\.\d+)'\s*;")
if (-not $match.Success) {
  throw 'Не удалось прочитать APP_VERSION из src\uTypes.pas.'
}

$appVersion = $match.Groups['version'].Value
if ([string]::IsNullOrWhiteSpace($Version)) {
  $Version = $appVersion
}
if ($Version -ne $appVersion) {
  throw "Запрошена версия $Version, но APP_VERSION равен $appVersion."
}
if ($Version -notmatch '^\d+\.\d+\.\d+$') {
  throw "Некорректная версия: $Version."
}
if (-not (Test-Path -LiteralPath $LazBuild -PathType Leaf)) {
  throw "lazbuild не найден: $LazBuild"
}

if (-not $AllowDirty) {
  $status = & git -C $repoRoot status --porcelain
  if ($LASTEXITCODE -ne 0) {
    throw 'Не удалось проверить состояние Git.'
  }
  if ($status) {
    throw 'Рабочая копия содержит изменения. Зафиксируйте их перед выпуском релиза.'
  }
}

function Invoke-LazarusBuild([string]$ProjectFile) {
  & $LazBuild $ProjectFile
  if ($LASTEXITCODE -ne 0) {
    throw "Ошибка сборки проекта: $ProjectFile"
  }
}

Invoke-LazarusBuild (Join-Path $repoRoot 'Library.lpi')
Invoke-LazarusBuild (Join-Path $repoRoot 'LibraryUpdater.lpi')
Invoke-LazarusBuild (Join-Path $repoRoot 'tests\UpdaterTests.lpi')
Invoke-LazarusBuild (Join-Path $repoRoot 'tests\UpdaterProbe.lpi')

$testExe = Join-Path $repoRoot 'lib\tests\UpdaterTests.exe'
& $testExe
if ($LASTEXITCODE -ne 0) {
  throw 'Тесты обновления завершились с ошибкой.'
}

function Test-UpdaterExecutable {
  $testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("Library Updater Обновление-" + [guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Path $testRoot | Out-Null
  try {
    $target = Join-Path $testRoot 'Library.exe'
    $source = Join-Path $testRoot 'NewLibrary.exe'
    $log = Join-Path $testRoot 'updater.log'
    $marker = "$target.started"
    [System.IO.File]::WriteAllText($target, 'old-version')
    Copy-Item -LiteralPath (Join-Path $repoRoot 'lib\tests\UpdaterProbe.exe') -Destination $source
    $arguments = "--wait-pid 0 --source `"$source`" --target `"$target`" " +
      "--restart `"$target`" --log `"$log`" --silent"
    $process = Start-Process -FilePath (Join-Path $repoRoot 'Prog\LibraryUpdater.exe') `
      -ArgumentList $arguments `
      -Wait -PassThru
    if ($process.ExitCode -ne 0) {
      if (Test-Path -LiteralPath $log) {
        Get-Content -LiteralPath $log | Write-Host
      }
      throw "Updater завершился с кодом $($process.ExitCode) в успешном сценарии."
    }
    for ($i = 0; ($i -lt 50) -and (-not (Test-Path -LiteralPath $marker)); $i++) {
      Start-Sleep -Milliseconds 100
    }
    if (-not (Test-Path -LiteralPath $marker)) {
      throw 'Updater не запустил установленное приложение.'
    }
    if ((Get-Content -LiteralPath "$target.old" -Raw) -ne 'old-version') {
      throw 'Updater не сохранил предыдущую версию.'
    }

    Remove-Item -LiteralPath $target,$marker,"$target.old" -Force
    [System.IO.File]::WriteAllText($target, 'rollback-version')
    if (Test-Path -LiteralPath $source) {
      Remove-Item -LiteralPath $source -Force
    }
    $process = Start-Process -FilePath (Join-Path $repoRoot 'Prog\LibraryUpdater.exe') `
      -ArgumentList $arguments `
      -Wait -PassThru
    if ($process.ExitCode -eq 0) {
      throw 'Updater не сообщил об ошибке отсутствующего нового EXE.'
    }
    if ((Get-Content -LiteralPath $target -Raw) -ne 'rollback-version') {
      throw 'Updater не восстановил предыдущую версию после ошибки.'
    }
  }
  finally {
    if (Test-Path -LiteralPath $testRoot) {
      Remove-Item -LiteralPath $testRoot -Recurse -Force
    }
  }
}

Test-UpdaterExecutable

$appExe = Join-Path $repoRoot 'Prog\Library.exe'
$updaterExe = Join-Path $repoRoot 'Prog\LibraryUpdater.exe'
$instruction = Join-Path $repoRoot 'Инструкция_установки_новой_версии.md'
foreach ($requiredFile in @($appExe, $updaterExe, $instruction)) {
  if (-not (Test-Path -LiteralPath $requiredFile -PathType Leaf)) {
    throw "Не найден файл релиза: $requiredFile"
  }
}

$distDir = [System.IO.Path]::GetFullPath((Join-Path $repoRoot 'dist'))
$expectedPrefix = $repoRoot.TrimEnd([System.IO.Path]::DirectorySeparatorChar) +
  [System.IO.Path]::DirectorySeparatorChar
if (-not $distDir.StartsWith($expectedPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
  throw "Недопустимый путь dist: $distDir"
}
if (Test-Path -LiteralPath $distDir) {
  Remove-Item -LiteralPath $distDir -Recurse -Force
}
$stageDir = Join-Path $distDir 'stage'
New-Item -ItemType Directory -Path $stageDir | Out-Null

Copy-Item -LiteralPath $appExe -Destination (Join-Path $stageDir 'Library.exe')
Copy-Item -LiteralPath $updaterExe -Destination (Join-Path $stageDir 'LibraryUpdater.exe')
Copy-Item -LiteralPath $instruction -Destination (Join-Path $stageDir 'INSTALL.md')

$assetName = "Library-v$Version-win64.zip"
$archiveFile = Join-Path $distDir $assetName
Push-Location $stageDir
try {
  Compress-Archive -LiteralPath @(
    'Library.exe',
    'LibraryUpdater.exe',
    'INSTALL.md'
  ) -DestinationPath $archiveFile -CompressionLevel Optimal
}
finally {
  Pop-Location
}

$entries = [System.IO.Compression.ZipFile]::OpenRead($archiveFile)
try {
  $entryNames = @($entries.Entries | ForEach-Object FullName | Sort-Object)
  $expectedNames = @(
    'Library.exe',
    'LibraryUpdater.exe',
    'INSTALL.md'
  ) | Sort-Object
  if (($entryNames.Count -ne 3) -or
      (Compare-Object -ReferenceObject $expectedNames -DifferenceObject $entryNames)) {
    throw 'Созданный ZIP содержит неожиданный набор файлов.'
  }
}
finally {
  $entries.Dispose()
}

$hash = (Get-FileHash -LiteralPath $archiveFile -Algorithm SHA256).Hash.ToLowerInvariant()
$hashFile = "$archiveFile.sha256"
Set-Content -LiteralPath $hashFile -Value "$hash  $assetName" -Encoding ascii
Remove-Item -LiteralPath $stageDir -Recurse -Force

& $testExe $archiveFile
if ($LASTEXITCODE -ne 0) {
  throw 'Проверка содержимого release-архива завершилась с ошибкой.'
}

Write-Host "Готов архив: $archiveFile"
Write-Host "SHA-256: $hash"
Write-Host "Файл суммы: $hashFile"
