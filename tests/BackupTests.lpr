program BackupTests;

{$mode objfpc}{$H+}

uses
  Classes, SysUtils, FileUtil, uDatabase;

var
  Failures: Integer = 0;

procedure Check(ACondition: Boolean; const AMessage: string);
begin
  if ACondition then
    WriteLn('[OK] ', AMessage)
  else
  begin
    WriteLn('[FAIL] ', AMessage);
    Inc(Failures);
  end;
end;

procedure WriteText(const AFileName, AText: string);
var
  Lines: TStringList;
begin
  ForceDirectories(ExtractFileDir(AFileName));
  Lines := TStringList.Create;
  try
    Lines.Text := AText;
    Lines.SaveToFile(AFileName);
  finally
    Lines.Free;
  end;
end;

function ReadText(const AFileName: string): string;
var
  Lines: TStringList;
begin
  Lines := TStringList.Create;
  try
    Lines.LoadFromFile(AFileName);
    Result := Lines.Text;
  finally
    Lines.Free;
  end;
end;

function CountDirectories(const ADir: string): Integer;
var
  SR: TSearchRec;
begin
  Result := 0;
  if FindFirst(IncludeTrailingPathDelimiter(ADir) + '*', faDirectory, SR) <> 0 then
    Exit;
  try
    repeat
      if (SR.Name <> '.') and (SR.Name <> '..') and
        ((SR.Attr and faDirectory) <> 0) then
        Inc(Result);
    until FindNext(SR) <> 0;
  finally
    FindClose(SR);
  end;
end;

procedure TestFullBackup;
var
  Root, BackupPath, Err, LegacyDir, CorruptDir, SafetyName: string;
  DB: TLibraryDB;
  SR: TSearchRec;
  BackupCountBefore, BackupCountAfter: Integer;
begin
  Root := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'LibraryBackupTests-' + IntToStr(GetTickCount64) + PathDelim;
  ForceDirectories(Root);
  WriteText(Root + 'Library.exe', 'application');
  WriteText(Root + 'LibraryUpdater.exe', 'updater');
  WriteText(Root + 'INSTALL.md', 'installation');
  WriteText(Root + 'GridLayout.cfg', 'grid-original');
  WriteText(Root + 'UserLayout.cfg', 'user-original');
  DB := TLibraryDB.Create(Root);
  try
    Check(DB.Open(Err), 'тестовая база открыта: ' + Err);
    WriteText(DB.Paths.CoversDir + 'cover.jpg', 'cover-original');
    WriteText(DB.Paths.DataDir + 'ignored.tmp', 'temporary');
    Check(DB.CreateBackup(BackupPath, Err), 'полная копия создана: ' + Err);
    Check(FileExists(BackupPath + 'Library.exe'), 'сохранён Library.exe');
    Check(FileExists(BackupPath + 'LibraryUpdater.exe'), 'сохранён LibraryUpdater.exe');
    Check(FileExists(BackupPath + 'INSTALL.md'), 'сохранён INSTALL.md');
    Check(FileExists(BackupPath + 'RESTORE.txt'), 'создана инструкция восстановления');
    Check(FileExists(BackupPath + 'Covers' + PathDelim + 'cover.jpg'),
      'сохранена обложка');
    Check(not FileExists(BackupPath + 'Data' + PathDelim + 'ignored.tmp'),
      'временный файл Data исключён');
    Check(Pos('BackupFormatVersion=2', ReadText(BackupPath + 'manifest.txt')) > 0,
      'манифест содержит версию формата');

    WriteText(DB.Paths.CoversDir + 'cover.jpg', 'cover-changed');
    WriteText(DB.Paths.CoversDir + 'extra.jpg', 'extra');
    WriteText(DB.Paths.GridLayoutFile, 'grid-changed');
    BackupCountBefore := CountDirectories(DB.Paths.BackupDir);
    Check(DB.RestoreBackup(BackupPath, Err), 'полная копия восстановлена: ' + Err);
    Check(Pos('cover-original', ReadText(DB.Paths.CoversDir + 'cover.jpg')) > 0,
      'обложка восстановлена');
    Check(not FileExists(DB.Paths.CoversDir + 'extra.jpg'),
      'лишняя обложка удалена');
    Check(Pos('grid-original', ReadText(DB.Paths.GridLayoutFile)) > 0,
      'раскладка восстановлена');
    BackupCountAfter := 0;
    SafetyName := '';
    if FindFirst(DB.Paths.BackupDir + '*', faDirectory, SR) = 0 then
    try
      repeat
        if (SR.Name <> '.') and (SR.Name <> '..') and
          ((SR.Attr and faDirectory) <> 0) then
        begin
          Inc(BackupCountAfter);
          if IncludeTrailingPathDelimiter(DB.Paths.BackupDir + SR.Name) <>
            IncludeTrailingPathDelimiter(BackupPath) then
            SafetyName := SR.Name;
        end;
      until FindNext(SR) <> 0;
    finally
      FindClose(SR);
    end;
    Check((BackupCountAfter = BackupCountBefore + 1) and (SafetyName <> ''),
      'перед восстановлением создана отдельная страховочная копия');

    LegacyDir := DB.Paths.BackupDir + 'legacy' + PathDelim;
    ForceDirectories(LegacyDir + 'Data');
    Check(not DB.RestoreBackup(LegacyDir, Err) and
      (Pos('старая', LowerCase(Err)) > 0),
      'старая Data-only копия отклонена');

    CorruptDir := DB.Paths.BackupDir + 'corrupt' + PathDelim;
    CopyDirTree(BackupPath, CorruptDir, [cffOverwriteFile]);
    WriteText(CorruptDir + 'manifest.txt', 'BackupFormatVersion=broken');
    Check(not DB.RestoreBackup(CorruptDir, Err),
      'повреждённый манифест отклонён');

    DeleteFile(Root + 'LibraryUpdater.exe');
    BackupCountBefore := CountDirectories(DB.Paths.BackupDir);
    Check(not DB.CreateBackup(SafetyName, Err),
      'копия без updater не создаётся');
    Check(CountDirectories(DB.Paths.BackupDir) = BackupCountBefore,
      'незавершённая копия удалена');
  finally
    DB.Free;
    DeleteDirectory(Root, False);
  end;
end;

begin
  TestFullBackup;
  if Failures <> 0 then
    Halt(1);
  WriteLn('Все тесты резервного копирования пройдены.');
end.
