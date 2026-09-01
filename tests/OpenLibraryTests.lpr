program OpenLibraryTests;

{$mode objfpc}{$H+}

uses
  Classes, SysUtils, FileUtil, uOpenLibrary, uOpenRouter;

var
  Failures: Integer = 0;
  MockMode: Integer = 0;
  MockRequestedRussian: Boolean = False;
  MockGoogleCalled: Boolean = False;
  MockGoogleKeyPassed: Boolean = False;

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

function MockHttpGet(const AURL: string; out AStatusCode: Cardinal;
  out AResponseBody, AError: string): Boolean;
begin
  AStatusCode := 0;
  AResponseBody := '';
  AError := '';
  if MockMode = 2 then
  begin
    AError := 'сервер недоступен';
    Exit(False);
  end;
  Result := True;
  if Pos('/search.json?', AURL) > 0 then
  begin
    MockRequestedRussian := Pos('&lang=ru', AURL) > 0;
    AStatusCode := 200;
    if (MockMode = 3) or (MockMode >= 6) then
      AResponseBody := '{"docs":[]}'
    else
      AResponseBody := '{"docs":[{"key":"/works/OL1W",' +
        '"title":"Название произведения","author_name":["Автор 1","Автор 2"],' +
        '"editions":{"docs":[{"key":"/books/OL1M",' +
        '"title":"Название издания","publisher":["Издатель"],' +
        '"publish_date":["2005"],"isbn":["5170196369"],' +
        '"language":["rus"]}]}}]}';
  end
  else if Pos('www.googleapis.com/books/v1/volumes?', AURL) > 0 then
  begin
    MockGoogleCalled := True;
    MockGoogleKeyPassed := Pos('&key=test-google-key', AURL) > 0;
    if MockMode = 8 then
    begin
      AStatusCode := 429;
      AResponseBody := '{"error":{"message":"Quota exceeded"}}';
    end
    else if MockMode = 7 then
    begin
      AStatusCode := 200;
      AResponseBody := '{"totalItems":0}';
    end
    else
    begin
      AStatusCode := 200;
      AResponseBody := '{"totalItems":1,"items":[{"volumeInfo":{' +
        '"title":"Название Google","subtitle":"Подзаголовок",' +
        '"authors":["Автор Google"],"publisher":"Издатель Google",' +
        '"publishedDate":"2017-03-01",' +
        '"description":"<b>Описание</b> &amp; текст",' +
        '"mainCategory":"История","language":"ru",' +
        '"industryIdentifiers":[{"type":"ISBN_13",' +
        '"identifier":"9785170196364"}],"imageLinks":{' +
        '"large":"https://example.org/google-cover.png"}}}]}';
    end;
  end
  else if Pos('/works/OL1W.json', AURL) > 0 then
  begin
    AStatusCode := 200;
    AResponseBody := '{"description":{"value":"Описание"},' +
      '"subjects":["Богословие","История"]}';
  end
  else if Pos('covers.openlibrary.org', AURL) > 0 then
  begin
    if MockMode = 4 then
    begin
      AStatusCode := 404;
      AResponseBody := '';
    end
    else if MockMode = 5 then
    begin
      AStatusCode := 200;
      AResponseBody := '<html>ошибка</html>';
    end
    else
    begin
      AStatusCode := 200;
      AResponseBody := #$FF#$D8#$FF + 'JPEG';
    end;
  end
  else if Pos('example.org/google-cover.png', AURL) > 0 then
  begin
    AStatusCode := 200;
    AResponseBody := #$89 + 'PNG' + #13#10#$1A#10 + 'IMAGE';
  end
  else
  begin
    AStatusCode := 404;
    AResponseBody := '';
  end;
end;

procedure TestISBN;
var
  Normalized, Err: string;
begin
  Check(NormalizeISBN('5-17-019636-9', Normalized, Err),
    'ISBN-10 с дефисами проходит проверку: ' + Err);
  CheckEqual('5170196369', Normalized, 'ISBN-10 нормализуется');
  Check(NormalizeISBN('978 5 17019636 4', Normalized, Err),
    'ISBN-13 с пробелами проходит проверку: ' + Err);
  CheckEqual('9785170196364', Normalized, 'ISBN-13 нормализуется');
  Check(NormalizeISBN('0-8044-2957-X', Normalized, Err),
    'ISBN-10 с X проходит проверку: ' + Err);
  Check(not NormalizeISBN('5-17-019636-8', Normalized, Err),
    'неверная контрольная сумма ISBN-10 отклоняется');
  Check(not NormalizeISBN('9785170196365', Normalized, Err),
    'неверная контрольная сумма ISBN-13 отклоняется');
  Check(not NormalizeISBN('123', Normalized, Err),
    'неверная длина ISBN отклоняется');
  Check(not NormalizeISBN('9785A70196364', Normalized, Err),
    'посторонние символы ISBN отклоняются');
end;

procedure TestHTTPPath;
begin
  CheckEqual('/search.json?isbn=5170196369&limit=1',
    HttpRequestTarget('https://openlibrary.org/search.json?isbn=5170196369&limit=1'),
    'HTTP-путь сохраняет query-параметры');
  CheckEqual('/?isbn=1', HttpRequestTarget('https://example.org?isbn=1#part'),
    'URL без пути получает корень и не отправляет фрагмент');
end;

procedure TestResponses;
var
  Data: TOpenLibraryBookData;
  Found: Boolean;
  Err, Response: string;
begin
  Response := '{"docs":[{"key":"/works/WRONG","title":"Другая",' +
    '"editions":{"docs":[{"title":"Неточное издание",' +
    '"isbn":["0451526535"]}]}},{"key":"/works/OL1W","title":"Работа",' +
    '"author_name":["Автор"],"subject":["Категория"],' +
    '"editions":{"docs":[{"title":"Точное издание",' +
    '"publisher":["Издатель"],"publish_date":["издано в 2005 году"],' +
    '"isbn":["5170196369","9785170196364"]}]}}]}';
  Check(ParseOpenLibrarySearchResponse(Response, '5170196369', Data, Found, Err),
    'ответ поиска разбирается: ' + Err);
  Check(Found, 'точное издание найдено');
  CheckEqual('Точное издание', Data.Title, 'берётся название точного издания');
  CheckEqual('Автор', Data.Authors, 'разбираются авторы');
  Check((Data.Year = 2005) and (Data.Publisher = 'Издатель'),
    'разбираются год и издательство (год=' + IntToStr(Data.Year) +
    ', издательство=' + Data.Publisher + ')');
  CheckEqual('Категория', Data.CategoryName, 'берётся первая тема');
  CheckEqual('/works/OL1W', Data.WorkKey, 'сохраняется ключ произведения');

  Response := '{"docs":[{"key":"/works/OLRUW",' +
    '"title":"Uspeshnyj rukovoditel'' (The Complete Idiot''s Guide To)",' +
    '"author_name":["E. Dubrin"],"language":["rus"],' +
    '"editions":{"docs":[{' +
    '"title":"Uspeshnyj rukovoditel'' (The Complete Idiot''s Guide To)",' +
    '"publisher":["AST"],"publish_date":["2005"],' +
    '"isbn":["5170196369"],"language":["rus"]}]}}]}';
  Check(ParseOpenLibrarySearchResponse(Response, '5170196369', Data, Found, Err),
    'русское издание в транслитерации разбирается: ' + Err);
  CheckEqual('Uspeshnyj rukovoditel'' (The Complete Idiot''s Guide To)',
    Data.Title, 'API-парсер сохраняет исходное название для проверки моделью');
  CheckEqual('E. Dubrin', Data.Authors,
    'API-парсер сохраняет исходное имя автора');
  CheckEqual('AST', Data.Publisher,
    'API-парсер сохраняет исходное издательство');
  CheckEqual('rus', Data.Language, 'сохраняется язык точного издания');

  Response := '{"docs":[{"key":"/works/OLENW","title":"English title",' +
    '"author_name":["John Smith"],"editions":{"docs":[{' +
    '"title":"English title","publisher":["Example Press"],' +
    '"isbn":["5170196369"],"language":["eng"]}]}}]}';
  Check(ParseOpenLibrarySearchResponse(Response, '5170196369', Data, Found, Err),
    'английское издание разбирается: ' + Err);
  CheckEqual('English title', Data.Title,
    'данные нерусского издания не транслитерируются');

  Check(ParseOpenLibrarySearchResponse('{"docs":[]}', '5170196369',
    Data, Found, Err) and not Found, 'пустой результат отличается от ошибки JSON');
  Check(not ParseOpenLibrarySearchResponse('{bad', '5170196369',
    Data, Found, Err), 'некорректный JSON поиска отклоняется');

  ClearOpenLibraryBookData(Data);
  Check(MergeOpenLibraryWorkResponse('{"description":"Строка",' +
    '"subjects":["Тема"]}', Data, Err),
    'строковое описание произведения разбирается');
  CheckEqual('Строка', Data.Description, 'строковое описание заполнено');
  CheckEqual('Тема', Data.CategoryName, 'тема произведения заполнена');
  ClearOpenLibraryBookData(Data);
  Check(MergeOpenLibraryWorkResponse('{"description":{"value":"Объект"}}',
    Data, Err), 'объектное описание произведения разбирается');
  CheckEqual('Объект', Data.Description, 'значение объектного описания заполнено');
end;

procedure TestGoogleBooksResponses;
var
  Data: TOpenLibraryBookData;
  Found: Boolean;
  Err, Response: string;
begin
  Response := '{"totalItems":2,"items":[{"volumeInfo":{' +
    '"title":"Неточное","language":"ru",' +
    '"industryIdentifiers":[{"identifier":"0451526535"}]}},' +
    '{"volumeInfo":{"title":"Название","subtitle":"Подзаголовок",' +
    '"authors":["Автор 1","Автор 2"],"publisher":"Издатель",' +
    '"publishedDate":"2018-02-03","description":"<b>Текст</b> &amp; ещё",' +
    '"categories":["Категория"],"language":"ru",' +
    '"industryIdentifiers":[{"type":"ISBN_13","identifier":"9785170196364"}],' +
    '"imageLinks":{"thumbnail":"http://example.org/cover.jpg"}}}]}';
  Check(ParseGoogleBooksResponse(Response, '9785170196364', Data, Found, Err),
    'ответ Google Books разбирается: ' + Err);
  Check(Found, 'Google Books выбирает точный ISBN');
  Check((Data.Title = 'Название: Подзаголовок') and
    (Data.Authors = 'Автор 1, Автор 2') and (Data.Year = 2018) and
    (Data.Publisher = 'Издатель') and (Data.Description = 'Текст & ещё') and
    (Data.CategoryName = 'Категория') and (Data.CoverURL =
      'https://example.org/cover.jpg') and (Data.Source = olsGoogleBooks),
    'Google Books заполняет русские данные, описание, категорию и обложку');
  Check(ParseGoogleBooksResponse('{"totalItems":0}', '9785170196364',
    Data, Found, Err) and not Found,
    'отсутствие items Google Books отличается от ошибки');
  Check(not ParseGoogleBooksResponse('{bad', '9785170196364', Data, Found, Err),
    'некорректный JSON Google Books отклоняется');
end;

procedure TestCacheAndLookup;
var
  Dir, Err, WarningText, CoverFile: string;
  Data, Loaded: TOpenLibraryBookData;
begin
  Dir := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'LibraryOpenLibrary-' + IntToStr(GetTickCount64);
  ForceDirectories(Dir);
  try
    MockMode := 1;
    MockRequestedRussian := False;
    Check(LookupOpenLibraryBook('5-17-019636-9', Dir, Data, WarningText,
      Err, @MockHttpGet), 'онлайн-поиск и кэширование выполняются: ' + Err);
    Check(MockRequestedRussian,
      'поиск Open Library запрашивает русскоязычное представление');
    Check((Data.Title = 'Название издания') and
      (Data.Authors = 'Автор 1, Автор 2') and (Data.Year = 2005) and
      (Data.Description = 'Описание') and
      (Data.CategoryName = 'Богословие'),
      'онлайн-поиск заполняет все доступные поля');
    Check(FileExists(Data.CoverCacheFile), 'обложка сохраняется в кэше');
    Check(LoadOpenLibraryCache(Dir, '5170196369', Loaded, Err),
      'запись кэша читается: ' + Err);
    Check((Loaded.Source = olsCache) and
      (Loaded.Title = 'Название издания') and
      FileExists(Loaded.CoverCacheFile),
      'кэш восстанавливает метаданные и обложку');
    CheckEqual(Data.Language, Loaded.Language,
      'кэш сохраняет язык издания');

    MockMode := 2;
    Check(LookupOpenLibraryBook('5-17-019636-9', Dir, Loaded, WarningText,
      Err, @MockHttpGet), 'при сетевой ошибке используется кэш: ' + Err);
    Check((Loaded.Source = olsCache) and (Pos('кэша', WarningText) > 0),
      'пользователь получает сообщение об офлайн-источнике');

    MockMode := 3;
    Check(not LookupOpenLibraryBook('5-17-019636-9', Dir, Loaded,
      WarningText, Err, @MockHttpGet),
      'ответ «не найдено» не подменяется старым кэшем');

    MockMode := 4;
    Check(LookupOpenLibraryBook('978-5-17-019636-4', Dir, Loaded,
      WarningText, Err, @MockHttpGet),
      'отсутствие обложки не отменяет заполнение метаданных: ' + Err);

    MockMode := 5;
    Check(LookupOpenLibraryBook('978-5-17-019636-4', Dir, Loaded,
      WarningText, Err, @MockHttpGet),
      'ошибочный формат обложки не отменяет заполнение: ' + Err);
    Check(Pos('неизвестного формата', WarningText) > 0,
      'ошибка формата обложки показана предупреждением');

    Check(not CacheOpenLibraryCover(Dir, '5170196369', '', CoverFile, Err),
      'пустая обложка отклоняется');
    WriteBytes(IncludeTrailingPathDelimiter(Dir) + '5170196369.json', '{bad');
    Check(not LoadOpenLibraryCache(Dir, '5170196369', Loaded, Err),
      'повреждённый кэш безопасно отклоняется');
  finally
    DeleteDirectory(Dir, False);
  end;
end;

procedure TestGoogleFallback;
var
  Dir, Err, WarningText: string;
  Data: TOpenLibraryBookData;
begin
  Dir := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'LibraryGoogleBooks-' + IntToStr(GetTickCount64);
  ForceDirectories(Dir);
  try
    MockMode := 6;
    MockGoogleCalled := False;
    MockGoogleKeyPassed := False;
    Check(LookupBookByISBN('978-5-17-019636-4', Dir, 'test-google-key',
      Data, WarningText, Err, @MockHttpGet),
      'Google Books вызывается после пустого ответа Open Library: ' + Err);
    Check(MockGoogleCalled and MockGoogleKeyPassed,
      'Google Books получает отдельный API Key');
    Check((Data.Source = olsGoogleBooks) and (Data.Title =
      'Название Google: Подзаголовок') and
      (ExtractFileExt(Data.CoverCacheFile) = '.png') and
      FileExists(Data.CoverCacheFile) and (Pos('Google Books', WarningText) > 0),
      'резервный поиск Google Books возвращает PNG-обложку и источник');

    MockMode := 7;
    Check(not LookupBookByISBN('978-5-17-019636-4', Dir, '', Data,
      WarningText, Err, @MockHttpGet) and
      (Pos('Open Library и Google Books', Err) > 0),
      'отсутствие книги у обоих источников показано пользователю');

    MockMode := 8;
    Check(not LookupBookByISBN('978-5-17-019636-4', Dir, '', Data,
      WarningText, Err, @MockHttpGet) and (Pos('квоты', Err) > 0),
      'ошибка квоты Google Books объясняется пользователю');

    MockMode := 2;
    Check(LookupBookByISBN('978-5-17-019636-4', Dir, '', Data,
      WarningText, Err, @MockHttpGet) and (Data.Source = olsCache),
      'кэш Google Books доступен при сетевой ошибке');
  finally
    DeleteDirectory(Dir, False);
  end;
end;

procedure TestLiveLookup;
var
  Dir, Err, WarningText: string;
  Data: TOpenLibraryBookData;
begin
  Dir := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'LibraryOpenLibraryLive-' + IntToStr(GetTickCount64);
  ForceDirectories(Dir);
  try
    Check(LookupOpenLibraryBook('5-17-019636-9', Dir, Data, WarningText,
      Err), 'реальный запрос Open Library выполняется: ' + Err);
    Check((Data.Title <> '') and (Data.Authors <> '') and
      (Data.Year = 2005) and (Data.Publisher <> '') and
      SameText(Data.Language, 'rus'),
      'реальный ответ возвращает исходные данные ISBN для проверки моделью');
  finally
    DeleteDirectory(Dir, False);
  end;
end;

begin
  TestISBN;
  TestHTTPPath;
  TestResponses;
  TestGoogleBooksResponses;
  TestCacheAndLookup;
  TestGoogleFallback;
  if SameText(ParamStr(1), '--live') then
    TestLiveLookup;
  if Failures <> 0 then
  begin
    WriteLn('Ошибок: ', Failures);
    Halt(1);
  end;
  WriteLn('Все тесты Open Library пройдены.');
end.
