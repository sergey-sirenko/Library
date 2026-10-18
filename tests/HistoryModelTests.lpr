program HistoryModelTests;

{$mode objfpc}{$H+}

uses Classes, SysUtils, FileUtil, fpjson, uTypes, uDatabase, uEntities,
  uBookSearch, uBookSearchHistory, uOpenRouterModels, uJSONFile;

var Checks, Failures: Integer;

procedure Check(AValue: Boolean; const AMessage: string);
begin
  Inc(Checks);
  if AValue then WriteLn('[OK] ', AMessage)
  else
  begin
    Inc(Failures);
    WriteLn('[FAIL] ', AMessage);
  end;
end;

procedure Equal(const AExpected, AActual, AMessage: string);
begin
  Check(AExpected = AActual, AMessage);
end;

function ReadText(const AFile: string): string;
var Lines: TStringList;
begin
  Lines := TStringList.Create;
  try
    Lines.LoadFromFile(AFile);
    Result := Lines.Text;
  finally
    Lines.Free;
  end;
end;

procedure WriteText(const AFile, AText: string);
var Stream: TStringStream;
begin
  Stream := TStringStream.Create(AText);
  try Stream.SaveToFile(AFile); finally Stream.Free; end;
end;

procedure TestPrices(const ARoot: string);
var Models, Loaded: TModelInfoArray; IDs, Pinned: TStringList;
  Err, FileName, Selected: string; Stamp, CachedAt: TDateTime; I: Integer;
begin
  Check(ParseOpenRouterModels('{"data":[' +
    '{"id":"anthropic/claude-sonnet-5.5","name":"Sonnet","pricing":{"prompt":"0.000002","completion":"0.000010"},' +
    '"architecture":{"input_modalities":["text","image"]}},' +
    '{"id":"unknown/model","pricing":{"prompt":"invalid"}},' +
    '{"id":"free/model","pricing":{"prompt":"0","completion":"0"}}]}', Models, Err),
    'каталог цен разбирается на искусственном ответе');
  Check((Length(Models) = 3) and (Models[0].PromptPrice = 2) and
    (Abs(Models[0].CompletionPrice - 10) < 0.00001), 'цены пересчитываются за миллион токенов');
  Check(Models[0].SupportsImage, 'возможность обработки изображений сохранена');
  Check((Models[1].PromptPrice < 0) and (Models[1].CompletionPrice < 0),
    'неизвестная и некорректная цена не объявляется бесплатной');
  Check(Pos('бесплатно', ModelPriceText('unknown/model', Models)) = 0,
    'неизвестная цена обозначается отдельно');
  Check(Pos('бесплатно', ModelPriceText('free/model', Models)) > 0,
    'явная нулевая цена обозначается бесплатной');
  Equal('Цена неизвестна', ModelPriceText('outside/model', Models), 'нет цены для отсутствующей модели');
  IDs := TStringList.Create;
  Pinned := TStringList.Create;
  try
    IDs.Add('existing/favorite');
    Selected := IDs[0];
    AddRecommendedSearchModels(IDs);
    AddRecommendedSearchModels(IDs);
    Check((IDs.Count = 4) and (IDs[0] = Selected), 'рекомендации не дублируются и сохраняют прежнее избранное');
    for I := 0 to High(RECOMMENDED_SEARCH_MODELS) do
      Check(IDs.IndexOf(RECOMMENDED_SEARCH_MODELS[I]) >= 0, 'модель присутствует: ' + RECOMMENDED_SEARCH_MODELS[I]);
    ModelPriceText(IDs[1], Models);
    Equal(RECOMMENDED_SEARCH_MODELS[0], IDs[1], 'отображение цены не меняет ID для API');
    SetLength(Loaded, 3);
    for I := 0 to 2 do
    begin
      Loaded[I].Id := 'test/model-' + IntToStr(I);
      Loaded[I].PromptPrice := I;
    end;
    Pinned.Add('test/model-2');
    LimitModelSelection(Loaded, 1, Pinned);
    Check((Length(Loaded) = 1) and (Loaded[0].Id = 'test/model-2'),
      'дорогая закреплённая модель не теряется из-за лимита списка');
  finally
    Pinned.Free;
    IDs.Free;
  end;
  FileName := ARoot + 'prices.json';
  Stamp := EncodeDate(2026, 10, 18) + EncodeTime(10, 20, 30, 0);
  Check(SaveModelPriceCache(FileName, Models, Stamp, Err), 'кэш цен сохраняется: ' + Err);
  Check(LoadModelPriceCache(FileName, Loaded, CachedAt), 'цены доступны из кэша без сети');
  Check((Length(Loaded) = 3) and (Abs(CachedAt - Stamp) < 0.000001), 'дата обновления кэша сохраняется');
  Check((Loaded[0].PromptPrice = 2) and (Loaded[1].PromptPrice < 0), 'кэш сохраняет известные и неизвестные цены');
  WriteText(FileName, '{"version":99}');
  Check(not LoadModelPriceCache(FileName, Loaded, CachedAt) and (Length(Loaded) = 0),
    'неподдерживаемый кэш не используется как актуальный');
  Check(not ParseOpenRouterModels('{bad', Loaded, Err) and (Length(Loaded) = 0),
    'повреждённый каталог цен отклоняется');
  Check(not ParseOpenRouterModels('{"data":{}}', Loaded, Err), 'неверная структура каталога отклоняется');
end;

procedure TestHistory(const ARoot: string);
var DB: TLibraryDB; B, Other: TBook; Candidates: TList; Snapshot: TBookSearchSnapshot;
  History, Reloaded, SecondUser, Blocked: TBookSearchHistory;
  Response, Restored: TBookSearchResponse; Err, Fingerprint, Original: string;
  Stale: Boolean; Unavailable, I: Integer; Root: TJSONData;
begin
  DB := TLibraryDB.Create(ARoot + 'unused-db');
  Candidates := TList.Create;
  History := TBookSearchHistory.Create(ARoot, 1);
  Reloaded := nil;
  SecondUser := TBookSearchHistory.Create(ARoot, 2);
  Blocked := nil;
  try
    B := TBook.Create;
    B.ID := 9000000000;
    B.Title := 'Книга «Свет»';
    B.Description := 'Глава 2, с. 42';
    DB.Books.Add(B);
    Other := TBook.Create;
    Other.ID := 2;
    Other.Title := 'Другая';
    DB.Books.Add(Other);
    DB.Settings.OpenRouterApiKey := 'PRIVATE_KEY_MARKER';
    Check(History.Load(Err) and (History.Count = 0), 'отсутствующая история открывается пустой');
    Fingerprint := CurrentBookSearchFingerprint(DB, '', '', False);
    Candidates.Add(Other);
    Candidates.Add(B);
    Snapshot := TBookSearchSnapshot.Create(DB, Candidates, 'Запрос');
    try Equal(Fingerprint, Snapshot.Fingerprint, 'отпечаток не зависит от порядка списка и времени снимка');
    finally Snapshot.Free; end;
    Response.Status := 'ok';
    Response.Message := '';
    SetLength(Response.Matches, 2);
    Response.Matches[0].BookID := Other.ID;
    Response.Matches[0].Relevance := 'high';
    Response.Matches[0].Reason := 'Предположение по названию';
    Response.Matches[0].Location := 'место не установлено';
    Response.Matches[1].BookID := B.ID;
    Response.Matches[1].Relevance := 'medium';
    Response.Matches[1].Reason := 'Кириллица "кавычки"' + #13#10 + 'новая строка';
    Response.Matches[1].Location := B.Description;
    Check(History.Add('Вопрос "свет"', '', '', RECOMMENDED_SEARCH_MODELS[0], Fingerprint,
      False, Response, Err), 'успешный поиск сохраняется: ' + Err);
    Check(History.Add('Вопрос "свет"', '', '', RECOMMENDED_SEARCH_MODELS[2], Fingerprint,
      False, Response, Err), 'результат другой модели сохраняется отдельно');
    Check((History.Count = 2) and (History[0].Model = RECOMMENDED_SEARCH_MODELS[2]), 'новые записи показаны первыми');
    Reloaded := TBookSearchHistory.Create(ARoot, 1);
    Check(Reloaded.Load(Err) and (Reloaded.Count = 2), 'история восстанавливается после нового запуска');
    Equal(History[0].Query, Reloaded[0].Query, 'запрос с кавычками сохранён');
    Equal(Response.Matches[1].Reason, Reloaded[0].Response.Matches[1].Reason,
      'обоснование с кириллицей и переносами сохранено');
    Check(Reloaded[0].Response.Matches[1].BookID = B.ID, 'Int64 ID книги сохраняется без округления');
    Check(Reloaded[0].CreatedAt > 0, 'время поиска сохраняется');
    Check(Pos(RECOMMENDED_SEARCH_MODELS[2], Reloaded[0].Details) > 0, 'история показывает модель и дату');
    Restored := Reloaded[0].Restore(DB, Stale, Unavailable);
    Check(not Stale and (Unavailable = 0) and (Length(Restored.Matches) = 2),
      'неизменённый каталог восстанавливает результаты без сети');
    Check((Restored.Matches[0].BookID = Other.ID) and (Restored.Matches[1].BookID = B.ID),
      'порядок модели сохранён');
    B.Description := 'Описание изменено';
    Restored := Reloaded[0].Restore(DB, Stale, Unavailable);
    Check(Stale and (Pos('требуют проверки', Restored.Matches[1].Location) > 0),
      'изменение описания помечает старое указание места');
    Other.Deleted := True;
    Restored := Reloaded[0].Restore(DB, Stale, Unavailable);
    Check(Stale and (Unavailable = 1) and (Length(Restored.Matches) = 1),
      'недоступные книги не подставляются в текущую таблицу');
    Check(Restored.Matches[0].Rank = 2, 'исходный ранг сохраняется после пропуска недоступной книги');
    Check(Length(Reloaded[0].Response.Matches) = 2, 'недоступная книга остаётся в исходной истории');
    Check(SecondUser.Load(Err) and (SecondUser.Count = 0), 'другой пользователь имеет отдельную историю');
    Response.Matches := nil;
    Check(SecondUser.Add('Другой вопрос', 'автор', '0001', RECOMMENDED_SEARCH_MODELS[1],
      Fingerprint, True, Response, Err), 'пустой успешный результат и фильтры сохраняются');
    Check(SecondUser.Load(Err) and (SecondUser[0].TitleQuery = 'автор') and
      (SecondUser[0].InventoryQuery = '0001') and SecondUser[0].IncludeDeleted,
      'обычные фильтры и режим удалённых восстанавливаются');
    Check(Length(SecondUser[0].Response.Matches) = 0, 'нулевой результат сохраняется явно');
    Check(Pos('PRIVATE_KEY_MARKER', ReadText(History.FileName)) = 0, 'ключ доступа не сохраняется в истории');
    Response.Status := 'clarification';
    Check(not History.Add('Вопрос', '', '', 'test/model', Fingerprint, False, Response, Err) and
      (History.Count = 2), 'неуспешный ответ не сохраняется');
    Response.Status := 'ok';
    WriteText(ARoot + 'blocked', 'file');
    Blocked := TBookSearchHistory.Create(ARoot + 'blocked' + PathDelim, 1);
    Check(not Blocked.Add('Вопрос', '', '', 'test/model', Fingerprint, False, Response, Err) and
      (Blocked.Count = 0), 'ошибка записи не оставляет несохранённую запись в списке');
    Original := '{corrupt PRIVATE_CONTENT_MARKER';
    WriteText(History.FileName, Original);
    Check(not History.Load(Err) and not History.Writable, 'повреждённая история блокирует перезапись');
    Check(Pos('PRIVATE_CONTENT_MARKER', Err) = 0, 'ошибка чтения не раскрывает содержимое истории');
    Check(not History.Add('Новый вопрос', '', '', 'test/model', Fingerprint, False, Response, Err),
      'новый ответ не затирает повреждённый файл');
    Check(Pos(Original, ReadText(History.FileName)) = 1, 'повреждённый исходный файл сохранён');
    Check(History.Clear(Err) and (History.Count = 0), 'явная очистка восстанавливает пустую историю');
    Check(Reloaded.Load(Err) and (Reloaded.Count = 0), 'очистка сохраняется между запусками');
    Check(SecondUser.Load(Err) and (SecondUser.Count = 1), 'очистка не затрагивает другого пользователя');
    for I := 1 to 105 do
      if not History.Add('Тест ' + IntToStr(I), '', '', 'test/model', Fingerprint,
        False, Response, Err) then raise Exception.Create(Err);
    Check(History.Load(Err) and (History.Count = 105), 'история не удаляется по скрытому лимиту');
    Root := ReadJSONFile(History.FileName);
    try
      TJSONObject(Root).Integers['version'] := 99;
      Check(WriteJSONFile(History.FileName, Root, Err), 'тестовый неподдерживаемый формат записан');
    finally Root.Free; end;
    Check(not History.Load(Err), 'неподдерживаемая версия истории не перезаписывается');
    Check(History.Clear(Err), 'неподдерживаемый формат очищается только явно');
    WriteText(History.FileName, ReadText(SecondUser.FileName));
    Check(not History.Load(Err), 'файл чужого пользователя не принимается за свою историю');
  finally
    Blocked.Free;
    SecondUser.Free;
    Reloaded.Free;
    History.Free;
    Candidates.Free;
    DB.Free;
  end;
end;

procedure TestLiveModels;
var Models: TModelInfoArray; Err, ID: string; I: Integer; Found: Boolean;
begin
  if not FetchOpenRouterModels('', Models, Err) then raise Exception.Create(Err);
  Check(Length(Models) > 0, 'публичный каталог OpenRouter доступен без ключа');
  for ID in RECOMMENDED_SEARCH_MODELS do
  begin
    Found := False;
    for I := 0 to High(Models) do
      if Models[I].Id = ID then
        Found := (Models[I].PromptPrice >= 0) and (Models[I].CompletionPrice >= 0);
    Check(Found, 'в публичном каталоге есть модель и цены: ' + ID);
  end;
end;

var Root: string;
begin
  SetMultiByteConversionCodePage(CP_UTF8);
  Root := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'LibraryHistoryModelTests-' + IntToStr(GetTickCount64) + PathDelim;
  ForceDirectories(Root);
  try
    try
      TestPrices(Root);
      TestHistory(Root);
      if (ParamCount > 0) and (ParamStr(1) = '--live-models') then TestLiveModels;
    except
      on E: Exception do
      begin Inc(Failures); WriteLn('[FAIL] ', E.Message); end;
    end;
  finally
    if Pos(IncludeTrailingPathDelimiter(GetTempDir(False)) + 'LibraryHistoryModelTests-',
      ExpandFileName(Root)) = 1 then DeleteDirectory(Root, False);
  end;
  WriteLn('Проверок: ', Checks, '. Ошибок: ', Failures);
  if Failures <> 0 then Halt(1);
end.
