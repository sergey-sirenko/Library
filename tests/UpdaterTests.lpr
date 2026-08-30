program UpdaterTests;

{$mode objfpc}{$H+}

uses
  Classes, SysUtils, FileUtil, uUpdater;

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

procedure TestVersions;
var
  Major, Minor, Patch: Int64;
  Valid: Boolean;
begin
  Check(ParseSemanticVersion('1.2.3', Major, Minor, Patch) and
    (Major = 1) and (Minor = 2) and (Patch = 3), 'обычная версия');
  Check(ParseSemanticVersion('v10.20.300', Major, Minor, Patch) and
    (Major = 10) and (Minor = 20) and (Patch = 300), 'версия с префиксом v');
  Check(not ParseSemanticVersion('1.2', Major, Minor, Patch),
    'неполная версия отклоняется');
  Check(not ParseSemanticVersion('1.2.3-beta', Major, Minor, Patch),
    'prerelease-суффикс отклоняется');
  Check(CompareSemanticVersions('1.2.0', '1.1.9', Valid) = 1,
    'более новая версия');
  Check(Valid, 'сравнение новых версий валидно');
  Check(CompareSemanticVersions('1.0.0', '1.0.0', Valid) = 0,
    'равные версии');
  Check(CompareSemanticVersions('1.0.0', '2.0.0', Valid) = -1,
    'более старая версия');
  CompareSemanticVersions('bad', '1.0.0', Valid);
  Check(not Valid, 'некорректная версия отмечается как ошибка');
end;

procedure TestReleaseJSON;
const
  Digest = '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
var
  JSON, Err: string;
  ReleaseInfo: TUpdateRelease;
begin
  JSON := '{"tag_name":"v1.2.3","draft":false,"prerelease":false,' +
    '"html_url":"https://github.com/sergey-sirenko/Library/releases/tag/v1.2.3",' +
    '"body":"Описание","assets":[{' +
    '"name":"Library-v1.2.3-win64.zip","size":12345,' +
    '"digest":"sha256:' + Digest + '",' +
    '"browser_download_url":"https://github.com/download.zip"}]}' ;
  Check(ParseReleaseJSON(JSON, ReleaseInfo, Err), 'корректный JSON релиза');
  Check(ReleaseInfo.Version = '1.2.3', 'версия извлечена из JSON');
  Check(ReleaseInfo.SHA256 = Digest, 'SHA-256 извлечён из JSON');

  JSON := StringReplace(JSON, 'sha256:' + Digest, '', []);
  Check(not ParseReleaseJSON(JSON, ReleaseInfo, Err),
    'релиз без SHA-256 отклоняется');

  JSON := '{"tag_name":"v1.2.3","draft":false,"prerelease":true,"assets":[]}';
  Check(not ParseReleaseJSON(JSON, ReleaseInfo, Err),
    'предварительный релиз отклоняется');
end;

procedure TestSHA256;
const
  EmptySHA256 = 'e3b0c44298fc1c149afbf4c8996fb924' +
    '27ae41e4649b934ca495991b7852b855';
var
  FileName, Hash, Err: string;
  Stream: TFileStream;
begin
  FileName := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'LibraryUpdaterTests-' + IntToStr(GetTickCount64) + '.tmp';
  Stream := TFileStream.Create(FileName, fmCreate);
  Stream.Free;
  try
    Check(FileSHA256(FileName, Hash, Err), 'вычисление SHA-256 файла');
    Check(Hash = EmptySHA256, 'SHA-256 пустого файла');
  finally
    DeleteFile(FileName);
  end;
end;

procedure TestPackage(const AZipFile: string);
var
  OutputDir, AppFile, UpdaterFile, Err: string;
begin
  OutputDir := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'LibraryPackageTests-' + IntToStr(GetTickCount64);
  try
    Check(ValidateUpdatePackage(AZipFile, OutputDir, AppFile, UpdaterFile, Err),
      'проверка и распаковка release-архива: ' + Err);
    Check(FileExists(AppFile), 'в архиве найден Library.exe');
    Check(FileExists(UpdaterFile), 'в архиве найден LibraryUpdater.exe');
    Check(FileExists(IncludeTrailingPathDelimiter(OutputDir) +
      UPDATE_INSTRUCTION_FILE), 'в архиве найдена инструкция');
  finally
    if DirectoryExists(OutputDir) then
      DeleteDirectory(OutputDir, False);
  end;
end;

begin
  TestVersions;
  TestReleaseJSON;
  TestSHA256;
  if ParamCount = 1 then
    TestPackage(ParamStr(1));
  if Failures <> 0 then
  begin
    WriteLn('Ошибок: ', Failures);
    Halt(1);
  end;
  WriteLn('Все тесты обновления пройдены.');
end.
