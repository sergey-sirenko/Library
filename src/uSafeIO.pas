unit uSafeIO;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, uTechLog;

type
  TValidateProc = function(AStream: TStream): Boolean of object;

  TSafeIO = class
  private
    FLog: TTechLog;
  public
    constructor Create(ALog: TTechLog);
    function WriteAtomically(const ATargetFile: string; AWriteProc: TNotifyEvent;
      AValidate: TValidateProc): Boolean;
  end;

implementation

constructor TSafeIO.Create(ALog: TTechLog);
begin
  inherited Create;
  FLog := ALog;
end;

function TSafeIO.WriteAtomically(const ATargetFile: string; AWriteProc: TNotifyEvent;
  AValidate: TValidateProc): Boolean;
var
  TempFile, BackupFile: string;
  MS: TMemoryStream;
  FS: TFileStream;
begin
  Result := False;
  TempFile := ATargetFile + '.tmp';
  BackupFile := ATargetFile + '.bak';
  MS := TMemoryStream.Create;
  try
    try
      AWriteProc(MS);
      MS.Position := 0;
      if Assigned(AValidate) and (not AValidate(MS)) then
      begin
        if Assigned(FLog) then
          FLog.Write('Проверка временных данных не пройдена: ' + ATargetFile);
        Exit;
      end;

      FS := TFileStream.Create(TempFile, fmCreate);
      try
        MS.Position := 0;
        FS.CopyFrom(MS, MS.Size);
      finally
        FS.Free;
      end;

      FS := TFileStream.Create(TempFile, fmOpenRead or fmShareDenyWrite);
      try
        if Assigned(AValidate) and (not AValidate(FS)) then
        begin
          if Assigned(FLog) then
            FLog.Write('Проверка временного файла не пройдена: ' + TempFile);
          Exit;
        end;
      finally
        FS.Free;
      end;

      if FileExists(BackupFile) then
        DeleteFile(BackupFile);
      if FileExists(ATargetFile) then
      begin
        if not RenameFile(ATargetFile, BackupFile) then
        begin
          if Assigned(FLog) then
            FLog.Write('Не удалось переименовать рабочий файл: ' + ATargetFile);
          Exit;
        end;
      end;

      if not RenameFile(TempFile, ATargetFile) then
      begin
        if FileExists(BackupFile) then
          RenameFile(BackupFile, ATargetFile);
        if Assigned(FLog) then
          FLog.Write('Не удалось заменить рабочий файл: ' + ATargetFile);
        Exit;
      end;

      FS := TFileStream.Create(ATargetFile, fmOpenRead or fmShareDenyWrite);
      try
        if Assigned(AValidate) and (not AValidate(FS)) then
        begin
          if Assigned(FLog) then
            FLog.Write('Повторная проверка рабочего файла не пройдена: ' + ATargetFile);
          if FileExists(BackupFile) then
          begin
            DeleteFile(ATargetFile);
            RenameFile(BackupFile, ATargetFile);
          end;
          Exit;
        end;
      finally
        FS.Free;
      end;

      if FileExists(BackupFile) then
        DeleteFile(BackupFile);
      if FileExists(TempFile) then
        DeleteFile(TempFile);
      Result := True;
    except
      on E: Exception do
      begin
        if Assigned(FLog) then
          FLog.Write('Ошибка безопасной записи ' + ATargetFile + ': ' + E.Message);
        if FileExists(TempFile) then
          DeleteFile(TempFile);
        if (not FileExists(ATargetFile)) and FileExists(BackupFile) then
          RenameFile(BackupFile, ATargetFile);
      end;
    end;
  finally
    MS.Free;
  end;
end;

end.
