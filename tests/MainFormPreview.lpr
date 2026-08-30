program MainFormPreview;

{$mode objfpc}{$H+}

uses
  Interfaces, Forms, SysUtils, Dialogs, uMainForm, uDatabase;

var
  DB: TLibraryDB;
  Err, RootDir: string;
begin
  RequireDerivedFormResource := True;
  Application.Scaled := True;
  Application.Initialize;
  if ParamCount = 1 then
    RootDir := ExpandFileName(ParamStr(1))
  else
    RootDir := IncludeTrailingPathDelimiter(GetTempDir(False)) + 'LibraryUIQA';
  DB := TLibraryDB.Create(RootDir);
  try
    if not DB.Open(Err) then
    begin
      MessageDlg(Err, mtError, [mbOK], 0);
      Exit;
    end;
    if not DB.Login('admin', 'admin', Err) then
    begin
      MessageDlg(Err, mtError, [mbOK], 0);
      Exit;
    end;
    Application.CreateForm(TMainForm, MainForm);
    MainForm.DB := DB;
    Application.Run;
  finally
    DB.Free;
  end;
end.
