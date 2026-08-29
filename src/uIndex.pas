unit uIndex;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Contnrs, uTypes, uBinaryIO, uSafeIO, uTechLog;

type
  TIndexEntry = class
  public
    Key: string;
    ID: TId;
  end;

  TSearchIndex = class
  private
    FEntries: TObjectList;
    FLog: TTechLog;
    FSafeIO: TSafeIO;
    FFileName: string;
    function CompareKey(const A, B: string): Integer;
    function FindInsertPos(const AKey: string): Integer;
    procedure WriteToStream(Sender: TObject);
    function ValidateStream(AStream: TStream): Boolean;
  public
    constructor Create(const AFileName: string; ASafeIO: TSafeIO; ALog: TTechLog);
    destructor Destroy; override;
    procedure Clear;
    procedure Add(const AKey: string; AID: TId);
    procedure Rebuild;
    procedure Save;
    function Load: Boolean;
    procedure FindContains(const AQuery: string; AOut: TList; ALimit: Integer = 0);
    function FindExactIDs(const AKey: string; AOut: TList): Integer;
    property Entries: TObjectList read FEntries;
  end;

implementation

constructor TSearchIndex.Create(const AFileName: string; ASafeIO: TSafeIO; ALog: TTechLog);
begin
  inherited Create;
  FFileName := AFileName;
  FSafeIO := ASafeIO;
  FLog := ALog;
  FEntries := TObjectList.Create(True);
end;

destructor TSearchIndex.Destroy;
begin
  FEntries.Free;
  inherited Destroy;
end;

procedure TSearchIndex.Clear;
begin
  FEntries.Clear;
end;

function TSearchIndex.CompareKey(const A, B: string): Integer;
begin
  Result := CompareText(A, B);
end;

function TSearchIndex.FindInsertPos(const AKey: string): Integer;
var
  L, R, M: Integer;
  E: TIndexEntry;
begin
  L := 0;
  R := FEntries.Count;
  while L < R do
  begin
    M := (L + R) div 2;
    E := TIndexEntry(FEntries[M]);
    if CompareKey(E.Key, AKey) < 0 then
      L := M + 1
    else
      R := M;
  end;
  Result := L;
end;

procedure TSearchIndex.Add(const AKey: string; AID: TId);
var
  E: TIndexEntry;
  Pos: Integer;
  NK: string;
begin
  NK := NormalizeKey(AKey);
  if NK = '' then
    Exit;
  E := TIndexEntry.Create;
  E.Key := NK;
  E.ID := AID;
  Pos := FindInsertPos(NK);
  FEntries.Insert(Pos, E);
end;

procedure TSearchIndex.Rebuild;
begin
  { заполнение снаружи через Clear/Add, затем Save }
end;

procedure TSearchIndex.WriteToStream(Sender: TObject);
var
  S: TStream;
  Payload: TMemoryStream;
  H: TIndexHeader;
  I: Integer;
  E: TIndexEntry;
  CRC: LongWord;
begin
  S := TStream(Sender);
  Payload := TMemoryStream.Create;
  try
    for I := 0 to FEntries.Count - 1 do
    begin
      E := TIndexEntry(FEntries[I]);
      WriteString(Payload, E.Key);
      WriteInt64(Payload, E.ID);
    end;
    CRC := CalcCRC32(Payload, 0, Payload.Size);
    FillIndexHeader(H, FEntries.Count, CRC);
    S.WriteBuffer(H, SizeOf(H));
    Payload.Position := 0;
    S.CopyFrom(Payload, Payload.Size);
  finally
    Payload.Free;
  end;
end;

function TSearchIndex.ValidateStream(AStream: TStream): Boolean;
var
  H: TIndexHeader;
  CRC: LongWord;
begin
  Result := False;
  if AStream.Size < SizeOf(H) then
    Exit;
  AStream.Position := 0;
  AStream.ReadBuffer(H, SizeOf(H));
  if not CheckIndexHeader(H) then
    Exit;
  CRC := CalcCRC32(AStream, SizeOf(H), AStream.Size - SizeOf(H));
  Result := CRC = H.PayloadCRC;
end;

procedure TSearchIndex.Save;
begin
  if not FSafeIO.WriteAtomically(FFileName, @WriteToStream, @ValidateStream) then
    raise Exception.Create('Не удалось сохранить индекс: ' + ExtractFileName(FFileName));
end;

function TSearchIndex.Load: Boolean;
var
  FS: TFileStream;
  H: TIndexHeader;
  CRC: LongWord;
  I: Integer;
  E: TIndexEntry;
begin
  Result := False;
  Clear;
  if not FileExists(FFileName) then
    Exit;
  try
    FS := TFileStream.Create(FFileName, fmOpenRead or fmShareDenyWrite);
    try
      if FS.Size < SizeOf(H) then
        Exit;
      FS.ReadBuffer(H, SizeOf(H));
      if not CheckIndexHeader(H) then
        Exit;
      CRC := CalcCRC32(FS, SizeOf(H), FS.Size - SizeOf(H));
      if CRC <> H.PayloadCRC then
        Exit;
      FS.Position := SizeOf(H);
      for I := 1 to H.EntryCount do
      begin
        E := TIndexEntry.Create;
        E.Key := ReadString(FS);
        E.ID := ReadInt64(FS);
        FEntries.Add(E);
      end;
      Result := True;
    finally
      FS.Free;
    end;
  except
    on E: Exception do
    begin
      Clear;
      if Assigned(FLog) then
        FLog.Write('Ошибка чтения индекса ' + FFileName + ': ' + E.Message);
      Result := False;
    end;
  end;
end;

procedure TSearchIndex.FindContains(const AQuery: string; AOut: TList; ALimit: Integer);
var
  Q: string;
  I: Integer;
  E: TIndexEntry;
  Seen: TList;
begin
  Q := NormalizeKey(AQuery);
  Seen := TList.Create;
  try
    for I := 0 to FEntries.Count - 1 do
    begin
      E := TIndexEntry(FEntries[I]);
      if (Q = '') or (Pos(Q, E.Key) > 0) then
      begin
        if Seen.IndexOf(Pointer(E.ID)) < 0 then
        begin
          Seen.Add(Pointer(E.ID));
          AOut.Add(Pointer(E.ID));
          if (ALimit > 0) and (AOut.Count >= ALimit) then
            Break;
        end;
      end;
    end;
  finally
    Seen.Free;
  end;
end;

function TSearchIndex.FindExactIDs(const AKey: string; AOut: TList): Integer;
var
  NK: string;
  Pos, I: Integer;
  E: TIndexEntry;
begin
  Result := 0;
  NK := NormalizeKey(AKey);
  Pos := FindInsertPos(NK);
  I := Pos;
  while I < FEntries.Count do
  begin
    E := TIndexEntry(FEntries[I]);
    if CompareKey(E.Key, NK) <> 0 then
      Break;
    AOut.Add(Pointer(E.ID));
    Inc(Result);
    Inc(I);
  end;
end;

end.
