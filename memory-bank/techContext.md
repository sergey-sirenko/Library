# Технический контекст

## Стек и окружение

- Free Pascal 3.2.2, Lazarus 3.x/4.x, LCL, RTL, FCL и LazUtils.
- Целевая платформа: `x86_64-win64`.
- Сторонние runtime-DLL, ORM и СУБД не используются.
- Единственный канонический путь Lazarus в текущем окружении:
  `C:\Users\Sergey\AppData\Local\lazarus\lazbuild.exe`.

## Структура

- `Library.lpi`, `LibraApp.lpr` — основное приложение.
- `LibraryUpdater.lpi`, `LibraryUpdater.lpr` — помощник обновления.
- `src/` — модули, `src/forms/` — формы, `tests/` — тестовые проекты.
- `docs/` — техническое задание и пользовательские инструкции.
- `Prog/` — рабочие EXE и runtime-окружение.
- `lib/` — результаты компиляции; `dist/` — release-артефакты.
- Версия приложения задаётся `APP_VERSION` в `src/uTypes.pas`.

## Команды

Основное приложение:

```powershell
& 'C:\Users\Sergey\AppData\Local\lazarus\lazbuild.exe' 'C:\Users\Sergey\source\repos\Library\Library.lpi'
```

Полная release-проверка из чистого рабочего дерева:

```powershell
& '.\scripts\Build-Release.ps1'
```

`-AllowDirty` допустим только для промежуточной локальной проверки, но не для
выпуска версии.

## Матрица проверок

| Изменение | Обязательная проверка |
|---|---|
| Только Markdown и правила LLM | Ссылки, согласованность, `git diff --check`; сборка не требуется |
| `.pas`, `.lpr`, `.lfm`, `.lpi` | Сборка затронутого проекта, результат `0 errors` |
| Updater или release-процесс | `scripts/Build-Release.ps1`; при разработке допустим `-AllowDirty` |
| UI и бизнес-сценарии | Сборка плюс ручная проверка затронутого сценария |

Release-скрипт собирает основное приложение, updater, `UpdaterTests` и
`UpdaterProbe`, затем проверяет версии, JSON, SHA-256, установку, откат и состав
архива. Если `Prog/Library.exe` занят запущенным приложением, перед сборкой его
нужно закрыть.
