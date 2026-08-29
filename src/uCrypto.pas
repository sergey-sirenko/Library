unit uCrypto;

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

function GenerateSalt: string;
function HashPassword(const APassword, ASalt: string): string;
function VerifyPassword(const APassword, ASalt, AHash: string): Boolean;

implementation

uses
  sha1;

function BytesToHex(const Buf: array of Byte): string;
const
  HexDigits: array[0..15] of Char = '0123456789abcdef';
var
  I: Integer;
begin
  SetLength(Result, Length(Buf) * 2);
  for I := 0 to High(Buf) do
  begin
    Result[I * 2 + 1] := HexDigits[Buf[I] shr 4];
    Result[I * 2 + 2] := HexDigits[Buf[I] and $0F];
  end;
end;

function GenerateSalt: string;
var
  Buf: array[0..15] of Byte;
  I: Integer;
begin
  Randomize;
  for I := 0 to High(Buf) do
    Buf[I] := Byte(Random(256));
  Result := BytesToHex(Buf);
end;

function HashPassword(const APassword, ASalt: string): string;
var
  Raw: RawByteString;
begin
  { SHA-1 — стандартный модуль hash Free Pascal 3.2.x }
  Raw := UTF8Encode(ASalt + #1 + APassword);
  Result := SHA1Print(SHA1String(Raw));
end;

function VerifyPassword(const APassword, ASalt, AHash: string): Boolean;
begin
  Result := SameText(HashPassword(APassword, ASalt), AHash);
end;

end.
