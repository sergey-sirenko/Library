program RecognitionTests;

{$mode objfpc}{$H+}

uses
  Classes, SysUtils, Contnrs, FileUtil, LConvEncoding, uEntities, uDatabase,
  uOpenRouter, uTypes;

var
  Failures: Integer = 0;

procedure Check(ACondition: Boolean; const AMessage: string);
begin
  if ACondition then
    WriteLn('[OK] ', AMessage)
  else
  begin
    WriteLn('[FAIL] ', AMessage);
    Inc(Failures);
  end;
end;

procedure CheckEqual(const AExpected, AActual, AMessage: string);
begin
  Check(AExpected = AActual, AMessage + ' (ожидалось «' + AExpected +
    '», получено «' + AActual + '»)');
end;

procedure TestImageResponses;
var
  Book: TRecognizedBook;
  Stats: TRecognitionStats;
  Err, Response: string;
begin
  Response := '{"choices":[{"message":{"content":"{\"title\":\"Добротолюбие\",' +
    '\"inventoryNumber\":\"101\",\"authors\":\"Сборник\",\"year\":1895,' +
    '\"publisher\":\"Типография\",\"isbn\":\"978-1\",' +
    '\"description\":\"Описание\",\"category\":\"Богословие\"}"}}],' +
    '"model":"vision/model","usage":{"prompt_tokens":10,' +
    '"completion_tokens":20,"total_tokens":30,"cost":0.125}}';
  Book := nil;
  Check(ParseBookImageResponse(Response, Book, Stats, Err),
    'полный ответ распознавания изображения разбирается: ' + Err);
  try
    CheckEqual('Добротолюбие', Book.Title, 'название изображения');
    CheckEqual('101', Book.InventoryNo, 'инвентарный номер изображения');
    CheckEqual('Сборник', Book.Authors, 'авторы изображения');
    CheckEqual('1895', Book.Year, 'год изображения');
    CheckEqual('Богословие', Book.CategoryName, 'категория изображения');
    Check((Stats.Models = 'vision/model') and (Stats.TotalTokens = 30) and
      Stats.HasCost and (Abs(Stats.RecognitionCost - 0.125) < 0.000001),
      'статистика изображения извлекается');
  finally
    Book.Free;
  end;

  Response := '{"choices":[{"message":{"content":"{\"title\":\"Частичная\",' +
    '\"inventoryNumber\":\"\"}"}}],"model":"vision/model"}';
  Book := nil;
  Check(ParseBookImageResponse(Response, Book, Stats, Err),
    'частично распознанное изображение сохраняется для ручной правки: ' + Err);
  try
    Check((Book <> nil) and (Book.InventoryNo = ''),
      'пустое обязательное поле не отбрасывает строку');
  finally
    Book.Free;
  end;

  Book := nil;
  Check(not ParseBookImageResponse('{bad json', Book, Stats, Err),
    'некорректный JSON изображения отклоняется');
end;

procedure TestTextResponses;
var
  Books: TObjectList;
  Book: TRecognizedBook;
  Stats: TRecognitionStats;
  Err, Response: string;
begin
  Books := TObjectList.Create(True);
  try
    Response := '{"choices":[{"message":{"content":"{\"books\":[{' +
      '\"title\":\"Первая\",\"inventoryNumber\":\"201\",' +
      '\"authors\":\"Автор\",\"year\":\"2001\",\"publisher\":\"Издатель\",' +
      '\"isbn\":\"ISBN-1\",\"description\":\"Текст\",' +
      '\"category\":\"История\"},{\"title\":\"Вторая\",' +
      '\"inventoryNumber\":\"\"}]}"}}],"model":"text/model",' +
      '"usage":{"prompt_tokens":100,"completion_tokens":50,' +
      '"total_tokens":150,"cost":0}}';
    Check(ParseBooksTextResponse(Response, Books, Stats, Err),
      'массив текстовых записей разбирается: ' + Err);
    Check(Books.Count = 2, 'сохраняется количество и порядок текстовых записей');
    Book := TRecognizedBook(Books[0]);
    CheckEqual('Издатель', Book.Publisher, 'издательство из текста');
    CheckEqual('ISBN-1', Book.ISBN, 'ISBN из текста');
    Check(TRecognizedBook(Books[1]).InventoryNo = '',
      'частичная текстовая запись доступна для ручной правки');
    Check((Stats.TotalTokens = 150) and Stats.HasCost and
      (Stats.RecognitionCost = 0), 'нулевая стоимость остаётся известной');

    Check(not ParseBooksTextResponse('{"choices":[]}', Books, Stats, Err),
      'ответ без результата модели отклоняется');
  finally
    Books.Free;
  end;
end;

procedure WriteBytes(const AFileName, AData: string);
var
  Stream: TFileStream;
begin
  Stream := TFileStream.Create(AFileName, fmCreate);
  try
    if AData <> '' then
      Stream.WriteBuffer(AData[1], Length(AData));
  finally
    Stream.Free;
  end;
end;

procedure TestTextFiles;
var
  Dir, FileName, Text, Loaded, Err: string;
  Lines: TStringList;
  I: Integer;
  Ok: Boolean;
begin
  Check(ValidateRecognitionText('Наименование;Инвентарный номер' + LineEnding +
    'Книга;1', Err), 'поддерживается разделитель «;»: ' + Err);
  Check(ValidateRecognitionText('Инв. номер' + #9 + 'Название' + LineEnding +
    '2' + #9 + 'Книга', Err), 'поддерживается TAB и произвольный порядок: ' + Err);
  Check(ValidateRecognitionText('Название|Инвентарный номер' + LineEnding +
    'Книга|3', Err), 'поддерживается разделитель «|»: ' + Err);
  Check(not ValidateRecognitionText('', Err), 'пустой текст отклоняется');
  Check(not ValidateRecognitionText('Автор;Год' + LineEnding + 'А;2000', Err),
    'заголовок без обязательных колонок отклоняется');

  Lines := TStringList.Create;
  try
    Lines.Add('Наименование;Инвентарный номер');
    for I := 1 to MAX_TEXT_RECOGNITION_BOOKS + 1 do
      Lines.Add('Книга ' + IntToStr(I) + ';' + IntToStr(I));
    Check(not ValidateRecognitionText(Lines.Text, Err),
      'файл более чем со 100 записями отклоняется');
  finally
    Lines.Free;
  end;

  Dir := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'LibraryRecognitionFiles-' + IntToStr(GetTickCount64);
  ForceDirectories(Dir);
  try
    Text := 'Название;Инвентарный номер' + LineEnding + 'Книга;5';
    FileName := IncludeTrailingPathDelimiter(Dir) + 'utf8.txt';
    WriteBytes(FileName, Text);
    Ok := LoadRecognitionTextFile(FileName, Loaded, Err) and (Loaded = Text);
    Check(Ok, 'читается UTF-8: ' + Err);

    FileName := IncludeTrailingPathDelimiter(Dir) + 'utf8-bom.txt';
    WriteBytes(FileName, #$EF#$BB#$BF + Text);
    Ok := LoadRecognitionTextFile(FileName, Loaded, Err) and (Loaded = Text);
    Check(Ok, 'читается UTF-8 BOM: ' + Err);

    FileName := IncludeTrailingPathDelimiter(Dir) + 'cp1251.txt';
    WriteBytes(FileName, string(UTF8ToCP1251(Text)));
    Ok := LoadRecognitionTextFile(FileName, Loaded, Err) and (Loaded = Text);
    Check(Ok, 'читается Windows-1251: ' + Err);
  finally
    DeleteDirectory(Dir, False);
  end;
end;

function FindActiveCategoryByName(ADB: TLibraryDB; const AName: string): TCategory;
var
  I: Integer;
  Category: TCategory;
begin
  for I := 0 to ADB.Categories.Count - 1 do
  begin
    Category := TCategory(ADB.Categories[I]);
    if (not Category.Deleted) and SameText(Category.Name, AName) then
      Exit(Category);
  end;
  Result := nil;
end;

function NewRecognizedBook(const ATitle, AInventory, AYear,
  ACategory: string): TRecognizedBook;
begin
  Result := TRecognizedBook.Create;
  Result.Title := ATitle;
  Result.InventoryNo := AInventory;
  Result.Authors := 'Автор ' + ATitle;
  Result.Year := AYear;
  Result.Publisher := 'Издательство';
  Result.ISBN := 'ISBN-' + AInventory;
  Result.Description := 'Описание ' + ATitle;
  Result.CategoryName := ACategory;
end;

procedure TestDatabaseImport;
var
  RootDir, Err: string;
  DB: TLibraryDB;
  Items: TObjectList;
  Book: TBook;
  ExistingCategory, NewCategory: TCategory;
  SavedCount, InitialCategoryCount, InitialBookCount: Integer;
begin
  RootDir := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'LibraryRecognitionDB-' + IntToStr(GetTickCount64);
  ForceDirectories(RootDir);
  DB := TLibraryDB.Create(RootDir);
  try
    Check(DB.Open(Err), 'тестовая база открывается: ' + Err);
    Check(DB.Login('admin', 'admin', Err), 'вход в тестовую базу: ' + Err);
    ExistingCategory := DB.AddCategory('Богословие', '', '', Err);
    Check(ExistingCategory <> nil, 'создаётся исходная категория: ' + Err);
    InitialCategoryCount := DB.Categories.Count;
    Items := TObjectList.Create(True);
    try
      Items.Add(NewRecognizedBook('Первая', '301', '1999', 'богословие'));
      Items.Add(NewRecognizedBook('Вторая', '302', '2000', 'История'));
      Items.Add(NewRecognizedBook('Третья', '303', '', 'ИСТОРИЯ'));
      Items.Add(NewRecognizedBook('Четвёртая', '304', '2024', ''));
      Check(DB.ImportRecognizedBooks(Items, 'Основной фонд', SavedCount, Err),
        'расширенные записи импортируются: ' + Err);
      Check(SavedCount = 4, 'сохранены все валидные строки');
      Check(DB.Books.Count = 4, 'созданы четыре книги');
      Check(DB.Copies.Count = 4, 'созданы четыре экземпляра');
      Check(DB.Categories.Count = InitialCategoryCount + 1,
        'повторяющаяся новая категория создаётся один раз');
      NewCategory := FindActiveCategoryByName(DB, 'История');
      Check(NewCategory <> nil, 'новая категория найдена в базе');
      Book := TBook(DB.Books[0]);
      Check((Book.Authors = 'Автор Первая') and (Book.Year = 1999) and
        (Book.Publisher = 'Издательство') and (Book.ISBN = 'ISBN-301') and
        (Book.Description = 'Описание Первая') and
        (Book.CategoryID = ExistingCategory.ID),
        'все поля первой книги и существующая категория сохранены');
      Check((TBook(DB.Books[1]).CategoryID = NewCategory.ID) and
        (TBook(DB.Books[2]).CategoryID = NewCategory.ID),
        'категория сопоставляется без учёта регистра');
      Check(TBook(DB.Books[3]).CategoryID = 0,
        'пустая категория сохраняется как «без категории»');
    finally
      Items.Free;
    end;

    InitialBookCount := DB.Books.Count;
    Items := TObjectList.Create(True);
    try
      Items.Add(NewRecognizedBook('Конфликт', '301', '2020', ''));
      Check(not DB.ImportRecognizedBooks(Items, 'Основной фонд', SavedCount, Err),
        'существующий инвентарный номер отклоняется');
      Check(DB.Books.Count = InitialBookCount,
        'при конфликте база не получает новую книгу');
    finally
      Items.Free;
    end;

    Items := TObjectList.Create(True);
    try
      Items.Add(NewRecognizedBook('Неверный год', '305', '20xx', ''));
      Check(not DB.ImportRecognizedBooks(Items, 'Основной фонд', SavedCount, Err),
        'некорректный год отклоняется');
    finally
      Items.Free;
    end;
  finally
    DB.Free;
    DeleteDirectory(RootDir, False);
  end;
end;

procedure TestInitialBookCopy;
var
  RootDir, Err: string;
  DB, ReloadedDB: TLibraryDB;
  Book: TBook;
  CopyItem: TCopy;
  Location: TLocation;
  BookID, LocationID: TId;
  InitialBookCount, InitialCopyCount: Integer;
begin
  RootDir := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'LibraryInitialBookCopy-' + IntToStr(GetTickCount64);
  ForceDirectories(RootDir);
  DB := TLibraryDB.Create(RootDir);
  try
    Check(DB.Open(Err), 'тестовая база новой карточки открывается: ' + Err);
    Check(DB.Login('admin', 'admin', Err),
      'вход в базу новой карточки: ' + Err);
    Location := DB.AddLocation('Основной фонд', '', Err);
    Check(Location <> nil, 'создаётся место хранения первого экземпляра: ' + Err);
    if Location = nil then
      Exit;
    LocationID := Location.ID;

    Book := DB.AddBookWithInitialCopy('Новая книга', 'Автор', 2026,
      'Издательство', '9785170000000', 0, 'Описание', '', '701',
      LocationID, Err);
    Check(Book <> nil, 'книга и первый экземпляр создаются вместе: ' + Err);
    if Book = nil then
      Exit;
    BookID := Book.ID;
    CopyItem := DB.FindCopyByInv('701');
    Check((CopyItem <> nil) and (CopyItem.BookID = BookID) and
      (CopyItem.LocationID = LocationID),
      'первый экземпляр связан с книгой и местом хранения');
    Check((CopyItem <> nil) and (CopyItem.Status = csAvailable) and
      (CopyItem.Condition = DEFAULT_COPY_CONDITION) and
      (Trunc(CopyItem.ReceivedAt) = Trunc(Date)),
      'первый экземпляр получает значения по умолчанию');

    InitialBookCount := DB.Books.Count;
    InitialCopyCount := DB.Copies.Count;
    Check(DB.AddBookWithInitialCopy('Без номера', '', 0, '', '', 0, '',
      '', '', LocationID, Err) = nil,
      'пустой инвентарный номер отклоняется');
    Check(DB.AddBookWithInitialCopy('Повтор номера', '', 0, '', '', 0, '',
      '', '701', LocationID, Err) = nil,
      'повторный инвентарный номер отклоняется');
    Check(DB.AddBookWithInitialCopy('Повтор ISBN', '', 0, '',
      '978-5-17-000000-0', 0, '', '', '702', LocationID, Err) = nil,
      'повторный ISBN в другом формате отклоняется');
    Check(DB.AddBookWithInitialCopy('Без места', '', 0, '', '', 0, '',
      '', '702', 0, Err) = nil,
      'недействительное место хранения отклоняется');
    Check((DB.Books.Count = InitialBookCount) and
      (DB.Copies.Count = InitialCopyCount),
      'ошибки проверки не создают частичных записей');

    DB.Free;
    DB := nil;
    ReloadedDB := TLibraryDB.Create(RootDir);
    try
      Err := '';
      Check(ReloadedDB.Open(Err),
        'база с книгой и экземпляром открывается повторно: ' + Err);
      Book := ReloadedDB.FindBook(BookID);
      CopyItem := ReloadedDB.FindCopyByInv('701');
      Check((Book <> nil) and (CopyItem <> nil) and
        (CopyItem.BookID = BookID) and (CopyItem.LocationID = LocationID),
        'книга и связанный экземпляр сохраняются после перезагрузки');
    finally
      ReloadedDB.Free;
    end;
  finally
    DB.Free;
    DeleteDirectory(RootDir, False);
  end;
end;

procedure TestBookSearchDeletedRecords;
var
  RootDir, Err: string;
  DB: TLibraryDB;
  ActiveBook, DeletedBook: TBook;
  ActiveCopy, DeletedCopy: TCopy;
  Location: TLocation;
  Results: TList;
begin
  RootDir := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'LibraryBookSearch-' + IntToStr(GetTickCount64);
  ForceDirectories(RootDir);
  DB := TLibraryDB.Create(RootDir);
  try
    Check(DB.Open(Err), 'база поиска книг открывается: ' + Err);
    Check(DB.Login('admin', 'admin', Err), 'вход в базу поиска книг: ' + Err);
    Location := DB.AddLocation('Основной фонд', '', Err);
    Check(Location <> nil, 'создаётся место хранения для поиска книг: ' + Err);
    if Location = nil then
      Exit;

    ActiveBook := DB.AddBook('Активная книга', 'Автор', 2020, '', '', 0, '', '', Err);
    DeletedBook := DB.AddBook('Удалённая книга', 'Автор', 2021, '', '', 0, '', '', Err);
    Check((ActiveBook <> nil) and (DeletedBook <> nil),
      'создаются активная и удалённая книги: ' + Err);
    if (ActiveBook = nil) or (DeletedBook = nil) then
      Exit;
    ActiveCopy := DB.AddCopy(ActiveBook.ID, '801', DEFAULT_COPY_CONDITION,
      Location.ID, '', Date, Err);
    DeletedCopy := DB.AddCopy(DeletedBook.ID, '802', DEFAULT_COPY_CONDITION,
      Location.ID, '', Date, Err);
    Check((ActiveCopy <> nil) and (DeletedCopy <> nil),
      'создаются экземпляры для поиска книг: ' + Err);
    if (ActiveCopy = nil) or (DeletedCopy = nil) then
      Exit;
    Check(DB.DeleteBook(DeletedBook, Err), 'удаляется тестовая книга: ' + Err);
    Check(DB.DeleteCopy(ActiveCopy, Err), 'удаляется тестовый экземпляр: ' + Err);

    Results := TList.Create;
    try
      DB.SearchBooks('удалённая', '', Results, False);
      Check(Results.Count = 0,
        'без флажка удалённая книга не находится по названию');
      Results.Clear;
      DB.SearchBooks('УДАЛЁННАЯ', '', Results, True);
      Check((Results.Count = 1) and (TBook(Results[0]) = DeletedBook),
        'с флажком удалённая книга находится по названию без учёта регистра');
      Results.Clear;
      DB.SearchBooks('', '802', Results, False);
      Check(Results.Count = 0,
        'без флажка удалённая книга не находится по инвентарному номеру');
      Results.Clear;
      DB.SearchBooks('', '802', Results, True);
      Check((Results.Count = 1) and (TBook(Results[0]) = DeletedBook),
        'с флажком удалённая книга находится по инвентарному номеру');
      Results.Clear;
      DB.SearchBooks('', '801', Results, False);
      Check(Results.Count = 0,
        'без флажка удалённый экземпляр не находится');
      Results.Clear;
      DB.SearchBooks('', '801', Results, True);
      Check((Results.Count = 1) and (TBook(Results[0]) = ActiveBook),
        'с флажком удалённый экземпляр участвует в поиске');
      Results.Clear;
      DB.SearchBooks('удалённая', '802', Results, True);
      Check(Results.Count = 1,
        'совпадение по двум полям не добавляет книгу повторно');
    finally
      Results.Free;
    end;
  finally
    DB.Free;
    DeleteDirectory(RootDir, False);
  end;
end;

function CountFiles(const ADirectory: string): Integer;
var
  Search: TSearchRec;
begin
  Result := 0;
  if FindFirst(IncludeTrailingPathDelimiter(ADirectory) + '*.*', faAnyFile,
    Search) <> 0 then
    Exit;
  try
    repeat
      if (Search.Name <> '.') and (Search.Name <> '..') and
        ((Search.Attr and faDirectory) = 0) then
        Inc(Result);
    until FindNext(Search) <> 0;
  finally
    FindClose(Search);
  end;
end;

procedure TestCoverStorage;
var
  RootDir, SourceJpg, SourcePng, Err: string;
  DB, ReloadedDB: TLibraryDB;
  Book: TBook;
  InitialCoverCount: Integer;
begin
  RootDir := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'LibraryCoverStorage-' + IntToStr(GetTickCount64);
  ForceDirectories(RootDir);
  DB := TLibraryDB.Create(RootDir);
  try
    Check(DB.Open(Err), 'тестовая база для обложек открывается: ' + Err);
    Check(DB.Login('admin', 'admin', Err), 'вход в тестовую базу обложек: ' + Err);
    SourceJpg := RootDir + 'cache-cover.jpg';
    WriteBytes(SourceJpg, #$FF#$D8#$FF + 'JPEG');
    InitialCoverCount := CountFiles(DB.Paths.CoversDir);
    Check(InitialCoverCount = 0,
      'кэшированная обложка не попадает в Covers до сохранения книги');
    Book := DB.AddBook('Книга с обложкой', '', 0, '', '', 0, '', SourceJpg, Err);
    Check(Book <> nil, 'книга с кэшированной обложкой сохраняется: ' + Err);
    if Book <> nil then
    begin
      Check((ExtractFilePath(Book.CoverFile) = '') and
        (Book.CoverFile = Format('%.6d.jpg', [Book.ID])),
        'в базе хранится относительное имя JPEG-обложки');
      Check(FileExists(DB.Paths.CoversDir + Book.CoverFile),
        'при сохранении JPEG копируется в Covers');
      SourcePng := RootDir + 'cache-cover.png';
      WriteBytes(SourcePng, #$89 + 'PNG');
      Check(DB.UpdateBook(Book, Book.Title, Book.Authors, Book.Year,
        Book.Publisher, Book.ISBN, Book.CategoryID, Book.Description,
        SourcePng, Err), 'обложка существующей книги заменяется: ' + Err);
      Check((ExtractFilePath(Book.CoverFile) = '') and
        (Book.CoverFile = Format('%.6d.png', [Book.ID])) and
        FileExists(DB.Paths.CoversDir + Book.CoverFile),
        'при обновлении хранится относительное имя PNG-обложки');
    end;
    Check(DB.UpdateSettings('Тестовая библиотека', 14, 5, 2, True, 10, 1,
      '', '', 'test-google-key', Err),
      'ключ Google Books сохраняется в настройках: ' + Err);
    DB.Free;
    DB := nil;
    ReloadedDB := TLibraryDB.Create(RootDir);
    try
      Check(ReloadedDB.Open(Err) and
        (ReloadedDB.Settings.GoogleBooksApiKey = 'test-google-key'),
        'ключ Google Books читается из совместимого Settings.dat: ' + Err);
    finally
      ReloadedDB.Free;
    end;
  finally
    DB.Free;
    DeleteDirectory(RootDir, False);
  end;
end;

begin
  TestImageResponses;
  TestTextResponses;
  TestTextFiles;
  TestDatabaseImport;
  TestInitialBookCopy;
  TestBookSearchDeletedRecords;
  TestCoverStorage;
  if Failures <> 0 then
  begin
    WriteLn('Ошибок: ', Failures);
    Halt(1);
  end;
  WriteLn('Все тесты распознавания пройдены.');
end.
