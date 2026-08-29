unit uBinaryIO;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, uTypes;

type
  TDataHeader = packed record
    Signature: array[0..7] of AnsiChar;
    Version: LongWord;
    RecordCount: LongWord;
    NextID: Int64;
    PayloadCRC: LongWord;
    Reserved: LongWord;
  end;

  TIndexHeader = packed record
    Signature: array[0..7] of AnsiChar;
    Version: LongWord;
    EntryCount: LongWord;
    PayloadCRC: LongWord;
    Reserved: LongWord;
  end;

procedure WriteString(AStream: TStream; const S: string);
function ReadString(AStream: TStream): string;
procedure WriteBool(AStream: TStream; V: Boolean);
function ReadBool(AStream: TStream): Boolean;
procedure WriteInt64(AStream: TStream; V: Int64);
function ReadInt64(AStream: TStream): Int64;
procedure WriteInteger(AStream: TStream; V: Integer);
function ReadInteger(AStream: TStream): Integer;
procedure WriteDateTime(AStream: TStream; V: TDateTime);
function ReadDateTime(AStream: TStream): TDateTime;
function CalcCRC32(AStream: TStream; AFrom, ACount: Int64): LongWord;
procedure FillDataHeader(out H: TDataHeader; ACount: LongWord; ANextID: Int64; ACRC: LongWord);
procedure FillIndexHeader(out H: TIndexHeader; ACount: LongWord; ACRC: LongWord);
function CheckDataHeader(const H: TDataHeader): Boolean;
function CheckIndexHeader(const H: TIndexHeader): Boolean;

implementation

uses
  crc;

procedure WriteString(AStream: TStream; const S: string);
var
  Raw: RawByteString;
  Len: LongWord;
begin
  Raw := UTF8Encode(S);
  Len := Length(Raw);
  AStream.WriteBuffer(Len, SizeOf(Len));
  if Len > 0 then
    AStream.WriteBuffer(Raw[1], Len);
end;

function ReadString(AStream: TStream): string;
var
  Len: LongWord;
  Raw: RawByteString;
begin
  AStream.ReadBuffer(Len, SizeOf(Len));
  SetLength(Raw, Len);
  if Len > 0 then
    AStream.ReadBuffer(Raw[1], Len);
  Result := UTF8Decode(Raw);
end;

procedure WriteBool(AStream: TStream; V: Boolean);
var
  B: Byte;
begin
  if V then B := 1 else B := 0;
  AStream.WriteBuffer(B, 1);
end;

function ReadBool(AStream: TStream): Boolean;
var
  B: Byte;
begin
  AStream.ReadBuffer(B, 1);
  Result := B <> 0;
end;

procedure WriteInt64(AStream: TStream; V: Int64);
begin
  AStream.WriteBuffer(V, SizeOf(V));
end;

function ReadInt64(AStream: TStream): Int64;
begin
  AStream.ReadBuffer(Result, SizeOf(Result));
end;

procedure WriteInteger(AStream: TStream; V: Integer);
begin
  AStream.WriteBuffer(V, SizeOf(V));
end;

function ReadInteger(AStream: TStream): Integer;
begin
  AStream.ReadBuffer(Result, SizeOf(Result));
end;

procedure WriteDateTime(AStream: TStream; V: TDateTime);
begin
  AStream.WriteBuffer(V, SizeOf(V));
end;

function ReadDateTime(AStream: TStream): TDateTime;
begin
  AStream.ReadBuffer(Result, SizeOf(Result));
end;

function CalcCRC32(AStream: TStream; AFrom, ACount: Int64): LongWord;
var
  Buf: array[0..8191] of Byte;
  Left, N: Int64;
  CrcVal: LongWord;
begin
  CrcVal := 0;
  AStream.Position := AFrom;
  Left := ACount;
  while Left > 0 do
  begin
    if Left > Length(Buf) then
      N := Length(Buf)
    else
      N := Left;
    AStream.ReadBuffer(Buf[0], N);
    CrcVal := CRC32(CrcVal, @Buf[0], N);
    Dec(Left, N);
  end;
  Result := CrcVal;
end;

procedure FillDataHeader(out H: TDataHeader; ACount: LongWord; ANextID: Int64; ACRC: LongWord);
var
  I: Integer;
  Sig: string;
begin
  FillChar(H, SizeOf(H), 0);
  Sig := DATA_SIGNATURE;
  for I := 1 to Length(Sig) do
    if I <= 8 then
      H.Signature[I - 1] := AnsiChar(Sig[I]);
  H.Version := FORMAT_VERSION;
  H.RecordCount := ACount;
  H.NextID := ANextID;
  H.PayloadCRC := ACRC;
end;

procedure FillIndexHeader(out H: TIndexHeader; ACount: LongWord; ACRC: LongWord);
var
  I: Integer;
  Sig: string;
begin
  FillChar(H, SizeOf(H), 0);
  Sig := INDEX_SIGNATURE;
  for I := 1 to Length(Sig) do
    if I <= 8 then
      H.Signature[I - 1] := AnsiChar(Sig[I]);
  H.Version := FORMAT_VERSION;
  H.EntryCount := ACount;
  H.PayloadCRC := ACRC;
end;

function CheckDataHeader(const H: TDataHeader): Boolean;
var
  Sig: string;
  I: Integer;
begin
  SetLength(Sig, 8);
  for I := 0 to 7 do
    Sig[I + 1] := Char(H.Signature[I]);
  Result := (TrimRight(Sig) = DATA_SIGNATURE) and (H.Version >= 1) and
    (H.Version <= FORMAT_VERSION);
end;

function CheckIndexHeader(const H: TIndexHeader): Boolean;
var
  Sig: string;
  I: Integer;
begin
  SetLength(Sig, 8);
  for I := 0 to 7 do
    Sig[I + 1] := Char(H.Signature[I]);
  Result := (TrimRight(Sig) = INDEX_SIGNATURE) and (H.Version = FORMAT_VERSION);
end;

end.
