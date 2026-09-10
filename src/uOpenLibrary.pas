unit uOpenLibrary;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, uTypes, uBookHttp;

type
  TOpenLibrarySource = (olsOnline, olsGoogleBooks, olsCache, olsRsl);

  TOpenLibraryBookData = record
    NormalizedISBN: string;
    Title: string;
    Authors: string;
    Year: Integer;
    Publisher: string;
    Description: string;
    CategoryName: string;
    Language: string;
    WorkKey: string;
    CoverURL: string;
    CoverCacheFile: string;
    Source: TOpenLibrarySource;
    FromCache: Boolean;
    TextIsPlain: Boolean;
    Origin: TOpenLibrarySource;
    SourceURL: string;
    Warnings: string;
  end;

  TBookCandidates = array of TOpenLibraryBookData;
  TBookCandidateSelector = function(const AItems: TBookCandidates): Integer of object;

  TOpenLibraryHttpGet = function(const AURL: string; out AStatusCode: Cardinal;
    out AResponseBody, AError: string): Boolean;

function EquivalentISBN(const A, B: string): Boolean;
function ValidateBookData(const AISBN: string; var AData: TOpenLibraryBookData;
  out AError: string): Boolean;
function BookSourceName(const AData: TOpenLibraryBookData): string;
procedure ClearOpenLibraryBookData(var AData: TOpenLibraryBookData);
function NormalizeISBN(const AISBN: string; out ANormalized,
  AError: string): Boolean;
function ParseOpenLibrarySearchResponse(const AResponse, ANormalizedISBN: string;
  out AData: TOpenLibraryBookData; out AFound: Boolean;
  out AError: string): Boolean;
function MergeOpenLibraryWorkResponse(const AResponse: string;
  var AData: TOpenLibraryBookData; out AError: string): Boolean;
function ParseGoogleBooksResponse(const AResponse, ANormalizedISBN: string;
  out AData: TOpenLibraryBookData; out AFound: Boolean;
  out AError: string): Boolean;
function SaveOpenLibraryCache(const ACacheDir: string;
  const AData: TOpenLibraryBookData; out AError: string): Boolean;
function LoadOpenLibraryCache(const ACacheDir, ANormalizedISBN: string;
  out AData: TOpenLibraryBookData; out AError: string): Boolean;
function CacheOpenLibraryCover(const ACacheDir, ANormalizedISBN,
  AContent: string; out AFileName, AError: string): Boolean;
function LookupOpenLibraryBook(const AISBN, ACacheDir: string;
  out AData: TOpenLibraryBookData; out AWarning, AError: string;
  AHttpGet: TOpenLibraryHttpGet = nil): Boolean;
function LookupBookByISBN(const AISBN, ACacheDir, AGoogleBooksApiKey: string;
  out AData: TOpenLibraryBookData; out AWarning, AError: string;
  AHttpGet: TOpenLibraryHttpGet = nil;
  ARslSession: TBookHttpSession = nil;
  ASelect: TBookCandidateSelector = nil): Boolean;

implementation

uses
  fpjson, jsonparser, FileUtil, uBookText, uRsl;

const
  OPENLIBRARY_SEARCH_URL = 'https://openlibrary.org/search.json?q=isbn%3A';
  OPENLIBRARY_BASE_URL = 'https://openlibrary.org';
  OPENLIBRARY_COVER_URL = 'https://covers.openlibrary.org/b/isbn/';
  OPENLIBRARY_SEARCH_FIELDS =
    '&fields=key,title,author_name,subject,language,editions,editions.key,' +
    'editions.title,editions.publish_date,editions.publisher,editions.isbn,' +
    'editions.language&limit=10';
  OPENLIBRARY_RUSSIAN_LANGUAGE_FILTER = '+language%3Arus';
  GOOGLE_BOOKS_URL = 'https://www.googleapis.com/books/v1/volumes?q=isbn%3A';
  MAX_COVER_SIZE = 10 * 1024 * 1024;

function HasCyrillicTitle(const ATitle: string): Boolean; forward;
function JSONFirstText(AData: TJSONData): string; forward;
function JSONTextArrayByName(AObject: TJSONObject; const AName: string): string; forward;

function CanonicalISBN(const S: string): string;
var Err: string; I, Sum: Integer;
begin
  if not NormalizeISBN(S, Result, Err) then Exit('');
  if Length(Result) = 10 then
  begin
    Result := '978' + Copy(Result, 1, 9);
    Sum := 0;
    for I := 1 to 12 do
      if Odd(I) then Inc(Sum, Ord(Result[I]) - 48)
      else Inc(Sum, 3 * (Ord(Result[I]) - 48));
    Result := Result + IntToStr((10 - Sum mod 10) mod 10);
  end;
end;

function EquivalentISBN(const A, B: string): Boolean;
var Key: string;
begin
  Key := CanonicalISBN(A);
  Result := (Key <> '') and (Key = CanonicalISBN(B));
end;

function BookSourceName(const AData: TOpenLibraryBookData): string;
var Source: TOpenLibrarySource;
begin
  Source := AData.Source;
  if AData.FromCache then Source := AData.Origin;
  case Source of
    olsOnline: Result := 'Open Library';
    olsGoogleBooks: Result := 'Google Books';
    olsRsl: Result := 'РГБ';
    else Result := 'неизвестный источник';
  end;
  if AData.FromCache then Result := Result + ' (локальный кэш)';
end;

function ValidateBookData(const AISBN: string; var AData: TOpenLibraryBookData;
  out AError: string): Boolean;
var W: string;
  procedure Clean(var S: string; const LabelText: string);
  begin
    W := EncodingWarning(S);
    if W <> '' then AddBookWarning(AData.Warnings, LabelText + ': ' + W);
    if AData.TextIsPlain then S := PlainBookText(S)
    else S := HTMLText(S);
    W := TextWarning(S);
    if W <> '' then AddBookWarning(AData.Warnings, LabelText + ': ' + W);
  end;
begin
  Result := False;
  AError := '';
  if not EquivalentISBN(AISBN, AData.NormalizedISBN) then
  begin
    AError := 'ISBN записи не совпадает с запросом.';
    Exit;
  end;
  Clean(AData.Title, 'Название');
  Clean(AData.Authors, 'Авторы');
  Clean(AData.Publisher, 'Издательство');
  Clean(AData.Description, 'Описание');
  Clean(AData.CategoryName, 'Категория');
  AData.TextIsPlain := True;
  if AData.Title = '' then AError := 'В записи отсутствует название.'
  else if not HasCyrillicTitle(AData.Title) then
    AError := 'Не найдена запись с кириллическим названием.';
  if AError <> '' then Exit;
  if AData.Year <> 0 then
  begin
    AData.Year := CheckedYear(IntToStr(AData.Year), W);
    AddBookWarning(AData.Warnings, W);
  end;
  Result := True;
end;

procedure ClearOpenLibraryBookData(var AData: TOpenLibraryBookData);
begin
  AData.NormalizedISBN := '';
  AData.Title := '';
  AData.Authors := '';
  AData.Year := 0;
  AData.Publisher := '';
  AData.Description := '';
  AData.CategoryName := '';
  AData.Language := '';
  AData.WorkKey := '';
  AData.CoverURL := '';
  AData.CoverCacheFile := '';
  AData.Source := olsOnline;
  AData.Origin := olsOnline;
  AData.FromCache := False;
  AData.TextIsPlain := False;
  AData.SourceURL := '';
  AData.Warnings := '';
end;

function GoogleVolumeHasISBN(AInfo: TJSONObject;
  const ANormalizedISBN: string): Boolean;
var
  IdentifiersData: TJSONData;
  Identifiers: TJSONArray;
  I: Integer;
  Identifier, Normalized, Err: string;
begin
  Result := False;
  if AInfo = nil then
    Exit;
  IdentifiersData := AInfo.Find('industryIdentifiers');
  if not (IdentifiersData is TJSONArray) then
    Exit;
  Identifiers := TJSONArray(IdentifiersData);
  for I := 0 to Identifiers.Count - 1 do
    if Identifiers[I] is TJSONObject then
    begin
      Identifier := TJSONObject(Identifiers[I]).Get('identifier', '');
      if NormalizeISBN(Identifier, Normalized, Err) and
        EquivalentISBN(Normalized, ANormalizedISBN) then
        Exit(True);
    end;
end;

function HasCyrillicTitle(const ATitle: string): Boolean;
var
  Title: UnicodeString;
  I: Integer;
begin
  Result := False;
  Title := UTF8Decode(ATitle);
  for I := 1 to Length(Title) do
    if (Title[I] >= UnicodeChar($0400)) and (Title[I] <= UnicodeChar($052F)) then
      Exit(True);
end;

function GoogleCoverURL(AInfo: TJSONObject): string;
const
  COVER_SIZES: array[0..5] of string = ('extraLarge', 'large', 'medium',
    'small', 'thumbnail', 'smallThumbnail');
var
  LinksData: TJSONData;
  Links: TJSONObject;
  I: Integer;
begin
  Result := '';
  if AInfo = nil then
    Exit;
  LinksData := AInfo.Find('imageLinks');
  if not (LinksData is TJSONObject) then
    Exit;
  Links := TJSONObject(LinksData);
  for I := Low(COVER_SIZES) to High(COVER_SIZES) do
  begin
    Result := Trim(Links.Get(COVER_SIZES[I], ''));
    if Result <> '' then
      Break;
  end;
  if Pos('http://', LowerCase(Result)) = 1 then
    Result := 'https://' + Copy(Result, Length('http://') + 1, MaxInt);
end;

function ParseGoogleBooksResponse(const AResponse, ANormalizedISBN: string;
  out AData: TOpenLibraryBookData; out AFound: Boolean;
  out AError: string): Boolean;
var
  Root, ItemsData, InfoData: TJSONData;
  Items: TJSONArray;
  Item, Info: TJSONObject;
  I: Integer;
  Subtitle, YearWarning: string;
begin
  Result := False;
  AFound := False;
  AError := '';
  ClearOpenLibraryBookData(AData);
  AData.NormalizedISBN := ANormalizedISBN;
  Root := nil;
  try
    try
      Root := GetJSON(AResponse);
      if not (Root is TJSONObject) then
        raise Exception.Create('ответ не является JSON-объектом');
      ItemsData := TJSONObject(Root).Find('items');
      if ItemsData = nil then
      begin
        Result := True;
        Exit;
      end;
      if not (ItemsData is TJSONArray) then
        raise Exception.Create('поле items не является массивом');
      Items := TJSONArray(ItemsData);
      for I := 0 to Items.Count - 1 do
      begin
        if not (Items[I] is TJSONObject) then
          Continue;
        Item := TJSONObject(Items[I]);
        InfoData := Item.Find('volumeInfo');
        if not (InfoData is TJSONObject) then
          Continue;
        Info := TJSONObject(InfoData);
        if not SameText(Trim(Info.Get('language', '')), 'ru') then
          Continue;
        if not GoogleVolumeHasISBN(Info, ANormalizedISBN) then
          Continue;
        ClearOpenLibraryBookData(AData);
        AData.NormalizedISBN := ANormalizedISBN;
        AData.Title := Trim(Info.Get('title', ''));
        Subtitle := Trim(Info.Get('subtitle', ''));
        if (AData.Title <> '') and (Subtitle <> '') then
          AData.Title := AData.Title + ': ' + Subtitle;
        AData.Authors := JSONTextArrayByName(Info, 'authors');
        AData.Publisher := Trim(Info.Get('publisher', ''));
        AData.Year := CheckedYear(Info.Get('publishedDate', ''), YearWarning);
        AddBookWarning(AData.Warnings, YearWarning);
        AData.Description := Info.Get('description', '');
        AData.CategoryName := Trim(Info.Get('mainCategory', ''));
        if AData.CategoryName = '' then
          AData.CategoryName := JSONFirstText(Info.Find('categories'));
        AData.Language := 'ru';
        AData.CoverURL := GoogleCoverURL(Info);
        AData.Source := olsGoogleBooks;
        AData.Origin := olsGoogleBooks;
        AData.SourceURL := Info.Get('infoLink', 'https://books.google.com/');
        if not ValidateBookData(ANormalizedISBN, AData, AError) then Continue;
        AFound := True;
        Result := True;
        Exit;
      end;
      AError := '';
      Result := True;
    except
      on E: Exception do
        AError := 'Не удалось разобрать ответ Google Books: ' + E.Message + '.';
    end;
  finally
    Root.Free;
  end;
end;

function NormalizeISBN(const AISBN: string; out ANormalized,
  AError: string): Boolean;
var
  I, Sum, Digit: Integer;
  Ch: Char;
  Input: string;
begin
  Result := False;
  ANormalized := '';
  AError := '';
  Input := NormalizeISBNFormat(AISBN);
  for I := 1 to Length(Input) do
  begin
    Ch := Input[I];
    if (Ch >= '0') and (Ch <= '9') then
      ANormalized := ANormalized + Ch
    else if (UpCase(Ch) = 'X') then
      ANormalized := ANormalized + 'X'
    else
    begin
      AError := 'ISBN содержит недопустимые символы.';
      Exit;
    end;
  end;
  if Length(ANormalized) = 10 then
  begin
    Sum := 0;
    for I := 1 to 10 do
    begin
      if (I = 10) and (ANormalized[I] = 'X') then
        Digit := 10
      else if (ANormalized[I] >= '0') and (ANormalized[I] <= '9') then
        Digit := Ord(ANormalized[I]) - Ord('0')
      else
      begin
        AError := 'Символ X допустим только в конце ISBN-10.';
        Exit;
      end;
      Sum := Sum + (11 - I) * Digit;
    end;
    if (Sum mod 11) <> 0 then
    begin
      AError := 'Неверная контрольная сумма ISBN-10.';
      Exit;
    end;
  end
  else if Length(ANormalized) = 13 then
  begin
    if (Copy(ANormalized, 1, 3) <> '978') and (Copy(ANormalized, 1, 3) <> '979') then
    begin
      AError := 'ISBN-13 должен начинаться с 978 или 979.';
      Exit;
    end;
    Sum := 0;
    for I := 1 to 13 do
    begin
      if not (ANormalized[I] in ['0'..'9']) then
      begin
        AError := 'ISBN-13 должен содержать только цифры.';
        Exit;
      end;
      Digit := Ord(ANormalized[I]) - Ord('0');
      if Odd(I) then
        Sum := Sum + Digit
      else
        Sum := Sum + 3 * Digit;
    end;
    if (Sum mod 10) <> 0 then
    begin
      AError := 'Неверная контрольная сумма ISBN-13.';
      Exit;
    end;
  end
  else
  begin
    AError := 'ISBN должен содержать 10 или 13 знаков.';
    Exit;
  end;
  Result := True;
end;

function JSONFirstText(AData: TJSONData): string;
begin
  Result := '';
  if AData = nil then
    Exit;
  if AData is TJSONArray then
  begin
    if TJSONArray(AData).Count > 0 then
      Result := JSONFirstText(TJSONArray(AData)[0]);
    Exit;
  end;
  if AData.JSONType <> jtNull then
    Result := Trim(AData.AsString);
end;

function JSONTextArray(AData: TJSONData): string;
var
  I: Integer;
  Value: string;
begin
  Result := '';
  if not (AData is TJSONArray) then
  begin
    Result := JSONFirstText(AData);
    Exit;
  end;
  for I := 0 to TJSONArray(AData).Count - 1 do
  begin
    Value := JSONFirstText(TJSONArray(AData)[I]);
    if Value = '' then
      Continue;
    if Result <> '' then
      Result := Result + ', ';
    Result := Result + Value;
  end;
end;

function JSONTextArrayByName(AObject: TJSONObject; const AName: string): string;
begin
  if AObject = nil then
    Exit('');
  Result := JSONTextArray(AObject.Find(AName));
end;

function JSONContainsText(AData: TJSONData; const AValue: string): Boolean;
var
  I: Integer;
begin
  Result := False;
  if AData = nil then
    Exit;
  if AData is TJSONArray then
  begin
    for I := 0 to TJSONArray(AData).Count - 1 do
      if JSONContainsText(TJSONArray(AData)[I], AValue) then
        Exit(True);
    Exit;
  end;
  Result := SameText(Trim(AData.AsString), AValue);
end;

function JSONArrayContainsISBN(AData: TJSONData;
  const ANormalizedISBN: string): Boolean;
var
  I: Integer;
  Value, Normalized, Err: string;
begin
  Result := False;
  if not (AData is TJSONArray) then
    Exit;
  for I := 0 to TJSONArray(AData).Count - 1 do
  begin
    Value := JSONFirstText(TJSONArray(AData)[I]);
    if NormalizeISBN(Value, Normalized, Err) and
      EquivalentISBN(Normalized, ANormalizedISBN) then
      Exit(True);
  end;
end;

function FindMatchingEdition(AWork: TJSONObject;
  const ANormalizedISBN: string): TJSONObject;
var
  EditionsData, DocsData: TJSONData;
  Docs: TJSONArray;
  I: Integer;
begin
  Result := nil;
  EditionsData := AWork.Find('editions');
  if not (EditionsData is TJSONObject) then
    Exit;
  DocsData := TJSONObject(EditionsData).Find('docs');
  if not (DocsData is TJSONArray) then
    Exit;
  Docs := TJSONArray(DocsData);
  for I := 0 to Docs.Count - 1 do
    if (Docs[I] is TJSONObject) and
      JSONArrayContainsISBN(TJSONObject(Docs[I]).Find('isbn'),
        ANormalizedISBN) then
      Exit(TJSONObject(Docs[I]));
end;

function ParseOpenLibrarySearchResponse(const AResponse, ANormalizedISBN: string;
  out AData: TOpenLibraryBookData; out AFound: Boolean;
  out AError: string): Boolean;
var
  Root: TJSONData;
  DocsData: TJSONData;
  Docs: TJSONArray;
  Work, CandidateWork, Edition: TJSONObject;
  I: Integer;
  PublishDate, YearWarning: string;
begin
  Result := False;
  AFound := False;
  AError := '';
  ClearOpenLibraryBookData(AData);
  AData.NormalizedISBN := ANormalizedISBN;
  Root := nil;
  try
    try
      Root := GetJSON(AResponse);
      if not (Root is TJSONObject) then
        raise Exception.Create('ответ не является JSON-объектом');
      DocsData := TJSONObject(Root).Find('docs');
      if not (DocsData is TJSONArray) then
        raise Exception.Create('в ответе отсутствует массив docs');
      Docs := TJSONArray(DocsData);
      if Docs.Count = 0 then
      begin
        Result := True;
        Exit;
      end;
      Work := nil;
      Edition := nil;
      for I := 0 to Docs.Count - 1 do
        if Docs[I] is TJSONObject then
        begin
          CandidateWork := TJSONObject(Docs[I]);
          Edition := FindMatchingEdition(CandidateWork, ANormalizedISBN);
          if Edition <> nil then
          begin
            Work := CandidateWork;
            Break;
          end;
        end;
      if Work = nil then
      begin
        Result := True;
        Exit;
      end;
      AData.WorkKey := JSONFirstText(Work.Find('key'));
      AData.SourceURL := OPENLIBRARY_BASE_URL + AData.WorkKey;
      AData.Title := JSONFirstText(Work.Find('title'));
      AData.Authors := JSONTextArray(Work.Find('author_name'));
      AData.CategoryName := JSONFirstText(Work.Find('subject'));
      if JSONContainsText(Work.Find('language'), 'rus') then
        AData.Language := 'rus'
      else
        AData.Language := JSONFirstText(Work.Find('language'));
      if Edition <> nil then
      begin
        if JSONFirstText(Edition.Find('title')) <> '' then
          AData.Title := JSONFirstText(Edition.Find('title'));
        AData.Publisher := JSONFirstText(Edition.Find('publisher'));
        if JSONContainsText(Edition.Find('language'), 'rus') then
          AData.Language := 'rus'
        else if JSONFirstText(Edition.Find('language')) <> '' then
          AData.Language := JSONFirstText(Edition.Find('language'));
        PublishDate := JSONFirstText(Edition.Find('publish_date'));
        AData.Year := CheckedYear(PublishDate, YearWarning);
        AddBookWarning(AData.Warnings, YearWarning);
      end;
      AFound := True;
      Result := True;
    except
      on E: Exception do
        AError := 'Не удалось разобрать ответ Open Library: ' + E.Message + '.';
    end;
  finally
    Root.Free;
  end;
end;

function MergeOpenLibraryWorkResponse(const AResponse: string;
  var AData: TOpenLibraryBookData; out AError: string): Boolean;
var
  Root, DescriptionData, ValueData: TJSONData;
begin
  Result := False;
  AError := '';
  Root := nil;
  try
    try
      Root := GetJSON(AResponse);
      if not (Root is TJSONObject) then
        raise Exception.Create('ответ не является JSON-объектом');
      if AData.Description = '' then
      begin
        DescriptionData := TJSONObject(Root).Find('description');
        if DescriptionData is TJSONObject then
        begin
          ValueData := TJSONObject(DescriptionData).Find('value');
          AData.Description := JSONFirstText(ValueData);
        end
        else
          AData.Description := JSONFirstText(DescriptionData);
      end;
      if AData.CategoryName = '' then
        AData.CategoryName := JSONFirstText(TJSONObject(Root).Find('subjects'));
      Result := True;
    except
      on E: Exception do
        AError := 'Не удалось разобрать описание Open Library: ' + E.Message + '.';
    end;
  finally
    Root.Free;
  end;
end;

function SafeWriteFile(const AFileName, AContent: string;
  out AError: string): Boolean;
var
  Stream: TFileStream;
  TempFile, BackupFile: string;
begin
  Result := False;
  AError := '';
  TempFile := AFileName + '.tmp';
  BackupFile := AFileName + '.bak';
  try
    if FileExists(TempFile) then
      DeleteFile(TempFile);
    Stream := TFileStream.Create(TempFile, fmCreate);
    try
      if AContent <> '' then
        Stream.WriteBuffer(AContent[1], Length(AContent));
    finally
      Stream.Free;
    end;
    if FileExists(BackupFile) then
      DeleteFile(BackupFile);
    if FileExists(AFileName) and not RenameFile(AFileName, BackupFile) then
      raise Exception.Create('не удалось подготовить предыдущую версию');
    if not RenameFile(TempFile, AFileName) then
    begin
      if FileExists(BackupFile) then
        RenameFile(BackupFile, AFileName);
      raise Exception.Create('не удалось заменить файл');
    end;
    if FileExists(BackupFile) then
      DeleteFile(BackupFile);
    Result := True;
  except
    on E: Exception do
    begin
      if FileExists(TempFile) then
        DeleteFile(TempFile);
      AError := E.Message;
    end;
  end;
end;

function CacheJSONFile(const ACacheDir, ANormalizedISBN: string): string;
begin
  Result := IncludeTrailingPathDelimiter(ACacheDir) + ANormalizedISBN + '.json';
end;

function CacheCoverFile(const ACacheDir, ANormalizedISBN: string;
  const AExtension: string = '.jpg'): string;
begin
  Result := IncludeTrailingPathDelimiter(ACacheDir) + ANormalizedISBN + AExtension;
end;

function SaveOpenLibraryCache(const ACacheDir: string;
  const AData: TOpenLibraryBookData; out AError: string): Boolean;
var
  Root: TJSONObject;
  Content: string;
begin
  Result := False;
  AError := '';
  if not ForceDirectories(ACacheDir) then
  begin
    AError := 'Не удалось создать каталог кэша поиска книг.';
    Exit;
  end;
  Root := TJSONObject.Create;
  try
    Root.Add('version', 2);
    Root.Add('plain_text', AData.TextIsPlain);
    Root.Add('origin', Ord(AData.Origin));
    Root.Add('source_url', AData.SourceURL);
    Root.Add('warnings', AData.Warnings);
    Root.Add('isbn', AData.NormalizedISBN);
    Root.Add('title', AData.Title);
    Root.Add('authors', AData.Authors);
    Root.Add('year', AData.Year);
    Root.Add('publisher', AData.Publisher);
    Root.Add('description', AData.Description);
    Root.Add('category', AData.CategoryName);
    Root.Add('language', AData.Language);
    Root.Add('work_key', AData.WorkKey);
    Root.Add('cover_url', AData.CoverURL);
    Root.Add('cover_file', ExtractFileName(AData.CoverCacheFile));
    Root.Add('source', Ord(AData.Source));
    Content := Root.AsJSON;
  finally
    Root.Free;
  end;
  Result := SafeWriteFile(CacheJSONFile(ACacheDir, AData.NormalizedISBN),
    Content, AError);
  if not Result then
    AError := 'Не удалось сохранить кэш поиска книг: ' + AError + '.';
end;

function ReadFileBytes(const AFileName: string): string;
var
  Stream: TFileStream;
begin
  Stream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  try
    if Stream.Size > MaxInt then
      raise Exception.Create('файл слишком большой');
    SetLength(Result, SizeInt(Stream.Size));
    if Stream.Size > 0 then
      Stream.ReadBuffer(Result[1], LongInt(Stream.Size));
  finally
    Stream.Free;
  end;
end;

function LoadOpenLibraryCache(const ACacheDir, ANormalizedISBN: string;
  out AData: TOpenLibraryBookData; out AError: string): Boolean;
var
  Root: TJSONData;
  FileName, CoverName: string;
  SourceValue: Integer;
begin
  Result := False;
  AError := '';
  ClearOpenLibraryBookData(AData);
  FileName := CacheJSONFile(ACacheDir, ANormalizedISBN);
  if not FileExists(FileName) then
  begin
    AError := 'В локальном кэше нет данных для этого ISBN.';
    Exit;
  end;
  Root := nil;
  try
    try
      Root := GetJSON(ReadFileBytes(FileName));
      if not (Root is TJSONObject) then
        raise Exception.Create('запись кэша не является JSON-объектом');
      if TJSONObject(Root).Get('version', 1) > 2 then
        raise Exception.Create('неизвестная версия кэша');
      AData.TextIsPlain := TJSONObject(Root).Get('plain_text', False);
      AData.NormalizedISBN := NormalizeISBNFormat(
        TJSONObject(Root).Get('isbn', ANormalizedISBN));
      AData.Title := TJSONObject(Root).Get('title', '');
      AData.Authors := TJSONObject(Root).Get('authors', '');
      AData.Year := TJSONObject(Root).Get('year', 0);
      AData.Publisher := TJSONObject(Root).Get('publisher', '');
      AData.Description := TJSONObject(Root).Get('description', '');
      AData.CategoryName := TJSONObject(Root).Get('category', '');
      AData.Language := TJSONObject(Root).Get('language', '');
      AData.WorkKey := TJSONObject(Root).Get('work_key', '');
      AData.CoverURL := TJSONObject(Root).Get('cover_url', '');
      CoverName := TJSONObject(Root).Get('cover_file', '');
      if CoverName <> '' then
        AData.CoverCacheFile := IncludeTrailingPathDelimiter(ACacheDir) +
          ExtractFileName(CoverName)
      else
        AData.CoverCacheFile := CacheCoverFile(ACacheDir, ANormalizedISBN);
      if not FileExists(AData.CoverCacheFile) then
        AData.CoverCacheFile := '';
      AData.Source := olsCache;
      AData.FromCache := True;
      SourceValue := TJSONObject(Root).Get('origin', TJSONObject(Root).Get('source', 2));
      if (SourceValue < 0) or (SourceValue > Ord(High(TOpenLibrarySource))) then
        SourceValue := Ord(olsCache);
      AData.Origin := TOpenLibrarySource(SourceValue);
      AData.SourceURL := TJSONObject(Root).Get('source_url', '');
      AData.Warnings := TJSONObject(Root).Get('warnings', '');
      if not ValidateBookData(ANormalizedISBN, AData, AError) then
        raise Exception.Create(AError);
      if (Trim(AData.Title) = '') and (Trim(AData.Authors) = '') and
        (AData.Year = 0) and (Trim(AData.Publisher) = '') and
        (Trim(AData.Description) = '') and
        (Trim(AData.CategoryName) = '') then
        raise Exception.Create('в записи кэша отсутствуют данные книги');
      Result := True;
    except
      on E: Exception do
        AError := 'Повреждён кэш поиска книг: ' + E.Message + '.';
    end;
  finally
    Root.Free;
  end;
end;

function CacheOpenLibraryCover(const ACacheDir, ANormalizedISBN,
  AContent: string; out AFileName, AError: string): Boolean;
var
  Extension: string;
begin
  Result := False;
  AFileName := '';
  AError := '';
  if Length(AContent) = 0 then
  begin
    AError := 'Сервис поиска книг не вернул данные обложки.';
    Exit;
  end;
  if Length(AContent) > MAX_COVER_SIZE then
  begin
    AError := 'Обложка превышает допустимый размер 10 МБ.';
    Exit;
  end;
  Extension := '';
  if (Length(AContent) >= 3) and (Byte(AContent[1]) = $FF) and
    (Byte(AContent[2]) = $D8) and (Byte(AContent[3]) = $FF) then
    Extension := '.jpg'
  else if (Length(AContent) >= 8) and (Byte(AContent[1]) = $89) and
    (Copy(AContent, 2, 3) = 'PNG') then
    Extension := '.png';
  if Extension = '' then
  begin
    AError := 'Сервис поиска книг вернул файл обложки неизвестного формата.';
    Exit;
  end;
  if not ForceDirectories(ACacheDir) then
  begin
    AError := 'Не удалось создать каталог кэша поиска книг.';
    Exit;
  end;
  AFileName := CacheCoverFile(ACacheDir, ANormalizedISBN, Extension);
  Result := SafeWriteFile(AFileName, AContent, AError);
  if not Result then
  begin
    AError := 'Не удалось сохранить обложку: ' + AError + '.';
    AFileName := '';
  end;
end;

threadvar
  CurrentBookSession: TBookHttpSession;

function DefaultHttpGet(const AURL: string; out AStatusCode: Cardinal;
  out AResponseBody, AError: string): Boolean;
var Session: TBookHttpSession;
begin
  Session := CurrentBookSession;
  if Session = nil then Session := TBookHttpSession.Create;
  try
    Result := Session.Request('GET', AURL, '', AStatusCode, AResponseBody, AError);
  finally
    if CurrentBookSession = nil then Session.Free;
  end;
end;

procedure AppendWarning(var AWarning: string; const AValue: string);
begin
  if Trim(AValue) = '' then
    Exit;
  if AWarning <> '' then
    AWarning := AWarning + LineEnding;
  AWarning := AWarning + AValue;
end;

function LookupOpenLibraryBookInternal(const AISBN, ACacheDir: string;
  out AData: TOpenLibraryBookData; out AWarning, AError: string;
  out ANotFound: Boolean;
  AHttpGet: TOpenLibraryHttpGet; AAllowCache: Boolean = True): Boolean;
var
  Getter: TOpenLibraryHttpGet;
  Normalized, Response, NetworkError, ParseError, CacheError: string;
  WorkError, CoverError, CacheSaveError, CoverFile: string;
  Status: Cardinal;
  Found, OnlineFailed: Boolean;
begin
  Result := False;
  ANotFound := False;
  AWarning := '';
  AError := '';
  ClearOpenLibraryBookData(AData);
  if not NormalizeISBN(AISBN, Normalized, AError) then
    Exit;
  Getter := AHttpGet;
  if not Assigned(Getter) then
    Getter := @DefaultHttpGet;

  Status := 0;
  Response := '';
  NetworkError := '';
  OnlineFailed := not Getter(OPENLIBRARY_SEARCH_URL + Normalized +
    OPENLIBRARY_RUSSIAN_LANGUAGE_FILTER + OPENLIBRARY_SEARCH_FIELDS, Status,
    Response, NetworkError);
  if not OnlineFailed then
    OnlineFailed := (Status < 200) or (Status >= 300);
  if not OnlineFailed then
  begin
    if not ParseOpenLibrarySearchResponse(Response, Normalized, AData, Found,
      ParseError) then
    begin
      OnlineFailed := True;
      NetworkError := ParseError;
    end
    else if not Found then
    begin
      ANotFound := True;
      Exit;
    end;
  end;

  if OnlineFailed then
  begin
    if AAllowCache and LoadOpenLibraryCache(ACacheDir, Normalized, AData, CacheError) then
    begin
      if not HasCyrillicTitle(AData.Title) then
      begin
        ANotFound := True;
        Exit;
      end;
      AWarning := 'Нет доступа к Open Library. Использованы данные из локального кэша.';
      Result := True;
      Exit;
    end;
    if NetworkError <> '' then
      AError := 'Не удалось получить данные Open Library: ' + NetworkError
    else if Status <> 0 then
      AError := 'Open Library вернул HTTP ' + IntToStr(Status) + '.'
    else
      AError := 'Не удалось получить данные Open Library.';
    Exit;
  end;

  if not HasCyrillicTitle(AData.Title) then
  begin
    ANotFound := True;
    Exit;
  end;

  AData.Source := olsOnline;
  AData.CoverURL := OPENLIBRARY_COVER_URL + Normalized + '-L.jpg?default=false';
  if AData.WorkKey <> '' then
  begin
    Status := 0;
    Response := '';
    WorkError := '';
    if Getter(OPENLIBRARY_BASE_URL + AData.WorkKey + '.json', Status,
      Response, WorkError) and (Status >= 200) and (Status < 300) then
    begin
      if not MergeOpenLibraryWorkResponse(Response, AData, WorkError) then
        AppendWarning(AWarning, WorkError);
    end
    else if Status <> 404 then
    begin
      if WorkError <> '' then
        AppendWarning(AWarning, 'Описание книги не загружено: ' + WorkError)
      else
        AppendWarning(AWarning, 'Описание книги не загружено: HTTP ' +
          IntToStr(Status) + '.');
    end;
  end;

  Status := 0;
  Response := '';
  CoverError := '';
  if Getter(AData.CoverURL, Status, Response, CoverError) and
    (Status >= 200) and (Status < 300) then
  begin
    if CacheOpenLibraryCover(ACacheDir, Normalized, Response, CoverFile,
      CoverError) then
      AData.CoverCacheFile := CoverFile
    else
      AppendWarning(AWarning, CoverError);
  end
  else if Status <> 404 then
  begin
    if CoverError <> '' then
      AppendWarning(AWarning, 'Обложка не загружена: ' + CoverError)
    else
      AppendWarning(AWarning, 'Обложка не загружена: HTTP ' +
        IntToStr(Status) + '.');
  end;

  if not ValidateBookData(AData.NormalizedISBN, AData, AError) then Exit;
  if not SaveOpenLibraryCache(ACacheDir, AData, CacheSaveError) then
    AppendWarning(AWarning, CacheSaveError);
  Result := True;
end;

function LookupOpenLibraryBook(const AISBN, ACacheDir: string;
  out AData: TOpenLibraryBookData; out AWarning, AError: string;
  AHttpGet: TOpenLibraryHttpGet): Boolean;
var
  NotFound: Boolean;
begin
  Result := LookupOpenLibraryBookInternal(AISBN, ACacheDir, AData, AWarning,
    AError, NotFound, AHttpGet);
  if (not Result) and NotFound then
    AError := 'Книга с указанным ISBN не найдена в Open Library.';
end;

function LookupGoogleBooks(const ANormalizedISBN, ACacheDir,
  AGoogleBooksApiKey: string; out AData: TOpenLibraryBookData;
  out AWarning, AError: string; AHttpGet: TOpenLibraryHttpGet): Boolean;
var
  Getter: TOpenLibraryHttpGet;
  Url, Response, NetworkError, ParseError: string;
  CoverError, CacheSaveError, CoverFile: string;
  Status: Cardinal;
  Found: Boolean;
begin
  Result := False;
  AWarning := '';
  AError := '';
  ClearOpenLibraryBookData(AData);
  Getter := AHttpGet;
  if not Assigned(Getter) then
    Getter := @DefaultHttpGet;
  Url := GOOGLE_BOOKS_URL + ANormalizedISBN + '&langRestrict=ru&maxResults=10';
  if Trim(AGoogleBooksApiKey) <> '' then
    Url := Url + '&key=' + Trim(AGoogleBooksApiKey);
  Status := 0;
  Response := '';
  NetworkError := '';
  if not Getter(Url, Status, Response, NetworkError) then
  begin
    AError := 'Не удалось получить данные Google Books: ' + NetworkError;
    Exit;
  end;
  if (Status < 200) or (Status >= 300) then
  begin
    if Status = 429 then
      AError := 'Google Books отклонил запрос из-за ограничения квоты. ' +
        'Укажите Google Books API Key в настройках или повторите попытку позже.'
    else
      AError := 'Google Books вернул HTTP ' + IntToStr(Status) + '.';
    Exit;
  end;
  if not ParseGoogleBooksResponse(Response, ANormalizedISBN, AData, Found,
    ParseError) then
  begin
    AError := ParseError;
    Exit;
  end;
  if not Found then
  begin
    AError := 'Книга с указанным ISBN не найдена в источниках с кириллическим названием.';
    Exit;
  end;
  AData.Source := olsGoogleBooks;
  if AData.CoverURL <> '' then
  begin
    Status := 0;
    Response := '';
    CoverError := '';
    if Getter(AData.CoverURL, Status, Response, CoverError) and
      (Status >= 200) and (Status < 300) then
    begin
      if CacheOpenLibraryCover(ACacheDir, ANormalizedISBN, Response, CoverFile,
        CoverError) then
        AData.CoverCacheFile := CoverFile
      else
        AppendWarning(AWarning, CoverError);
    end
    else if Status <> 404 then
    begin
      if CoverError <> '' then
        AppendWarning(AWarning, 'Обложка Google Books не загружена: ' + CoverError)
      else
        AppendWarning(AWarning, 'Обложка Google Books не загружена: HTTP ' +
          IntToStr(Status) + '.');
    end;
  end;
  if not ValidateBookData(AData.NormalizedISBN, AData, AError) then Exit;
  if not SaveOpenLibraryCache(ACacheDir, AData, CacheSaveError) then
    AppendWarning(AWarning, CacheSaveError);
  Result := True;
end;

function LookupBookByISBN(const AISBN, ACacheDir, AGoogleBooksApiKey: string;
  out AData: TOpenLibraryBookData; out AWarning, AError: string;
  AHttpGet: TOpenLibraryHttpGet; ARslSession: TBookHttpSession;
  ASelect: TBookCandidateSelector): Boolean;
var
  Normalized, Errors, Warn, Err: string;
  NotFound, Found: Boolean;
  Items: TBookCandidates;
  Index: Integer;
  PreviousSession: TBookHttpSession;
  procedure Finish;
  begin
    AError := '';
    AWarning := Errors;
    AddBookWarning(AWarning, Warn);
    AddBookWarning(AWarning, 'Источник данных: ' + BookSourceName(AData) + '.');
    AddBookWarning(AWarning, AData.Warnings);
    Result := True;
  end;
begin
  Result := False;
  AWarning := '';
  AError := '';
  ClearOpenLibraryBookData(AData);
  if not NormalizeISBN(AISBN, Normalized, AError) then Exit;
  Errors := '';
  Warn := '';
  if LookupRsl(Normalized, ARslSession, Items, Err) and (Length(Items) > 0) then
  begin
    Index := 0;
    if Length(Items) > 1 then
    begin
      if not Assigned(ASelect) then
      begin
        AError := 'РГБ вернула несколько записей: требуется выбор книги.';
        Exit;
      end;
      Index := ASelect(Items);
      if (Index < 0) or (Index > High(Items)) then Exit;
    end;
    AData := Items[Index];
    if not SaveOpenLibraryCache(ACacheDir, AData, Err) then Warn := Err;
    Finish;
    Exit;
  end;
  if Err = '' then Err := 'РГБ: подходящая книга не найдена.';
  AddBookWarning(Errors, Err);
  PreviousSession := CurrentBookSession;
  CurrentBookSession := TBookHttpSession.Create;
  try
    Found := LookupOpenLibraryBookInternal(Normalized, ACacheDir, AData, Warn,
      Err, NotFound, AHttpGet, False);
  finally
    CurrentBookSession.Free;
    CurrentBookSession := PreviousSession;
  end;
  if Found then
  begin
    Finish;
    Exit;
  end;
  if Err = '' then Err := 'Open Library: подходящая книга не найдена.';
  AddBookWarning(Errors, Err);
  CurrentBookSession := TBookHttpSession.Create;
  try
    Found := LookupGoogleBooks(Normalized, ACacheDir, AGoogleBooksApiKey,
      AData, Warn, Err, AHttpGet);
  finally
    CurrentBookSession.Free;
    CurrentBookSession := PreviousSession;
  end;
  if Found then
  begin
    Finish;
    Exit;
  end;
  AddBookWarning(Errors, Err);
  if LoadOpenLibraryCache(ACacheDir, Normalized, AData, Err) then
  begin
    Warn := 'Онлайн-поиск не дал результата; использованы данные из локального кэша.';
    Finish;
    Exit;
  end;
  AError := Errors;
  AddBookWarning(AError, Err);
end;

end.
