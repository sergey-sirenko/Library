# Технический контекст

## Стек и окружение

- Free Pascal 3.2.2, Lazarus 3.x/4.x, LCL, RTL, FCL и LazUtils.
- Целевая платформа: `x86_64-win64`.
- Репозиторий: `C:\Users\Sergey\source\repos\Library`.
- Lazarus: `C:\Users\Sergey\AppData\Local\lazarus`.
- Сторонние runtime-DLL, ORM и СУБД не используются.

## Проекты и каталоги

- `Library.lpi`, `LibraApp.lpr` — основное приложение.
- `LibraryUpdater.lpi`, `LibraryUpdater.lpr` — помощник обновления.
- `src/` — модули, `src/forms/` — формы, `tests/` — тестовые проекты.
- `Prog/` — рабочие EXE и runtime-окружение, `lib/` — результаты компиляции,
  `dist/` — игнорируемые release-артефакты.
- `Data/`, `Covers/`, `Backup/`, `Logs/` — пользовательские данные и журналы.

## Сборка и тесты

Основной проект:

```powershell
& 'C:\Users\Sergey\AppData\Local\lazarus\lazbuild.exe' 'C:\Users\Sergey\source\repos\Library\Library.lpi'
```

Полная release-проверка из чистого рабочего дерева:

```powershell
& '.\scripts\Build-Release.ps1'
```

Скрипт собирает основное приложение, updater, `UpdaterTests` и `UpdaterProbe`,
проверяет версии, JSON релиза, SHA-256, состав ZIP, успешную замену и откат.
`-AllowDirty` используется только для промежуточной разработки.

## Хранение и сеть

- `Data\*.dat` — бинарные сущности; `Data\*.idx` — собственные индексы.
- Хеш пароля реализован стандартным модулем `sha1` FPC.
- HTTPS выполняется через `winhttp.dll`/SChannel.
- GitHub endpoint обновлений:
  `https://api.github.com/repos/sergey-sirenko/Library/releases/latest`.

## Релизы

- Версия задаётся константой `APP_VERSION` в `src/uTypes.pas`.
- Тег: `v<версия>`; архив: `dist/Library-v<версия>-win64.zip`.
- В релиз прикладываются ZIP и `Library-v<версия>-win64.zip.sha256`.
- Публикуются только стабильные релизы; draft и prerelease клиент игнорирует.
- После публикации проверяются публичный API, имя asset, размер и GitHub digest.
