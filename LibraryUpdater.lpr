program LibraryUpdater;

{$mode objfpc}{$H+}
{$apptype GUI}

uses
  Classes, SysUtils, Windows, ShellApi;

const
  WAIT_TIMEOUT_MS = 120000;
  MOVEFILE_WRITE_THROUGH_FLAG = $00000008;

var
  SilentMode: Boolean = False;
  CommandArgs: TStringList;

type
  TLPWSTRArray = array[0..0] of LPWSTR;
  PLPWSTRArray = ^TLPWSTRArray;

procedure LoadCommandArgs;
var
  ArgValues: pLPWSTR;
  Count, I: LongInt;
begin
  CommandArgs := TStringList.Create;
  Count := 0;
  ArgValues := CommandLineToArgvW(GetCommandLineW, @Count);
  if ArgValues <> nil then
  begin
    for I := 0 to Count - 1 do
      CommandArgs.Add(UTF8Encode(WideString(PLPWSTRArray(ArgValues)^[I])));
    LocalFree(HLOCAL(ArgValues));
  end
  else
    for I := 0 to ParamCount do
      CommandArgs.Add(ParamStr(I));
end;

function Wide(const S: string): WideString;
begin
  Result := UTF8Decode(S);
end;

procedure WriteLog(const AFileName, AMessage: string);
var
  F: TextFile;
begin
  if AFileName = '' then Exit;
  try
    ForceDirectories(ExtractFilePath(AFileName));
    AssignFile(F, AFileName);
    if FileExists(AFileName) then Append(F) else Rewrite(F);
    try
      WriteLn(F, FormatDateTime('yyyy-mm-dd hh:nn:ss', Now) + ' ' + AMessage);
    finally
      CloseFile(F);
    end;
  except
  end;
end;

procedure ShowFailure(const AMessage: string);
var
  W: WideString;
begin
  if SilentMode then Exit;
  W := Wide(AMessage);
  MessageBoxW(0, PWideChar(W), 'Обновление библиотеки', MB_OK or MB_ICONERROR);
end;

function ReadOption(const AName: string; out AValue: string): Boolean;
var
  I: Integer;
begin
  Result := False;
  AValue := '';
  for I := 1 to CommandArgs.Count - 2 do
    if CommandArgs[I] = AName then
    begin
      AValue := CommandArgs[I + 1];
      Exit(True);
    end;
end;

function HasOption(const AName: string): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 1 to CommandArgs.Count - 1 do
    if CommandArgs[I] = AName then
      Exit(True);
end;

function WaitForApplication(APid: DWORD): Boolean;
var
  Handle: THandle;
begin
  Result := False;
  if APid = 0 then
    Exit(True);
  Handle := OpenProcess(SYNCHRONIZE, False, APid);
  if Handle = 0 then
    Exit(True);
  try
    Result := WaitForSingleObject(Handle, WAIT_TIMEOUT_MS) = WAIT_OBJECT_0;
  finally
    CloseHandle(Handle);
  end;
end;

function MoveReplace(const ASource, ADestination: string): Boolean;
var
  SourceW, DestinationW: WideString;
begin
  SourceW := Wide(ASource);
  DestinationW := Wide(ADestination);
  Result := MoveFileExW(PWideChar(SourceW), PWideChar(DestinationW),
    MOVEFILE_REPLACE_EXISTING or MOVEFILE_WRITE_THROUGH_FLAG);
end;

function DeleteWide(const AFileName: string): Boolean;
var
  W: WideString;
begin
  W := Wide(AFileName);
  Result := DeleteFileW(PWideChar(W));
end;

function StartApplication(const AFileName: string): Boolean;
var
  Info: TShellExecuteInfoW;
  FileW, DirW: WideString;
begin
  FileW := Wide(AFileName);
  DirW := Wide(ExtractFilePath(AFileName));
  FillChar(Info, SizeOf(Info), 0);
  Info.cbSize := SizeOf(Info);
  Info.fMask := SEE_MASK_FLAG_NO_UI;
  Info.lpVerb := 'open';
  Info.lpFile := PWideChar(FileW);
  Info.lpDirectory := PWideChar(DirW);
  Info.nShow := SW_SHOWNORMAL;
  Result := ShellExecuteExW(@Info);
end;

procedure ScheduleDirectoryCleanup(const ADirectory: string);
var
  DirectoryW, ItemW: WideString;
  SR: TSearchRec;
  Item: string;
begin
  if ADirectory = '' then Exit;
  if FindFirst(IncludeTrailingPathDelimiter(ADirectory) + '*', faAnyFile, SR) = 0 then
  try
    repeat
      if (SR.Name = '.') or (SR.Name = '..') then Continue;
      Item := IncludeTrailingPathDelimiter(ADirectory) + SR.Name;
      if (SR.Attr and faDirectory) <> 0 then
        ScheduleDirectoryCleanup(Item)
      else
      begin
        ItemW := Wide(Item);
        MoveFileExW(PWideChar(ItemW), nil, MOVEFILE_DELAY_UNTIL_REBOOT);
      end;
    until FindNext(SR) <> 0;
  finally
    SysUtils.FindClose(SR);
  end;
  DirectoryW := Wide(ADirectory);
  MoveFileExW(PWideChar(DirectoryW), nil, MOVEFILE_DELAY_UNTIL_REBOOT);
end;

procedure ScheduleCleanup(const ADirectory: string);
var
  SelfW: WideString;
begin
  ScheduleDirectoryCleanup(ADirectory);
  SelfW := Wide(CommandArgs[0]);
  MoveFileExW(PWideChar(SelfW), nil, MOVEFILE_DELAY_UNTIL_REBOOT);
end;

var
  WaitPidText, SourceFile, TargetFile, RestartFile, LogFile, CleanupDir: string;
  OldFile, ErrorText: string;
  WaitPid: DWORD;
  HadOld: Boolean;
begin
  SetMultiByteConversionCodePage(CP_UTF8);
  SetMultiByteFileSystemCodePage(CP_UTF8);
  LoadCommandArgs;
  SilentMode := HasOption('--silent');
  if (not ReadOption('--wait-pid', WaitPidText)) or
    (not TryStrToDWord(WaitPidText, WaitPid)) or
    (not ReadOption('--source', SourceFile)) or
    (not ReadOption('--target', TargetFile)) or
    (not ReadOption('--restart', RestartFile)) or
    (not ReadOption('--log', LogFile)) then
  begin
    ShowFailure('Некорректные параметры установщика обновления.');
    Halt(2);
  end;
  ReadOption('--cleanup-dir', CleanupDir);
  WriteLog(LogFile, 'Запущена установка обновления.');
  WriteLog(LogFile, 'Источник: ' + SourceFile + '; назначение: ' + TargetFile + '.');
  if not WaitForApplication(WaitPid) then
  begin
    ErrorText := 'Приложение не завершилось за две минуты. Обновление отменено.';
    WriteLog(LogFile, ErrorText);
    ShowFailure(ErrorText);
    Halt(3);
  end;
  OldFile := TargetFile + '.old';
  if FileExists(OldFile) then DeleteWide(OldFile);
  HadOld := FileExists(TargetFile);
  if HadOld and (not MoveReplace(TargetFile, OldFile)) then
  begin
    ErrorText := 'Не удалось сохранить предыдущую версию Library.exe, код ' +
      IntToStr(GetLastError) + '.';
    WriteLog(LogFile, ErrorText);
    ShowFailure(ErrorText);
    Halt(4);
  end;
  if not MoveReplace(SourceFile, TargetFile) then
  begin
    ErrorText := 'Не удалось установить новый Library.exe, код ' +
      IntToStr(GetLastError) + '.';
    if HadOld then MoveReplace(OldFile, TargetFile);
    WriteLog(LogFile, ErrorText + ' Выполнен откат.');
    ShowFailure(ErrorText + LineEnding + 'Восстановлена предыдущая версия.');
    Halt(5);
  end;
  if not StartApplication(RestartFile) then
  begin
    ErrorText := 'Не удалось запустить обновлённую программу, код ' +
      IntToStr(GetLastError) + '.';
    DeleteWide(TargetFile);
    if HadOld then MoveReplace(OldFile, TargetFile);
    WriteLog(LogFile, ErrorText + ' Выполнен откат.');
    ShowFailure(ErrorText + LineEnding + 'Восстановлена предыдущая версия.');
    Halt(6);
  end;
  WriteLog(LogFile, 'Обновление установлено, программа перезапущена.');
  ScheduleCleanup(CleanupDir);
end.
