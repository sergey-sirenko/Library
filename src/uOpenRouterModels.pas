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

implementation

uses
  fpjson, jsonparser, StrUtils, uOpenRouter;

const
  MODELS_REQUEST_TIMEOUT_MS = 15000;

function ParsePricePerMillion(const S: string): Double;
var
  FS: TFormatSettings;
begin
  if Trim(S) = '' then
    Exit(0);
  { JSON всегда использует точку независимо от региональных настроек Windows. }
  FS := DefaultFormatSettings;
  FS.DecimalSeparator := '.';
  if not TryStrToFloat(Trim(S), Result, FS) then
    Exit(0);
  { OpenRouter отдаёт цену за токен; переводим в $/1M для удобства. }
  Result := Result * 1000000.0;
end;

function FetchOpenRouterModels(const AApiKey: string;
  out AModels: TModelInfoArray; out AError: string): Boolean;
var
  StatusCode: DWORD;
  ResponseBody, ServerMsg: string;
  Root, ModelObj, PricingObj, ArchitectureObj: TJSONData;
  ModelsArr, ModalitiesArr: TJSONArray;
  i, j, N: Integer;
begin
  Result := False;
  SetLength(AModels, 0);
  AError := '';
  if Trim(AApiKey) = '' then
  begin
    AError := 'Не задан OpenRouter API Key.';
    Exit;
  end;
  if not HttpRequest('GET', OPENROUTER_MODELS_URL, AApiKey, '',
    StatusCode, ResponseBody, AError, MODELS_REQUEST_TIMEOUT_MS) then
    Exit;
  if (StatusCode < 200) or (StatusCode >= 300) then
  begin
    ServerMsg := ExtractOpenRouterErrorMessage(ResponseBody);
    AError := 'HTTP ' + IntToStr(StatusCode) + '. ' + ServerMsg;
    Exit;
  end;
  try
    Root := GetJSON(ResponseBody);
  except
    on E: Exception do
    begin
      AError := 'Не удалось разобрать ответ: ' + E.Message;
      Exit;
    end;
  end;
  if not (Root is TJSONObject) then
  begin
    AError := 'Ответ не является JSON-объектом.';
    Root.Free;
    Exit;
  end;
  ModelsArr := TJSONObject(Root).Arrays['data'];
  if ModelsArr = nil then
  begin
    AError := 'В ответе отсутствует список моделей.';
    Root.Free;
    Exit;
  end;
  N := ModelsArr.Count;
  SetLength(AModels, N);
  for i := 0 to N - 1 do
  begin
    ModelObj := ModelsArr[i];
    AModels[i].Id := '';
    AModels[i].Name := '';
    AModels[i].PromptPrice := 0;
    AModels[i].CompletionPrice := 0;
    AModels[i].SupportsImage := False;
    if ModelObj is TJSONObject then
    begin
      AModels[i].Id := Trim(TJSONObject(ModelObj).Get('id', ''));
      AModels[i].Name := Trim(TJSONObject(ModelObj).Get('name', ''));
      PricingObj := TJSONObject(ModelObj).Objects['pricing'];
      if (PricingObj <> nil) and (PricingObj is TJSONObject) then
      begin
        AModels[i].PromptPrice := ParsePricePerMillion(
          TJSONObject(PricingObj).Get('prompt', ''));
        AModels[i].CompletionPrice := ParsePricePerMillion(
          TJSONObject(PricingObj).Get('completion', ''));
      end;
      ArchitectureObj := TJSONObject(ModelObj).Objects['architecture'];
      if ArchitectureObj is TJSONObject then
      begin
        ModalitiesArr := TJSONObject(ArchitectureObj).Arrays['input_modalities'];
        if ModalitiesArr <> nil then
          for j := 0 to ModalitiesArr.Count - 1 do
            if SameText(Trim(ModalitiesArr.Items[j].AsString), 'image') then
            begin
              AModels[i].SupportsImage := True;
              Break;
            end;
      end;
    end;
  end;
  Root.Free;
  Result := True;
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
  if P < 0 then
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

end.
