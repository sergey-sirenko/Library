program LibraApp;

{$mode objfpc}{$H+}

{$IFDEF WINDOWS}
{$R Library.rc}
{$ENDIF}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  Interfaces, Forms, SysUtils, Dialogs,
  uMainForm, uLoginForm, uDatabase, uTypes;

var
  DB: TLibraryDB;
  Err: string;
  Path, BackupErr: string;
begin
  RequireDerivedFormResource := True;
  Application.Scaled := True;
  Application.Initialize;
  Application.Title := APP_NAME;
  { иконка окна берётся из ресурса MAINICON (Library.rc) }

  DB := TLibraryDB.Create;
  try
    if not DB.Open(Err) then
    begin
      MessageDlg('Не удалось открыть данные:' + LineEnding + Err + LineEnding +
        'Каталог Data: ' + DB.Paths.DataDir, mtError, [mbOK], 0);
      Exit;
    end;
    if Err <> '' then
      MessageDlg('Предупреждение проверки целостности:' + LineEnding + Err + LineEnding +
        'Рекомендуется восстановить данные из резервной копии.', mtWarning, [mbOK], 0);

    { размер UI берётся из Settings.UIFontSize в формах через ApplyFormUIFont }
    Application.Title := EffectiveLibraryTitle(DB.Settings.LibraryName);

    if (not DB.MaybeAutoBackup(Path, BackupErr)) and (BackupErr <> '') then
      MessageDlg(BackupErr, mtWarning, [mbOK], 0);

    if not TLoginForm.Execute(DB) then
      Exit;

    Application.CreateForm(TMainForm, MainForm);
    MainForm.DB := DB;
    if (Application.Icon <> nil) and (not Application.Icon.Empty) then
      MainForm.Icon.Assign(Application.Icon);
    Application.Run;
  finally
    DB.Free;
  end;
end.
