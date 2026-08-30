unit uUpdater;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Windows;

const
  GITHUB_LATEST_RELEASE_URL =
    'https://api.github.com/repos/sergey-sirenko/Library/releases/latest';
  UPDATE_INSTRUCTION_FILE = 'INSTALL.md';

type
  TUpdateRelease = record
    Version: string;
    TagName: string;
    DownloadURL: string;
    AssetName: string;
    AssetSize: Int64;
    SHA256: string;
    ReleaseURL: string;
    Notes: string;
  end;

  TUpdateStage = (
    usIdle, usChecking, usDownloading, usVerifying, usExtracting, usReady
  );

  TUpdateCheckThread = class(TThread)
  private
    FReleaseInfo: TUpdateRelease;
    FError: string;
    FNoRelease: Boolean;
  protected
    procedure Execute; override;
  public
    constructor Create;
    property ReleaseInfo: TUpdateRelease read FReleaseInfo;
    property ErrorText: string read FError;
    property NoRelease: Boolean read FNoRelease;
  end;

  TUpdatePrepareThread = class(TThread)
  private
    FReleaseInfo: TUpdateRelease;
    FWorkDir: string;
    FStagedApp: string;
    FStagedUpdater: string;
    FError: string;
    FBytesDownloaded: Int64;
    FStage: TUpdateStage;
  protected
    procedure Execute; override;
  public
    constructor Create(const ARelease: TUpdateRelease; const AWorkDir: string);
    property WorkDir: string read FWorkDir;
    property StagedApp: string read FStagedApp;
    property StagedUpdater: string read FStagedUpdater;
    property ErrorText: string read FError;
    property BytesDownloaded: Int64 read FBytesDownloaded;
    property Stage: TUpdateStage read FStage;
  end;

function ParseSemanticVersion(const AValue: string; out AMajor, AMinor,
  APatch: Int64): Boolean;
function CompareSemanticVersions(const ALeft, ARight: string;
  out AValid: Boolean): Integer;
function ParseReleaseJSON(const AJSON: string; out ARelease: TUpdateRelease;
  out AError: string): Boolean;
function CheckLatestRelease(out ARelease: TUpdateRelease; out ANoRelease: Boolean;
  out AError: string): Boolean;
function FileSHA256(const AFileName: string; out AHash, AError: string): Boolean;
function ValidateUpdatePackage(const AZipFile, AOutputDir: string;
  out AAppFile, AUpdaterFile, AError: string): Boolean;
function LaunchPreparedUpdate(const AUpdaterFile, ANewAppFile, ACurrentAppFile,
  ALogFile, ACleanupDir: string; out AError: string): Boolean;

implementation

uses
  WinHttp, ShellApi, fpjson, jsonparser, zipper, FileUtil, uOpenRouter;

const
  UPDATE_TIMEOUT_MS = 30000;
  BCRYPT_SHA256_ALGORITHM: PWideChar = 'SHA256';
  BCRYPT_OBJECT_LENGTH: PWideChar = 'ObjectLength';
  BCRYPT_HASH_LENGTH: PWideChar = 'HashDigestLength';

type
  NTSTATUS = LongInt;
  BCRYPT_ALG_HANDLE = Pointer;
  BCRYPT_HASH_HANDLE = Pointer;

function BCryptOpenAlgorithmProvider(out phAlgorithm: BCRYPT_ALG_HANDLE;
  pszAlgId, pszImplementation: PWideChar; dwFlags: ULONG): NTSTATUS; stdcall;
  external 'bcrypt.dll';
function BCryptCloseAlgorithmProvider(hAlgorithm: BCRYPT_ALG_HANDLE;
  dwFlags: ULONG): NTSTATUS; stdcall; external 'bcrypt.dll';
function BCryptGetProperty(hObject: Pointer; pszProperty: PWideChar;
  pbOutput: PByte; cbOutput: ULONG; out pcbResult: ULONG;
  dwFlags: ULONG): NTSTATUS; stdcall; external 'bcrypt.dll';
function BCryptCreateHash(hAlgorithm: BCRYPT_ALG_HANDLE;
  out phHash: BCRYPT_HASH_HANDLE; pbHashObject: PByte; cbHashObject: ULONG;
  pbSecret: PByte; cbSecret, dwFlags: ULONG): NTSTATUS; stdcall;
  external 'bcrypt.dll';
function BCryptHashData(hHash: BCRYPT_HASH_HANDLE; pbInput: PByte;
  cbInput, dwFlags: ULONG): NTSTATUS; stdcall; external 'bcrypt.dll';
function BCryptFinishHash(hHash: BCRYPT_HASH_HANDLE; pbOutput: PByte;
  cbOutput, dwFlags: ULONG): NTSTATUS; stdcall; external 'bcrypt.dll';
function BCryptDestroyHash(hHash: BCRYPT_HASH_HANDLE): NTSTATUS; stdcall;
  external 'bcrypt.dll';

function WinHttpSetTimeouts(hInternet: HINTERNET; nResolveTimeout,
  nConnectTimeout, nSendTimeout, nReceiveTimeout: Integer): BOOL; stdcall;
  external 'winhttp.dll' name 'WinHttpSetTimeouts';

function OnlyDigits(const S: string): Boolean;
var
  I: Integer;
begin
  Result := S <> '';
  for I := 1 to Length(S) do
    if not (S[I] in ['0'..'9']) then
      Exit(False);
end;

function IsHexDigest(const S: string): Boolean;
var
  I: Integer;
begin
  Result := Length(S) = 64;
  if not Result then Exit;
  for I := 1 to Length(S) do
    if not (S[I] in ['0'..'9', 'a'..'f', 'A'..'F']) then
      Exit(False);
end;

procedure ResetRelease(out ARelease: TUpdateRelease);
begin
  ARelease.Version := '';
  ARelease.TagName := '';
  ARelease.DownloadURL := '';
  ARelease.AssetName := '';
  ARelease.AssetSize := 0;
  ARelease.SHA256 := '';
  ARelease.ReleaseURL := '';
  ARelease.Notes := '';
end;

function ParseSemanticVersion(const AValue: string; out AMajor, AMinor,
  APatch: Int64): Boolean;
var
  S: string;
  Parts: TStringList;
begin
  Result := False;
  AMajor := 0;
  AMinor := 0;
  APatch := 0;
  S := Trim(AValue);
  if (S <> '') and ((S[1] = 'v') or (S[1] = 'V')) then
    Delete(S, 1, 1);
  Parts := TStringList.Create;
  try
    Parts.StrictDelimiter := True;
    Parts.Delimiter := '.';
    Parts.DelimitedText := S;
    if (Parts.Count <> 3) or (not OnlyDigits(Parts[0])) or
      (not OnlyDigits(Parts[1])) or (not OnlyDigits(Parts[2])) then
      Exit;
    if (not TryStrToInt64(Parts[0], AMajor)) or
      (not TryStrToInt64(Parts[1], AMinor)) or
      (not TryStrToInt64(Parts[2], APatch)) then
      Exit;
    Result := True;
  finally
    Parts.Free;
  end;
end;

function CompareSemanticVersions(const ALeft, ARight: string;
  out AValid: Boolean): Integer;
var
  LMajor, LMinor, LPatch, RMajor, RMinor, RPatch: Int64;
begin
  Result := 0;
  AValid := ParseSemanticVersion(ALeft, LMajor, LMinor, LPatch) and
    ParseSemanticVersion(ARight, RMajor, RMinor, RPatch);
  if not AValid then
    Exit;
  if LMajor <> RMajor then
  begin
    if LMajor < RMajor then Result := -1 else Result := 1;
    Exit;
  end;
  if LMinor <> RMinor then
  begin
    if LMinor < RMinor then Result := -1 else Result := 1;
    Exit;
  end;
  if LPatch <> RPatch then
  begin
    if LPatch < RPatch then Result := -1 else Result := 1;
  end;
end;

function ParseReleaseJSON(const AJSON: string; out ARelease: TUpdateRelease;
  out AError: string): Boolean;
var
  Root, Item: TJSONData;
  Obj, AssetObj: TJSONObject;
  Assets: TJSONArray;
  I: Integer;
  Major, Minor, Patch: Int64;
  Digest, ExpectedName: string;
begin
  Result := False;
  ResetRelease(ARelease);
  AError := '';
  Root := nil;
  try
    try
      Root := GetJSON(AJSON);
    except
      on E: Exception do
      begin
        AError := 'GitHub вернул некорректный JSON: ' + E.Message;
        Exit;
      end;
    end;
    if not (Root is TJSONObject) then
    begin
      AError := 'GitHub вернул ответ неожиданного формата.';
      Exit;
    end;
    Obj := TJSONObject(Root);
    if Obj.Get('draft', False) or Obj.Get('prerelease', False) then
    begin
      AError := 'Последний релиз не является стабильным опубликованным релизом.';
      Exit;
    end;
    ARelease.TagName := Trim(Obj.Get('tag_name', ''));
    if not ParseSemanticVersion(ARelease.TagName, Major, Minor, Patch) then
    begin
      AError := 'Некорректный тег версии релиза: «' + ARelease.TagName + '».';
      Exit;
    end;
    ARelease.Version := Format('%d.%d.%d', [Major, Minor, Patch]);
    ARelease.ReleaseURL := Obj.Get('html_url', '');
    ARelease.Notes := Obj.Get('body', '');
    ExpectedName := 'Library-v' + ARelease.Version + '-win64.zip';
    Item := Obj.Find('assets');
    if not (Item is TJSONArray) then
    begin
      AError := 'В релизе отсутствует список файлов.';
      Exit;
    end;
    Assets := TJSONArray(Item);
    for I := 0 to Assets.Count - 1 do
      if Assets.Items[I] is TJSONObject then
      begin
        AssetObj := TJSONObject(Assets.Items[I]);
        if AssetObj.Get('name', '') = ExpectedName then
        begin
          ARelease.AssetName := ExpectedName;
          ARelease.DownloadURL := AssetObj.Get('browser_download_url', '');
          ARelease.AssetSize := AssetObj.Get('size', Int64(0));
          Digest := LowerCase(Trim(AssetObj.Get('digest', '')));
          if Copy(Digest, 1, 7) = 'sha256:' then
            Delete(Digest, 1, 7);
          ARelease.SHA256 := Digest;
          Break;
        end;
      end;
    if ARelease.DownloadURL = '' then
    begin
      AError := 'В релизе отсутствует архив «' + ExpectedName + '».';
      Exit;
    end;
    if (ARelease.AssetSize <= 0) then
    begin
      AError := 'Для архива обновления указан некорректный размер.';
      Exit;
    end;
    if not IsHexDigest(ARelease.SHA256) then
    begin
      AError := 'В релизе отсутствует корректная контрольная сумма SHA-256.';
      Exit;
    end;
    if Pos('https://', LowerCase(ARelease.DownloadURL)) <> 1 then
    begin
      AError := 'GitHub вернул небезопасный адрес загрузки обновления.';
      Exit;
    end;
    Result := True;
  finally
    Root.Free;
  end;
end;

function CheckLatestRelease(out ARelease: TUpdateRelease; out ANoRelease: Boolean;
  out AError: string): Boolean;
var
  StatusCode: DWORD;
  Body: string;
begin
  ResetRelease(ARelease);
  ANoRelease := False;
  AError := '';
  Result := HttpRequest('GET', GITHUB_LATEST_RELEASE_URL, '', '', StatusCode,
    Body, AError, UPDATE_TIMEOUT_MS);
  if not Result then
    Exit;
  if StatusCode = 404 then
  begin
    ANoRelease := True;
    Exit(True);
  end;
  if StatusCode <> 200 then
  begin
    if StatusCode = 403 then
      AError := 'GitHub отклонил запрос (HTTP 403). Возможно, исчерпан лимит запросов.'
    else
      AError := 'GitHub вернул HTTP ' + IntToStr(StatusCode) + '.';
    Exit(False);
  end;
  Result := ParseReleaseJSON(Body, ARelease, AError);
end;

function BytesToHex(const ABytes: array of Byte): string;
const
  Hex: array[0..15] of Char = '0123456789abcdef';
var
  I: Integer;
begin
  SetLength(Result, Length(ABytes) * 2);
  for I := 0 to High(ABytes) do
  begin
    Result[I * 2 + 1] := Hex[ABytes[I] shr 4];
    Result[I * 2 + 2] := Hex[ABytes[I] and $0F];
  end;
end;

function FileSHA256(const AFileName: string; out AHash, AError: string): Boolean;
var
  Alg: BCRYPT_ALG_HANDLE;
  Hash: BCRYPT_HASH_HANDLE;
  ObjectLength, HashLength, Returned: ULONG;
  HashObject, Digest, Buffer: array of Byte;
  Stream: TFileStream;
  ReadCount: LongInt;
begin
  Result := False;
  AHash := '';
  AError := '';
  Alg := nil;
  Hash := nil;
  Stream := nil;
  try
    try
    if BCryptOpenAlgorithmProvider(Alg, BCRYPT_SHA256_ALGORITHM, nil, 0) < 0 then
    begin
      AError := 'Не удалось открыть системный алгоритм SHA-256.';
      Exit;
    end;
    ObjectLength := 0;
    if BCryptGetProperty(Alg, BCRYPT_OBJECT_LENGTH, @ObjectLength,
      SizeOf(ObjectLength), Returned, 0) < 0 then
    begin
      AError := 'Не удалось определить параметры SHA-256.';
      Exit;
    end;
    HashLength := 0;
    if BCryptGetProperty(Alg, BCRYPT_HASH_LENGTH, @HashLength,
      SizeOf(HashLength), Returned, 0) < 0 then
    begin
      AError := 'Не удалось определить длину SHA-256.';
      Exit;
    end;
    SetLength(HashObject, ObjectLength);
    SetLength(Digest, HashLength);
    SetLength(Buffer, 65536);
    if BCryptCreateHash(Alg, Hash, @HashObject[0], Length(HashObject), nil,
      0, 0) < 0 then
    begin
      AError := 'Не удалось создать вычислитель SHA-256.';
      Exit;
    end;
    Stream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
    repeat
      ReadCount := Stream.Read(Buffer[0], Length(Buffer));
      if (ReadCount > 0) and
        (BCryptHashData(Hash, @Buffer[0], ReadCount, 0) < 0) then
      begin
        AError := 'Ошибка вычисления SHA-256.';
        Exit;
      end;
    until ReadCount = 0;
    if BCryptFinishHash(Hash, @Digest[0], Length(Digest), 0) < 0 then
    begin
      AError := 'Не удалось завершить вычисление SHA-256.';
      Exit;
    end;
    AHash := BytesToHex(Digest);
    Result := True;
    except
      on E: Exception do
        AError := 'Не удалось вычислить SHA-256: ' + E.Message;
    end;
  finally
    Stream.Free;
    if Hash <> nil then
      BCryptDestroyHash(Hash);
    if Alg <> nil then
      BCryptCloseAlgorithmProvider(Alg, 0);
  end;
end;

function DownloadFile(AThread: TUpdatePrepareThread; const AURL,
  AFileName: string; AExpectedSize: Int64; out AError: string): Boolean;
var
  Session, Connect, Request: HINTERNET;
  UC: URL_COMPONENTS;
  Host, Path, Extra: WideString;
  Port: INTERNET_PORT;
  Flags, StatusCode, StatusSize: DWORD;
  Available, BytesRead, ErrCode: DWORD;
  Buffer: array[0..65535] of Byte;
  Stream: TFileStream;
begin
  Result := False;
  AError := '';
  Session := nil;
  Connect := nil;
  Request := nil;
  Stream := nil;
  try
    try
    FillChar(UC, SizeOf(UC), 0);
    UC.dwStructSize := SizeOf(UC);
    SetLength(Host, 512);
    SetLength(Path, 4096);
    SetLength(Extra, 4096);
    UC.lpszHostName := PWideChar(Host);
    UC.dwHostNameLength := Length(Host);
    UC.lpszUrlPath := PWideChar(Path);
    UC.dwUrlPathLength := Length(Path);
    UC.lpszExtraInfo := PWideChar(Extra);
    UC.dwExtraInfoLength := Length(Extra);
    if not WinHttpCrackUrl(PWideChar(UTF8Decode(AURL)), Length(AURL), 0, @UC) then
    begin
      AError := 'Не удалось разобрать адрес загрузки, код ' +
        IntToStr(GetLastError) + '.';
      Exit;
    end;
    SetLength(Host, UC.dwHostNameLength);
    SetLength(Path, UC.dwUrlPathLength);
    SetLength(Extra, UC.dwExtraInfoLength);
    Path := Path + Extra;
    Port := UC.nPort;
    if Port = 0 then Port := INTERNET_DEFAULT_HTTPS_PORT;
    Session := WinHttpOpen('LibraryAppUpdater/1.1.1',
      WINHTTP_ACCESS_TYPE_DEFAULT_PROXY, WINHTTP_NO_PROXY_NAME,
      WINHTTP_NO_PROXY_BYPASS, 0);
    if Session = nil then
    begin
      AError := 'Не удалось открыть HTTP-сессию, код ' + IntToStr(GetLastError) + '.';
      Exit;
    end;
    if not WinHttpSetTimeouts(Session, UPDATE_TIMEOUT_MS, UPDATE_TIMEOUT_MS,
      UPDATE_TIMEOUT_MS, UPDATE_TIMEOUT_MS) then
    begin
      AError := 'Не удалось настроить таймаут загрузки.';
      Exit;
    end;
    Connect := WinHttpConnect(Session, PWideChar(Host), Port, 0);
    if Connect = nil then
    begin
      AError := 'Не удалось подключиться к серверу загрузки, код ' +
        IntToStr(GetLastError) + '.';
      Exit;
    end;
    Flags := WINHTTP_FLAG_SECURE;
    Request := WinHttpOpenRequest(Connect, 'GET', PWideChar(Path), nil,
      WINHTTP_NO_REFERER, WINHTTP_DEFAULT_ACCEPT_TYPES, Flags);
    if Request = nil then
    begin
      AError := 'Не удалось создать запрос загрузки, код ' +
        IntToStr(GetLastError) + '.';
      Exit;
    end;
    if not WinHttpSendRequest(Request, WINHTTP_NO_ADDITIONAL_HEADERS, 0,
      nil, 0, 0, 0) then
    begin
      AError := 'Не удалось отправить запрос загрузки, код ' +
        IntToStr(GetLastError) + '.';
      Exit;
    end;
    if not WinHttpReceiveResponse(Request, nil) then
    begin
      AError := 'Не удалось получить архив обновления, код ' +
        IntToStr(GetLastError) + '.';
      Exit;
    end;
    StatusCode := 0;
    StatusSize := SizeOf(StatusCode);
    WinHttpQueryHeaders(Request,
      WINHTTP_QUERY_STATUS_CODE or WINHTTP_QUERY_FLAG_NUMBER,
      WINHTTP_HEADER_NAME_BY_INDEX, @StatusCode, @StatusSize,
      WINHTTP_NO_HEADER_INDEX);
    if StatusCode <> 200 then
    begin
      AError := 'Сервер загрузки вернул HTTP ' + IntToStr(StatusCode) + '.';
      Exit;
    end;
    Stream := TFileStream.Create(AFileName, fmCreate);
    while not AThread.Terminated do
    begin
      Available := 0;
      if not WinHttpQueryDataAvailable(Request, @Available) then
      begin
        ErrCode := GetLastError;
        AError := 'Ошибка чтения архива, код ' + IntToStr(ErrCode) + '.';
        Exit;
      end;
      if Available = 0 then Break;
      if Available > SizeOf(Buffer) then Available := SizeOf(Buffer);
      BytesRead := 0;
      if not WinHttpReadData(Request, @Buffer[0], Available, @BytesRead) then
      begin
        ErrCode := GetLastError;
        AError := 'Ошибка загрузки архива, код ' + IntToStr(ErrCode) + '.';
        Exit;
      end;
      if BytesRead = 0 then Break;
      Stream.WriteBuffer(Buffer[0], BytesRead);
      Inc(AThread.FBytesDownloaded, BytesRead);
      if (AExpectedSize > 0) and (AThread.FBytesDownloaded > AExpectedSize) then
      begin
        AError := 'Размер загружаемого архива превышает заявленный.';
        Exit;
      end;
    end;
    if (AThread <> nil) and AThread.Terminated then
    begin
      AError := 'Загрузка обновления отменена.';
      Exit;
    end;
    if (AExpectedSize > 0) and (AThread.FBytesDownloaded <> AExpectedSize) then
    begin
      AError := Format('Размер архива не совпадает: ожидалось %d, получено %d байт.',
        [AExpectedSize, AThread.FBytesDownloaded]);
      Exit;
    end;
    Result := True;
    except
      on E: Exception do
        AError := 'Ошибка загрузки обновления: ' + E.Message;
    end;
  finally
    Stream.Free;
    if Request <> nil then WinHttpCloseHandle(Request);
    if Connect <> nil then WinHttpCloseHandle(Connect);
    if Session <> nil then WinHttpCloseHandle(Session);
    if (not Result) and FileExists(AFileName) then SysUtils.DeleteFile(AFileName);
  end;
end;

function ValidateAndExtractPackage(AThread: TUpdatePrepareThread;
  const AZipFile, AOutputDir: string; out AAppFile, AUpdaterFile,
  AError: string): Boolean;
var
  Unzipper: TUnZipper;
  I: Integer;
  EntryName: string;
  HasApp, HasUpdater, HasInstruction: Boolean;
begin
  Result := False;
  AError := '';
  AAppFile := '';
  AUpdaterFile := '';
  HasApp := False;
  HasUpdater := False;
  HasInstruction := False;
  Unzipper := TUnZipper.Create;
  try
    try
      Unzipper.FileName := AZipFile;
      Unzipper.UseUTF8 := True;
      Unzipper.Examine;
      if Unzipper.Entries.Count <> 3 then
      begin
        AError := 'Архив обновления должен содержать ровно три файла.';
        Exit;
      end;
      for I := 0 to Unzipper.Entries.Count - 1 do
      begin
        EntryName := Unzipper.Entries[I].ArchiveFileName;
        if EntryName = 'Library.exe' then HasApp := True
        else if EntryName = 'LibraryUpdater.exe' then HasUpdater := True
        else if EntryName = UPDATE_INSTRUCTION_FILE then HasInstruction := True
        else
        begin
          AError := 'В архиве найден неожиданный файл: ' + EntryName + '.';
          Exit;
        end;
      end;
      if (not HasApp) or (not HasUpdater) or (not HasInstruction) then
      begin
        AError := 'В архиве отсутствуют обязательные файлы обновления.';
        Exit;
      end;
      if (AThread <> nil) and AThread.Terminated then
      begin
        AError := 'Установка обновления отменена.';
        Exit;
      end;
      FreeAndNil(Unzipper);
      Unzipper := TUnZipper.Create;
      Unzipper.FileName := AZipFile;
      Unzipper.UseUTF8 := True;
      ForceDirectories(AOutputDir);
      Unzipper.OutputPath := AOutputDir;
      Unzipper.UnZipAllFiles;
      AAppFile := IncludeTrailingPathDelimiter(AOutputDir) + 'Library.exe';
      AUpdaterFile := IncludeTrailingPathDelimiter(AOutputDir) + 'LibraryUpdater.exe';
      if (not FileExists(AAppFile)) or (not FileExists(AUpdaterFile)) then
      begin
        AError := 'Не удалось извлечь исполняемые файлы обновления.';
        Exit;
      end;
      Result := True;
    except
      on E: Exception do
        AError := 'Не удалось распаковать обновление: ' + E.Message;
    end;
  finally
    Unzipper.Free;
  end;
end;

function ValidateUpdatePackage(const AZipFile, AOutputDir: string;
  out AAppFile, AUpdaterFile, AError: string): Boolean;
begin
  Result := ValidateAndExtractPackage(nil, AZipFile, AOutputDir,
    AAppFile, AUpdaterFile, AError);
end;

constructor TUpdateCheckThread.Create;
begin
  inherited Create(True);
  FreeOnTerminate := False;
end;

procedure TUpdateCheckThread.Execute;
begin
  CheckLatestRelease(FReleaseInfo, FNoRelease, FError);
end;

constructor TUpdatePrepareThread.Create(const ARelease: TUpdateRelease;
  const AWorkDir: string);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FReleaseInfo := ARelease;
  FWorkDir := IncludeTrailingPathDelimiter(AWorkDir);
  FStage := usIdle;
end;

procedure TUpdatePrepareThread.Execute;
var
  ZipFile, ExtractDir, ActualHash, HashError: string;
begin
  try
    ForceDirectories(FWorkDir);
    ZipFile := FWorkDir + FReleaseInfo.AssetName;
    ExtractDir := FWorkDir + 'package';
    FStage := usDownloading;
    if not DownloadFile(Self, FReleaseInfo.DownloadURL, ZipFile,
      FReleaseInfo.AssetSize, FError) then
      Exit;
    if Terminated then
    begin
      FError := 'Загрузка обновления отменена.';
      Exit;
    end;
    FStage := usVerifying;
    if not FileSHA256(ZipFile, ActualHash, HashError) then
    begin
      FError := HashError;
      Exit;
    end;
    if not SameText(ActualHash, FReleaseInfo.SHA256) then
    begin
      FError := 'Контрольная сумма SHA-256 архива не совпадает. Установка отменена.';
      Exit;
    end;
    FStage := usExtracting;
    if not ValidateAndExtractPackage(Self, ZipFile, ExtractDir,
      FStagedApp, FStagedUpdater, FError) then
      Exit;
    FStage := usReady;
  except
    on E: Exception do
      FError := 'Ошибка подготовки обновления: ' + E.Message;
  end;
end;

function QuoteArg(const S: string): string;
begin
  Result := '"' + StringReplace(S, '"', '\"', [rfReplaceAll]) + '"';
end;

function DirectoryWritable(const ADirectory: string): Boolean;
var
  TestFile: string;
  Stream: TFileStream;
begin
  Result := False;
  TestFile := IncludeTrailingPathDelimiter(ADirectory) +
    '.library-update-write-test-' + IntToStr(GetCurrentProcessId) + '.tmp';
  try
    Stream := TFileStream.Create(TestFile, fmCreate);
    Stream.Free;
    Result := SysUtils.DeleteFile(TestFile);
  except
    if FileExists(TestFile) then SysUtils.DeleteFile(TestFile);
  end;
end;

function LaunchPreparedUpdate(const AUpdaterFile, ANewAppFile, ACurrentAppFile,
  ALogFile, ACleanupDir: string; out AError: string): Boolean;
var
  Info: TShellExecuteInfoW;
  Verb, UpdaterW, ParamsW, TargetDir: WideString;
  Params: string;
begin
  Result := False;
  AError := '';
  if (not FileExists(AUpdaterFile)) or (not FileExists(ANewAppFile)) then
  begin
    AError := 'Подготовленные файлы обновления не найдены.';
    Exit;
  end;
  TargetDir := UTF8Decode(ExtractFilePath(ACurrentAppFile));
  Params := '--wait-pid ' + IntToStr(GetCurrentProcessId) +
    ' --source ' + QuoteArg(ANewAppFile) +
    ' --target ' + QuoteArg(ACurrentAppFile) +
    ' --restart ' + QuoteArg(ACurrentAppFile) +
    ' --log ' + QuoteArg(ALogFile) +
    ' --cleanup-dir ' + QuoteArg(ACleanupDir);
  UpdaterW := UTF8Decode(AUpdaterFile);
  ParamsW := UTF8Decode(Params);
  if DirectoryWritable(UTF8Encode(TargetDir)) then
    Verb := 'open'
  else
    Verb := 'runas';
  FillChar(Info, SizeOf(Info), 0);
  Info.cbSize := SizeOf(Info);
  Info.fMask := SEE_MASK_NOCLOSEPROCESS or SEE_MASK_FLAG_NO_UI;
  Info.lpVerb := PWideChar(Verb);
  Info.lpFile := PWideChar(UpdaterW);
  Info.lpParameters := PWideChar(ParamsW);
  Info.lpDirectory := PWideChar(TargetDir);
  Info.nShow := SW_SHOWNORMAL;
  if not ShellExecuteExW(@Info) then
  begin
    if GetLastError = ERROR_CANCELLED then
      AError := 'Запрос прав администратора отменён.'
    else
      AError := 'Не удалось запустить установщик обновления, код ' +
        IntToStr(GetLastError) + '.';
    Exit;
  end;
  if Info.hProcess <> 0 then CloseHandle(Info.hProcess);
  Result := True;
end;

end.
