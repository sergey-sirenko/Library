unit uOpenRouter;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Contnrs, uEntities, uTypes;

type
  TRecognitionTextFormat = (rtfDelimitedTable, rtfCopiedWebPage);

  TBookMetadataLocalization = record
    ISBN: string;
    Language: string;
    Title: string;
    Authors: string;
    Publisher: string;
    Description: string;
    CategoryName: string;
  end;

const
  OPENROUTER_MODELS_URL = 'https://openrouter.ai/api/v1/models';
  MAX_TEXT_RECOGNITION_BOOKS = 100;
  TEXT_RECOGNITION_SAMPLE_ROWS = 5;

{ Низкоуровневый HTTP-вызов через WinHTTP (SChannel, без сторонних DLL).
  Используется также модулем uOpenRouterModels. }
function HttpRequest(const AMethod, AUrl, AApiKey, ARequestBody: string;
  out AStatusCode: DWORD; out AResponseBody: string; out AError: string;
  const ATimeoutMs: Cardinal = 0): Boolean;

{ Возвращает путь вместе со строкой запроса, который должен быть передан
  WinHttpOpenRequest. Фрагмент URL (#...) на сервер не отправляется. }
function HttpRequestTarget(const AUrl: string): string;

{ Достаёт error.message из JSON-ответа OpenRouter (если есть). Пустая строка,
  если тело не JSON или поле отсутствует. }
function ExtractOpenRouterErrorMessage(const ABody: string): string;

function TestOpenRouterConnection(const AApiKey, AModel: string; out AError: string;
  out AModelsCount: Integer; out AModelAvailable: Boolean): Boolean;

function RecognizeBookImage(const AFileName, AModel, AApiKey: string;
  out ABook: TRecognizedBook; out AStats: TRecognitionStats;
  out AError: string): Boolean;
function RecognizeBooksTextFile(const AFileName, AModel, AApiKey: string;
  ABooks: TObjectList; out AFormat: TRecognitionTextFormat;
  out AHasCategoryColumn: Boolean;
  out AStats: TRecognitionStats; out AError: string): Boolean;
function LocalizeBookMetadata(const AModel, AApiKey: string;
  const AOriginal: TBookMetadataLocalization;
  out ALocalized: TBookMetadataLocalization; out AStats: TRecognitionStats;
  out AError: string): Boolean;

{ Чистые функции разбора и проверки используются также автотестами. }
function ParseBookImageResponse(const AResponse: string; out ABook: TRecognizedBook;
  out AStats: TRecognitionStats; out AError: string): Boolean;
function ParseBooksTextResponse(const AResponse: string; ABooks: TObjectList;
  out AStats: TRecognitionStats; out AError: string): Boolean;
function ParseBookMetadataLocalizationResponse(const AResponse: string;
  const AOriginal: TBookMetadataLocalization;
  out ALocalized: TBookMetadataLocalization; out AStats: TRecognitionStats;
  out AError: string): Boolean;
function BuildTextRecognitionSample(const AText: string): string;
function DetectRecognitionTextFormat(const AText: string;
  out AFormat: TRecognitionTextFormat; out ARecordCount: Integer;
  out AHasCategoryColumn: Boolean;
  out AError: string): Boolean;
function ValidateRecognitionResultCount(AFormat: TRecognitionTextFormat;
  AExpectedCount, AActualCount: Integer; out AError: string): Boolean;
function LoadRecognitionTextFile(const AFileName: string; out AText: string;
  out AError: string): Boolean;
function ValidateRecognitionText(const AText: string; out AError: string): Boolean;

implementation

uses
  Windows, WinHttp, fpjson, jsonparser, base64, LConvEncoding, LazUTF8,
  StrUtils;

const
  OPENROUTER_COMPLETIONS_URL = 'https://openrouter.ai/api/v1/chat/completions';
  HTTP_USER_AGENT =
    'LibraryApp/1.1.1 (+https://github.com/sergey-sirenko/Library)';

{ В WinHttp.pas из поставки Lazarus отсутствует это объявление, хотя функция
  доступна в системной winhttp.dll. }
function WinHttpSetTimeouts(hInternet: HINTERNET; nResolveTimeout,
  nConnectTimeout, nSendTimeout, nReceiveTimeout: Integer): BOOL; stdcall;
  external 'winhttp.dll' name 'WinHttpSetTimeouts';

{ Расшифровка основных кодов ошибок WinHTTP в человеческие сообщения. }
function WinHttpErrorText(ACode: DWORD): string;
begin
  case ACode of
    12002: Result := 'таймаут соединения с сервером';
    12004: Result := 'внутренняя ошибка WinHTTP';
    12005: Result := 'некорректный URL';
    12006: Result := 'неподдерживаемая схема URL (допускаются http и https)';
    12007: Result := 'не удалось разрешить имя сервера (проблема DNS)';
    12015: Result := 'сбой в настройках WinHTTP';
    12029: Result := 'сервер недоступен или отверг соединение';
    12030: Result := 'соединение с сервером разорвано';
    12032: Result := 'соединение с сервером разорвано';
    12037: Result := 'сертификат сервера отозван';
    12038: Result := 'сервер требует клиентский сертификат, который не настроен';
    12044: Result := 'срок действия сертификата сервера истёк';
    12045: Result := 'цепочка доверия сертификата не прошла проверку';
    12046: Result := 'имя в сертификате не совпадает с адресом сервера';
    12175: Result := 'сбой TLS при соединении с сервером';
    else
      Result := 'код ошибки ' + IntToStr(ACode);
  end;
end;

function HttpRequestTarget(const AUrl: string): string;
var
  SchemePos, AuthorityStart, PathPos, QueryPos, FragmentPos, StartPos: SizeInt;
begin
  Result := '/';
  SchemePos := Pos('://', AUrl);
  if SchemePos > 0 then
    AuthorityStart := SchemePos + 3
  else
    AuthorityStart := 1;
  PathPos := PosEx('/', AUrl, AuthorityStart);
  QueryPos := PosEx('?', AUrl, AuthorityStart);
  if (PathPos > 0) and ((QueryPos = 0) or (PathPos < QueryPos)) then
    StartPos := PathPos
  else if QueryPos > 0 then
  begin
    Result := '/';
    StartPos := QueryPos;
  end
  else
    Exit;
  if StartPos = QueryPos then
    Result := Result + Copy(AUrl, StartPos, MaxInt)
  else
    Result := Copy(AUrl, StartPos, MaxInt);
  FragmentPos := Pos('#', Result);
  if FragmentPos > 0 then
    SetLength(Result, FragmentPos - 1);
  if Result = '' then
    Result := '/';
end;

{ Достаёт message из JSON-ответа OpenRouter вида error.message. }
function ExtractOpenRouterErrorMessage(const ABody: string): string;
var
  Root, ErrObj: TJSONData;
  Msg: string;
begin
  Result := '';
  if Trim(ABody) = '' then
    Exit;
  Root := nil;
  try
    try
      Root := GetJSON(ABody);
      if Root is TJSONObject then
      begin
        ErrObj := TJSONObject(Root).Objects['error'];
        if (ErrObj <> nil) and (ErrObj is TJSONObject) then
        begin
          Msg := TJSONObject(ErrObj).Get('message', '');
          if Msg <> '' then
            Result := Msg;
        end;
      end;
    except
      { Тело не JSON или структура неожиданная — оставляем Result пустым. }
    end;
  finally
    Root.Free;
  end;
end;

{ HTTP-обёртка над WinHTTP. Внутри использует SChannel (встроен в Windows),
  внешних DLL не требует. Поддерживает GET (AResquestBody='') и POST JSON. }
function HttpRequest(const AMethod, AUrl, AApiKey, ARequestBody: string;
  out AStatusCode: DWORD; out AResponseBody: string; out AError: string;
  const ATimeoutMs: Cardinal): Boolean;
var
  Session, Connect, Request: HINTERNET;
  UC: URL_COMPONENTS;
  Host, Path, WideUrl: WideString;
  Method, WHeaders: WideString;
  IsHTTPS: Boolean;
  Port: INTERNET_PORT;
  Flags: DWORD;
  BodyPtr: Pointer;
  BodyLen: DWORD;
  Buffer: array[0..8191] of Byte;
  Available, BytesRead: DWORD;
  Chunk: RawByteString;
  StatusCode: DWORD;
  StatusSize: DWORD;
  ErrCode: DWORD;
begin
  Result := False;
  AStatusCode := 0;
  AResponseBody := '';
  AError := '';
  Session := nil;
  Connect := nil;
  Request := nil;

  try
    { Разбираем URL на scheme/host/port/path. }
    FillChar(UC, SizeOf(UC), 0);
    UC.dwStructSize := SizeOf(UC);
    SetLength(Host, 256);
    WideUrl := UTF8Decode(AUrl);
    UC.lpszHostName := PWideChar(Host);
    UC.dwHostNameLength := Length(Host);
    Method := UTF8Decode(AMethod);
    if not WinHttpCrackUrl(PWideChar(WideUrl), Length(WideUrl), 0, @UC) then
    begin
      ErrCode := GetLastError;
      AError := 'Разбор URL: ' + WinHttpErrorText(ErrCode) + '.';
      Exit;
    end;
    SetLength(Host, UC.dwHostNameLength);
    Path := UTF8Decode(HttpRequestTarget(AUrl));
    IsHTTPS := UC.nScheme = INTERNET_SCHEME_HTTPS;
    Port := UC.nPort;
    if Port = 0 then
    begin
      if IsHTTPS then
        Port := INTERNET_DEFAULT_HTTPS_PORT
      else
        Port := INTERNET_DEFAULT_HTTP_PORT;
    end;

    Session := WinHttpOpen(PWideChar(UTF8Decode(HTTP_USER_AGENT)),
      WINHTTP_ACCESS_TYPE_DEFAULT_PROXY, WINHTTP_NO_PROXY_NAME,
      WINHTTP_NO_PROXY_BYPASS, 0);
    if Session = nil then
    begin
      ErrCode := GetLastError;
      AError := 'Открытие HTTP-сессии: ' + WinHttpErrorText(ErrCode) + '.';
      Exit;
    end;
    { Для операций, где вызывающая сторона задаёт ограничение времени,
      не полагаемся на системные настройки WinHTTP. }
    if ATimeoutMs > 0 then
      if not WinHttpSetTimeouts(Session, Integer(ATimeoutMs),
        Integer(ATimeoutMs), Integer(ATimeoutMs), Integer(ATimeoutMs)) then
      begin
        ErrCode := GetLastError;
        AError := 'Настройка таймаута HTTP: ' + WinHttpErrorText(ErrCode) + '.';
        Exit;
      end;
    Connect := WinHttpConnect(Session, PWideChar(Host), Port, 0);
    if Connect = nil then
    begin
      ErrCode := GetLastError;
      AError := 'Подключение к серверу ' + UTF8Encode(Host) + ': ' +
        WinHttpErrorText(ErrCode) + '.';
      Exit;
    end;

    Flags := 0;
    if IsHTTPS then
      Flags := WINHTTP_FLAG_SECURE;
    Request := WinHttpOpenRequest(Connect, PWideChar(Method), PWideChar(Path),
      nil, WINHTTP_NO_REFERER, WINHTTP_DEFAULT_ACCEPT_TYPES, Flags);
    if Request = nil then
    begin
      ErrCode := GetLastError;
      AError := 'Создание HTTP-запроса: ' + WinHttpErrorText(ErrCode) + '.';
      Exit;
    end;

    { Заголовки: авторизация и Content-Type. }
    if Trim(AApiKey) <> '' then
    begin
      WHeaders := UTF8Decode('Authorization: Bearer ' + AApiKey);
      if not WinHttpAddRequestHeaders(Request, PWideChar(WHeaders),
        Length(WHeaders), WINHTTP_ADDREQ_FLAG_ADD_IF_NEW) then
      begin
        ErrCode := GetLastError;
        AError := 'Добавление заголовка Authorization: ' + WinHttpErrorText(ErrCode) + '.';
        Exit;
      end;
    end;
    if ARequestBody <> '' then
    begin
      WHeaders := UTF8Decode('Content-Type: application/json');
      WinHttpAddRequestHeaders(Request, PWideChar(WHeaders),
        Length(WHeaders), WINHTTP_ADDREQ_FLAG_ADD_IF_NEW);
      BodyPtr := PAnsiChar(ARequestBody);
      BodyLen := Length(ARequestBody);
    end
    else
    begin
      BodyPtr := nil;
      BodyLen := 0;
    end;

    if not WinHttpSendRequest(Request, WINHTTP_NO_ADDITIONAL_HEADERS, 0,
      BodyPtr, BodyLen, BodyLen, 0) then
    begin
      ErrCode := GetLastError;
      AError := 'Отправка запроса: ' + WinHttpErrorText(ErrCode) + '.';
      Exit;
    end;
    if not WinHttpReceiveResponse(Request, nil) then
    begin
      ErrCode := GetLastError;
      AError := 'Получение ответа: ' + WinHttpErrorText(ErrCode) + '.';
      Exit;
    end;

    { Код статуса. }
    StatusCode := 0;
    StatusSize := SizeOf(StatusCode);
    if WinHttpQueryHeaders(Request,
      WINHTTP_QUERY_STATUS_CODE or WINHTTP_QUERY_FLAG_NUMBER,
      WINHTTP_HEADER_NAME_BY_INDEX, @StatusCode, @StatusSize,
      WINHTTP_NO_HEADER_INDEX) then
      AStatusCode := StatusCode;

    { Тело ответа (читаем до победного блоками по 8 КБ). }
    while True do
    begin
      Available := 0;
      if not WinHttpQueryDataAvailable(Request, @Available) then
        Break;
      if Available = 0 then
        Break;
      if Available > SizeOf(Buffer) then
        Available := SizeOf(Buffer);
      BytesRead := 0;
      if not WinHttpReadData(Request, @Buffer[0], Available, @BytesRead) then
        Break;
      if BytesRead = 0 then
        Break;
      SetLength(Chunk, BytesRead);
      Move(Buffer[0], Chunk[1], BytesRead);
      AResponseBody := AResponseBody + Chunk;
      if BytesRead < Available then
        Break;
    end;

    Result := True;
  finally
    if Request <> nil then
      WinHttpCloseHandle(Request);
    if Connect <> nil then
      WinHttpCloseHandle(Connect);
    if Session <> nil then
      WinHttpCloseHandle(Session);
  end;
end;

function ImageMimeType(const AFileName: string): string;
var
  Ext: string;
begin
  Ext := LowerCase(ExtractFileExt(AFileName));
  if (Ext = '.jpg') or (Ext = '.jpeg') then
    Result := 'image/jpeg'
  else if Ext = '.png' then
    Result := 'image/png'
  else if Ext = '.webp' then
    Result := 'image/webp'
  else if Ext = '.gif' then
    Result := 'image/gif'
  else
    Result := '';
end;

function FileAsBase64(const AFileName: string): string;
var
  FS: TFileStream;
  Data: RawByteString;
begin
  FS := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  try
    if FS.Size > MaxInt then
      raise Exception.Create('Файл изображения слишком большой.');
    SetLength(Data, SizeInt(FS.Size));
    if FS.Size > 0 then
      FS.ReadBuffer(Data[1], LongInt(FS.Size));
    Result := EncodeStringBase64(Data);
  finally
    FS.Free;
  end;
end;

function RecognitionPrompt: string;
begin
  Result :=
    'Распознай фотографию библиотечной книги. Найди название книги и инвентарный ' +
    'номер на библиотечном штампе, а также автора или авторов, год издания, ' +
    'издательство, ISBN, краткое описание и категорию, если они видны. Верни ' +
    'только корректный JSON без Markdown и пояснений в формате ' +
    '{"title":"","inventoryNumber":"","authors":"","year":"",' +
    '"publisher":"","isbn":"","description":"","category":""}. ' +
    'Не выдумывай отсутствующие данные: неизвестные значения оставляй пустыми.';
end;

function BuildTextRecognitionSample(const AText: string): string;
var
  Lines: TStringList;
  HeaderFound: Boolean;
  I, RecordCount: Integer;
begin
  Result := '';
  Lines := TStringList.Create;
  try
    Lines.Text := AText;
    HeaderFound := False;
    RecordCount := 0;
    for I := 0 to Lines.Count - 1 do
    begin
      if Trim(Lines[I]) = '' then
        Continue;
      if HeaderFound and (RecordCount >= TEXT_RECOGNITION_SAMPLE_ROWS) then
        Break;
      if Result <> '' then
        Result := Result + LineEnding;
      Result := Result + Lines[I];
      if HeaderFound then
        Inc(RecordCount)
      else
        HeaderFound := True;
    end;
  finally
    Lines.Free;
  end;
end;

function DelimitedTextRecognitionPrompt(const AText: string): string;
var
  ControlSample: string;
begin
  ControlSample := BuildTextRecognitionSample(AText);
  Result :=
    'Преобразуй таблицу, полученную после диктовки данных библиотечных книг, в ' +
    'структурированные записи. Первая непустая строка содержит заголовки. ' +
    'Сначала определи назначение каждой колонки по заголовкам и контрольному ' +
    'фрагменту из первых пяти записей. Порядок колонок произвольный. Если ' +
    'заголовки и значения противоречат друг другу, но фактическое назначение ' +
    'колонок определяется однозначно, исправь сопоставление и верни ' +
    'mappingConfirmed=true. Если обязательную или поддерживаемую колонку нельзя ' +
    'определить однозначно, верни mappingConfirmed=false и краткую причину в ' +
    'mappingError. Неизвестные дополнительные колонки игнорируй: они не делают ' +
    'сопоставление неоднозначным. Разделителями служат точка с запятой, табуляция ' +
    'или вертикальная черта; в отдельных строках разделители могут быть ' +
    'ошибочными. Обязательные поля — название или наименование и инвентарный ' +
    'номер. Возможные дополнительные поля — авторы, год, издательство, ISBN, ' +
    'описание и категория. Отсутствующее значение в отдельной записи не является ' +
    'ошибкой структуры. Исправляй только очевидные ошибки распознавания речи и ' +
    'разделения, сохраняй исходный порядок и количество записей и не выдумывай ' +
    'отсутствующие данные. Верни только корректный JSON без Markdown и пояснений ' +
    'в формате {"mappingConfirmed":true,"mappingError":"","books":[' +
    '{"title":"","inventoryNumber":"","authors":"","year":"",' +
    '"publisher":"","isbn":"","description":"","category":""}]}. ' +
    'При mappingConfirmed=false верни пустой массив books.' + LineEnding +
    'Контрольный фрагмент:' + LineEnding + ControlSample + LineEnding +
    'Полный текст файла:' + LineEnding + AText;
end;

function CopiedWebPageRecognitionPrompt(const AText: string;
  AExpectedRecordCount: Integer): string;
begin
  Result :=
    'Преобразуй текст, скопированный со страницы сайта с избранными книгами, в ' +
    'структурированные записи. В тексте ожидается ровно ' +
    IntToStr(AExpectedRecordCount) + ' библиографических записей. Строка с ' +
    'библиографическим описанием и ISBN начинает запись книги. Следующую ' +
    'содержательную строку до элементов управления страницы считай сведениями ' +
    'об авторе этой книги; одиночное тире означает отсутствие дополнительной ' +
    'строки автора. Игнорируй заголовок страницы, приглашение поиска, строки ' +
    '«+ добавить метку», «Удалить», «Сортировать по», «Ключевые слова», ' +
    '«+ добавить слово» и другие элементы интерфейса сайта. Извлеки название и ' +
    'подзаголовок, авторов, год, издательство и ISBN. Служебное обозначение ' +
    '«[Текст]» в название не включай. Сведения об издании, количестве страниц, ' +
    'иллюстрациях, размере, серии, переплёте и тираже перенеси в description, ' +
    'если они присутствуют. Категорию не выдумывай: если она явно не указана, ' +
    'верни пустую строку. Инвентарный номер не выдумывай и всегда возвращай ' +
    'пустым: приложение назначит его автоматически. Сохрани исходный порядок и ' +
    'верни ровно ' + IntToStr(AExpectedRecordCount) + ' книг. Если границы ' +
    'записей нельзя определить однозначно, верни mappingConfirmed=false и ' +
    'краткую причину в mappingError; иначе верни mappingConfirmed=true. Верни ' +
    'только корректный JSON без Markdown и пояснений в формате ' +
    '{"mappingConfirmed":true,"mappingError":"","books":[' +
    '{"title":"","inventoryNumber":"","authors":"","year":"",' +
    '"publisher":"","isbn":"","description":"","category":""}]}. ' +
    'При mappingConfirmed=false верни пустой массив books.' + LineEnding +
    'Текст страницы:' + LineEnding + AText;
end;

function TextRecognitionPrompt(const AText: string;
  AFormat: TRecognitionTextFormat; AExpectedRecordCount: Integer): string;
begin
  if AFormat = rtfCopiedWebPage then
    Result := CopiedWebPageRecognitionPrompt(AText, AExpectedRecordCount)
  else
    Result := DelimitedTextRecognitionPrompt(AText);
end;

function BookMetadataLocalizationPrompt(
  const AData: TBookMetadataLocalization): string;
var
  Source: TJSONObject;
begin
  Source := TJSONObject.Create;
  try
    Source.Add('isbn', AData.ISBN);
    Source.Add('sourceLanguage', AData.Language);
    Source.Add('title', AData.Title);
    Source.Add('authors', AData.Authors);
    Source.Add('publisher', AData.Publisher);
    Source.Add('description', AData.Description);
    Source.Add('category', AData.CategoryName);
    Result :=
      'Проверь библиографические данные книги, полученные из внешнего API. ' +
      'Исправь на русский язык только те фрагменты, которые по контексту должны ' +
      'быть русскими, но записаны латинской транслитерацией, смешанной кириллицей ' +
      'и латиницей, неверными похожими символами или на другом языке. Учитывай ' +
      'язык издания, название, авторов, издательство и общий контекст. Для ' +
      'русского издания переводи на русский общеупотребительные категории и ' +
      'описание, если API вернул их на другом языке. Очевидно иностранные ' +
      'названия, имена, издательства, бренды, аббревиатуры, формулы, обозначения ' +
      'и иностранные фрагменты внутри русского текста не переводи и не ' +
      'транслитерируй. Не меняй смысл, не добавляй сведения и не сокращай текст. ' +
      'Если поле не требует исправления, верни его без изменений. Верни только ' +
      'корректный JSON без Markdown и пояснений со всеми полями в формате ' +
      '{"title":"","authors":"","publisher":"","description":"",' +
      '"category":""}. Исходные данные:' + LineEnding + Source.AsJSON;
  finally
    Source.Free;
  end;
end;

function JsonFieldText(AObject: TJSONObject; const AName: string): string;
var
  Data: TJSONData;
begin
  Result := '';
  if AObject = nil then
    Exit;
  Data := AObject.Find(AName);
  if (Data <> nil) and (Data.JSONType <> jtNull) then
    Result := Trim(Data.AsString);
  if SameText(AName, 'isbn') then
    Result := NormalizeISBNFormat(Result);
end;

procedure FillRecognizedBook(AObject: TJSONObject; ABook: TRecognizedBook);
begin
  ABook.Title := JsonFieldText(AObject, 'title');
  ABook.InventoryNo := JsonFieldText(AObject, 'inventoryNumber');
  ABook.Authors := JsonFieldText(AObject, 'authors');
  ABook.Year := JsonFieldText(AObject, 'year');
  ABook.Publisher := JsonFieldText(AObject, 'publisher');
  ABook.ISBN := JsonFieldText(AObject, 'isbn');
  ABook.Description := JsonFieldText(AObject, 'description');
  ABook.CategoryName := JsonFieldText(AObject, 'category');
end;

procedure ExtractRecognitionStats(ARoot: TJSONObject; out AStats: TRecognitionStats);
var
  UsageData, UsageValue: TJSONData;
  UsageObj: TJSONObject;
begin
  ClearRecognitionStats(AStats);
  if ARoot = nil then
    Exit;
  AStats.Models := Trim(ARoot.Get('model', ''));
  UsageValue := ARoot.Find('usage');
  if not (UsageValue is TJSONObject) then
    Exit;
  UsageObj := TJSONObject(UsageValue);
  AStats.PromptTokens := UsageObj.Get('prompt_tokens', Int64(0));
  AStats.CompletionTokens := UsageObj.Get('completion_tokens', Int64(0));
  AStats.TotalTokens := UsageObj.Get('total_tokens', Int64(0));
  UsageData := UsageObj.Find('cost');
  if (UsageData <> nil) and (UsageData.JSONType <> jtNull) then
  begin
    AStats.RecognitionCost := UsageData.AsFloat;
    AStats.HasCost := True;
  end;
end;

function ParseResponseEnvelope(const AResponse: string; out ARoot,
  AContent: TJSONData; out AStats: TRecognitionStats): Boolean;
var
  Choices: TJSONArray;
  MessageObj, RootObj: TJSONObject;
  ContentText: string;
begin
  Result := False;
  ARoot := nil;
  AContent := nil;
  ClearRecognitionStats(AStats);
  ARoot := GetJSON(AResponse);
  if not (ARoot is TJSONObject) then
    raise Exception.Create('Ответ не является JSON-объектом.');
  RootObj := TJSONObject(ARoot);
  Choices := RootObj.Arrays['choices'];
  if (Choices = nil) or (Choices.Count = 0) or not (Choices[0] is TJSONObject) then
    raise Exception.Create('В ответе отсутствует результат модели.');
  MessageObj := TJSONObject(TJSONObject(Choices[0]).Objects['message']);
  if MessageObj = nil then
    raise Exception.Create('В ответе отсутствует сообщение модели.');
  ContentText := Trim(MessageObj.Get('content', ''));
  if ContentText = '' then
    raise Exception.Create('Модель не вернула результат.');
  AContent := GetJSON(ContentText);
  ExtractRecognitionStats(RootObj, AStats);
  Result := True;
end;

function ParseBookImageResponse(const AResponse: string; out ABook: TRecognizedBook;
  out AStats: TRecognitionStats; out AError: string): Boolean;
var
  Root, Content: TJSONData;
begin
  Result := False;
  ABook := nil;
  AError := '';
  Root := nil;
  Content := nil;
  ClearRecognitionStats(AStats);
  try
    try
      ParseResponseEnvelope(AResponse, Root, Content, AStats);
      if not (Content is TJSONObject) then
        raise Exception.Create('Результат модели не является JSON-объектом.');
      ABook := TRecognizedBook.Create;
      FillRecognizedBook(TJSONObject(Content), ABook);
      Result := True;
    except
      on E: Exception do
      begin
        FreeAndNil(ABook);
        ClearRecognitionStats(AStats);
        AError := 'Не удалось разобрать данные изображения: ' + E.Message;
      end;
    end;
  finally
    Content.Free;
    Root.Free;
  end;
end;

function ParseBooksTextResponse(const AResponse: string; ABooks: TObjectList;
  out AStats: TRecognitionStats; out AError: string): Boolean;
var
  Root, Content, BooksData, MappingConfirmedData, MappingErrorData: TJSONData;
  ContentObject: TJSONObject;
  Books: TJSONArray;
  Book: TRecognizedBook;
  I: Integer;
  MappingError: string;
begin
  Result := False;
  AError := '';
  Root := nil;
  Content := nil;
  ClearRecognitionStats(AStats);
  if ABooks = nil then
  begin
    AError := 'Не передан список для результатов распознавания.';
    Exit;
  end;
  ABooks.Clear;
  try
    try
      ParseResponseEnvelope(AResponse, Root, Content, AStats);
      if not (Content is TJSONObject) then
        raise Exception.Create('Результат модели не является JSON-объектом.');
      ContentObject := TJSONObject(Content);
      MappingConfirmedData := ContentObject.Find('mappingConfirmed');
      if (MappingConfirmedData = nil) or
         (MappingConfirmedData.JSONType <> jtBoolean) then
        raise Exception.Create('В результате модели отсутствует признак проверки колонок mappingConfirmed.');
      MappingErrorData := ContentObject.Find('mappingError');
      if (MappingErrorData = nil) or (MappingErrorData.JSONType <> jtString) then
        raise Exception.Create('В результате модели отсутствует описание проверки колонок mappingError.');
      BooksData := ContentObject.Find('books');
      if not (BooksData is TJSONArray) then
        raise Exception.Create('В результате модели отсутствует массив books.');
      if not MappingConfirmedData.AsBoolean then
      begin
        MappingError := Trim(MappingErrorData.AsString);
        if MappingError = '' then
          MappingError := 'модель не смогла однозначно определить назначение колонок';
        raise Exception.Create('Не удалось однозначно определить расположение колонок: ' +
          MappingError + '.');
      end;
      Books := TJSONArray(BooksData);
      for I := 0 to Books.Count - 1 do
      begin
        if not (Books[I] is TJSONObject) then
          Continue;
        Book := TRecognizedBook.Create;
        FillRecognizedBook(TJSONObject(Books[I]), Book);
        ABooks.Add(Book);
      end;
      if ABooks.Count = 0 then
        raise Exception.Create('Модель не вернула ни одной записи книги.');
      if ABooks.Count > MAX_TEXT_RECOGNITION_BOOKS then
        raise Exception.Create('Модель вернула более 100 записей.');
      Result := True;
    except
      on E: Exception do
      begin
        ABooks.Clear;
        ClearRecognitionStats(AStats);
        AError := 'Не удалось разобрать текстовый файл: ' + E.Message;
      end;
    end;
  finally
    Content.Free;
    Root.Free;
  end;
end;

function RequiredLocalizationField(AObject: TJSONObject;
  const AName: string): string;
var
  Data: TJSONData;
begin
  Data := AObject.Find(AName);
  if (Data = nil) or (Data.JSONType <> jtString) then
    raise Exception.Create('В результате модели отсутствует строковое поле ' +
      AName + '.');
  Result := Trim(Data.AsString);
end;

procedure EnsureLocalizationFieldNotLost(const AOriginal, ALocalized,
  AFieldCaption: string);
begin
  if (Trim(AOriginal) <> '') and (Trim(ALocalized) = '') then
    raise Exception.Create('Модель очистила поле «' + AFieldCaption + '».');
end;

function ParseBookMetadataLocalizationResponse(const AResponse: string;
  const AOriginal: TBookMetadataLocalization;
  out ALocalized: TBookMetadataLocalization; out AStats: TRecognitionStats;
  out AError: string): Boolean;
var
  Root, Content: TJSONData;
  ContentObject: TJSONObject;
  Parsed: TBookMetadataLocalization;
begin
  Result := False;
  ALocalized := AOriginal;
  AError := '';
  Root := nil;
  Content := nil;
  ClearRecognitionStats(AStats);
  try
    try
      ParseResponseEnvelope(AResponse, Root, Content, AStats);
      if not (Content is TJSONObject) then
        raise Exception.Create('Результат модели не является JSON-объектом.');
      ContentObject := TJSONObject(Content);
      Parsed := AOriginal;
      Parsed.Title := RequiredLocalizationField(ContentObject, 'title');
      Parsed.Authors := RequiredLocalizationField(ContentObject, 'authors');
      Parsed.Publisher := RequiredLocalizationField(ContentObject, 'publisher');
      Parsed.Description := RequiredLocalizationField(ContentObject, 'description');
      Parsed.CategoryName := RequiredLocalizationField(ContentObject, 'category');
      EnsureLocalizationFieldNotLost(AOriginal.Title, Parsed.Title, 'Название');
      EnsureLocalizationFieldNotLost(AOriginal.Authors, Parsed.Authors, 'Автор(ы)');
      EnsureLocalizationFieldNotLost(AOriginal.Publisher, Parsed.Publisher,
        'Издательство');
      EnsureLocalizationFieldNotLost(AOriginal.Description, Parsed.Description,
        'Описание');
      EnsureLocalizationFieldNotLost(AOriginal.CategoryName, Parsed.CategoryName,
        'Категория');
      ALocalized := Parsed;
      Result := True;
    except
      on E: Exception do
      begin
        ALocalized := AOriginal;
        ClearRecognitionStats(AStats);
        AError := 'Не удалось проверить локализацию данных книги: ' + E.Message;
      end;
    end;
  finally
    Content.Free;
    Root.Free;
  end;
end;

function NormalizeHeaderName(const AValue: string): string;
begin
  Result := UTF8LowerCase(Trim(AValue));
  Result := StringReplace(Result, ' ', '', [rfReplaceAll]);
  Result := StringReplace(Result, '.', '', [rfReplaceAll]);
  Result := StringReplace(Result, '_', '', [rfReplaceAll]);
  Result := StringReplace(Result, '-', '', [rfReplaceAll]);
  Result := StringReplace(Result, '"', '', [rfReplaceAll]);
end;

function IsTitleHeader(const AValue: string): Boolean;
var
  Key: string;
begin
  Key := NormalizeHeaderName(AValue);
  Result := (Key = 'наименование') or (Key = 'название') or
    (Key = 'наименованиекниги') or (Key = 'названиекниги') or
    (Key = 'title');
end;

function IsInventoryHeader(const AValue: string): Boolean;
var
  Key: string;
begin
  Key := NormalizeHeaderName(AValue);
  Result := (Key = 'инвентарныйномер') or (Key = 'инвномер') or
    (Key = 'инвентарный№') or (Key = 'инв№') or
    (Key = 'inventorynumber');
end;

function IsCategoryHeader(const AValue: string): Boolean;
var
  Key: string;
begin
  Key := NormalizeHeaderName(AValue);
  Result := (Key = 'категория') or (Key = 'категории') or
    (Key = 'category');
end;

function HeaderDelimiter(const AHeader: string): Char;
var
  Semicolons, Tabs, Pipes: Integer;
begin
  Semicolons := Length(AHeader) - Length(StringReplace(AHeader, ';', '', [rfReplaceAll]));
  Tabs := Length(AHeader) - Length(StringReplace(AHeader, #9, '', [rfReplaceAll]));
  Pipes := Length(AHeader) - Length(StringReplace(AHeader, '|', '', [rfReplaceAll]));
  Result := #0;
  if (Semicolons >= Tabs) and (Semicolons >= Pipes) and (Semicolons > 0) then
    Result := ';'
  else if (Tabs >= Pipes) and (Tabs > 0) then
    Result := #9
  else if Pipes > 0 then
    Result := '|';
end;

function HasLikelyISBN(const AValue: string): Boolean;
var
  LowerValue: string;
  I, MarkerPos, DigitCount: Integer;
begin
  Result := False;
  LowerValue := LowerCase(AValue);
  MarkerPos := Pos('isbn', LowerValue);
  if MarkerPos = 0 then
    Exit;
  DigitCount := 0;
  for I := MarkerPos + 4 to Length(AValue) do
    if AValue[I] in ['0'..'9'] then
      Inc(DigitCount);
  Result := DigitCount >= 10;
end;

function DetectRecognitionTextFormat(const AText: string;
  out AFormat: TRecognitionTextFormat; out ARecordCount: Integer;
  out AHasCategoryColumn: Boolean;
  out AError: string): Boolean;
var
  Lines, Headers: TStringList;
  HeaderIndex, I: Integer;
  Delimiter: Char;
  HasTitle, HasInventory: Boolean;
begin
  Result := False;
  AFormat := rtfDelimitedTable;
  ARecordCount := 0;
  AHasCategoryColumn := False;
  AError := '';
  if Trim(AText) = '' then
  begin
    AError := 'Текстовый файл пуст.';
    Exit;
  end;
  Lines := TStringList.Create;
  Headers := TStringList.Create;
  try
    Lines.Text := AText;
    HeaderIndex := -1;
    for I := 0 to Lines.Count - 1 do
      if Trim(Lines[I]) <> '' then
      begin
        HeaderIndex := I;
        Break;
      end;
    if HeaderIndex < 0 then
    begin
      AError := 'В текстовом файле не найдена строка заголовков.';
      Exit;
    end;
    Delimiter := HeaderDelimiter(Lines[HeaderIndex]);
    HasTitle := False;
    HasInventory := False;
    if Delimiter <> #0 then
    begin
      Headers.StrictDelimiter := True;
      Headers.Delimiter := Delimiter;
      Headers.DelimitedText := Lines[HeaderIndex];
      for I := 0 to Headers.Count - 1 do
      begin
        HasTitle := HasTitle or IsTitleHeader(Headers[I]);
        HasInventory := HasInventory or IsInventoryHeader(Headers[I]);
        AHasCategoryColumn := AHasCategoryColumn or IsCategoryHeader(Headers[I]);
      end;
    end;
    if HasTitle or HasInventory then
    begin
      if not HasTitle or not HasInventory then
      begin
        AError := 'В заголовках должны быть колонки «Наименование» (или «Название») ' +
          'и «Инвентарный номер».';
        Exit;
      end;
      for I := HeaderIndex + 1 to Lines.Count - 1 do
        if Trim(Lines[I]) <> '' then
          Inc(ARecordCount);
      if ARecordCount = 0 then
      begin
        AError := 'В текстовом файле нет записей книг.';
        Exit;
      end;
      if ARecordCount > MAX_TEXT_RECOGNITION_BOOKS then
      begin
        AError := 'В текстовом файле больше 100 записей. Разделите его на несколько файлов.';
        Exit;
      end;
      AFormat := rtfDelimitedTable;
      Exit(True);
    end;

    for I := 0 to Lines.Count - 1 do
      if HasLikelyISBN(Lines[I]) then
        Inc(ARecordCount);
    if ARecordCount = 0 then
    begin
      AError := 'Файл не похож ни на таблицу с заголовками, ни на копию страницы ' +
        'с библиографическими записями и ISBN.';
      Exit;
    end;
    if ARecordCount > MAX_TEXT_RECOGNITION_BOOKS then
    begin
      AError := 'В текстовом файле больше 100 записей. Разделите его на несколько файлов.';
      Exit;
    end;
    AFormat := rtfCopiedWebPage;
    Result := True;
  finally
    Headers.Free;
    Lines.Free;
  end;
end;

function ValidateRecognitionText(const AText: string; out AError: string): Boolean;
var
  TextFormat: TRecognitionTextFormat;
  RecordCount: Integer;
  HasCategoryColumn: Boolean;
begin
  Result := DetectRecognitionTextFormat(AText, TextFormat, RecordCount,
    HasCategoryColumn, AError);
end;

function ValidateRecognitionResultCount(AFormat: TRecognitionTextFormat;
  AExpectedCount, AActualCount: Integer; out AError: string): Boolean;
begin
  AError := '';
  Result := (AFormat <> rtfCopiedWebPage) or
    (AExpectedCount = AActualCount);
  if not Result then
    AError := 'Модель вернула ' + IntToStr(AActualCount) +
      ' записей вместо ожидаемых ' + IntToStr(AExpectedCount) + '.';
end;

function LoadRecognitionTextFile(const AFileName: string; out AText: string;
  out AError: string): Boolean;
var
  Data: string;
  EncodingName: string;
  Encoded: Boolean;
  Stream: TFileStream;
begin
  Result := False;
  AText := '';
  AError := '';
  if not FileExists(AFileName) then
  begin
    AError := 'Текстовый файл не найден.';
    Exit;
  end;
  if not SameText(ExtractFileExt(AFileName), '.txt') then
  begin
    AError := 'Поддерживаются только текстовые файлы с расширением .txt.';
    Exit;
  end;
  try
    Stream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
    try
      if Stream.Size > MaxInt then
        raise Exception.Create('Текстовый файл слишком большой.');
      SetLength(Data, SizeInt(Stream.Size));
      if Stream.Size > 0 then
        Stream.ReadBuffer(Data[1], LongInt(Stream.Size));
    finally
      Stream.Free;
    end;
    EncodingName := GuessEncoding(Data);
    if EncodingName = '' then
      EncodingName := EncodingUTF8;
    AText := ConvertEncodingToUTF8(Data, EncodingName, Encoded);
    Result := ValidateRecognitionText(AText, AError);
  except
    on E: Exception do
      AError := 'Не удалось прочитать текстовый файл: ' + E.Message;
  end;
end;

function TestOpenRouterConnection(const AApiKey, AModel: string; out AError: string;
  out AModelsCount: Integer; out AModelAvailable: Boolean): Boolean;
var
  Root, ModelObj: TJSONData;
  ModelsArr: TJSONArray;
  i: Integer;
  ModelID: string;
  HaveModel: Boolean;
  StatusCode: DWORD;
  ResponseBody: string;
  ServerMsg: string;
begin
  Result := False;
  AError := '';
  AModelsCount := 0;
  AModelAvailable := True;
  HaveModel := Trim(AModel) <> '';
  if Trim(AApiKey) = '' then
  begin
    AError := 'Не задан OpenRouter API Key.';
    Exit;
  end;

  Root := nil;
  try
    try
      if not HttpRequest('GET', OPENROUTER_MODELS_URL, AApiKey, '',
        StatusCode, ResponseBody, AError) then
      begin
        { AError уже содержит конкретную причину (WinHTTP). }
        Exit;
      end;
      if (StatusCode < 200) or (StatusCode >= 300) then
      begin
        ServerMsg := ExtractOpenRouterErrorMessage(ResponseBody);
        if (StatusCode = 401) or (StatusCode = 403) then
        begin
          if ServerMsg <> '' then
            AError := 'API Key отклонён OpenRouter (HTTP ' + IntToStr(StatusCode) +
              '): ' + ServerMsg
          else
            AError := 'API Key отклонён OpenRouter (HTTP ' + IntToStr(StatusCode) +
              '). Проверьте правильность ключа и не истёк ли он.';
        end
        else if ServerMsg <> '' then
          AError := 'OpenRouter: HTTP ' + IntToStr(StatusCode) + '. ' + ServerMsg
        else
          AError := 'OpenRouter: HTTP ' + IntToStr(StatusCode) + ' (ответ без сообщения).';
        Exit;
      end;
      Root := GetJSON(ResponseBody);
      if not (Root is TJSONObject) then
      begin
        AError := 'Ответ OpenRouter не является JSON-объектом.';
        Exit;
      end;
      ModelsArr := TJSONObject(Root).Arrays['data'];
      if ModelsArr = nil then
      begin
        AError := 'В ответе OpenRouter отсутствует список моделей.';
        Exit;
      end;
      AModelsCount := ModelsArr.Count;
      if not HaveModel then
      begin
        Result := True;
        Exit;
      end;
      AModelAvailable := False;
      ModelID := Trim(AModel);
      for i := 0 to ModelsArr.Count - 1 do
      begin
        ModelObj := ModelsArr[i];
        if ModelObj is TJSONObject then
        begin
          if Trim(TJSONObject(ModelObj).Get('id', '')) = ModelID then
          begin
            AModelAvailable := True;
            Break;
          end;
        end;
      end;
      Result := True;
    except
      on E: Exception do
        AError := 'Локальная ошибка при проверке: ' + E.Message;
    end;
  finally
    Root.Free;
  end;
end;

function SendRecognitionRequest(const AApiKey, ARequestBody: string;
  out AResponseBody, AError: string): Boolean;
var
  StatusCode: DWORD;
  ServerMsg: string;
begin
  Result := False;
  AResponseBody := '';
  AError := '';
  if not HttpRequest('POST', OPENROUTER_COMPLETIONS_URL, AApiKey,
    ARequestBody, StatusCode, AResponseBody, AError) then
    Exit;
  if (StatusCode >= 200) and (StatusCode < 300) then
  begin
    Result := True;
    Exit;
  end;
  ServerMsg := ExtractOpenRouterErrorMessage(AResponseBody);
  if (StatusCode = 401) or (StatusCode = 403) then
  begin
    if ServerMsg <> '' then
      AError := 'API Key отклонён OpenRouter (HTTP ' + IntToStr(StatusCode) +
        '): ' + ServerMsg
    else
      AError := 'API Key отклонён OpenRouter (HTTP ' + IntToStr(StatusCode) +
        '). Проверьте правильность ключа.';
  end
  else if ServerMsg <> '' then
    AError := 'OpenRouter: HTTP ' + IntToStr(StatusCode) + '. ' + ServerMsg
  else
    AError := 'OpenRouter: HTTP ' + IntToStr(StatusCode) + ' (ответ без сообщения).';
end;

function LocalizeBookMetadata(const AModel, AApiKey: string;
  const AOriginal: TBookMetadataLocalization;
  out ALocalized: TBookMetadataLocalization; out AStats: TRecognitionStats;
  out AError: string): Boolean;
var
  Messages: TJSONArray;
  RequestJson, Message: TJSONObject;
  RequestBody, ResponseBody: string;
begin
  Result := False;
  ALocalized := AOriginal;
  AError := '';
  ClearRecognitionStats(AStats);
  if Trim(AModel) = '' then
  begin
    AError := 'Не задана модель OpenRouter.';
    Exit;
  end;
  if Trim(AApiKey) = '' then
  begin
    AError := 'Не задан OpenRouter API Key.';
    Exit;
  end;
  if (Trim(AOriginal.Title) = '') and (Trim(AOriginal.Authors) = '') and
     (Trim(AOriginal.Publisher) = '') and (Trim(AOriginal.Description) = '') and
     (Trim(AOriginal.CategoryName) = '') then
    Exit(True);
  try
    RequestJson := TJSONObject.Create;
    try
      RequestJson.Add('model', Trim(AModel));
      Messages := TJSONArray.Create;
      Message := TJSONObject.Create;
      Message.Add('role', 'user');
      Message.Add('content', BookMetadataLocalizationPrompt(AOriginal));
      Messages.Add(Message);
      RequestJson.Add('messages', Messages);
      RequestBody := RequestJson.AsJSON;
      if not SendRecognitionRequest(AApiKey, RequestBody, ResponseBody, AError) then
        Exit;
      if not ParseBookMetadataLocalizationResponse(ResponseBody, AOriginal,
        ALocalized, AStats, AError) then
        Exit;
      if Trim(AStats.Models) = '' then
        AStats.Models := Trim(AModel);
      Result := True;
    finally
      RequestJson.Free;
    end;
  except
    on E: Exception do
    begin
      ALocalized := AOriginal;
      ClearRecognitionStats(AStats);
      AError := 'Локальная ошибка при проверке данных книги: ' + E.Message;
    end;
  end;
end;

function RecognizeBookImage(const AFileName, AModel, AApiKey: string;
  out ABook: TRecognizedBook; out AStats: TRecognitionStats;
  out AError: string): Boolean;
var
  Messages, Content: TJSONArray;
  RequestJson: TJSONObject;
  Message, TextPart, ImagePart, ImageUrl: TJSONObject;
  MimeType, EncodedImage, RequestBody, ResponseBody: string;
begin
  Result := False;
  ABook := nil;
  AError := '';
  ClearRecognitionStats(AStats);
  if Trim(AModel) = '' then
  begin
    AError := 'Не задана модель OpenRouter.';
    Exit;
  end;
  if Trim(AApiKey) = '' then
  begin
    AError := 'Не задан OpenRouter API Key.';
    Exit;
  end;
  if not FileExists(AFileName) then
  begin
    AError := 'Файл изображения не найден.';
    Exit;
  end;
  MimeType := ImageMimeType(AFileName);
  if MimeType = '' then
  begin
    AError := 'Поддерживаются только JPEG, PNG, WebP и GIF.';
    Exit;
  end;

  try
    EncodedImage := FileAsBase64(AFileName);
    RequestJson := TJSONObject.Create;
    try
      RequestJson.Add('model', Trim(AModel));
      Messages := TJSONArray.Create;
      Message := TJSONObject.Create;
      Message.Add('role', 'user');
      Content := TJSONArray.Create;
      TextPart := TJSONObject.Create;
      TextPart.Add('type', 'text');
      TextPart.Add('text', RecognitionPrompt);
      Content.Add(TextPart);
      ImagePart := TJSONObject.Create;
      ImagePart.Add('type', 'image_url');
      ImageUrl := TJSONObject.Create;
      ImageUrl.Add('url', 'data:' + MimeType + ';base64,' + EncodedImage);
      ImagePart.Add('image_url', ImageUrl);
      Content.Add(ImagePart);
      Message.Add('content', Content);
      Messages.Add(Message);
      RequestJson.Add('messages', Messages);
      RequestBody := RequestJson.AsJSON;
      if not SendRecognitionRequest(AApiKey, RequestBody, ResponseBody, AError) then
        Exit;
      Result := ParseBookImageResponse(ResponseBody, ABook, AStats, AError);
      if Result and (Trim(AStats.Models) = '') then
        AStats.Models := Trim(AModel);
    finally
      RequestJson.Free;
    end;
  except
    on E: Exception do
    begin
      FreeAndNil(ABook);
      ClearRecognitionStats(AStats);
      AError := 'Локальная ошибка при распознавании изображения: ' + E.Message;
    end;
  end;
end;

function RecognizeBooksTextFile(const AFileName, AModel, AApiKey: string;
  ABooks: TObjectList; out AFormat: TRecognitionTextFormat;
  out AHasCategoryColumn: Boolean;
  out AStats: TRecognitionStats; out AError: string): Boolean;
var
  I, ExpectedRecordCount: Integer;
  Messages: TJSONArray;
  RequestJson, Message: TJSONObject;
  RequestBody, ResponseBody, TextContent: string;
begin
  Result := False;
  AFormat := rtfDelimitedTable;
  AHasCategoryColumn := False;
  AError := '';
  ClearRecognitionStats(AStats);
  if ABooks = nil then
  begin
    AError := 'Не передан список для результатов распознавания.';
    Exit;
  end;
  ABooks.Clear;
  if Trim(AModel) = '' then
  begin
    AError := 'Не задана модель OpenRouter.';
    Exit;
  end;
  if Trim(AApiKey) = '' then
  begin
    AError := 'Не задан OpenRouter API Key.';
    Exit;
  end;
  if not LoadRecognitionTextFile(AFileName, TextContent, AError) then
    Exit;
  if not DetectRecognitionTextFormat(TextContent, AFormat,
    ExpectedRecordCount, AHasCategoryColumn, AError) then
    Exit;
  try
    RequestJson := TJSONObject.Create;
    try
      RequestJson.Add('model', Trim(AModel));
      Messages := TJSONArray.Create;
      Message := TJSONObject.Create;
      Message.Add('role', 'user');
      Message.Add('content', TextRecognitionPrompt(TextContent, AFormat,
        ExpectedRecordCount));
      Messages.Add(Message);
      RequestJson.Add('messages', Messages);
      RequestBody := RequestJson.AsJSON;
      if not SendRecognitionRequest(AApiKey, RequestBody, ResponseBody, AError) then
        Exit;
      if not ParseBooksTextResponse(ResponseBody, ABooks, AStats, AError) then
        Exit;
      if not ValidateRecognitionResultCount(AFormat, ExpectedRecordCount,
        ABooks.Count, AError) then
      begin
        ABooks.Clear;
        ClearRecognitionStats(AStats);
        Exit;
      end;
      if Trim(AStats.Models) = '' then
        AStats.Models := Trim(AModel);
      for I := 0 to ABooks.Count - 1 do
        TRecognizedBook(ABooks[I]).SourceFile := AFileName;
      Result := True;
    finally
      RequestJson.Free;
    end;
  except
    on E: Exception do
    begin
      ABooks.Clear;
      ClearRecognitionStats(AStats);
      AError := 'Локальная ошибка при распознавании текста: ' + E.Message;
    end;
  end;
end;

end.
