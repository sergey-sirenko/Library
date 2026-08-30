unit uOpenRouter;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, uEntities;

const
  OPENROUTER_MODELS_URL = 'https://openrouter.ai/api/v1/models';

{ Низкоуровневый HTTP-вызов через WinHTTP (SChannel, без сторонних DLL).
  Используется также модулем uOpenRouterModels. }
function HttpRequest(const AMethod, AUrl, AApiKey, ARequestBody: string;
  out AStatusCode: DWORD; out AResponseBody: string; out AError: string;
  const ATimeoutMs: Cardinal = 0): Boolean;

{ Достаёт error.message из JSON-ответа OpenRouter (если есть). Пустая строка,
  если тело не JSON или поле отсутствует. }
function ExtractOpenRouterErrorMessage(const ABody: string): string;

function TestOpenRouterConnection(const AApiKey, AModel: string; out AError: string;
  out AModelsCount: Integer; out AModelAvailable: Boolean): Boolean;

function RecognizeBookImage(const AFileName, AModel, AApiKey: string;
  out ABook: TRecognizedBook; out AError: string): Boolean;

implementation

uses
  Classes, Windows, WinHttp, fpjson, jsonparser, base64;

const
  OPENROUTER_COMPLETIONS_URL = 'https://openrouter.ai/api/v1/chat/completions';
  HTTP_USER_AGENT = 'LibraryApp/1.1.0';

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
  Host, Path: WideString;
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
    SetLength(Path, 2048);
    UC.lpszHostName := PWideChar(Host);
    UC.dwHostNameLength := Length(Host);
    UC.lpszUrlPath := PWideChar(Path);
    UC.dwUrlPathLength := Length(Path);
    Method := UTF8Decode(AMethod);
    if not WinHttpCrackUrl(PWideChar(UTF8Decode(AUrl)), Length(AUrl), 0, @UC) then
    begin
      ErrCode := GetLastError;
      AError := 'Разбор URL: ' + WinHttpErrorText(ErrCode) + '.';
      Exit;
    end;
    SetLength(Host, UC.dwHostNameLength);
    SetLength(Path, UC.dwUrlPathLength);
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
    'Распознай фотографию библиотечной книги. Определи название книги по тексту ' +
    'на странице и инвентарный номер, написанный или напечатанный на библиотечном ' +
    'штампе. Верни только корректный JSON без Markdown и пояснений в формате ' +
    '{"title":"...","inventoryNumber":"..."}. Если значение не удалось ' +
    'прочитать, верни для него пустую строку.';
end;

function ExtractRecognition(const AResponse: string; out ABook: TRecognizedBook;
  out AError: string): Boolean;
var
  Root, Parsed, UsageData: TJSONData;
  Choices: TJSONArray;
  RootObj, MessageObj, UsageObj: TJSONObject;
  Content: string;
begin
  Result := False;
  ABook := nil;
  AError := '';
  Root := nil;
  Parsed := nil;
  try
    try
      Root := GetJSON(AResponse);
      if not (Root is TJSONObject) then
        raise Exception.Create('Ответ не является JSON-объектом.');
      RootObj := TJSONObject(Root);
      Choices := RootObj.Arrays['choices'];
      if (Choices = nil) or (Choices.Count = 0) or not (Choices[0] is TJSONObject) then
        raise Exception.Create('В ответе отсутствует результат модели.');
      MessageObj := TJSONObject(TJSONObject(Choices[0]).Objects['message']);
      if MessageObj = nil then
        raise Exception.Create('В ответе отсутствует сообщение модели.');
      Content := Trim(MessageObj.Get('content', ''));
      if Content = '' then
        raise Exception.Create('Модель не вернула результат.');
      Parsed := GetJSON(Content);
      if not (Parsed is TJSONObject) then
        raise Exception.Create('Результат модели не является JSON-объектом.');
      ABook := TRecognizedBook.Create;
      ABook.Title := Trim(TJSONObject(Parsed).Get('title', ''));
      ABook.InventoryNo := Trim(TJSONObject(Parsed).Get('inventoryNumber', ''));
      ABook.ModelUsed := Trim(RootObj.Get('model', ''));
      UsageObj := RootObj.Objects['usage'];
      if UsageObj <> nil then
      begin
        ABook.PromptTokens := UsageObj.Get('prompt_tokens', Int64(0));
        ABook.CompletionTokens := UsageObj.Get('completion_tokens', Int64(0));
        ABook.TotalTokens := UsageObj.Get('total_tokens', Int64(0));
        UsageData := UsageObj.Find('cost');
        if (UsageData <> nil) and (UsageData.JSONType <> jtNull) then
          ABook.RecognitionCost := UsageData.AsFloat;
      end;
      if (ABook.Title = '') or (ABook.InventoryNo = '') then
        raise Exception.Create('Модель не смогла определить все обязательные данные.');
      Result := True;
    except
      on E: Exception do
      begin
        FreeAndNil(ABook);
        AError := 'Не удалось распознать данные на изображении.';
      end;
    end;
  finally
    Parsed.Free;
    Root.Free;
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

function RecognizeBookImage(const AFileName, AModel, AApiKey: string;
  out ABook: TRecognizedBook; out AError: string): Boolean;
var
  Messages, Content: TJSONArray;
  RequestJson: TJSONObject;
  Message, TextPart, ImagePart, ImageUrl: TJSONObject;
  MimeType, EncodedImage, RequestBody, ResponseBody: string;
  StatusCode: DWORD;
  ServerMsg: string;
begin
  Result := False;
  ABook := nil;
  AError := '';
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

      try
        try
          if not HttpRequest('POST', OPENROUTER_COMPLETIONS_URL, AApiKey,
            RequestBody, StatusCode, ResponseBody, AError) then
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
                  '). Проверьте правильность ключа.';
            end
            else if ServerMsg <> '' then
              AError := 'OpenRouter: HTTP ' + IntToStr(StatusCode) + '. ' + ServerMsg
            else
              AError := 'OpenRouter: HTTP ' + IntToStr(StatusCode) + ' (ответ без сообщения).';
            Exit;
          end;
          Result := ExtractRecognition(ResponseBody, ABook, AError);
        except
          on E: Exception do
            AError := 'Локальная ошибка при распознавании: ' + E.Message;
        end;
      finally
      end;
    finally
      RequestJson.Free;
    end;
  except
    on E: Exception do
      AError := 'Не удалось подготовить изображение для распознавания.';
  end;
end;

end.
