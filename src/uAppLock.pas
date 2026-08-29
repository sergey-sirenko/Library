unit uAppLock;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, uAppPaths;

type
  TAppLock = class
  private
    FPaths: TAppPaths;
    FLocked: Boolean;
    FLockStream: TFileStream;
  public
    constructor Create(APaths: TAppPaths);
    destructor Destroy; override;
    function TryAcquire(out AError: string): Boolean;
    procedure Release;
    property Locked: Boolean read FLocked;
  end;

implementation

constructor TAppLock.Create(APaths: TAppPaths);
begin
  inherited Create;
  FPaths := APaths;
  FLocked := False;
  FLockStream := nil;
end;

destructor TAppLock.Destroy;
begin
  Release;
  inherited Destroy;
end;

function TAppLock.TryAcquire(out AError: string): Boolean;
begin
  Result := False;
  AError := '';

  if not ForceDirectories(FPaths.DataDir) then
  begin
    AError := 'Не удалось создать каталог данных:' + LineEnding + FPaths.DataDir +
      LineEnding + 'Проверьте путь и права на запись.';
    Exit;
  end;

  try
    if not FileExists(FPaths.LockFile) then
    begin
      FLockStream := TFileStream.Create(FPaths.LockFile, fmCreate);
      FreeAndNil(FLockStream);
    end;

    FLockStream := TFileStream.Create(FPaths.LockFile, fmOpenReadWrite or fmShareExclusive);
    FLockStream.Size := 0;
    with TStringList.Create do
    try
      Add('PID=' + IntToStr(GetProcessID));
      Add('StartedAt=' + FormatDateTime('yyyy-mm-dd hh:nn:ss', Now));
      Add('DataDir=' + FPaths.DataDir);
      SaveToStream(FLockStream);
    finally
      Free;
    end;

    FLocked := True;
    Result := True;
  except
    on E: EFCreateError do
      AError := 'Не удалось создать файл блокировки:' + LineEnding + FPaths.LockFile +
        LineEnding + E.Message + LineEnding + 'Проверьте права на запись в каталог Data.';
    on E: EFOpenError do
      if FileExists(FPaths.LockFile) then
        AError := 'Каталог данных уже используется другим экземпляром программы.' + LineEnding +
          'Закройте другой экземпляр или дождитесь завершения работы.' + LineEnding +
          'Каталог Data: ' + FPaths.DataDir
      else
        AError := 'Не удалось открыть файл блокировки:' + LineEnding + FPaths.LockFile +
          LineEnding + E.Message + LineEnding + 'Проверьте путь и права на запись.';
    on E: Exception do
      AError := 'Не удалось получить блокировку каталога Data:' + LineEnding +
        FPaths.DataDir + LineEnding + E.Message;
  end;

  if not Result then
  begin
    FreeAndNil(FLockStream);
    FLocked := False;
  end;
end;

procedure TAppLock.Release;
begin
  if FLocked then
  begin
    FreeAndNil(FLockStream);
    if FileExists(FPaths.LockFile) then
      SysUtils.DeleteFile(FPaths.LockFile);
    FLocked := False;
  end;
end;

end.
