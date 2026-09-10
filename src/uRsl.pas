unit uRsl;

{$mode objfpc}{$H+}

interface

uses Classes, SysUtils, uOpenLibrary, uBookHttp;

function ParseRslRecord(const AHTML, AISBN, AURL: string;
  out AData: TOpenLibraryBookData; out AError: string): Boolean;
function LookupRsl(const AISBN: string; ASession: TBookHttpSession;
  out AItems: TBookCandidates; out AError: string): Boolean;

implementation

uses RegExpr, fpjson, jsonparser, uBookText;

function SubField(const S, Code: string): string;
begin
  Result := HTMLText(MatchHTML('\$' + Code + '</strong>(.*?)(?:<br\s*/?>|$)', S));
end;

function HasISBN(const S, ISBN: string): Boolean;
var R: TRegExpr; Text: string; BeforePos, AfterPos: Integer;
begin
  Result := False;
  R := TRegExpr.Create;
  try
    R.Expression := '(?:97[89][ -]?)?(?:[0-9][ -]?){9}[0-9Xx]';
    Text := HTMLText(S);
    if R.Exec(Text) then repeat
      BeforePos := R.MatchPos[0] - 1;
      AfterPos := R.MatchPos[0] + R.MatchLen[0];
      if ((BeforePos = 0) or not (Text[BeforePos] in ['0'..'9', 'X', 'x'])) and
        ((AfterPos > Length(Text)) or not (Text[AfterPos] in ['0'..'9', 'X', 'x'])) and
        EquivalentISBN(R.Match[0], ISBN) then Exit(True);
    until not R.ExecNext;
  finally
    R.Free;
  end;
end;

function ParseRslRecord(const AHTML, AISBN, AURL: string;
  out AData: TOpenLibraryBookData; out AError: string): Boolean;
var
  Block, Tag, Cell, Value, Publication, YearText, W, Responsibility: string;
  Rows: TRegExpr;
  Matched, IsMarc: Boolean;
begin
  Result := False;
  AError := '';
  ClearOpenLibraryBookData(AData);
  AData.TextIsPlain := True;
  AData.Source := olsRsl;
  AData.Origin := olsRsl;
  AData.SourceURL := AURL;
  Block := MatchHTML('<div\b[^>]*\bid=["'']marc-rec["''][^>]*>(.*?)</div>', AHTML);
  IsMarc := Block <> '';
  if not IsMarc then
    Block := MatchHTML('<table\b[^>]*class=["''][^"'']*card-descr-table[^"'']*["''][^>]*>(.*?)</table>', AHTML);
  if Block = '' then
  begin
    AError := 'РГБ: не распознана структура карточки.';
    Exit;
  end;
  Matched := False;
  YearText := '';
  Responsibility := '';
  Rows := TRegExpr.Create;
  try
    Rows.Expression := '(?is)<tr\b[^>]*>\s*<t[dh]\b[^>]*>(.*?)</t[dh]>\s*<td\b[^>]*>(.*?)</td>\s*</tr>';
    if Rows.Exec(Block) then repeat
      Tag := HTMLText(Rows.Match[1]);
      Cell := Rows.Match[2];
      if IsMarc then
      begin
        Value := SubField(Cell, 'a');
        case Tag of
          '020': Matched := Matched or HasISBN(Value, AISBN);
          '245':
          begin
            AData.Title := Value;
            Value := SubField(Cell, 'b');
            if Value <> '' then
            begin
              if (AData.Title <> '') and (AData.Title[Length(AData.Title)] <> ':') then
                AData.Title := AData.Title + ':';
              AData.Title := AData.Title + ' ' + Value;
            end;
            Responsibility := SubField(Cell, 'c');
          end;
          '100', '110', '111', '700', '710', '711':
            if Value <> '' then
            begin
              if SubField(Cell, 'e') <> '' then
                Value := Value + ' (' + SubField(Cell, 'e') + ')';
              if AData.Authors <> '' then AData.Authors := AData.Authors + '; ';
              AData.Authors := AData.Authors + Value;
            end;
          '260', '264':
          begin
            { 264 с индикатором 4 — копирайт, не издатель. }
            if (Tag = '260') or (Copy(HTMLText(Cell), 2, 1) = '1') then
            begin
              AData.Publisher := SubField(Cell, 'b');
              if YearText <> '' then YearText := YearText + '; ';
              YearText := YearText + SubField(Cell, 'c');
            end;
          end;
          '041': AData.Language := Value;
          '520':
          begin
            if AData.Description <> '' then AData.Description := AData.Description + ' ';
            AData.Description := AData.Description + Value;
          end;
          '650': if AData.CategoryName = '' then AData.CategoryName := Value;
        end;
      end
      else
      begin
        Value := HTMLText(Cell);
        case Tag of
          'ISBN': Matched := Matched or HasISBN(Value, AISBN);
          'Заглавие': AData.Title := Value;
          'Автор', 'Авторы': AData.Authors := Value;
          'Сведения об ответственности': Responsibility := Value;
          'Язык': AData.Language := Value;
          'Аннотация': AData.Description := Value;
          'Тема': if AData.CategoryName = '' then AData.CategoryName := Value;
          'Выходные данные':
          begin
            { Только структурированное поле: место : издательство, год. }
            Publication := MatchHTML('^[^:]+:\s*(.*),\s*([^,]+)$', Value);
            YearText := MatchHTML('^[^:]+:\s*(.*),\s*([^,]+)$', Value, 2);
            AData.Publisher := Publication;
            if (Publication = '') and (Value <> '') then
              AddBookWarning(AData.Warnings, 'Выходные данные требуют ручной проверки.');
          end;
        end;
      end;
    until not Rows.ExecNext;
  finally
    Rows.Free;
  end;
  if not Matched then
  begin
    AError := 'РГБ: ISBN записи не совпадает с запросом.';
    Exit;
  end;
  if AData.Authors = '' then AData.Authors := Responsibility;
  NormalizeISBN(AISBN, AData.NormalizedISBN, AError);
  AData.Year := CheckedYear(YearText, W);
  AddBookWarning(AData.Warnings, W);
  Result := ValidateBookData(AISBN, AData, AError);
end;

function LookupRsl(const AISBN: string; ASession: TBookHttpSession;
  out AItems: TBookCandidates; out AError: string): Boolean;
var
  Owned: Boolean;
  HTML, Token, Body, Response, Content, URL, Err: string;
  Status: Cardinal;
  Root: TJSONData;
  Obj: TJSONObject;
  Links: TStringList;
  R: TRegExpr;
  I, Page, MaxPage, Hits, N: Integer;
  Data: TOpenLibraryBookData;
  Deadline: QWord;
  function Fetch(const Method, Address, Payload: string; out Text: string): Boolean;
  begin
    if GetTickCount64 >= Deadline then
    begin
      AError := 'РГБ: истекло время ожидания источника.';
      Exit(False);
    end;
    Result := ASession.Request(Method, Address, Payload, Status, Text, AError);
    if Result and ((Status < 200) or (Status >= 300)) then
    begin
      Result := False;
      AError := 'РГБ вернула HTTP ' + IntToStr(Status) + '.';
    end;
  end;
begin
  Result := False;
  AItems := nil;
  AError := '';
  Deadline := GetTickCount64 + 15000;
  Owned := ASession = nil;
  if Owned then ASession := TBookHttpSession.Create;
  Links := TStringList.Create;
  R := TRegExpr.Create;
  try
    try
      if not Fetch('GET', 'https://search.rsl.ru/ru/search', '', HTML) then Exit;
      Token := DecodeEntities(MatchHTML('<meta\b[^>]*name=["'']csrf-token["''][^>]*content=["'']([^"'']+)', HTML));
      if Token = '' then raise Exception.Create('РГБ: не найден токен поисковой формы.');
      Page := 1;
      MaxPage := 1;
      repeat
        Body := '_csrf=' + FormEncode(Token) + '&SearchFilterForm[search]=' +
          FormEncode('isbn:' + AISBN) + '&SearchFilterForm[page]=' + IntToStr(Page) +
          '&SearchFilterForm[updatedFields][]=search';
        if not Fetch('POST', 'https://search.rsl.ru/site/ajax-search?language=ru', Body, Response) then Exit;
        Root := GetJSON(Response);
        try
          if not (Root is TJSONObject) then raise Exception.Create('РГБ: ожидался JSON-объект.');
          Obj := TJSONObject(Root);
          if (Obj.Find('TotalHits') = nil) or (Obj.Find('content') = nil) then
            raise Exception.Create('РГБ: изменился формат поисковой выдачи.');
          Hits := Obj.Get('TotalHits', -1);
          if (Hits < 0) or (Hits > 100) then
            raise Exception.Create('РГБ: слишком широкая или некорректная выдача; уточните ISBN.');
          if Hits = 0 then Exit(True);
          MaxPage := Obj.Get('MaxPage', 1);
          if (MaxPage < 1) or (MaxPage > 10) then
            raise Exception.Create('РГБ: превышено число страниц выдачи.');
          Content := Obj.Get('content', '');
          R.Expression := '(?is)href=["''](/ru/record/[0-9]+)["'']';
          N := Links.Count;
          if R.Exec(Content) then repeat
            URL := 'https://search.rsl.ru' + R.Match[1];
            if Links.IndexOf(URL) < 0 then Links.Add(URL);
          until not R.ExecNext;
          if Links.Count = N then raise Exception.Create('РГБ: в выдаче нет ссылок на новые записи.');
        finally
          Root.Free;
        end;
        Inc(Page);
      until Page > MaxPage;
      for I := 0 to Links.Count - 1 do
      begin
        if not Fetch('GET', Links[I], '', HTML) then Exit;
        if ParseRslRecord(HTML, AISBN, Links[I], Data, Err) then
        begin
          SetLength(AItems, Length(AItems) + 1);
          AItems[High(AItems)] := Data;
        end
        else AddBookWarning(AError, Err);
      end;
      Result := Length(AItems) > 0;
      if Result then
        for I := 0 to High(AItems) do AddBookWarning(AItems[I].Warnings, AError);
    except
      on E: Exception do AError := 'Источник РГБ недоступен: ' + E.Message;
    end;
  finally
    R.Free;
    Links.Free;
    if Owned then ASession.Free;
  end;
end;

end.
