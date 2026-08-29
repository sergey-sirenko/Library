unit uLoginForm;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls,
  uDatabase, uTypes, uEntities, uUIFont;

type
  TLoginForm = class(TForm)
    lblTitle: TLabel;
    lblLogin: TLabel;
    lblPassword: TLabel;
    cbLogin: TComboBox;
    edtPassword: TEdit;
    btnOK: TButton;
    btnCancel: TButton;
    pnl: TPanel;
    procedure btnOKClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
  private
    FDB: TLibraryDB;
    procedure ApplyLoginLayout;
  public
    class function Execute(ADB: TLibraryDB): Boolean;
  end;

implementation

{$R *.lfm}

procedure TLoginForm.ApplyLoginLayout;
var
  Sz, TextH, FieldH, BtnH, BtnW, Gap, Margin, Y, InnerW, TitleH: Integer;
begin
  if FDB <> nil then
    Sz := ClampUIFontSize(FDB.Settings.UIFontSize)
  else
    Sz := DEFAULT_UI_FONT_SIZE;
  ApplyFormUIFont(Self, Sz);

  TextH := Canvas.TextHeight('Ag');
  FieldH := TextH + 12;
  BtnH := TextH + 14;
  Gap := Max(6, TextH div 2);
  Margin := 24;

  lblTitle.ParentFont := False;
  lblTitle.Font.Assign(Font);
  lblTitle.Font.Style := [fsBold];
  lblTitle.Font.Size := Sz + 2;
  lblTitle.Alignment := taCenter;
  lblTitle.AutoSize := False;

  lblLogin.ParentFont := True;
  lblPassword.ParentFont := True;
  lblLogin.AutoSize := True;
  lblPassword.AutoSize := True;

  Canvas.Font.Assign(lblTitle.Font);
  TitleH := Canvas.TextHeight('Ag') + 6;
  InnerW := Max(300, Canvas.TextWidth(lblTitle.Caption + 'WW'));
  Canvas.Font.Assign(Font);
  InnerW := Max(InnerW, Canvas.TextWidth('Имя пользователяWWW'));

  ClientWidth := InnerW + Margin * 2;
  pnl.Width := ClientWidth;

  Y := 16;
  lblTitle.SetBounds(Margin, Y, ClientWidth - Margin * 2, TitleH);

  Y := lblTitle.Top + lblTitle.Height + Gap + 4;
  lblLogin.Left := Margin + 16;
  lblLogin.Top := Y;

  Y := lblLogin.Top + lblLogin.Height + 4;
  cbLogin.SetBounds(lblLogin.Left, Y, ClientWidth - lblLogin.Left - Margin - 16, FieldH);

  Y := cbLogin.Top + cbLogin.Height + Gap + 4;
  lblPassword.Left := lblLogin.Left;
  lblPassword.Top := Y;

  Y := lblPassword.Top + lblPassword.Height + 4;
  edtPassword.SetBounds(lblLogin.Left, Y, cbLogin.Width, FieldH);

  BtnW := Max(90, Canvas.TextWidth('Отмена') + 28);
  Y := edtPassword.Top + edtPassword.Height + Gap + 8;
  btnOK.Width := Max(90, Canvas.TextWidth('Войти') + 28);
  btnOK.Height := BtnH;
  btnCancel.Width := BtnW;
  btnCancel.Height := BtnH;
  btnCancel.Top := Y;
  btnOK.Top := Y;
  btnCancel.Left := ClientWidth - Margin - 16 - btnCancel.Width;
  btnOK.Left := btnCancel.Left - 8 - btnOK.Width;

  ClientHeight := btnOK.Top + btnOK.Height + Margin;
  pnl.Height := ClientHeight;
end;

procedure TLoginForm.FormCreate(Sender: TObject);
begin
  Caption := 'Вход в систему';
  Position := poScreenCenter;
  BorderStyle := bsDialog;
  if (Application.Icon <> nil) and (not Application.Icon.Empty) then
    Icon.Assign(Application.Icon);
end;

procedure TLoginForm.FormShow(Sender: TObject);
var
  Title: string;
  LastLogin: string;
  I: Integer;
  U: TUser;
  SL: TStringList;
begin
  Title := EffectiveLibraryTitle(FDB.Settings.LibraryName);
  lblTitle.Caption := Title;
  Caption := Title;
  Application.Title := Title;
  cbLogin.Items.Clear;
  for I := 0 to FDB.Users.Count - 1 do
  begin
    U := TUser(FDB.Users[I]);
    if (not U.Deleted) and U.Active then
      cbLogin.Items.Add(U.Login);
  end;
  LastLogin := '';
  if FileExists(FDB.Paths.UserLayoutFile) then
  begin
    SL := TStringList.Create;
    try
      SL.LoadFromFile(FDB.Paths.UserLayoutFile);
      LastLogin := Trim(SL.Values['LastLogin']);
    finally
      SL.Free;
    end;
  end;
  cbLogin.ItemIndex := cbLogin.Items.IndexOf(LastLogin);
  if (cbLogin.ItemIndex < 0) and (cbLogin.Items.Count > 0) then
    cbLogin.ItemIndex := cbLogin.Items.IndexOf(DEFAULT_ADMIN_LOGIN);
  if (cbLogin.ItemIndex < 0) and (cbLogin.Items.Count > 0) then
    cbLogin.ItemIndex := 0;
  ApplyLoginLayout;
  edtPassword.Text := '';
  edtPassword.SetFocus;
end;

procedure TLoginForm.btnOKClick(Sender: TObject);
var
  Err: string;
  SL: TStringList;
begin
  if cbLogin.ItemIndex < 0 then
  begin
    MessageDlg('Выберите пользователя.', mtError, [mbOK], 0);
    Exit;
  end;
  if FDB.Login(Trim(cbLogin.Text), edtPassword.Text, Err) then
  begin
    SL := TStringList.Create;
    try
      if FileExists(FDB.Paths.UserLayoutFile) then
        SL.LoadFromFile(FDB.Paths.UserLayoutFile);
      SL.Values['LastLogin'] := Trim(cbLogin.Text);
      SL.SaveToFile(FDB.Paths.UserLayoutFile);
    finally
      SL.Free;
    end;
    ModalResult := mrOK
  end
  else
    MessageDlg(Err, mtError, [mbOK], 0);
end;

class function TLoginForm.Execute(ADB: TLibraryDB): Boolean;
var
  F: TLoginForm;
begin
  F := TLoginForm.Create(nil);
  try
    F.FDB := ADB;
    Result := F.ShowModal = mrOK;
  finally
    F.Free;
  end;
end;

end.
