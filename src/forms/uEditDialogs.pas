unit uEditDialogs;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls,
  Calendar, Grids, uTypes, uEntities, uDatabase, uUIFont;

function EditBookDialog(ADB: TLibraryDB; ABook: TBook; out AResultID: TId): Boolean;
function EditCopyDialog(ADB: TLibraryDB; ACopy: TCopy; ABookID: TId; out AResultID: TId): Boolean;
function EditReaderDialog(ADB: TLibraryDB; AReader: TReader; out AResultID: TId): Boolean;
function EditCategoryDialog(ADB: TLibraryDB; ACat: TCategory; out AResultID: TId): Boolean;
function EditLocationDialog(ADB: TLibraryDB; ALoc: TLocation; out AResultID: TId): Boolean;
function EditUserDialog(ADB: TLibraryDB; AUser: TUser; out AResultID: TId): Boolean;
function IssueLoanDialog(ADB: TLibraryDB; out AResultID: TId): Boolean;
function PickDateDialog(ADB: TLibraryDB; const ATitle: string; var ADate: TDateTime): Boolean;
function ImportRecognizedBooksDialog(ADB: TLibraryDB; AItems: TList;
  AFailures: TStrings; const AStats: TRecognitionStats): Boolean;

implementation

uses
  LazUTF8, FPImage, FPReadJPEG, FPReadPNG, IntfGraphics, uOpenLibrary;

function FieldHeight(AForm: TForm): Integer;
begin
  Result := AForm.Canvas.TextHeight('Ag') + 12;
end;

function CardLayoutUserKey(ADB: TLibraryDB; const AKey, ASuffix: string): string;
var
  UID: TId;
begin
  UID := 0;
  if (ADB <> nil) and (ADB.CurrentUser <> nil) then
    UID := ADB.CurrentUser.ID;
  Result := 'User.' + IntToStr(UID) + '.Card.' + AKey + '.' + ASuffix;
end;

procedure LoadCardFormSize(ADB: TLibraryDB; AForm: TForm; const AKey: string);
var
  SL: TStringList;
  Fn: string;
  W, H: Integer;
begin
  if (ADB = nil) or (AForm = nil) then
    Exit;
  Fn := ADB.Paths.UserLayoutFile;
  if not FileExists(Fn) then
    Exit;
  SL := TStringList.Create;
  try
    try
      SL.LoadFromFile(Fn);
      W := StrToIntDef(SL.Values[CardLayoutUserKey(ADB, AKey, 'Width')], 0);
      H := StrToIntDef(SL.Values[CardLayoutUserKey(ADB, AKey, 'Height')], 0);
      if (W >= AForm.Constraints.MinWidth) and (W > 0) then
        AForm.Width := W;
      if (H >= AForm.Constraints.MinHeight) and (H > 0) then
        AForm.Height := H;
    except
      { размер карточки не критичен }
    end;
  finally
    SL.Free;
  end;
end;

procedure SaveCardFormSize(ADB: TLibraryDB; AForm: TForm; const AKey: string);
var
  SL: TStringList;
  Fn: string;
begin
  if (ADB = nil) or (AForm = nil) then
    Exit;
  Fn := ADB.Paths.UserLayoutFile;
  SL := TStringList.Create;
  try
    try
      if FileExists(Fn) then
        SL.LoadFromFile(Fn);
      SL.Values[CardLayoutUserKey(ADB, AKey, 'Width')] := IntToStr(AForm.Width);
      SL.Values[CardLayoutUserKey(ADB, AKey, 'Height')] := IntToStr(AForm.Height);
      SL.SaveToFile(Fn);
    except
      { размер карточки не критичен }
    end;
  finally
    SL.Free;
  end;
end;

function LoadCardLayoutID(ADB: TLibraryDB; const AKey,
  ASuffix: string): TId;
var
  SL: TStringList;
  Fn: string;
begin
  Result := 0;
  if (ADB = nil) or (ADB.CurrentUser = nil) then
    Exit;
  Fn := ADB.Paths.UserLayoutFile;
  if not FileExists(Fn) then
    Exit;
  SL := TStringList.Create;
  try
    try
      SL.LoadFromFile(Fn);
      Result := StrToInt64Def(
        SL.Values[CardLayoutUserKey(ADB, AKey, ASuffix)], 0);
    except
      Result := 0;
    end;
  finally
    SL.Free;
  end;
end;

procedure SaveCardLayoutID(ADB: TLibraryDB; const AKey,
  ASuffix: string; AValue: TId);
var
  SL: TStringList;
  Fn: string;
begin
  if (ADB = nil) or (ADB.CurrentUser = nil) then
    Exit;
  Fn := ADB.Paths.UserLayoutFile;
  SL := TStringList.Create;
  try
    try
      if FileExists(Fn) then
        SL.LoadFromFile(Fn);
      SL.Values[CardLayoutUserKey(ADB, AKey, ASuffix)] := IntToStr(AValue);
      SL.SaveToFile(Fn);
    except
      { последнее место хранения не критично для сохранения книги }
    end;
  finally
    SL.Free;
  end;
end;

procedure PrepareCardForm(AForm: TForm);
begin
  AForm.BorderStyle := bsSizeable;
  AForm.Position := poScreenCenter;
end;

procedure SizeCardLabel(ALabel: TLabel; AForm: TForm; const ACaption: string; AWidth: Integer);
begin
  ALabel.Font.Assign(AForm.Font);
  ALabel.AutoSize := False;
  ALabel.Caption := ACaption;
  ALabel.Height := AForm.Canvas.TextHeight('Ag') + 4;
  ALabel.Width := Max(AWidth, AForm.Canvas.TextWidth(ACaption) + 8);
  ALabel.Anchors := [akLeft, akTop];
end;

function InputPanel(AOwner: TWinControl; const ACaption: string; var ATop: Integer;
  AWidth: Integer; out AEdit: TEdit): TLabel;
var
  H: Integer;
  F: TForm;
begin
  F := TForm(GetParentForm(AOwner));
  Result := TLabel.Create(AOwner);
  Result.Parent := AOwner;
  Result.Left := 16;
  Result.Top := ATop;
  if F <> nil then
  begin
    SizeCardLabel(Result, F, ACaption, AWidth);
    H := FieldHeight(F);
  end
  else
  begin
    Result.Caption := ACaption;
    Result.AutoSize := False;
    Result.Height := Result.Canvas.TextHeight('Ag') + 4;
    H := Result.Height + 12;
  end;
  AEdit := TEdit.Create(AOwner);
  AEdit.Parent := AOwner;
  AEdit.Left := 16;
  AEdit.Top := Result.Top + Result.Height + 4;
  AEdit.Width := AWidth;
  AEdit.Height := H;
  AEdit.Anchors := [akLeft, akTop, akRight];
  ATop := AEdit.Top + AEdit.Height + 8;
end;

function InputPanelWithButton(AOwner: TWinControl; const ACaption: string;
  var ATop: Integer; AWidth: Integer; const AButtonCaption: string;
  out AEdit: TEdit; out AButton: TButton): TLabel;
var
  ButtonWidth: Integer;
  F: TForm;
begin
  Result := InputPanel(AOwner, ACaption, ATop, AWidth, AEdit);
  AButton := TButton.Create(AOwner);
  AButton.Parent := AOwner;
  AButton.Caption := AButtonCaption;
  F := TForm(GetParentForm(AOwner));
  if F <> nil then
    ButtonWidth := Max(90, Max(
      F.Canvas.TextWidth(AButtonCaption),
      F.Canvas.TextWidth('Загрузка...')) + 28)
  else
    ButtonWidth := 90;
  AButton.SetBounds(AEdit.Left + AWidth - ButtonWidth, AEdit.Top,
    ButtonWidth, AEdit.Height);
  AButton.Anchors := [akTop, akRight];
  AEdit.Width := Max(80, AWidth - ButtonWidth - 8);
end;

function InputCombo(AOwner: TWinControl; const ACaption: string; var ATop: Integer;
  AWidth: Integer; out ACombo: TComboBox): TLabel;
var
  H: Integer;
  F: TForm;
begin
  F := TForm(GetParentForm(AOwner));
  Result := TLabel.Create(AOwner);
  Result.Parent := AOwner;
  Result.Left := 16;
  Result.Top := ATop;
  if F <> nil then
  begin
    SizeCardLabel(Result, F, ACaption, AWidth);
    H := FieldHeight(F);
  end
  else
  begin
    Result.Caption := ACaption;
    Result.AutoSize := False;
    Result.Height := Result.Canvas.TextHeight('Ag') + 4;
    H := Result.Height + 12;
  end;
  ACombo := TComboBox.Create(AOwner);
  ACombo.Parent := AOwner;
  ACombo.Left := 16;
  ACombo.Top := Result.Top + Result.Height + 4;
  ACombo.Width := AWidth;
  ACombo.Height := H;
  ACombo.Style := csDropDownList;
  ACombo.Anchors := [akLeft, akTop, akRight];
  ATop := ACombo.Top + ACombo.Height + 8;
end;

procedure PlaceDialogButtons(AForm: TForm; var ATop: Integer;
  out AOK, ACancel: TButton; const AOKCaption: string = 'Сохранить');
var
  H, W: Integer;
begin
  H := FieldHeight(AForm);
  W := Max(90, AForm.Canvas.TextWidth('Отмена') + 28);
  { Сначала высота клиентской области — иначе akBottom считает
    отрицательный отступ (кнопки уже ниже текущего ClientHeight)
    и после ресайза уезжают за нижний край. }
  AForm.ClientHeight := ATop + H + 16;
  AOK := TButton.Create(AForm);
  AOK.Parent := AForm;
  AOK.Caption := AOKCaption;
  AOK.ModalResult := mrNone;
  AOK.Default := True;
  AOK.Width := Max(W, AForm.Canvas.TextWidth(AOKCaption) + 28);
  AOK.Height := H;
  ACancel := TButton.Create(AForm);
  ACancel.Parent := AForm;
  ACancel.Caption := 'Отмена';
  ACancel.ModalResult := mrCancel;
  ACancel.Cancel := True;
  ACancel.Width := W;
  ACancel.Height := H;
  ACancel.Top := ATop;
  AOK.Top := ATop;
  ACancel.Left := AForm.ClientWidth - 16 - ACancel.Width;
  AOK.Left := ACancel.Left - 8 - AOK.Width;
  AOK.Anchors := [akRight, akBottom];
  ACancel.Anchors := [akRight, akBottom];
  AForm.Constraints.MinWidth := AForm.Width;
  AForm.Constraints.MinHeight := AForm.Height;
end;

type
  TBookDlgHelper = class
  public
    DB: TLibraryDB;
    Form: TForm;
    Book: TBook;
    eTitle, eAuthors, eYear, ePublisher, eISBN, eDesc, eCover, eInv: TEdit;
    btnFillISBN: TButton;
    cbCat, cbLoc: TComboBox;
    FieldsPanel, CoverPanel: TPanel;
    CoverPreview: TImage;
    CoverPlaceholder: TLabel;
    btnOK: TButton;
    ExternalCategoryIndex: Integer;
    ResultID: TId;
    Saved: Boolean;
    function FindActiveCategory(const AName: string): TCategory;
    procedure SelectExternalCategory(const AName: string);
    procedure UpdateCoverPreview;
    procedure CoverPathChange(Sender: TObject);
    procedure FormResize(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure FillISBNClick(Sender: TObject);
    procedure ISBNKeyPress(Sender: TObject; var Key: Char);
    procedure OKClick(Sender: TObject);
  end;

  TCopyDlgHelper = class
  public
    DB: TLibraryDB;
    Form: TForm;
    CopyEntity: TCopy;
    BookID: TId;
    eInv, eNote: TEdit;
    cbCond, cbLoc: TComboBox;
    ResultID: TId;
    Saved: Boolean;
    procedure OKClick(Sender: TObject);
  end;

  TReaderDlgHelper = class
  public
    DB: TLibraryDB;
    Form: TForm;
    Reader: TReader;
    eName, ePhone, eAddress, eContacts, eNote, eBlock: TEdit;
    cbStatus: TComboBox;
    ResultID: TId;
    Saved: Boolean;
    procedure OKClick(Sender: TObject);
  end;

  TCategoryDlgHelper = class
  public
    DB: TLibraryDB;
    Form: TForm;
    Cat: TCategory;
    eName, eCode, eDesc: TEdit;
    ResultID: TId;
    Saved: Boolean;
    procedure OKClick(Sender: TObject);
  end;

  TLocationDlgHelper = class
  public
    DB: TLibraryDB;
    Form: TForm;
    Loc: TLocation;
    eName, eDesc: TEdit;
    ResultID: TId;
    Saved: Boolean;
    procedure OKClick(Sender: TObject);
  end;

  TUserDlgHelper = class
  public
    DB: TLibraryDB;
    Form: TForm;
    User: TUser;
    eLogin, eDisplay, ePass: TEdit;
    cbRole: TComboBox;
    chkActive: TCheckBox;
    ResultID: TId;
    Saved: Boolean;
    procedure OKClick(Sender: TObject);
  end;

  TIssueLoanDlgHelper = class
  public
    DB: TLibraryDB;
    Form: TForm;
    eInv: TEdit;
    edtSearch: TEdit;
    lblBook: TLabel;
    lbReaders: TListBox;
    ResultID: TId;
    Saved: Boolean;
    procedure ClearBookCaption;
    procedure DoFindInv;
    procedure FindInvClick(Sender: TObject);
    procedure InvKeyPress(Sender: TObject; var Key: Char);
    procedure InvExit(Sender: TObject);
    procedure InvChange(Sender: TObject);
    procedure DoSearch;
    procedure SearchClick(Sender: TObject);
    procedure SearchKeyPress(Sender: TObject; var Key: Char);
    procedure OKClick(Sender: TObject);
  end;

  TRecognizedImportDlgHelper = class
  public
    DB: TLibraryDB;
    Form: TForm;
    Grid: TStringGrid;
    Location: TComboBox;
    Problems: TMemo;
    Items: TList;
    Saved: Boolean;
    procedure SaveClick(Sender: TObject);
  end;

function TBookDlgHelper.FindActiveCategory(const AName: string): TCategory;
var
  I: Integer;
  Category: TCategory;
begin
  for I := 0 to DB.Categories.Count - 1 do
  begin
    Category := TCategory(DB.Categories[I]);
    if (not Category.Deleted) and
      (UTF8CompareText(Trim(Category.Name), Trim(AName)) = 0) then
      Exit(Category);
  end;
  Result := nil;
end;

procedure TBookDlgHelper.SelectExternalCategory(const AName: string);
var
  I: Integer;
  Category: TCategory;
begin
  if Trim(AName) = '' then
    Exit;
  if (ExternalCategoryIndex >= 0) and
    (ExternalCategoryIndex < cbCat.Items.Count) and
    (cbCat.Items.Objects[ExternalCategoryIndex] = nil) then
  begin
    cbCat.Items.Delete(ExternalCategoryIndex);
    ExternalCategoryIndex := -1;
  end;
  for I := 0 to cbCat.Items.Count - 1 do
    if cbCat.Items.Objects[I] <> nil then
    begin
      Category := TCategory(cbCat.Items.Objects[I]);
      if UTF8CompareText(Trim(Category.Name), Trim(AName)) = 0 then
      begin
        cbCat.ItemIndex := I;
        Exit;
      end;
    end;
  ExternalCategoryIndex := cbCat.Items.Add(Trim(AName));
  cbCat.ItemIndex := ExternalCategoryIndex;
end;

procedure TBookDlgHelper.UpdateCoverPreview;
var
  FileName: string;
  ImageData: TLazIntfImage;
  Reader: TFPCustomImageReader;
begin
  if (CoverPreview = nil) or (CoverPlaceholder = nil) then
    Exit;
  FileName := Trim(eCover.Text);
  if (FileName = '') and (Book <> nil) and (Book.CoverFile <> '') then
    FileName := DB.Paths.CoversDir + Book.CoverFile
  else if (FileName <> '') and not FileExists(FileName) and
    (ExtractFilePath(FileName) = '') then
    FileName := DB.Paths.CoversDir + FileName;
  CoverPreview.Picture.Clear;
  CoverPlaceholder.Visible := True;
  CoverPlaceholder.Caption := 'Нет обложки';
  if (FileName = '') or not FileExists(FileName) then
    Exit;
  try
    ImageData := TLazIntfImage.Create(0, 0);
    try
      if SameText(ExtractFileExt(FileName), '.png') then
        Reader := TFPReaderPNG.Create
      else
        Reader := TFPReaderJPEG.Create;
      try
        ImageData.LoadFromFile(FileName, Reader);
        CoverPreview.Picture.Bitmap.LoadFromIntfImage(ImageData);
      finally
        Reader.Free;
      end;
    finally
      ImageData.Free;
    end;
    CoverPlaceholder.Visible := False;
  except
    CoverPreview.Picture.Clear;
    CoverPlaceholder.Caption := 'Не удалось открыть обложку';
  end;
end;

procedure TBookDlgHelper.CoverPathChange(Sender: TObject);
begin
  UpdateCoverPreview;
end;

procedure TBookDlgHelper.FormResize(Sender: TObject);
begin
  if (FieldsPanel = nil) or (CoverPanel = nil) then
    Exit;
  FieldsPanel.Width := Max(300, CoverPanel.Left - 8);
end;

procedure TBookDlgHelper.FormShow(Sender: TObject);
begin
  if (eISBN <> nil) and eISBN.CanFocus then
  begin
    eISBN.SetFocus;
    eISBN.SelectAll;
  end;
end;

procedure TBookDlgHelper.FillISBNClick(Sender: TObject);
var
  Data: TOpenLibraryBookData;
  WarningText, Err, OldCaption: string;
  OldCursor: TCursor;
begin
  OldCaption := btnFillISBN.Caption;
  OldCursor := Screen.Cursor;
  btnFillISBN.Enabled := False;
  btnFillISBN.Caption := 'Загрузка...';
  Screen.Cursor := crHourGlass;
  try
    if not LookupBookByISBN(eISBN.Text, DB.Paths.OpenLibraryCacheDir,
      DB.Settings.GoogleBooksApiKey, Data, WarningText, Err) then
    begin
      MessageDlg(Err, mtError, [mbOK], 0);
      Exit;
    end;
    if Data.Title <> '' then
      eTitle.Text := Data.Title;
    if Data.Authors <> '' then
      eAuthors.Text := Data.Authors;
    if Data.Year > 0 then
      eYear.Text := IntToStr(Data.Year);
    if Data.Publisher <> '' then
      ePublisher.Text := Data.Publisher;
    if Data.Description <> '' then
      eDesc.Text := Data.Description;
    if Data.CategoryName <> '' then
      SelectExternalCategory(Data.CategoryName);
    if Data.CoverCacheFile <> '' then
      eCover.Text := Data.CoverCacheFile;
    UpdateCoverPreview;
    if WarningText <> '' then
      MessageDlg('Данные книги заполнены.' + LineEnding + LineEnding +
        WarningText, mtWarning, [mbOK], 0);
  finally
    Screen.Cursor := OldCursor;
    btnFillISBN.Caption := OldCaption;
    btnFillISBN.Enabled := True;
  end;
end;

procedure TBookDlgHelper.ISBNKeyPress(Sender: TObject; var Key: Char);
begin
  if Key <> #13 then
    Exit;
  Key := #0;
  FillISBNClick(Sender);
end;

procedure TBookDlgHelper.OKClick(Sender: TObject);
var
  NewBook: TBook;
  NewCategory: TCategory;
  Err: string;
  Year: Integer;
  CatID, LocID: TId;
  Ok: Boolean;
begin
  if Trim(eTitle.Text) = '' then
  begin
    MessageDlg('Укажите название книги.', mtError, [mbOK], 0);
    Exit;
  end;
  Year := StrToIntDef(Trim(eYear.Text), 0);
  LocID := 0;
  if Book = nil then
  begin
    if Trim(eInv.Text) = '' then
    begin
      MessageDlg('Укажите инвентарный номер.', mtError, [mbOK], 0);
      Exit;
    end;
    if DB.FindCopyByInv(eInv.Text) <> nil then
    begin
      MessageDlg('Инвентарный номер уже существует.', mtError, [mbOK], 0);
      Exit;
    end;
    if (cbLoc.ItemIndex < 0) or
      (cbLoc.Items.Objects[cbLoc.ItemIndex] = nil) then
    begin
      MessageDlg('Укажите место хранения.', mtError, [mbOK], 0);
      Exit;
    end;
    LocID := TLocation(cbLoc.Items.Objects[cbLoc.ItemIndex]).ID;
  end;
  CatID := 0;
  if (cbCat.ItemIndex >= 0) and (cbCat.Items.Objects[cbCat.ItemIndex] <> nil) then
    CatID := TCategory(cbCat.Items.Objects[cbCat.ItemIndex]).ID;
  if (cbCat.ItemIndex = ExternalCategoryIndex) and
    (ExternalCategoryIndex >= 0) then
  begin
    NewCategory := FindActiveCategory(cbCat.Items[ExternalCategoryIndex]);
    if NewCategory = nil then
      NewCategory := DB.AddCategory(cbCat.Items[ExternalCategoryIndex], '', '', Err);
    if NewCategory = nil then
    begin
      MessageDlg(Err, mtError, [mbOK], 0);
      Exit;
    end;
    CatID := NewCategory.ID;
  end;
  if Book = nil then
  begin
    NewBook := DB.AddBookWithInitialCopy(eTitle.Text, eAuthors.Text, Year,
      ePublisher.Text, eISBN.Text, CatID, eDesc.Text, Trim(eCover.Text),
      eInv.Text, LocID, Err);
    Ok := NewBook <> nil;
    if Ok then
    begin
      ResultID := NewBook.ID;
      SaveCardLayoutID(DB, 'Book', 'LastLocationID', LocID);
    end;
  end
  else
  begin
    Ok := DB.UpdateBook(Book, eTitle.Text, eAuthors.Text, Year, ePublisher.Text,
      eISBN.Text, CatID, eDesc.Text, Trim(eCover.Text), Err);
    if Ok then
      ResultID := Book.ID;
  end;
  if Ok then
  begin
    Saved := True;
    Form.ModalResult := mrOK;
  end
  else
    MessageDlg(Err, mtError, [mbOK], 0);
end;

procedure TCopyDlgHelper.OKClick(Sender: TObject);
var
  Err: string;
  LocID: TId;
  NewCopy: TCopy;
  Ok: Boolean;
begin
  if (cbLoc.ItemIndex < 0) or (cbLoc.Items.Objects[cbLoc.ItemIndex] = nil) then
  begin
    MessageDlg('Укажите место хранения.', mtError, [mbOK], 0);
    Exit;
  end;
  LocID := TLocation(cbLoc.Items.Objects[cbLoc.ItemIndex]).ID;
  if CopyEntity = nil then
  begin
    NewCopy := DB.AddCopy(BookID, eInv.Text, cbCond.Text, LocID, eNote.Text, Date, Err);
    Ok := NewCopy <> nil;
    if Ok then
      ResultID := NewCopy.ID;
  end
  else
  begin
    Ok := DB.UpdateCopy(CopyEntity, eInv.Text, cbCond.Text, LocID, eNote.Text,
      CopyEntity.ReceivedAt, CopyEntity.Status, Err);
    if Ok then
      ResultID := CopyEntity.ID;
  end;
  if Ok then
  begin
    Saved := True;
    Form.ModalResult := mrOK;
  end
  else
    MessageDlg(Err, mtError, [mbOK], 0);
end;

procedure TReaderDlgHelper.OKClick(Sender: TObject);
var
  Err: string;
  St: TReaderStatus;
  NewReader: TReader;
  Ok: Boolean;
begin
  if cbStatus.ItemIndex = 1 then
    St := rsBlocked
  else
    St := rsActive;
  if Reader = nil then
  begin
    NewReader := DB.AddReader(eName.Text, ePhone.Text, eAddress.Text, eContacts.Text,
      eNote.Text, 0, Err);
    Ok := NewReader <> nil;
    if Ok then
      ResultID := NewReader.ID;
  end
  else
  begin
    Ok := DB.UpdateReader(Reader, eName.Text, ePhone.Text, eAddress.Text,
      eContacts.Text, eNote.Text, Reader.BirthDate, St, eBlock.Text, Err);
    if Ok then
      ResultID := Reader.ID;
  end;
  if Ok then
  begin
    Saved := True;
    Form.ModalResult := mrOK;
  end
  else
    MessageDlg(Err, mtError, [mbOK], 0);
end;

procedure TCategoryDlgHelper.OKClick(Sender: TObject);
var
  Err: string;
  NewCat: TCategory;
  Ok: Boolean;
begin
  if Cat = nil then
  begin
    NewCat := DB.AddCategory(eName.Text, eCode.Text, eDesc.Text, Err);
    Ok := NewCat <> nil;
    if Ok then
      ResultID := NewCat.ID;
  end
  else
  begin
    Ok := DB.UpdateCategory(Cat, eName.Text, eCode.Text, eDesc.Text, Err);
    if Ok then
      ResultID := Cat.ID;
  end;
  if Ok then
  begin
    Saved := True;
    Form.ModalResult := mrOK;
  end
  else
    MessageDlg(Err, mtError, [mbOK], 0);
end;

procedure TLocationDlgHelper.OKClick(Sender: TObject);
var
  Err: string;
  NewLoc: TLocation;
  Ok: Boolean;
begin
  if Loc = nil then
  begin
    NewLoc := DB.AddLocation(eName.Text, eDesc.Text, Err);
    Ok := NewLoc <> nil;
    if Ok then
      ResultID := NewLoc.ID;
  end
  else
  begin
    Ok := DB.UpdateLocation(Loc, eName.Text, eDesc.Text, Err);
    if Ok then
      ResultID := Loc.ID;
  end;
  if Ok then
  begin
    Saved := True;
    Form.ModalResult := mrOK;
  end
  else
    MessageDlg(Err, mtError, [mbOK], 0);
end;

procedure TUserDlgHelper.OKClick(Sender: TObject);
var
  Err: string;
  Role: TUserRole;
  NewUser: TUser;
  Ok: Boolean;
begin
  if cbRole.ItemIndex = 1 then
    Role := urAdmin
  else
    Role := urLibrarian;
  if User = nil then
  begin
    NewUser := DB.AddUser(eLogin.Text, eDisplay.Text, ePass.Text, Role, Err);
    Ok := NewUser <> nil;
    if Ok then
      ResultID := NewUser.ID;
  end
  else
  begin
    Ok := DB.UpdateUser(User, eDisplay.Text, ePass.Text, Role, chkActive.Checked, Err);
    if Ok then
      ResultID := User.ID;
  end;
  if Ok then
  begin
    Saved := True;
    Form.ModalResult := mrOK;
  end
  else
    MessageDlg(Err, mtError, [mbOK], 0);
end;

function EditBookDialog(ADB: TLibraryDB; ABook: TBook; out AResultID: TId): Boolean;
var
  F: TForm;
  eTitle, eAuthors, eYear, ePublisher, eISBN, eDesc, eCover, eInv: TEdit;
  cbCat, cbLoc: TComboBox;
  btnOK, btnCancel, btnFillISBN: TButton;
  Helper: TBookDlgHelper;
  FieldsPanel, CoverPanel: TPanel;
  CoverPreview: TImage;
  CoverPlaceholder: TLabel;
  I, Y, FW, CoverWidth: Integer;
  C: TCategory;
  L: TLocation;
  LastLocationID: TId;
  CatsSL: TStringList;
begin
  Result := False;
  AResultID := 0;
  F := TForm.Create(nil);
  Helper := TBookDlgHelper.Create;
  try
    Helper.Saved := False;
    Helper.ResultID := 0;
    Helper.DB := ADB;
    Helper.Form := F;
    Helper.Book := ABook;
    Helper.ExternalCategoryIndex := -1;
    ApplyFormUIFont(F, ADB.Settings.UIFontSize);
    PrepareCardForm(F);
    F.Caption := 'Книга';
    CoverWidth := 210;
    F.ClientWidth := 680;
    FieldsPanel := TPanel.Create(F);
    FieldsPanel.Parent := F;
    FieldsPanel.BevelOuter := bvNone;
    FieldsPanel.SetBounds(0, 0, F.ClientWidth - CoverWidth - 24, 1);
    FieldsPanel.Anchors := [akLeft, akTop, akBottom];
    CoverPanel := TPanel.Create(F);
    CoverPanel.Parent := F;
    CoverPanel.Caption := 'Обложка';
    CoverPanel.BevelOuter := bvLowered;
    CoverPanel.SetBounds(F.ClientWidth - 16 - CoverWidth, 8, CoverWidth, 80);
    CoverPanel.Anchors := [akTop, akRight, akBottom];
    CoverPreview := TImage.Create(F);
    CoverPreview.Parent := CoverPanel;
    CoverPreview.Align := alClient;
    CoverPreview.Center := True;
    CoverPreview.Proportional := True;
    CoverPreview.Stretch := True;
    CoverPlaceholder := TLabel.Create(F);
    CoverPlaceholder.Parent := CoverPanel;
    CoverPlaceholder.Align := alClient;
    CoverPlaceholder.Alignment := taCenter;
    CoverPlaceholder.Layout := tlCenter;
    CoverPlaceholder.Caption := 'Нет обложки';
    CoverPlaceholder.Transparent := True;
    FW := FieldsPanel.Width - 32;
    Y := 8;
    InputPanelWithButton(FieldsPanel, 'ISBN', Y, FW, 'Заполнить', eISBN,
      btnFillISBN);
    eInv := nil;
    cbLoc := nil;
    if ABook = nil then
    begin
      InputPanel(FieldsPanel, 'Инвентарный номер *', Y, FW, eInv);
      eInv.Text := ADB.SuggestNextInventoryNo;
      InputCombo(FieldsPanel, 'Место хранения *', Y, FW, cbLoc);
      for I := 0 to ADB.Locations.Count - 1 do
      begin
        L := TLocation(ADB.Locations[I]);
        if not L.Deleted then
          cbLoc.Items.AddObject(L.Name, L);
      end;
      LastLocationID := LoadCardLayoutID(ADB, 'Book', 'LastLocationID');
      for I := 0 to cbLoc.Items.Count - 1 do
        if (cbLoc.Items.Objects[I] <> nil) and
          (TLocation(cbLoc.Items.Objects[I]).ID = LastLocationID) then
        begin
          cbLoc.ItemIndex := I;
          Break;
        end;
    end;
    InputPanel(FieldsPanel, 'Название *', Y, FW, eTitle);
    InputPanel(FieldsPanel, 'Автор(ы)', Y, FW, eAuthors);
    InputPanel(FieldsPanel, 'Год', Y, FW, eYear);
    InputPanel(FieldsPanel, 'Издательство', Y, FW, ePublisher);
    InputPanel(FieldsPanel, 'Описание', Y, FW, eDesc);
    InputCombo(FieldsPanel, 'Категория', Y, FW, cbCat);
    cbCat.Items.AddObject('(нет)', nil);
    // Активные категории — отсортировать по наименованию (без учёта регистра)
    CatsSL := TStringList.Create;
    try
      CatsSL.Sorted := True;
      CatsSL.CaseSensitive := False;
      for I := 0 to ADB.Categories.Count - 1 do
      begin
        C := TCategory(ADB.Categories[I]);
        if not C.Deleted then
          CatsSL.AddObject(C.Name, C);
      end;
      for I := 0 to CatsSL.Count - 1 do
        cbCat.Items.AddObject(CatsSL[I], CatsSL.Objects[I]);
    finally
      CatsSL.Free;
    end;
    cbCat.ItemIndex := 0;
    InputPanel(FieldsPanel, 'Путь к обложке (jpg/png)', Y, FW, eCover);
    FieldsPanel.Height := Y;
    PlaceDialogButtons(F, Y, btnOK, btnCancel);
    CoverPanel.Height := Max(80, btnOK.Top - CoverPanel.Top - 8);
    Helper.eTitle := eTitle;
    Helper.eAuthors := eAuthors;
    Helper.eYear := eYear;
    Helper.ePublisher := ePublisher;
    Helper.eISBN := eISBN;
    Helper.eInv := eInv;
    Helper.btnFillISBN := btnFillISBN;
    Helper.eDesc := eDesc;
    Helper.eCover := eCover;
    Helper.cbCat := cbCat;
    Helper.cbLoc := cbLoc;
    Helper.FieldsPanel := FieldsPanel;
    Helper.CoverPanel := CoverPanel;
    Helper.CoverPreview := CoverPreview;
    Helper.CoverPlaceholder := CoverPlaceholder;
    Helper.btnOK := btnOK;
    btnFillISBN.OnClick := @Helper.FillISBNClick;
    eISBN.OnKeyPress := @Helper.ISBNKeyPress;
    eCover.OnChange := @Helper.CoverPathChange;
    btnOK.OnClick := @Helper.OKClick;
    F.OnResize := @Helper.FormResize;
    F.OnShow := @Helper.FormShow;
    LoadCardFormSize(ADB, F, 'Book');
    if ABook <> nil then
    begin
      eTitle.Text := ABook.Title;
      eAuthors.Text := ABook.Authors;
      eYear.Text := IntToStr(ABook.Year);
      ePublisher.Text := ABook.Publisher;
      eISBN.Text := ABook.ISBN;
      eDesc.Text := ABook.Description;
      for I := 0 to cbCat.Items.Count - 1 do
        if (cbCat.Items.Objects[I] <> nil) and
           (TCategory(cbCat.Items.Objects[I]).ID = ABook.CategoryID) then
          cbCat.ItemIndex := I;
    end;
    Helper.FormResize(nil);
    Helper.UpdateCoverPreview;
    if F.ShowModal <> mrOK then
      Exit;
    if Helper.Saved then
    begin
      Result := True;
      AResultID := Helper.ResultID;
    end;
  finally
    SaveCardFormSize(ADB, F, 'Book');
    Helper.Free;
    F.Free;
  end;
end;

function EditCopyDialog(ADB: TLibraryDB; ACopy: TCopy; ABookID: TId; out AResultID: TId): Boolean;
var
  F: TForm;
  eInv, eNote: TEdit;
  cbCond, cbLoc: TComboBox;
  btnOK, btnCancel: TButton;
  Helper: TCopyDlgHelper;
  BookID: TId;
  I, Y, FW: Integer;
  L: TLocation;
begin
  Result := False;
  AResultID := 0;
  BookID := ABookID;
  if ACopy <> nil then
    BookID := ACopy.BookID;
  F := TForm.Create(nil);
  Helper := TCopyDlgHelper.Create;
  try
    Helper.Saved := False;
    Helper.ResultID := 0;
    Helper.DB := ADB;
    Helper.Form := F;
    Helper.CopyEntity := ACopy;
    Helper.BookID := BookID;
    ApplyFormUIFont(F, ADB.Settings.UIFontSize);
    PrepareCardForm(F);
    F.Caption := 'Экземпляр';
    F.ClientWidth := 380;
    FW := F.ClientWidth - 32;
    Y := 8;
    InputPanel(F, 'Инвентарный номер *', Y, FW, eInv);
    InputCombo(F, 'Состояние', Y, FW, cbCond);
    cbCond.Items.Add(COPY_CONDITION_BAD);
    cbCond.Items.Add(COPY_CONDITION_MEDIUM);
    cbCond.Items.Add(COPY_CONDITION_GOOD);
    cbCond.ItemIndex := 1;
    InputCombo(F, 'Место хранения *', Y, FW, cbLoc);
    for I := 0 to ADB.Locations.Count - 1 do
    begin
      L := TLocation(ADB.Locations[I]);
      if not L.Deleted then
        cbLoc.Items.AddObject(L.Name, L);
    end;
    InputPanel(F, 'Примечание', Y, FW, eNote);
    PlaceDialogButtons(F, Y, btnOK, btnCancel);
    Helper.eInv := eInv;
    Helper.eNote := eNote;
    Helper.cbCond := cbCond;
    Helper.cbLoc := cbLoc;
    btnOK.OnClick := @Helper.OKClick;
    LoadCardFormSize(ADB, F, 'Copy');
    if ACopy <> nil then
    begin
      eInv.Text := ACopy.InventoryNo;
      cbCond.ItemIndex := cbCond.Items.IndexOf(NormalizeCopyCondition(ACopy.Condition));
      if cbCond.ItemIndex < 0 then
        cbCond.ItemIndex := 1;
      eNote.Text := ACopy.Note;
      for I := 0 to cbLoc.Items.Count - 1 do
        if (cbLoc.Items.Objects[I] <> nil) and
           (TLocation(cbLoc.Items.Objects[I]).ID = ACopy.LocationID) then
          cbLoc.ItemIndex := I;
    end
    else
    begin
      { Новый экземпляр: подставить первый свободный инв. №,
        начиная с номера, заданного в настройках; дырки заполняются
        сразу, иначе — следующий за максимальным. }
      eInv.Text := ADB.SuggestNextInventoryNo;
    end;
    if F.ShowModal <> mrOK then
      Exit;
    if Helper.Saved then
    begin
      Result := True;
      AResultID := Helper.ResultID;
    end;
  finally
    SaveCardFormSize(ADB, F, 'Copy');
    Helper.Free;
    F.Free;
  end;
end;

function EditReaderDialog(ADB: TLibraryDB; AReader: TReader; out AResultID: TId): Boolean;
var
  F: TForm;
  eName, ePhone, eAddress, eContacts, eNote, eBlock: TEdit;
  cbStatus: TComboBox;
  btnOK, btnCancel: TButton;
  Helper: TReaderDlgHelper;
  Y, FW: Integer;
begin
  Result := False;
  AResultID := 0;
  F := TForm.Create(nil);
  Helper := TReaderDlgHelper.Create;
  try
    Helper.Saved := False;
    Helper.ResultID := 0;
    Helper.DB := ADB;
    Helper.Form := F;
    Helper.Reader := AReader;
    ApplyFormUIFont(F, ADB.Settings.UIFontSize);
    PrepareCardForm(F);
    F.Caption := 'Читатель';
    F.ClientWidth := 400;
    FW := F.ClientWidth - 32;
    Y := 8;
    InputPanel(F, 'Ф. И. О. *', Y, FW, eName);
    InputPanel(F, 'Телефон', Y, FW, ePhone);
    InputPanel(F, 'Адрес', Y, FW, eAddress);
    InputPanel(F, 'Доп. контакты', Y, FW, eContacts);
    InputPanel(F, 'Примечание', Y, FW, eNote);
    InputCombo(F, 'Статус', Y, FW, cbStatus);
    cbStatus.Items.Add('активен');
    cbStatus.Items.Add('заблокирован');
    cbStatus.ItemIndex := 0;
    InputPanel(F, 'Причина блокировки', Y, FW, eBlock);
    PlaceDialogButtons(F, Y, btnOK, btnCancel);
    Helper.eName := eName;
    Helper.ePhone := ePhone;
    Helper.eAddress := eAddress;
    Helper.eContacts := eContacts;
    Helper.eNote := eNote;
    Helper.eBlock := eBlock;
    Helper.cbStatus := cbStatus;
    btnOK.OnClick := @Helper.OKClick;
    LoadCardFormSize(ADB, F, 'Reader');
    if AReader <> nil then
    begin
      eName.Text := AReader.FullName;
      ePhone.Text := AReader.Phone;
      eAddress.Text := AReader.Address;
      eContacts.Text := AReader.Contacts;
      eNote.Text := AReader.Note;
      eBlock.Text := AReader.BlockReason;
      if AReader.Status = rsBlocked then
        cbStatus.ItemIndex := 1;
    end;
    if F.ShowModal <> mrOK then
      Exit;
    if Helper.Saved then
    begin
      Result := True;
      AResultID := Helper.ResultID;
    end;
  finally
    SaveCardFormSize(ADB, F, 'Reader');
    Helper.Free;
    F.Free;
  end;
end;

function EditCategoryDialog(ADB: TLibraryDB; ACat: TCategory; out AResultID: TId): Boolean;
var
  F: TForm;
  eName, eCode, eDesc: TEdit;
  btnOK, btnCancel: TButton;
  Helper: TCategoryDlgHelper;
  Y, FW: Integer;
begin
  Result := False;
  AResultID := 0;
  F := TForm.Create(nil);
  Helper := TCategoryDlgHelper.Create;
  try
    Helper.Saved := False;
    Helper.ResultID := 0;
    Helper.DB := ADB;
    Helper.Form := F;
    Helper.Cat := ACat;
    ApplyFormUIFont(F, ADB.Settings.UIFontSize);
    PrepareCardForm(F);
    F.Caption := 'Категория';
    F.ClientWidth := 380;
    FW := F.ClientWidth - 32;
    Y := 8;
    InputPanel(F, 'Наименование *', Y, FW, eName);
    InputPanel(F, 'Шифр (необязательно)', Y, FW, eCode);
    InputPanel(F, 'Описание', Y, FW, eDesc);
    PlaceDialogButtons(F, Y, btnOK, btnCancel);
    Helper.eName := eName;
    Helper.eCode := eCode;
    Helper.eDesc := eDesc;
    btnOK.OnClick := @Helper.OKClick;
    LoadCardFormSize(ADB, F, 'Category');
    if ACat <> nil then
    begin
      eName.Text := ACat.Name;
      eCode.Text := ACat.Code;
      eDesc.Text := ACat.Description;
    end;
    if F.ShowModal <> mrOK then
      Exit;
    if Helper.Saved then
    begin
      Result := True;
      AResultID := Helper.ResultID;
    end;
  finally
    SaveCardFormSize(ADB, F, 'Category');
    Helper.Free;
    F.Free;
  end;
end;

function EditLocationDialog(ADB: TLibraryDB; ALoc: TLocation; out AResultID: TId): Boolean;
var
  F: TForm;
  eName, eDesc: TEdit;
  btnOK, btnCancel: TButton;
  Helper: TLocationDlgHelper;
  Y, FW: Integer;
begin
  Result := False;
  AResultID := 0;
  F := TForm.Create(nil);
  Helper := TLocationDlgHelper.Create;
  try
    Helper.Saved := False;
    Helper.ResultID := 0;
    Helper.DB := ADB;
    Helper.Form := F;
    Helper.Loc := ALoc;
    ApplyFormUIFont(F, ADB.Settings.UIFontSize);
    PrepareCardForm(F);
    F.Caption := 'Место хранения';
    F.ClientWidth := 380;
    FW := F.ClientWidth - 32;
    Y := 8;
    InputPanel(F, 'Наименование *', Y, FW, eName);
    InputPanel(F, 'Описание', Y, FW, eDesc);
    PlaceDialogButtons(F, Y, btnOK, btnCancel);
    Helper.eName := eName;
    Helper.eDesc := eDesc;
    btnOK.OnClick := @Helper.OKClick;
    LoadCardFormSize(ADB, F, 'Location');
    if ALoc <> nil then
    begin
      eName.Text := ALoc.Name;
      eDesc.Text := ALoc.Description;
    end;
    if F.ShowModal <> mrOK then
      Exit;
    if Helper.Saved then
    begin
      Result := True;
      AResultID := Helper.ResultID;
    end;
  finally
    SaveCardFormSize(ADB, F, 'Location');
    Helper.Free;
    F.Free;
  end;
end;

function EditUserDialog(ADB: TLibraryDB; AUser: TUser; out AResultID: TId): Boolean;
var
  F: TForm;
  eLogin, eDisplay, ePass: TEdit;
  cbRole: TComboBox;
  chkActive: TCheckBox;
  btnOK, btnCancel: TButton;
  Helper: TUserDlgHelper;
  Y, FW, H: Integer;
begin
  Result := False;
  AResultID := 0;
  F := TForm.Create(nil);
  Helper := TUserDlgHelper.Create;
  try
    Helper.Saved := False;
    Helper.ResultID := 0;
    Helper.DB := ADB;
    Helper.Form := F;
    Helper.User := AUser;
    ApplyFormUIFont(F, ADB.Settings.UIFontSize);
    PrepareCardForm(F);
    F.Caption := 'Пользователь';
    F.ClientWidth := 380;
    FW := F.ClientWidth - 32;
    Y := 8;
    InputPanel(F, 'Имя входа *', Y, FW, eLogin);
    InputPanel(F, 'Отображаемое имя', Y, FW, eDisplay);
    InputPanel(F, 'Пароль (пусто = не менять)', Y, FW, ePass);
    ePass.EchoMode := emPassword;
    InputCombo(F, 'Роль', Y, FW, cbRole);
    cbRole.Items.Add('Библиотекарь');
    cbRole.Items.Add('Администратор');
    cbRole.ItemIndex := 0;
    H := FieldHeight(F);
    chkActive := TCheckBox.Create(F);
    chkActive.Parent := F;
    chkActive.Left := 16;
    chkActive.Top := Y;
    chkActive.Caption := 'Активен';
    chkActive.Checked := True;
    chkActive.AutoSize := True;
    chkActive.Height := Max(chkActive.Height, H);
    chkActive.Anchors := [akLeft, akTop];
    Y := chkActive.Top + chkActive.Height + 12;
    PlaceDialogButtons(F, Y, btnOK, btnCancel);
    Helper.eLogin := eLogin;
    Helper.eDisplay := eDisplay;
    Helper.ePass := ePass;
    Helper.cbRole := cbRole;
    Helper.chkActive := chkActive;
    btnOK.OnClick := @Helper.OKClick;
    LoadCardFormSize(ADB, F, 'User');
    if AUser <> nil then
    begin
      eLogin.Text := AUser.Login;
      eLogin.ReadOnly := True;
      eDisplay.Text := AUser.DisplayName;
      if AUser.Role = urAdmin then
        cbRole.ItemIndex := 1;
      chkActive.Checked := AUser.Active;
    end;
    if F.ShowModal <> mrOK then
      Exit;
    if Helper.Saved then
    begin
      Result := True;
      AResultID := Helper.ResultID;
    end;
  finally
    SaveCardFormSize(ADB, F, 'User');
    Helper.Free;
    F.Free;
  end;
end;

procedure TIssueLoanDlgHelper.ClearBookCaption;
begin
  if lblBook <> nil then
    lblBook.Caption := '';
end;

procedure TIssueLoanDlgHelper.DoFindInv;
var
  Inv: string;
  C: TCopy;
  B: TBook;
  Title: string;
begin
  if lblBook = nil then
    Exit;
  Inv := Trim(eInv.Text);
  if Inv = '' then
  begin
    ClearBookCaption;
    Exit;
  end;
  C := DB.FindCopyByInv(Inv);
  if C = nil then
  begin
    lblBook.Caption := 'Экземпляр не найден';
    Exit;
  end;
  B := DB.FindBook(C.BookID);
  if (B <> nil) and (not B.Deleted) then
    Title := B.Title
  else
    Title := '(книга не найдена)';
  if C.Status = csAvailable then
    lblBook.Caption := Title
  else
    lblBook.Caption := Title + ' — недоступен (' + CopyStatusToStr(C.Status) + ')';
end;

procedure TIssueLoanDlgHelper.FindInvClick(Sender: TObject);
begin
  DoFindInv;
end;

procedure TIssueLoanDlgHelper.InvKeyPress(Sender: TObject; var Key: Char);
begin
  if Key = #13 then
  begin
    Key := #0;
    DoFindInv;
  end;
end;

procedure TIssueLoanDlgHelper.InvExit(Sender: TObject);
begin
  DoFindInv;
end;

procedure TIssueLoanDlgHelper.InvChange(Sender: TObject);
begin
  ClearBookCaption;
end;

procedure TIssueLoanDlgHelper.DoSearch;
var
  Q: string;
  Temp: TList;
  I: Integer;
  R: TReader;
  NQ: string;
begin
  lbReaders.Items.BeginUpdate;
  try
    lbReaders.Items.Clear;
    Q := Trim(edtSearch.Text);
    if Q = '' then
      Exit;
    NQ := NormalizeKey(Q);
    if NQ = '' then
      Exit;
    Temp := TList.Create;
    try
      DB.SearchReaders(Q, Temp, False);
      for I := 0 to Temp.Count - 1 do
      begin
        R := TReader(Temp[I]);
        if R.Status <> rsActive then
          Continue;
        if Pos(NQ, NormalizeKey(R.FullName)) = 0 then
          Continue;
        lbReaders.Items.AddObject(R.FullName, R);
      end;
    finally
      Temp.Free;
    end;
    if lbReaders.Items.Count > 0 then
      lbReaders.ItemIndex := 0;
  finally
    lbReaders.Items.EndUpdate;
  end;
end;

procedure TIssueLoanDlgHelper.SearchClick(Sender: TObject);
begin
  DoSearch;
end;

procedure TIssueLoanDlgHelper.SearchKeyPress(Sender: TObject; var Key: Char);
begin
  if Key = #13 then
  begin
    Key := #0;
    DoSearch;
  end;
end;

procedure TIssueLoanDlgHelper.OKClick(Sender: TObject);
var
  C: TCopy;
  R: TReader;
  NewLoan: TLoan;
  Err: string;
begin
  C := DB.FindCopyByInv(Trim(eInv.Text));
  if C = nil then
  begin
    MessageDlg('Экземпляр с таким инвентарным номером не найден.', mtError, [mbOK], 0);
    Exit;
  end;
  if lbReaders.ItemIndex < 0 then
  begin
    MessageDlg('Найдите и выберите читателя.', mtError, [mbOK], 0);
    Exit;
  end;
  R := TReader(lbReaders.Items.Objects[lbReaders.ItemIndex]);
  NewLoan := DB.IssueLoan(C.ID, R.ID, '', Err);
  if NewLoan = nil then
  begin
    MessageDlg(Err, mtError, [mbOK], 0);
    Exit;
  end;
  ResultID := NewLoan.ID;
  Saved := True;
  Form.ModalResult := mrOK;
end;

function IssueLoanDialog(ADB: TLibraryDB; out AResultID: TId): Boolean;
var
  F: TForm;
  eInv: TEdit;
  edtReaderSearch: TEdit;
  btnFindInv, btnSearch, btnOK, btnCancel: TButton;
  lbReaders: TListBox;
  lblInv, lblBook, lblReader: TLabel;
  Helper: TIssueLoanDlgHelper;
  Y, FW, H, BtnW, ListH, LabelH: Integer;
begin
  Result := False;
  AResultID := 0;
  F := TForm.Create(nil);
  Helper := TIssueLoanDlgHelper.Create;
  try
    Helper.ResultID := 0;
    Helper.Saved := False;
    ApplyFormUIFont(F, ADB.Settings.UIFontSize);
    PrepareCardForm(F);
    F.Caption := 'Выдача книги';
    F.ClientWidth := 420;
    FW := F.ClientWidth - 32;
    Y := 8;
    H := FieldHeight(F);
    BtnW := Max(90, F.Canvas.TextWidth('Найти') + 28);
    LabelH := F.Canvas.TextHeight('Ag') + 4;

    lblInv := TLabel.Create(F);
    lblInv.Parent := F;
    lblInv.Left := 16;
    lblInv.Top := Y;
    SizeCardLabel(lblInv, F, 'Инвентарный номер *', FW);
    eInv := TEdit.Create(F);
    eInv.Parent := F;
    eInv.Left := 16;
    eInv.Top := lblInv.Top + lblInv.Height + 4;
    eInv.Width := FW - BtnW - 8;
    eInv.Height := H;
    eInv.Anchors := [akLeft, akTop, akRight];
    btnFindInv := TButton.Create(F);
    btnFindInv.Parent := F;
    btnFindInv.Caption := 'Найти';
    btnFindInv.Left := 16 + eInv.Width + 8;
    btnFindInv.Top := eInv.Top;
    btnFindInv.Width := BtnW;
    btnFindInv.Height := H;
    btnFindInv.Anchors := [akTop, akRight];
    Y := eInv.Top + eInv.Height + 4;

    lblBook := TLabel.Create(F);
    lblBook.Parent := F;
    lblBook.Left := 16;
    lblBook.Top := Y;
    lblBook.AutoSize := False;
    lblBook.Width := FW;
    lblBook.Height := LabelH;
    lblBook.Caption := '';
    lblBook.Font.Assign(F.Font);
    lblBook.Anchors := [akLeft, akTop, akRight];
    Y := lblBook.Top + lblBook.Height + 8;

    lblReader := TLabel.Create(F);
    lblReader.Parent := F;
    lblReader.Left := 16;
    lblReader.Top := Y;
    SizeCardLabel(lblReader, F, 'Читатель *', FW);
    edtReaderSearch := TEdit.Create(F);
    edtReaderSearch.Parent := F;
    edtReaderSearch.Left := 16;
    edtReaderSearch.Top := lblReader.Top + lblReader.Height + 4;
    edtReaderSearch.Width := FW - BtnW - 8;
    edtReaderSearch.Height := H;
    edtReaderSearch.Anchors := [akLeft, akTop, akRight];
    btnSearch := TButton.Create(F);
    btnSearch.Parent := F;
    btnSearch.Caption := 'Найти';
    btnSearch.Left := 16 + edtReaderSearch.Width + 8;
    btnSearch.Top := edtReaderSearch.Top;
    btnSearch.Width := BtnW;
    btnSearch.Height := H;
    btnSearch.Anchors := [akTop, akRight];
    Y := edtReaderSearch.Top + edtReaderSearch.Height + 8;

    lbReaders := TListBox.Create(F);
    lbReaders.Parent := F;
    lbReaders.Left := 16;
    lbReaders.Top := Y;
    lbReaders.Width := FW;
    ListH := Max(120, F.Canvas.TextHeight('Ag') * 8);
    lbReaders.Height := ListH;
    lbReaders.Anchors := [akLeft, akTop, akRight];
    Y := lbReaders.Top + lbReaders.Height + 8;

    PlaceDialogButtons(F, Y, btnOK, btnCancel, 'Выдать');
    { akBottom после финальной высоты — список не наезжает на кнопки }
    lbReaders.Anchors := [akLeft, akTop, akRight, akBottom];

    btnOK.OnClick := @Helper.OKClick;
    btnFindInv.OnClick := @Helper.FindInvClick;
    eInv.OnKeyPress := @Helper.InvKeyPress;
    eInv.OnExit := @Helper.InvExit;
    eInv.OnChange := @Helper.InvChange;
    btnSearch.OnClick := @Helper.SearchClick;
    edtReaderSearch.OnKeyPress := @Helper.SearchKeyPress;

    Helper.DB := ADB;
    Helper.Form := F;
    Helper.eInv := eInv;
    Helper.edtSearch := edtReaderSearch;
    Helper.lblBook := lblBook;
    Helper.lbReaders := lbReaders;

    LoadCardFormSize(ADB, F, 'IssueLoan');
    if F.ShowModal <> mrOK then
      Exit;
    if Helper.Saved then
    begin
      Result := True;
      AResultID := Helper.ResultID;
    end;
  finally
    SaveCardFormSize(ADB, F, 'IssueLoan');
    Helper.Free;
    F.Free;
  end;
end;

function PickDateDialog(ADB: TLibraryDB; const ATitle: string; var ADate: TDateTime): Boolean;
var
  F: TForm;
  Cal: TCalendar;
  btnOK, btnCancel: TButton;
  lblHint: TLabel;
  Y: Integer;
begin
  Result := False;
  F := TForm.Create(nil);
  try
    ApplyFormUIFont(F, ADB.Settings.UIFontSize);
    PrepareCardForm(F);
    F.Caption := ATitle;
    F.ClientWidth := 300;
    Y := 8;
    lblHint := TLabel.Create(F);
    lblHint.Parent := F;
    lblHint.Left := 12;
    lblHint.Top := Y;
    SizeCardLabel(lblHint, F, 'Выберите дату и нажмите «OK»', F.ClientWidth - 24);
    Y := lblHint.Top + lblHint.Height + 8;
    Cal := TCalendar.Create(F);
    Cal.Parent := F;
    Cal.Left := 12;
    Cal.Top := Y;
    Cal.Width := F.ClientWidth - 24;
    Cal.Height := Max(220, F.Canvas.TextHeight('Ag') * 12);
    Cal.Anchors := [akLeft, akTop, akRight, akBottom];
    if ADate > 0 then
      Cal.DateTime := Trunc(ADate)
    else
      Cal.DateTime := Date;
    Y := Cal.Top + Cal.Height + 12;
    PlaceDialogButtons(F, Y, btnOK, btnCancel, 'OK');
    btnOK.ModalResult := mrOK;
    LoadCardFormSize(ADB, F, 'PickDate');
    if F.ShowModal <> mrOK then
      Exit;
    ADate := Trunc(Cal.DateTime);
    Result := True;
  finally
    SaveCardFormSize(ADB, F, 'PickDate');
    F.Free;
  end;
end;

procedure TRecognizedImportDlgHelper.SaveClick(Sender: TObject);
var
  I, SavedCount, YearValue: Integer;
  Item: TRecognizedBook;
  ValidItems: TList;
  Seen, Errors: TStringList;
  Err: string;
begin
  ValidItems := TList.Create;
  Seen := TStringList.Create;
  Errors := TStringList.Create;
  try
    if Trim(Location.Text) = '' then
    begin
      MessageDlg('Укажите место хранения.', mtError, [mbOK], 0);
      Exit;
    end;
    Seen.Sorted := True;
    Seen.CaseSensitive := False;
    Seen.Duplicates := dupIgnore;
    for I := 0 to Items.Count - 1 do
    begin
      Item := TRecognizedBook(Items[I]);
      Item.Title := Trim(Grid.Cells[0, I + 1]);
      Item.InventoryNo := Trim(Grid.Cells[1, I + 1]);
      Item.Authors := Trim(Grid.Cells[2, I + 1]);
      Item.Year := Trim(Grid.Cells[3, I + 1]);
      Item.Publisher := Trim(Grid.Cells[4, I + 1]);
      Item.ISBN := Trim(Grid.Cells[5, I + 1]);
      Item.Description := Trim(Grid.Cells[6, I + 1]);
      Item.CategoryName := Trim(Grid.Cells[7, I + 1]);
      if Item.Title = '' then
        Errors.Add('Строка ' + IntToStr(I + 1) + ': не указано наименование.')
      else if Item.InventoryNo = '' then
        Errors.Add('Строка ' + IntToStr(I + 1) + ': не указан инвентарный номер.')
      else if (Item.Year <> '') and
              ((not TryStrToInt(Item.Year, YearValue)) or
               (YearValue < 1) or (YearValue > 9999)) then
        Errors.Add('Строка ' + IntToStr(I + 1) +
          ': год должен быть целым числом от 1 до 9999.')
      else if Seen.IndexOf(Item.InventoryNo) >= 0 then
        Errors.Add('Строка ' + IntToStr(I + 1) + ': повторяющийся инв. номер «' + Item.InventoryNo + '».')
      else if DB.FindCopyByInv(Item.InventoryNo) <> nil then
        Errors.Add('Строка ' + IntToStr(I + 1) + ': инв. номер «' + Item.InventoryNo + '» уже есть в базе.')
      else
      begin
        Seen.Add(Item.InventoryNo);
        ValidItems.Add(Item);
      end;
    end;
    if Errors.Count > 0 then
    begin
      if Problems.Lines.Count > 0 then
        Problems.Lines.Add('');
      Problems.Lines.Add('Не сохранены:');
      Problems.Lines.AddStrings(Errors);
    end;
    if ValidItems.Count = 0 then
    begin
      MessageDlg('Нет строк, которые можно сохранить. Исправьте данные в таблице.', mtError, [mbOK], 0);
      Exit;
    end;
    if not DB.ImportRecognizedBooks(ValidItems, Trim(Location.Text), SavedCount, Err) then
    begin
      MessageDlg(Err, mtError, [mbOK], 0);
      Exit;
    end;
    Saved := True;
    if Errors.Count > 0 then
      MessageDlg('Сохранено книг и экземпляров: ' + IntToStr(SavedCount) +
        '. Не сохранено строк: ' + IntToStr(Errors.Count) + '.', mtWarning, [mbOK], 0)
    else
      MessageDlg('Сохранено книг и экземпляров: ' + IntToStr(SavedCount) + '.', mtInformation, [mbOK], 0);
    Form.ModalResult := mrOK;
  finally
    Errors.Free;
    Seen.Free;
    ValidItems.Free;
  end;
end;

function ImportRecognizedBooksDialog(ADB: TLibraryDB; AItems: TList;
  AFailures: TStrings; const AStats: TRecognitionStats): Boolean;
var
  F: TForm;
  Helper: TRecognizedImportDlgHelper;
  Grid: TStringGrid;
  Location: TComboBox;
  Problems: TMemo;
  lblTable, lblStats, lblLocation, lblProblems: TLabel;
  btnSave, btnCancel: TButton;
  I, Y, TextH, FieldH: Integer;
  Item: TRecognizedBook;
  Loc: TLocation;
  SavedFailures: TStringList;
  CostText, ModelsText: string;
begin
  Result := False;
  if (AItems = nil) or (AItems.Count = 0) then
    Exit;
  F := TForm.Create(nil);
  Helper := TRecognizedImportDlgHelper.Create;
  SavedFailures := TStringList.Create;
  try
    if AFailures <> nil then
      SavedFailures.Assign(AFailures);
    ApplyFormUIFont(F, ADB.Settings.UIFontSize);
    PrepareCardForm(F);
    F.Caption := 'Результаты распознавания';
    F.ClientWidth := 1080;
    F.ClientHeight := 650;
    F.Constraints.MinWidth := 720;
    F.Constraints.MinHeight := 620;
    TextH := F.Canvas.TextHeight('Ag');
    FieldH := TextH + 12;

    lblTable := TLabel.Create(F);
    lblTable.Parent := F;
    lblTable.Caption := 'Проверьте и при необходимости исправьте распознанные данные:';
    lblTable.SetBounds(16, 14, F.ClientWidth - 32, TextH + 4);

    Grid := TStringGrid.Create(F);
    Grid.Parent := F;
    Grid.SetBounds(16, lblTable.Top + lblTable.Height + 8,
      F.ClientWidth - 32, 270);
    Grid.Anchors := [akLeft, akTop, akRight];
    Grid.ColCount := 8;
    Grid.RowCount := AItems.Count + 1;
    Grid.FixedRows := 1;
    Grid.FixedCols := 0;
    Grid.Options := Grid.Options + [goEditing, goAlwaysShowEditor, goColSizing];
    Grid.Cells[0, 0] := 'Наименование';
    Grid.Cells[1, 0] := 'Инв. номер';
    Grid.Cells[2, 0] := 'Автор(ы)';
    Grid.Cells[3, 0] := 'Год';
    Grid.Cells[4, 0] := 'Издательство';
    Grid.Cells[5, 0] := 'ISBN';
    Grid.Cells[6, 0] := 'Описание';
    Grid.Cells[7, 0] := 'Категория';
    Grid.ColWidths[0] := 260;
    Grid.ColWidths[1] := 110;
    Grid.ColWidths[2] := 180;
    Grid.ColWidths[3] := 75;
    Grid.ColWidths[4] := 170;
    Grid.ColWidths[5] := 130;
    Grid.ColWidths[6] := 260;
    Grid.ColWidths[7] := 160;
    for I := 0 to AItems.Count - 1 do
    begin
      Item := TRecognizedBook(AItems[I]);
      Grid.Cells[0, I + 1] := Item.Title;
      Grid.Cells[1, I + 1] := Item.InventoryNo;
      Grid.Cells[2, I + 1] := Item.Authors;
      Grid.Cells[3, I + 1] := Item.Year;
      Grid.Cells[4, I + 1] := Item.Publisher;
      Grid.Cells[5, I + 1] := Item.ISBN;
      Grid.Cells[6, I + 1] := Item.Description;
      Grid.Cells[7, I + 1] := Item.CategoryName;
    end;

    ModelsText := Trim(AStats.Models);
    if ModelsText = '' then
      ModelsText := '—';
    if AStats.HasCost then
      CostText := Format('$%.6f', [AStats.RecognitionCost])
    else
      CostText := '—';
    Y := Grid.Top + Grid.Height + 10;
    lblStats := TLabel.Create(F);
    lblStats.Parent := F;
    lblStats.AutoSize := False;
    lblStats.WordWrap := True;
    lblStats.Caption := 'Модель: ' + ModelsText + LineEnding +
      Format('Токены: всего %d; вход %d; выход %d', [AStats.TotalTokens,
        AStats.PromptTokens, AStats.CompletionTokens]) + LineEnding +
      'Стоимость: ' + CostText;
    lblStats.SetBounds(16, Y, F.ClientWidth - 32, TextH * 3 + 8);
    lblStats.Anchors := [akLeft, akTop, akRight];

    Y := lblStats.Top + lblStats.Height + 10;
    lblLocation := TLabel.Create(F);
    lblLocation.Parent := F;
    lblLocation.Caption := 'Место хранения для всех экземпляров *';
    lblLocation.SetBounds(16, Y, 360, TextH + 4);

    Location := TComboBox.Create(F);
    Location.Parent := F;
    Location.SetBounds(16, lblLocation.Top + lblLocation.Height + 4,
      F.ClientWidth - 32, FieldH);
    Location.Anchors := [akLeft, akTop, akRight];
    Location.Style := csDropDown;
    for I := 0 to ADB.Locations.Count - 1 do
    begin
      Loc := TLocation(ADB.Locations[I]);
      if not Loc.Deleted then
        Location.Items.Add(Loc.Name);
    end;

    Y := Location.Top + Location.Height + 10;
    lblProblems := TLabel.Create(F);
    lblProblems.Parent := F;
    lblProblems.Caption := 'Не распознано или исключено из сохранения:';
    lblProblems.SetBounds(16, Y, 500, TextH + 4);

    Problems := TMemo.Create(F);
    Problems.Parent := F;
    Problems.SetBounds(16, lblProblems.Top + lblProblems.Height + 4,
      F.ClientWidth - 32, F.ClientHeight -
      (lblProblems.Top + lblProblems.Height + 4) - 52);
    Problems.Anchors := [akLeft, akTop, akRight, akBottom];
    Problems.ReadOnly := True;
    Problems.ScrollBars := ssVertical;
    Problems.Lines.Assign(SavedFailures);

    btnSave := TButton.Create(F);
    btnSave.Parent := F;
    btnSave.Caption := 'Сохранить';
    btnSave.SetBounds(F.ClientWidth - 220, F.ClientHeight - 38, 96, 28);
    btnSave.Anchors := [akRight, akBottom];
    btnSave.Default := True;

    btnCancel := TButton.Create(F);
    btnCancel.Parent := F;
    btnCancel.Caption := 'Отмена';
    btnCancel.SetBounds(F.ClientWidth - 116, F.ClientHeight - 38, 96, 28);
    btnCancel.Anchors := [akRight, akBottom];
    btnCancel.Cancel := True;
    btnCancel.ModalResult := mrCancel;

    Helper.DB := ADB;
    Helper.Form := F;
    Helper.Grid := Grid;
    Helper.Location := Location;
    Helper.Problems := Problems;
    Helper.Items := AItems;
    Helper.Saved := False;
    btnSave.OnClick := @Helper.SaveClick;
    LoadCardFormSize(ADB, F, 'RecognizedBooks');
    if F.ShowModal = mrOK then
      Result := Helper.Saved;
  finally
    SaveCardFormSize(ADB, F, 'RecognizedBooks');
    SavedFailures.Free;
    Helper.Free;
    F.Free;
  end;
end;

end.
