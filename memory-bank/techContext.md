# Технический контекст

## Стек
- Free Pascal
- Lazarus / LCL
- RTL / FCL (без сторонних DLL, ORM, СУБД)

## Хранение
- `Data\*.dat` — бинарные файлы сущностей
- `Data\*.idx` — собственные индексы
- `Covers\` — обложки
- `Backup\` — резервные копии
- `Logs\` — технический журнал и журнал действий

## Сборка
- Проект: `Library.lpi`
- Точка входа: `LibraApp.lpr` (не `Library` — ключевое слово Pascal)
- Исходники: `src\`
- Формы: `src\forms\`
- Пакеты: LCL, LazUtils
- Хеш пароля: модуль `sha1` (стандартный hash FPC 3.2.2)
- Lazarus: `%LOCALAPPDATA%\lazarus`
