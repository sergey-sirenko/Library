unit uBookHttp;

{$mode objfpc}{$H+}

interface

uses Classes, SysUtils;

type
  { Одна сессия и общий бюджет времени на источник, включая все его запросы. }
  TBookHttpSession = class
  private
    FState: IInterface;
    FDeadline: QWord;
  public
    constructor Create(ATimeoutMs: Cardinal = 15000);
    function Request(const AMethod, AURL, ABody: string;
      out AStatus: Cardinal; out AResponse, AError: string): Boolean; virtual;
  end;

function FormEncode(const S: string): string;
function BookRequestTarget(const URL: string): string;

implementation

uses Windows, WinHttp;

type
  IState = interface
    ['{8C60F0A7-EDCB-43CB-8366-85653ACBE329}']
    function Instance: TObject;
  end;

  TSessionState = class(TInterfacedObject, IState)
    Handle: HINTERNET;
    function Instance: TObject;
    destructor Destroy; override;
  end;

  TRequestState = class(TInterfacedObject, IState)
    Session: IInterface;
    Event: THandle;
    Method, URL, Body, Response, Error: string;
    Status, Timeout: Cardinal;
    Success: Boolean;
    function Instance: TObject;
    procedure Run;
    destructor Destroy; override;
  end;

  TRequestThread = class(TThread)
    State: IState;
    procedure Execute; override;
  end;

function WinHttpSetTimeouts(H: HINTERNET; A, B, C, D: Integer): BOOL;
  stdcall; external 'winhttp.dll' name 'WinHttpSetTimeouts';

function FormEncode(const S: string): string;
var C: AnsiChar;
begin
  Result := '';
  for C in S do
    if C in ['a'..'z', 'A'..'Z', '0'..'9', '-', '_', '.', '~'] then
      Result := Result + C
    else
      Result := Result + '%' + IntToHex(Ord(C), 2);
end;

function BookRequestTarget(const URL: string): string;
var I, J: Integer;
begin
  I := Pos('://', URL) + 3;
  while (I <= Length(URL)) and not (URL[I] in ['/', '?', '#']) do Inc(I);
  Result := Copy(URL, I, MaxInt);
  J := Pos('#', Result);
  if J > 0 then SetLength(Result, J - 1);
  if (Result = '') or (Result[1] = '?') then Result := '/' + Result;
end;

function TSessionState.Instance: TObject;
begin
  Result := Self;
end;

destructor TSessionState.Destroy;
begin
  if Handle <> nil then WinHttpCloseHandle(Handle);
  inherited Destroy;
end;

function TRequestState.Instance: TObject;
begin
  Result := Self;
end;

destructor TRequestState.Destroy;
begin
  if Event <> 0 then CloseHandle(Event);
  inherited Destroy;
end;

procedure TRequestState.Run;
var
  S: TSessionState;
  UC: URL_COMPONENTS;
  WURL, Host, Path, WMethod, Headers: UnicodeString;
  Connection, Req: HINTERNET;
  ReadCount, Size: DWORD;
  Buffer: array[0..8191] of AnsiChar;
  Chunk: string;
begin
  Connection := nil;
  Req := nil;
  try
    try
      S := TSessionState((Session as IState).Instance);
      if S.Handle = nil then
        S.Handle := WinHttpOpen('LibraryBookLookup/1.0',
          WINHTTP_ACCESS_TYPE_DEFAULT_PROXY, nil, nil, 0);
      if S.Handle = nil then RaiseLastOSError;
      if not WinHttpSetTimeouts(S.Handle, Timeout, Timeout, Timeout, Timeout) then
        RaiseLastOSError;
      FillChar(UC, SizeOf(UC), 0);
      UC.dwStructSize := SizeOf(UC);
      WURL := UTF8Decode(URL);
      SetLength(Host, Length(WURL));
      SetLength(Path, Length(WURL));
      UC.lpszHostName := PWideChar(Host);
      UC.dwHostNameLength := Length(Host);
      UC.lpszUrlPath := PWideChar(Path);
      UC.dwUrlPathLength := Length(Path);
      if not WinHttpCrackUrl(PWideChar(WURL), Length(WURL), 0, @UC) then
        RaiseLastOSError;
      if UC.nScheme <> INTERNET_SCHEME_HTTPS then
        raise Exception.Create('Ожидался адрес HTTPS.');
      SetLength(Host, UC.dwHostNameLength);
      { Сохраняем query string целиком. }
      Path := UTF8Decode(BookRequestTarget(URL));
      Connection := WinHttpConnect(S.Handle, PWideChar(Host), UC.nPort, 0);
      if Connection = nil then RaiseLastOSError;
      WMethod := UTF8Decode(Method);
      Req := WinHttpOpenRequest(Connection, PWideChar(WMethod), PWideChar(Path),
        nil, nil, nil, WINHTTP_FLAG_SECURE);
      if Req = nil then RaiseLastOSError;
      Headers := 'Content-Type: application/x-www-form-urlencoded'#13#10;
      if not WinHttpSendRequest(Req, PWideChar(Headers), Length(Headers),
        PAnsiChar(Body), Length(Body), Length(Body), 0) then RaiseLastOSError;
      if not WinHttpReceiveResponse(Req, nil) then RaiseLastOSError;
      Size := SizeOf(Status);
      if not WinHttpQueryHeaders(Req, WINHTTP_QUERY_STATUS_CODE or
        WINHTTP_QUERY_FLAG_NUMBER, nil, @Status, @Size, nil) then RaiseLastOSError;
      repeat
        ReadCount := 0;
        if not WinHttpReadData(Req, @Buffer[0], SizeOf(Buffer), @ReadCount) then
          RaiseLastOSError;
        if ReadCount = 0 then Break;
        if Length(Response) + ReadCount > 10 * 1024 * 1024 then
          raise Exception.Create('Ответ источника превышает 10 МБ.');
        SetString(Chunk, PAnsiChar(@Buffer[0]), ReadCount);
        Response := Response + Chunk;
      until False;
      Success := True;
    except
      on E: Exception do Error := E.Message;
    end;
  finally
    if Req <> nil then WinHttpCloseHandle(Req);
    if Connection <> nil then WinHttpCloseHandle(Connection);
  end;
end;

procedure TRequestThread.Execute;
var Job: TRequestState;
begin
  Job := TRequestState(State.Instance);
  Job.Run;
  SetEvent(Job.Event);
end;

constructor TBookHttpSession.Create(ATimeoutMs: Cardinal);
begin
  inherited Create;
  FState := TSessionState.Create;
  FDeadline := GetTickCount64 + ATimeoutMs;
end;

function TBookHttpSession.Request(const AMethod, AURL, ABody: string;
  out AStatus: Cardinal; out AResponse, AError: string): Boolean;
var
  State: IState;
  Job: TRequestState;
  Worker: TRequestThread;
  Remaining, NowTick: QWord;
begin
  Result := False;
  AStatus := 0;
  AResponse := '';
  AError := 'Истекло время ожидания источника (15 секунд).';
  NowTick := GetTickCount64;
  if NowTick >= FDeadline then Exit;
  Remaining := FDeadline - NowTick;
  Job := TRequestState.Create;
  State := Job;
  Job.Session := FState;
  Job.Timeout := Remaining;
  Job.Method := AMethod;
  Job.URL := AURL;
  Job.Body := ABody;
  Job.Event := CreateEvent(nil, True, False, nil);
  if Job.Event = 0 then RaiseLastOSError;
  Worker := TRequestThread.Create(True);
  Worker.FreeOnTerminate := True;
  Worker.State := State;
  Worker.Start;
  { При таймауте рабочий поток завершит только сетевой запрос и освободит
    свою сессию. Он не обращается к форме, кэшу или данным библиотеки. }
  if WaitForSingleObject(Job.Event, Remaining) <> WAIT_OBJECT_0 then
  begin
    FDeadline := 0;
    Exit;
  end;
  AStatus := Job.Status;
  AResponse := Job.Response;
  AError := Job.Error;
  Result := Job.Success;
end;

end.
