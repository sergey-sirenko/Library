program RslTests;

{$mode objfpc}{$H+}

uses Classes, SysUtils, FileUtil, fpjson, uOpenLibrary, uRsl, uBookHttp, uBookText;

const ISBN = '9789851675261';
var Failures, FallbackCalls: Integer; Fixture, TempDir: string;

procedure Check(Value: Boolean; const MessageText: string);
begin
  if Value then WriteLn('[OK] ', MessageText)
  else
  begin
    Inc(Failures);
    WriteLn('[FAIL] ', MessageText);
  end;
end;

type
  TMockRsl = class(TBookHttpSession)
    Mode, Calls: Integer;
    function Request(const AMethod, AURL, ABody: string; out AStatus: Cardinal;
      out AResponse, AError: string): Boolean; override;
  end;
  TChooser = class
    Choice, Count: Integer;
    function Select(const Items: TBookCandidates): Integer;
  end;

function TChooser.Select(const Items: TBookCandidates): Integer;
begin
  Count := Length(Items);
  Result := Choice;
end;

function TMockRsl.Request(const AMethod, AURL, ABody: string;
  out AStatus: Cardinal; out AResponse, AError: string): Boolean;
var J: TJSONObject; HTML: string;
begin
  Inc(Calls);
  AStatus := 200;
  AResponse := '';
  AError := '';
  Result := True;
  if Mode = 1 then
  begin
    AError := 'сетевая ошибка РГБ';
    Exit(False);
  end;
  if Pos('/ru/search', AURL) > 0 then
    AResponse := '<meta name="csrf-token" content="test+token/">'
  else if AMethod = 'POST' then
  begin
    Check(Pos('_csrf=test%2Btoken%2F', ABody) > 0, 'CSRF закодирован и передан');
    Check(Pos('SearchFilterForm[search]=isbn%3A' + ISBN, ABody) > 0,
      'поиск выполняется по полю ISBN');
    J := TJSONObject.Create;
    try
      HTML := '<a href="/ru/record/01004592496">Книга</a>';
      if Mode = 2 then HTML := HTML + '<a href="/ru/record/01004592497">Вторая</a>';
      if Mode = 3 then J.Add('TotalHits', 0) else J.Add('TotalHits', 1 + Ord(Mode = 2));
      J.Add('MaxPage', 1);
      J.Add('content', HTML);
      AResponse := J.AsJSON;
      if Mode = 4 then AResponse := '{bad';
    finally
      J.Free;
    end;
  end
  else
  begin
    AResponse := Fixture;
    if Pos('497', AURL) > 0 then
      AResponse := StringReplace(AResponse, 'Харвест', 'Другой издатель', [rfReplaceAll]);
  end;
end;

function Fallback(const URL: string; out Status: Cardinal;
  out Response, Error: string): Boolean;
begin
  Inc(FallbackCalls);
  Status := 200;
  Error := '';
  if Pos('openlibrary.org/search', URL) > 0 then Response := '{"docs":[]}'
  else if Pos('googleapis.com', URL) > 0 then
    Response := '{"items":[{"volumeInfo":{"title":"Книга из Google",' +
      '"language":"ru","industryIdentifiers":[{"identifier":"9789851675261"}]}}]}'
  else
  begin
    Status := 404;
    Response := '';
  end;
  Result := True;
end;

function Offline(const URL: string; out Status: Cardinal;
  out Response, Error: string): Boolean;
begin
  Inc(FallbackCalls);
  Status := 0;
  Response := '';
  Error := 'Нет сети';
  Result := False;
end;

procedure ParserTests;
var Data: TOpenLibraryBookData; Err, W, HTML: string; Found: Boolean;
begin
  Check(ParseRslRecord(Fixture, ISBN, 'https://search.rsl.ru/ru/record/01004592496', Data, Err),
    'публичная запись MARC21 разбирается: ' + Err);
  Check((Data.Title = 'Все секреты портретной фотографии') and
    (Data.Publisher = 'Харвест') and (Data.Year = 2009) and
    (Pos('Адамчик', Data.Authors) > 0) and (Pos('сост.', Data.Authors) > 0),
    'название, составитель, издательство и год извлечены из MARC21');
  Check((Data.Description = '') and (Data.CoverURL = '') and (Data.Language = 'rus'),
    'отсутствующие описание и обложка не выдумываются');
  Check(not ParseRslRecord(Fixture, '9785170196364', '', Data, Err), 'чужой ISBN отклоняется');
  HTML := Copy(Fixture, Pos('<table class="card-descr-table"', Fixture), MaxInt);
  Check(ParseRslRecord(HTML, ISBN, '', Data, Err) and (Data.Year = 2009) and
    (Data.Publisher = 'Харвест'), 'подписанные поля работают без MARC21: ' + Err);
  Check(not ParseRslRecord('<html>ISBN '+ISBN+'</html>', ISBN, '', Data, Err),
    'совпадение в произвольном тексте не принимается');
  Check(not ParseRslRecord('<div id="marc-rec"><table><tr>', ISBN, '', Data, Err),
    'повреждённая карточка отклоняется');
  Check(EquivalentISBN('5-17-019636-9', '9785170196364'), 'эквивалентные ISBN-10 и ISBN-13');
  Check(not EquivalentISBN('9785170196365', '9785170196364'), 'неверная контрольная сумма');
  Check(BookRequestTarget('https://example.org?q=123#fragment') = '/?q=123',
    'новый транспорт сохраняет query и исключает fragment');
  Check(HTMLText('<b>Текст</b>&nbsp;&amp;&#x2014;&#34;') = 'Текст &—"', 'HTML и числовые сущности');
  Check(CheckedYear('2009-2010', W) = 0, 'неоднозначный год не принимается');
  Check(CheckedYear('12345', W) = 0, 'пятизначный год не обрезается');
  Check(CheckedYear('2009?', W) = 0, 'предположительный год требует проверки');
  Check((CheckedYear('2999', W) = 2999) and (W <> ''), 'будущий год сопровождается предупреждением');
  Check(TextWarning('Книгa') <> '', 'смешение алфавитов отмечается');
  ClearOpenLibraryBookData(Data);
  Data.NormalizedISBN := ISBN;
  Data.Title := '<b>Книга</b>';
  Check(ValidateBookData(ISBN, Data, Err) and (Data.Warnings = ''),
    'HTML-разметка не считается иностранным текстом');
  ClearOpenLibraryBookData(Data);
  Data.NormalizedISBN := ISBN;
  Data.Title := 'Книга Microsoft';
  Data.Authors := 'John Smith';
  Check(ValidateBookData(ISBN, Data, Err) and (Data.Authors = 'John Smith') and
    (Data.Title = 'Книга Microsoft') and (Data.Warnings <> ''), 'иностранные фрагменты не изменяются');
  Check(ValidateBookData(ISBN, Data, Err), 'повторная проверка допустима');
  ClearOpenLibraryBookData(Data);
  Data.NormalizedISBN := ISBN;
  Data.Title := '&lt;b&gt;Название&lt;/b&gt; &amp;amp;';
  Check(ValidateBookData(ISBN, Data, Err) and ValidateBookData(ISBN, Data, Err) and
    (Data.Title = '<b>Название</b> &amp;'), 'повторная проверка не декодирует и не удаляет буквальный текст');
  Check(SaveOpenLibraryCache(TempDir, Data, Err) and
    LoadOpenLibraryCache(TempDir, ISBN, Data, Err) and
    (Data.Title = '<b>Название</b> &amp;'), 'кэш сохраняет буквальные HTML-подобные фрагменты');
  Check(TextWarning('Книга' + #$EF#$BF#$BD) <> '', 'повреждённый символ отмечается');
  Check(CheckedYear('-2009', W) = 0, 'отрицательный год отклоняется');
  Check(not ParseRslRecord(StringReplace(Fixture, '978-985-16-7526-1',
    '97898516752619', [rfReplaceAll]), ISBN, '', Data, Err), 'ISBN не извлекается из более длинного числа');
  Check(not ParseOpenLibrarySearchResponse('{bad', ISBN, Data, Found, Err), 'повреждённый JSON');
  Check(ParseOpenLibrarySearchResponse('{"docs":[{"title":"Другая книга","editions":{"docs":' +
    '[{"title":"Другая книга","isbn":["5170196369"]}]}}]}', ISBN, Data, Found, Err) and
    not Found, 'Open Library не подставляет первое несовпадающее издание');
end;

procedure ChainTests;
var S: TMockRsl; C: TChooser; Data: TOpenLibraryBookData; W, Err: string;
begin
  S := TMockRsl.Create;
  C := TChooser.Create;
  try
    FallbackCalls := 0;
    Check(LookupBookByISBN(ISBN, TempDir, '', Data, W, Err, @Fallback, S), 'РГБ первая: ' + Err);
    Check((Data.Source = olsRsl) and (FallbackCalls = 0), 'после успеха РГБ нет запросов за дополнениями');
    S.Mode := 1;
    Check(LookupBookByISBN(ISBN, TempDir, '', Data, W, Err, @Fallback, S) and
      (Data.Source = olsGoogleBooks) and (FallbackCalls = 2), 'ошибка РГБ → Open Library → Google, кэш не опережает онлайн');
    S.Mode := 3;
    Check(LookupBookByISBN(ISBN, TempDir, '', Data, W, Err, @Fallback, S) and
      (Data.Source = olsGoogleBooks), 'пустая выдача РГБ → резервные источники');
    S.Mode := 4;
    Check(LookupBookByISBN(ISBN, TempDir, '', Data, W, Err, @Fallback, S) and
      (Data.Source = olsGoogleBooks), 'изменение формата РГБ → резервные источники');
    S.Mode := 2;
    C.Choice := 1;
    FallbackCalls := 0;
    Check(LookupBookByISBN(ISBN, TempDir, '', Data, W, Err, @Fallback, S, @C.Select) and
      (C.Count = 2) and (Data.Publisher = 'Другой издатель') and (FallbackCalls = 0), 'выбор из двух записей');
    C.Choice := -1;
    Check(not LookupBookByISBN(ISBN, TempDir, '', Data, W, Err, @Fallback, S, @C.Select) and
      (Err = '') and (FallbackCalls = 0), 'отмена выбора не запускает другие источники');
    S.Mode := 1;
    Check(LookupBookByISBN(ISBN, TempDir, '', Data, W, Err, @Offline, S) and
      Data.FromCache and (Data.Origin = olsRsl) and (Data.SourceURL <> ''), 'кэш сохраняет происхождение и ссылку');
    S.Calls := 0;
    FallbackCalls := 0;
    Check(not LookupBookByISBN('123', TempDir, '', Data, W, Err, @Fallback, S) and
      (S.Calls = 0) and (FallbackCalls = 0), 'неверный ISBN не вызывает сеть');
  finally
    C.Free;
    S.Free;
  end;
end;

procedure CacheTests;
var S: TStringList; Data: TOpenLibraryBookData; Err: string;
begin
  S := TStringList.Create;
  try
    S.Text := '{"isbn":"9789851675261","title":"Старая запись","source":1}';
    S.SaveToFile(IncludeTrailingPathDelimiter(TempDir) + ISBN + '.json');
    Check(LoadOpenLibraryCache(TempDir, ISBN, Data, Err) and Data.FromCache and
      (Data.Origin = olsGoogleBooks), 'старый кэш читается с прежним значением source');
    S.Text := '{"isbn":"9785170196364","title":"Чужая книга"}';
    S.SaveToFile(IncludeTrailingPathDelimiter(TempDir) + ISBN + '.json');
    Check(not LoadOpenLibraryCache(TempDir, ISBN, Data, Err), 'чужой ISBN в кэше отклоняется');
  finally
    S.Free;
  end;
end;

procedure LiveTest;
var Items: TBookCandidates; Err: string; Started: QWord;
begin
  Started := GetTickCount64;
  Check(LookupRsl(ISBN, nil, Items, Err) and (Length(Items) = 1), 'реальная сессия РГБ: ' + Err);
  Check(GetTickCount64 - Started < 17000, 'общий бюджет источника');
end;

procedure DeadlineTests;
var Session: TBookHttpSession; Status: Cardinal; Response, Err: string; Started: QWord;
begin
  Session := TBookHttpSession.Create(0);
  try
    Started := GetTickCount64;
    Check(not Session.Request('GET', 'https://search.rsl.ru/ru/search', '', Status,
      Response, Err) and (Status = 0) and (Err <> '') and
      (GetTickCount64 - Started < 100), 'исчерпанный бюджет не запускает новый запрос');
  finally
    Session.Free;
  end;
end;

var S: TStringList;
begin
  S := TStringList.Create;
  try
    S.LoadFromFile(ExpandFileName(ExtractFilePath(ParamStr(0)) + '../../tests/fixtures/rsl/01004592496.html'));
    Fixture := S.Text;
  finally
    S.Free;
  end;
  TempDir := IncludeTrailingPathDelimiter(GetTempDir(False)) + 'LibraryRslTests-' + IntToStr(GetTickCount64);
  ForceDirectories(TempDir);
  try
    ParserTests;
    ChainTests;
    CacheTests;
    DeadlineTests;
    if ParamStr(1) = '--live' then LiveTest;
  finally
    DeleteDirectory(TempDir, False);
  end;
  if Failures > 0 then Halt(1);
  WriteLn('Все тесты РГБ и локальной проверки пройдены.');
end.
