unit uBookSearchHistory;

{$mode objfpc}{$H+}

interface

uses Classes, SysUtils, Contnrs, uTypes, uDatabase, uBookSearch;

type
  TBookSearchHistoryEntry = class
    Query, TitleQuery, InventoryQuery, Model, Fingerprint: string;
    IncludeDeleted: Boolean;
    CreatedAt: TDateTime;
    Response: TBookSearchResponse;
    function Caption: string;
    function Details: string;
    function Restore(ADB: TLibraryDB; out AStale: Boolean;
      out AUnavailable: Integer): TBookSearchResponse;
  end;

  TBookSearchHistory = class
  private
    FFileName: string;
    FUserID: TId;
    FEntries: TObjectList;
    FWritable: Boolean;
    function Save(out AError: string): Boolean;
    function GetCount: Integer;
    function GetEntry(AIndex: Integer): TBookSearchHistoryEntry;
  public
    constructor Create(const ADataDir: string; AUserID: TId);
    destructor Destroy; override;
    function Load(out AError: string): Boolean;
    function Add(const AQuery, ATitle, AInventory, AModel, AFingerprint: string;
      AIncludeDeleted: Boolean; const AResponse: TBookSearchResponse;
      out AError: string): Boolean;
    function Clear(out AError: string): Boolean;
    property Count: Integer read GetCount;
    property Entries[AIndex: Integer]: TBookSearchHistoryEntry read GetEntry; default;
    property Writable: Boolean read FWritable;
    property FileName: string read FFileName;
  end;

implementation

uses fpjson, uJSONFile, Math;

function ReadText(AObject: TJSONObject; const AName: string): string;
var D: TJSONData;
begin
  D := AObject.Find(AName);
  if (D = nil) or (D.JSONType <> jtString) then raise Exception.Create('field');
  Result := D.AsString;
end;

function TBookSearchHistoryEntry.Caption: string;
begin
  Result := StringReplace(StringReplace(Query, #13, ' ', [rfReplaceAll]), #10, ' ', [rfReplaceAll]);
end;

function TBookSearchHistoryEntry.Details: string;
begin
  Result := Model + ' — ' + FormatDateTime('dd.mm.yyyy hh:nn:ss', CreatedAt) +
    ' — книг: ' + IntToStr(Length(Response.Matches));
end;

function TBookSearchHistoryEntry.Restore(ADB: TLibraryDB; out AStale: Boolean;
  out AUnavailable: Integer): TBookSearchResponse;
var I, N: Integer;
begin
  AStale := CurrentBookSearchFingerprint(ADB, TitleQuery, InventoryQuery, IncludeDeleted) <> Fingerprint;
  AUnavailable := 0;
  Result.Status := 'ok';
  Result.Message := '';
  SetLength(Result.Matches, Length(Response.Matches));
  N := 0;
  for I := 0 to High(Response.Matches) do
  begin
    if (ADB.FindBook(Response.Matches[I].BookID) = nil) or
      (ADB.FindBook(Response.Matches[I].BookID).Deleted and not IncludeDeleted) then
    begin
      Inc(AUnavailable);
      Continue;
    end;
    Result.Matches[N] := Response.Matches[I];
    Result.Matches[N].Rank := I + 1;
    if AStale then
      Result.Matches[N].Location := 'Сохранённые сведения, требуют проверки: ' +
        Result.Matches[N].Location;
    Inc(N);
  end;
  SetLength(Result.Matches, N);
end;

constructor TBookSearchHistory.Create(const ADataDir: string; AUserID: TId);
begin
  inherited Create;
  if AUserID <= 0 then raise Exception.Create('Не определён пользователь истории поиска.');
  FFileName := IncludeTrailingPathDelimiter(ADataDir) + 'BookSearchHistory-' + IntToStr(AUserID) + '.json';
  FUserID := AUserID;
  FEntries := TObjectList.Create(True);
  FWritable := True;
end;

destructor TBookSearchHistory.Destroy;
begin
  FEntries.Free;
  inherited Destroy;
end;

function TBookSearchHistory.GetCount: Integer;
begin
  Result := FEntries.Count;
end;

function TBookSearchHistory.GetEntry(AIndex: Integer): TBookSearchHistoryEntry;
begin
  Result := TBookSearchHistoryEntry(FEntries[AIndex]);
end;

function TBookSearchHistory.Load(out AError: string): Boolean;
var Root: TJSONData; Items, Matches: TJSONArray; Item, Match: TJSONObject;
  Parsed: TObjectList; Entry: TBookSearchHistoryEntry; Value: TJSONData;
  I, J, K: Integer;
begin
  Result := False;
  AError := '';
  FWritable := False;
  Root := nil;
  Parsed := TObjectList.Create(True);
  try
    try
      if FileExists(FFileName) then
      begin
        Root := ReadJSONFile(FFileName);
        if not (Root is TJSONObject) then raise Exception.Create('root');
        if (TJSONObject(Root).Get('version', 0) <> 1) or
          (TJSONObject(Root).Get('user_id', Int64(0)) <> FUserID) then raise Exception.Create('version');
        if not TJSONObject(Root).Find('entries', Items) then raise Exception.Create('entries');
        for I := 0 to Items.Count - 1 do
        begin
          Item := Items.Objects[I];
          Entry := TBookSearchHistoryEntry.Create;
          Parsed.Add(Entry);
          Entry.Query := ReadText(Item, 'query');
          Entry.Model := ReadText(Item, 'model');
          Entry.Fingerprint := ReadText(Item, 'fingerprint');
          Entry.TitleQuery := ReadText(Item, 'title_query');
          Entry.InventoryQuery := ReadText(Item, 'inventory_query');
          Entry.CreatedAt := Item.Get('created_at', 0.0);
          Value := Item.Find('include_deleted');
          if (Value = nil) or (Value.JSONType <> jtBoolean) then raise Exception.Create('boolean');
          Entry.IncludeDeleted := Value.AsBoolean;
          if (Trim(Entry.Query) = '') or (Trim(Entry.Model) = '') or (Entry.Fingerprint = '') or
            IsNan(Entry.CreatedAt) or IsInfinite(Entry.CreatedAt) or ((Entry.CreatedAt <= 0) or (Entry.CreatedAt > 2958465)) then
            raise Exception.Create('metadata');
          if not Item.Find('results', Matches) then raise Exception.Create('results');
          Entry.Response.Status := 'ok';
          SetLength(Entry.Response.Matches, Matches.Count);
          for J := 0 to Matches.Count - 1 do
          begin
            Match := Matches.Objects[J];
            Value := Match.Find('book_id');
            if (Value = nil) or (Value.JSONType <> jtNumber) or
              not TryStrToInt64(Value.AsJSON, Entry.Response.Matches[J].BookID) then
              raise Exception.Create('id');
            for K := 0 to J - 1 do
              if Entry.Response.Matches[K].BookID = Entry.Response.Matches[J].BookID then
                raise Exception.Create('duplicate');
            Entry.Response.Matches[J].Relevance := ReadText(Match, 'relevance');
            if (Entry.Response.Matches[J].Relevance <> 'high') and
              (Entry.Response.Matches[J].Relevance <> 'medium') and
              (Entry.Response.Matches[J].Relevance <> 'low') then raise Exception.Create('relevance');
            Entry.Response.Matches[J].Reason := ReadText(Match, 'reason');
            Entry.Response.Matches[J].Location := ReadText(Match, 'location');
          end;
        end;
      end;
      FEntries.Free;
      FEntries := Parsed;
      Parsed := nil;
      FWritable := True;
      Result := True;
    except
      AError := 'Не удалось прочитать историю поиска. Файл сохранён без изменений; новые записи не добавляются.';
    end;
  finally
    Parsed.Free;
    Root.Free;
  end;
end;

function TBookSearchHistory.Save(out AError: string): Boolean;
var Root, Item, Match: TJSONObject; Items, Matches: TJSONArray;
  Entry: TBookSearchHistoryEntry; M: TBookSearchMatch; I: Integer;
begin
  Root := TJSONObject.Create;
  try
    Root.Add('version', 1);
    Root.Add('user_id', FUserID);
    Items := TJSONArray.Create;
    Root.Add('entries', Items);
    for I := 0 to Count - 1 do
    begin
      Entry := Entries[I];
      Item := TJSONObject.Create;
      Items.Add(Item);
      Item.Add('query', Entry.Query);
      Item.Add('model', Entry.Model);
      Item.Add('fingerprint', Entry.Fingerprint);
      Item.Add('title_query', Entry.TitleQuery);
      Item.Add('inventory_query', Entry.InventoryQuery);
      Item.Add('created_at', Double(Entry.CreatedAt));
      Item.Add('include_deleted', Entry.IncludeDeleted);
      Matches := TJSONArray.Create;
      Item.Add('results', Matches);
      for M in Entry.Response.Matches do
      begin
        Match := TJSONObject.Create;
        Matches.Add(Match);
        Match.Add('book_id', M.BookID);
        Match.Add('relevance', M.Relevance);
        Match.Add('reason', M.Reason);
        Match.Add('location', M.Location);
      end;
    end;
    Result := WriteJSONFile(FFileName, Root, AError);
  finally
    Root.Free;
  end;
end;

function TBookSearchHistory.Add(const AQuery, ATitle, AInventory, AModel, AFingerprint: string;
  AIncludeDeleted: Boolean; const AResponse: TBookSearchResponse; out AError: string): Boolean;
var Entry: TBookSearchHistoryEntry;
begin
  Result := False;
  AError := '';
  if not FWritable then
  begin
    AError := 'История поиска недоступна для записи. Исходный файл не изменён.';
    Exit;
  end;
  if (AResponse.Status <> 'ok') or (Trim(AQuery) = '') or (Trim(AModel) = '') or (AFingerprint = '') then
  begin
    AError := 'В историю можно сохранить только успешный поиск с запросом и моделью.';
    Exit;
  end;
  Entry := TBookSearchHistoryEntry.Create;
  Entry.Query := AQuery;
  Entry.TitleQuery := ATitle;
  Entry.InventoryQuery := AInventory;
  Entry.Model := AModel;
  Entry.Fingerprint := AFingerprint;
  Entry.IncludeDeleted := AIncludeDeleted;
  Entry.CreatedAt := Now;
  Entry.Response := AResponse;
  Entry.Response.Matches := Copy(AResponse.Matches);
  FEntries.Insert(0, Entry);
  Result := Save(AError);
  if not Result then FEntries.Delete(0);
end;

function TBookSearchHistory.Clear(out AError: string): Boolean;
var Previous: TObjectList;
begin
  Previous := FEntries;
  FEntries := TObjectList.Create(True);
  Result := Save(AError);
  if Result then
  begin
    Previous.Free;
    FWritable := True;
  end
  else
  begin
    FEntries.Free;
    FEntries := Previous;
  end;
end;

end.
