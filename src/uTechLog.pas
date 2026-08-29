unit uTechLog;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, uAppPaths, uTypes;

type
  TTechLog = class
  private
    FPaths: TAppPaths;
  public
    constructor Create(APaths: TAppPaths);
    procedure Write(const AMessage: string);
    procedure WriteFmt(const AFmt: string; const Args: array of const);
  end;

implementation

constructor TTechLog.Create(APaths: TAppPaths);
begin
  inherited Create;
  FPaths := APaths;
end;

procedure TTechLog.Write(const AMessage: string);
var
  F: TextFile;
  Line: string;
begin
  try
    ForceDirectories(FPaths.LogsDir);
    AssignFile(F, FPaths.TechLogFile);
    if FileExists(FPaths.TechLogFile) then
      Append(F)
    else
      Rewrite(F);
    try
      Line := FormatDateTime('yyyy-mm-dd hh:nn:ss', Now) + ' [' + APP_VERSION + '] ' + AMessage;
      WriteLn(F, Line);
    finally
      CloseFile(F);
    end;
  except
    { сбой техжурнала не должен останавливать работу }
  end;
end;

procedure TTechLog.WriteFmt(const AFmt: string; const Args: array of const);
begin
  Write(Format(AFmt, Args));
end;

end.
