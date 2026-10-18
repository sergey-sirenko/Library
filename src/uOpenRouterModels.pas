unit uOpenRouterModels;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  TModelInfo = record
    Id: string;
    Name: string;
    PromptPrice: Double;     { $ за 1 000 000 входных токенов }
    CompletionPrice: Double; { $ за 1 000 000 выходных токенов }
    SupportsImage: Boolean;  { принимает изображения во входном запросе }
  end;
  TModelInfoArray = array of TModelInfo;

{ Загружает каталог моделей OpenRouter. AModels заполняется даже при HTTP-ошибке —
  в этом случае Result = False и AError содержит причину. }
function FetchOpenRouterModels(const AApiKey: string;
  out AModels: TModelInfoArray; out AError: string): Boolean;

{ Сортирует по PromptPrice по возрастанию; при равенстве — по Id. }
procedure SortModelsByPromptPrice(var A: TModelInfoArray);

{ Форматирует цену для отображения: «бесплатно», «$0.100» или «$12.34». }
function FormatModelPrice(P: Double): string;

{ Провайдер модели (часть Id до «/»), в нижнем регистре, либо пусто. }
function ProviderOf(const AModelId: string): string;

{ True, если модель от «популярного» провайдера (см. POPULAR_PROVIDERS). }
function IsPopularProvider(const AModelId: string): Boolean;

{ Оставляет только платные модели от популярных провайдеров,
  которые принимают изображения. }
procedure FilterPopularPaid(var A: TModelInfoArray);

const
  RECOMMENDED_SEARCH_MODELS: array[0..2] of string = (
    'anthropic/claude-sonnet-5.5', 'anthropic/claude-opus-5.5', 'google/gemini-3.8-flash');

procedure AddRecommendedSearchModels(AIds: TStrings);
function ParseOpenRouterModels(const ABody: string; out AModels: TModelInfoArray;
  out AError: string): Boolean;
function ModelPriceText(const AModelID: string; const AModels: TModelInfoArray): string;
function SaveModelPriceCache(const AFile: string; const AModels: TModelInfoArray;
  AUpdatedAt: TDateTime; out AError: string): Boolean;
function LoadModelPriceCache(const AFile: string; out AModels: TModelInfoArray;
  out AUpdatedAt: TDateTime): Boolean;
procedure LimitModelSelection(var AModels: TModelInfoArray; ALimit: Integer; APinned: TStrings);

implementation

uses
  fpjson, jsonparser, StrUtils, Math, uOpenRouter, uJSONFile;

const
  MODELS_REQUEST_TIMEOUT_MS = 15000;

function ParsePricePerMillion(const S: string): Double;
var
  FS: TFormatSettings;
begin
  if Trim(S) = '' then
    Exit(-1);
  { JSON всегда использует точку независимо от региональных настроек Windows. }
  FS := DefaultFormatSettings;
  FS.DecimalSeparator := '.';
  if not TryStrToFloat(Trim(S), Result, FS) or IsNan(Result) or IsInfinite(Result) then
    Exit(-1);
  { OpenRouter отдаёт цену за токен; переводим в $/1M для удобства. }
  Result := Result * 1000000.0;
end;

function FetchOpenRouterModels(const AApiKey: string;
  out AModels: TModelInfoArray; out AError: string): Boolean;
var
  StatusCode: DWORD;
  ResponseBody, ServerMsg: string;
begin
  Result := False;
  SetLength(AModels, 0);
  AError := '';
  if not HttpRequest('GET', OPENROUTER_MODELS_URL, AApiKey, '',
    StatusCode, ResponseBody, AError, MODELS_REQUEST_TIMEOUT_MS) then
    Exit;
  if (StatusCode < 200) or (StatusCode >= 300) then
  begin
    ServerMsg := ExtractOpenRouterErrorMessage(ResponseBody);
    AError := 'HTTP ' + IntToStr(StatusCode) + '. ' + ServerMsg;
    Exit;
  end;
  Result := ParseOpenRouterModels(ResponseBody, AModels, AError);
end;

function ParseOpenRouterModels(const ABody: string; out AModels: TModelInfoArray;
  out AError: string): Boolean;
var
  Root, Pricing, Architecture: TJSONData;
  Models, Modalities: TJSONArray;
  Item: TJSONObject;
  Parsed: TModelInfoArray;
  I, J, N: Integer;

  function Price(AObject: TJSONData; const AName: string): Double;
  var Value: TJSONData;
  begin
    Result := -1;
    if not (AObject is TJSONObject) then Exit;
    Value := TJSONObject(AObject).Find(AName);
    if (Value <> nil) and (Value.JSONType in [jtString, jtNumber]) then
      Result := ParsePricePerMillion(Value.AsString);
  end;

begin
  Result := False;
  AModels := nil;
  AError := '';
  Root := nil;
  try
    try
      Root := GetJSON(ABody);
      if not (Root is TJSONObject) then raise Exception.Create('root');
      if not TJSONObject(Root).Find('data', Models) then raise Exception.Create('data');
      SetLength(Parsed, Models.Count);
      N := 0;
      for I := 0 to Models.Count - 1 do
      begin
        if not (Models[I] is TJSONObject) then Continue;
        Item := Models.Objects[I];
        Parsed[N].Id := Trim(Item.Get('id', ''));
        if Parsed[N].Id = '' then Continue;
        Parsed[N].Name := Trim(Item.Get('name', ''));
        if not Item.Find('pricing', Pricing) then Pricing := nil;
        Parsed[N].PromptPrice := Price(Pricing, 'prompt');
        Parsed[N].CompletionPrice := Price(Pricing, 'completion');
        Parsed[N].SupportsImage := False;
        if Item.Find('architecture', Architecture) and (Architecture is TJSONObject) then
          if TJSONObject(Architecture).Find('input_modalities', Modalities) then
            for J := 0 to Modalities.Count - 1 do
              if Modalities[J].AsString = 'image' then Parsed[N].SupportsImage := True;
        Inc(N);
      end;
      SetLength(Parsed, N);
      AModels := Parsed;
      Result := True;
    except
      AError := 'Не удалось разобрать каталог моделей OpenRouter.';
    end;
  finally
    Root.Free;
  end;
end;

procedure SortModelsByPromptPrice(var A: TModelInfoArray);
  function ComparablePromptPrice(const AModel: TModelInfo): Double;
  begin
    { Отрицательная цена — служебный sentinel (openrouter/auto и пр.),
      такие модели уезжают в самый конец списка. }
    if AModel.PromptPrice < 0 then
      Result := 1e18
    else
      Result := AModel.PromptPrice;
  end;

  function CompareModels(const ALeft, ARight: TModelInfo): Integer;
  var
    LeftPrice, RightPrice: Double;
  begin
    LeftPrice := ComparablePromptPrice(ALeft);
    RightPrice := ComparablePromptPrice(ARight);
    if LeftPrice < RightPrice then
      Exit(-1);
    if LeftPrice > RightPrice then
      Exit(1);
    if ALeft.Id < ARight.Id then
      Exit(-1);
    if ALeft.Id > ARight.Id then
      Exit(1);
    Result := 0;
  end;

  procedure QuickSort(ALeft, ARight: Integer);
  var
    i, j: Integer;
    Pivot, Tmp: TModelInfo;
  begin
    i := ALeft;
    j := ARight;
    Pivot := A[(ALeft + ARight) div 2];
    repeat
      while CompareModels(A[i], Pivot) < 0 do
        Inc(i);
      while CompareModels(A[j], Pivot) > 0 do
        Dec(j);
      if i <= j then
      begin
        Tmp := A[i];
        A[i] := A[j];
        A[j] := Tmp;
        Inc(i);
        Dec(j);
      end;
    until i > j;
    if ALeft < j then
      QuickSort(ALeft, j);
    if i < ARight then
      QuickSort(i, ARight);
  end;
begin
  if Length(A) > 1 then
    QuickSort(Low(A), High(A));
end;

function FormatModelPrice(P: Double): string;
begin
  if IsNan(P) or IsInfinite(P) or (P < 0) then
    Exit('—');
  if P = 0 then
    Exit('бесплатно');
  if P < 1 then
    Result := Format('$%.3f', [P])
  else if P < 100 then
    Result := Format('$%.2f', [P])
  else
    Result := Format('$%.0f', [P]);
end;

const
  { Список «популярных» провайдеров для диалога выбора модели.
    Сравнение по префиксу Id модели (часть до «/»). Можно расширять. }
  POPULAR_PROVIDERS: array[0..11] of string = (
    'openai', 'anthropic', 'google', 'meta-llama', 'mistralai', 'deepseek',
    'xai', 'qwen', 'cohere', 'nvidia', 'perplexity', 'minimax'
  );

function ProviderOf(const AModelId: string): string;
var
  i: Integer;
begin
  Result := '';
  for i := 1 to Length(AModelId) do
    if AModelId[i] = '/' then
    begin
      Result := Copy(AModelId, 1, i - 1);
      Exit;
    end;
end;

function IsPopularProvider(const AModelId: string): Boolean;
var
  Prov: string;
  i: Integer;
begin
  Prov := LowerCase(ProviderOf(AModelId));
  for i := Low(POPULAR_PROVIDERS) to High(POPULAR_PROVIDERS) do
    if Prov = POPULAR_PROVIDERS[i] then
      Exit(True);
  Result := False;
end;

{ Оставляет только модели с PromptPrice > 0 от популярных провайдеров,
  поддерживающие изображения во входном запросе. Batch-модели исключаются. }
procedure FilterPopularPaid(var A: TModelInfoArray);
var
  i, j: Integer;
begin
  j := 0;
  for i := 0 to High(A) do
    if (A[i].PromptPrice > 0) and A[i].SupportsImage and
      not EndsText(':batch', A[i].Id) and
      IsPopularProvider(A[i].Id) then
    begin
      if j <> i then
        A[j] := A[i];
      Inc(j);
    end;
  SetLength(A, j);
end;

procedure AddRecommendedSearchModels(AIds: TStrings);
var ID: string;
begin
  for ID in RECOMMENDED_SEARCH_MODELS do
    if AIds.IndexOf(ID) < 0 then AIds.Add(ID);
end;

function ModelPriceText(const AModelID: string; const AModels: TModelInfoArray): string;
var I: Integer;
begin
  for I := 0 to High(AModels) do
    if AModels[I].Id = Trim(AModelID) then
      Exit('Вход: ' + FormatModelPrice(AModels[I].PromptPrice) +
        ' / выход: ' + FormatModelPrice(AModels[I].CompletionPrice) + ' за 1 млн токенов');
  Result := 'Цена неизвестна';
end;

function SaveModelPriceCache(const AFile: string; const AModels: TModelInfoArray;
  AUpdatedAt: TDateTime; out AError: string): Boolean;
var Root, Item: TJSONObject; Items: TJSONArray; M: TModelInfo;
begin
  Root := TJSONObject.Create;
  try
    Root.Add('version', 1);
    Root.Add('updated_at', Double(AUpdatedAt));
    Items := TJSONArray.Create;
    Root.Add('models', Items);
    for M in AModels do
    begin
      Item := TJSONObject.Create;
      Items.Add(Item);
      Item.Add('id', M.Id);
      Item.Add('name', M.Name);
      Item.Add('input', M.PromptPrice);
      Item.Add('output', M.CompletionPrice);
      Item.Add('image', M.SupportsImage);
    end;
    Result := WriteJSONFile(AFile, Root, AError);
  finally
    Root.Free;
  end;
end;

function LoadModelPriceCache(const AFile: string; out AModels: TModelInfoArray;
  out AUpdatedAt: TDateTime): Boolean;
var Root: TJSONData; Items: TJSONArray; Parsed: TModelInfoArray;
  I: Integer; Stamp: Double;
begin
  Result := False;
  AModels := nil;
  AUpdatedAt := 0;
  Root := nil;
  if not FileExists(AFile) then Exit;
  try
    try
      Root := ReadJSONFile(AFile);
      if not (Root is TJSONObject) then Exit;
      if TJSONObject(Root).Get('version', 0) <> 1 then Exit;
      Stamp := TJSONObject(Root).Get('updated_at', 0.0);
      if IsNan(Stamp) or IsInfinite(Stamp) or ((Stamp <= 0) or (Stamp > 2958465)) then Exit;
      if not TJSONObject(Root).Find('models', Items) then Exit;
      SetLength(Parsed, Items.Count);
      for I := 0 to Items.Count - 1 do
      begin
        Parsed[I].Id := Items.Objects[I].Get('id', '');
        if Parsed[I].Id = '' then Exit;
        Parsed[I].Name := Items.Objects[I].Get('name', '');
        Parsed[I].PromptPrice := Items.Objects[I].Get('input', -1.0);
        Parsed[I].CompletionPrice := Items.Objects[I].Get('output', -1.0);
        if IsNan(Parsed[I].PromptPrice) or IsInfinite(Parsed[I].PromptPrice) or
          IsNan(Parsed[I].CompletionPrice) or IsInfinite(Parsed[I].CompletionPrice) then Exit;
        Parsed[I].SupportsImage := Items.Objects[I].Get('image', False);
      end;
      AModels := Parsed;
      AUpdatedAt := Stamp;
      Result := True;
    except
      Result := False;
    end;
  finally
    Root.Free;
  end;
end;

procedure LimitModelSelection(var AModels: TModelInfoArray; ALimit: Integer; APinned: TStrings);
var Selected: TModelInfoArray; I, N: Integer;
begin
  SetLength(Selected, Length(AModels));
  N := 0;
  for I := 0 to High(AModels) do
    if APinned.IndexOf(AModels[I].Id) >= 0 then
    begin
      Selected[N] := AModels[I];
      Inc(N);
    end;
  // Все закреплённые модели сохраняются даже при превышении лимита.
  for I := 0 to High(AModels) do
    if (N < ALimit) and (APinned.IndexOf(AModels[I].Id) < 0) then
    begin
      Selected[N] := AModels[I];
      Inc(N);
    end;
  SetLength(Selected, N);
  AModels := Selected;
  SortModelsByPromptPrice(AModels);
end;

end.
