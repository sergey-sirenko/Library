program UpdaterProbe;

{$mode objfpc}{$H+}

uses
  Classes, SysUtils;

var
  Marker: TFileStream;
begin
  Marker := TFileStream.Create(ParamStr(0) + '.started', fmCreate);
  Marker.Free;
end.
