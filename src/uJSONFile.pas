unit uJSONFile;

{$mode objfpc}{$H+}

interface

uses Classes, SysUtils, fpjson;

function ReadJSONFile(const AFile: string): TJSONData;
function WriteJSONFile(const AFile: string; AData: TJSONData; out AError: string): Boolean;

implementation

uses jsonparser, uSafeIO;

type
  TJSONWriter = class
    Text: string;
    procedure WriteStream(Sender: TObject);
    function Validate(AStream: TStream): Boolean;
  end;

function ReadJSONFile(const AFile: string): TJSONData;
var Stream: TFileStream;
begin
  Stream := TFileStream.Create(AFile, fmOpenRead or fmShareDenyWrite);
  try
    Result := GetJSON(Stream);
  finally
    Stream.Free;
  end;
end;

procedure TJSONWriter.WriteStream(Sender: TObject);
begin
  if Text <> '' then
    TStream(Sender).WriteBuffer(Text[1], Length(Text));
end;

function TJSONWriter.Validate(AStream: TStream): Boolean;
var Data: TJSONData;
begin
  Data := nil;
  try
    try
      Data := GetJSON(AStream);
      Result := Data <> nil;
    except
      Result := False;
    end;
  finally
    Data.Free;
  end;
end;

function WriteJSONFile(const AFile: string; AData: TJSONData; out AError: string): Boolean;
var Writer: TJSONWriter; IO: TSafeIO;
begin
  AError := '';
  Writer := TJSONWriter.Create;
  IO := TSafeIO.Create(nil);
  try
    try
      Writer.Text := AData.AsJSON;
      Result := ForceDirectories(ExtractFileDir(AFile)) and
        IO.WriteAtomically(AFile, @Writer.WriteStream, @Writer.Validate);
    except
      Result := False;
    end;
    if not Result then
      AError := 'Не удалось сохранить файл. Проверьте доступ к папке и свободное место.';
  finally
    IO.Free;
    Writer.Free;
  end;
end;

end.
