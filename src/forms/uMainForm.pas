unit uMainForm;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ComCtrls, ExtCtrls,
  StdCtrls, Grids, Menus, Buttons, ImgList, Spin, LMessages, LCLType, Contnrs,
  uDatabase, uEntities, uTypes, uReports, uEditDialogs, uSelectModelForm, uUIIcons, uOpenRouter;

type
  { Owner-draw закладок: активная подпись — коричневым (LCL без OnDrawTab). }
  TPageControl = class(ComCtrls.TPageControl)
  private
    procedure LMDrawItem(var Message: TLMDrawItems); message LM_DRAWITEM;
  end;

  { TEdit с подсказкой-«плейсхолдером» — серый текст внутри пустого поля.
    Рисуется через WndProc после WM_PAINT, чтобы перекрыть нативный EDIT. }
  TPlaceholderEdit = class(TEdit)
  private
    FPlaceholder: string;
    procedure SetPlaceholder(const Value: string);
  protected
    procedure WndProc(var Message: TLMessage); override;
  published
    property Placeholder: string read FPlaceholder write SetPlaceholder;
  end;

  TMainForm = class(TForm)
    pcMain: TPageControl;
    tsBooks: TTabSheet;
    tsReaders: TTabSheet;
    tsLoans: TTabSheet;
    tsOverdue: TTabSheet;
    tsReports: TTabSheet;
    tsUsers: TTabSheet;
    tsSettings: TTabSheet;
    tsBackup: TTabSheet;
    tsJournal: TTabSheet;
    tsCategories: TTabSheet;
    tsLocations: TTabSheet;
    pnlBooksTop: TPanel;
    edtBookSearch: TPlaceholderEdit;
    edtBookSearchInv: TPlaceholderEdit;
    btnBookSearchClear: TSpeedButton;
    btnBookSearch: TBitBtn;
    btnBookAdd: TBitBtn;
    btnBookRecognize: TBitBtn;
    btnBookEdit: TBitBtn;
    btnBookDelete: TBitBtn;
    btnBookRestore: TBitBtn;
    btnCopyAdd: TBitBtn;
    chkShowDeleted: TCheckBox;
    gridBooks: TStringGrid;
    splBooksCopies: TSplitter;
    pnlCopiesBottom: TPanel;
    pnlCopiesTop: TPanel;
    gridCopies: TStringGrid;
    btnCopyEdit: TBitBtn;
    btnCopyDelete: TBitBtn;
    pnlReadersTop: TPanel;
    edtReaderSearch: TEdit;
    btnReaderSearchClear: TSpeedButton;
    btnReaderSearch: TBitBtn;
    btnReaderAdd: TBitBtn;
    btnReaderEdit: TBitBtn;
    btnReaderDelete: TBitBtn;
    btnReaderRestore: TBitBtn;
    gridReaders: TStringGrid;
    pnlLoansTop: TPanel;
    btnLoanIssue: TBitBtn;
    btnLoanReturn: TBitBtn;
    btnLoanRenew: TBitBtn;
    btnLoanDate: TBitBtn;
    chkLoansOnlyLoaned: TCheckBox;
    gridLoans: TStringGrid;
    gridOverdue: TStringGrid;
    pnlReports: TPanel;
    cbReport: TComboBox;
    btnReportShow: TBitBtn;
    btnReportSave: TBitBtn;
    gridReport: TStringGrid;
    pnlUsersTop: TPanel;
    btnUserAdd: TBitBtn;
    btnUserEdit: TBitBtn;
    btnUserDelete: TBitBtn;
    gridUsers: TStringGrid;
    sbSettings: TScrollBox;
    pnlSettings: TPanel;
    edtLibName: TEdit;
    edtLoanDays: TEdit;
    edtMaxBooks: TEdit;
    edtMaxRenew: TEdit;
    chkAutoBackup: TCheckBox;
    lblUIFontSize: TLabel;
    seUIFontSize: TSpinEdit;
    lblInventoryStart: TLabel;
    seInventoryStart: TSpinEdit;
    lblOpenRouterModel: TLabel;
    cbOpenRouterModel: TComboBox;
    btnSelectOpenRouterModel: TBitBtn;
    lblOpenRouterApiKey: TLabel;
    edtOpenRouterApiKey: TEdit;
    btnTestOpenRouter: TBitBtn;
    btnSaveSettings: TBitBtn;
    lblLibName: TLabel;
    lblLoanDays: TLabel;
    lblMaxBooks: TLabel;
    lblMaxRenew: TLabel;
    pnlBackup: TPanel;
    btnBackupNow: TBitBtn;
    btnRestoreBackup: TBitBtn;
    lstBackups: TListBox;
    gridJournal: TStringGrid;
    pnlCatTop: TPanel;
    btnCatAdd: TBitBtn;
    btnCatEdit: TBitBtn;
    btnCatDelete: TBitBtn;
    gridCategories: TStringGrid;
    pnlLocTop: TPanel;
    btnLocAdd: TBitBtn;
    btnLocEdit: TBitBtn;
    btnLocDelete: TBitBtn;
    gridLocations: TStringGrid;
    statusBar: TStatusBar;
    procedure FormCreate(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormShow(Sender: TObject);
    procedure btnBookSearchClearClick(Sender: TObject);
    procedure btnBookSearchClick(Sender: TObject);
    procedure edtBookSearchChange(Sender: TObject);
    procedure edtBookSearchInvChange(Sender: TObject);
    procedure edtBookSearchInvKeyPress(Sender: TObject; var Key: char);
    procedure btnBookAddClick(Sender: TObject);
    procedure btnBookRecognizeClick(Sender: TObject);
    procedure btnBookEditClick(Sender: TObject);
    procedure btnBookDeleteClick(Sender: TObject);
    procedure btnBookRestoreClick(Sender: TObject);
    procedure btnCopyAddClick(Sender: TObject);
    procedure btnCopyEditClick(Sender: TObject);
    procedure btnCopyDeleteClick(Sender: TObject);
    procedure btnReaderSearchClearClick(Sender: TObject);
    procedure btnReaderSearchClick(Sender: TObject);
    procedure btnReaderAddClick(Sender: TObject);
    procedure btnReaderEditClick(Sender: TObject);
    procedure btnReaderDeleteClick(Sender: TObject);
    procedure btnReaderRestoreClick(Sender: TObject);
    procedure btnLoanIssueClick(Sender: TObject);
    procedure btnLoanReturnClick(Sender: TObject);
    procedure btnLoanRenewClick(Sender: TObject);
    procedure btnLoanDateClick(Sender: TObject);
    procedure btnReportShowClick(Sender: TObject);
    procedure btnReportSaveClick(Sender: TObject);
    procedure btnUserAddClick(Sender: TObject);
    procedure btnUserEditClick(Sender: TObject);
    procedure btnUserDeleteClick(Sender: TObject);
    procedure btnSaveSettingsClick(Sender: TObject);
    procedure btnTestOpenRouterClick(Sender: TObject);
    procedure btnSelectOpenRouterModelClick(Sender: TObject);
    procedure btnBackupNowClick(Sender: TObject);
    procedure btnRestoreBackupClick(Sender: TObject);
    procedure btnCatAddClick(Sender: TObject);
    procedure btnCatEditClick(Sender: TObject);
    procedure btnCatDeleteClick(Sender: TObject);
    procedure btnLocAddClick(Sender: TObject);
    procedure btnLocEditClick(Sender: TObject);
    procedure btnLocDeleteClick(Sender: TObject);
    procedure pcMainChange(Sender: TObject);
    procedure chkShowDeletedChange(Sender: TObject);
    procedure chkLoansOnlyLoanedChange(Sender: TObject);
    procedure gridBooksSelection(Sender: TObject; aCol, aRow: Integer);
    procedure gridAnySelection(Sender: TObject; aCol, aRow: Integer);
    procedure splBooksCopiesMoved(Sender: TObject);
    procedure gridLoansSelectCell(Sender: TObject; aCol, aRow: Integer;
      var CanSelect: Boolean);
    procedure gridLoansValidateEntry(Sender: TObject; aCol, aRow: Integer;
      const OldValue: string; var NewValue: String);
    procedure gridLoansEditingDone(Sender: TObject);
    procedure gridLoansDblClick(Sender: TObject);
    procedure gridLoansKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure gridOverdueDblClick(Sender: TObject);
  private
    FDB: TLibraryDB;
    FReports: TReportService;
    FReportLines: TStringList;
    FIcons: TImageList;
    FLoanIssuedCol: Integer;
    FLoanDueCol: Integer;
    procedure RefreshAll;
    procedure RefreshBooks;
    procedure RefreshCopies;
    procedure RefreshReaders;
    procedure RefreshLoans;
    procedure RefreshOverdue;
    procedure RefreshUsers;
    procedure RefreshSettings;
    procedure SetOpenRouterModel(const AModel: string);
    procedure RefreshOpenRouterModelList;
    procedure RefreshBackups;
    procedure RefreshJournal;
    procedure RefreshCategories;
    procedure RefreshLocations;
    procedure ApplyUIFontSize;
    procedure ReflowToolbarPanel(APanel: TPanel);
    procedure ReflowSettingsPanel;
    procedure ApplyRoleUI;
    function SelectedBook: TBook;
    function SelectedCopy: TCopy;
    function SelectedReader: TReader;
    function SelectedLoan: TLoan;
    function SelectedOverdue: TLoan;
    function SelectedUser: TUser;
    function SelectedCategory: TCategory;
    function SelectedLocation: TLocation;
    procedure SetupGrid(G: TStringGrid; const Cols: array of string);
    function FindGridRowByID(G: TStringGrid; AID: TId): Integer;
    procedure SelectGridRow(G: TStringGrid; ARow: Integer; ASetFocus: Boolean);
    procedure SelectGridEntity(G: TStringGrid; AID: TId; ASetFocus: Boolean);
    procedure SelectNearestGridRow(G: TStringGrid; APreferredRow: Integer; ASetFocus: Boolean);
    procedure UpdateGridActiveMarker(G: TStringGrid);
    function GridRowHasData(G: TStringGrid; ARow: Integer): Boolean;
    procedure SetupLoansGridEditing;
    procedure SaveGridLayouts;
    procedure LoadGridLayouts;
    procedure RecalcGridRowHeights(G: TStringGrid);
    procedure ClampBooksCopiesPanelHeight;
    procedure SetupUIIcons;
    procedure ApplyButtonIcon(AButton: TBitBtn; AIndex: Integer);
    procedure GridHeaderSized(Sender: TObject; IsColumn: Boolean; Index: Integer);
    procedure GridPrepareCanvas(Sender: TObject; aCol, aRow: Integer;
      aState: TGridDrawState);
    procedure ShowReportTable(ALines: TStrings);
    function CommitLoanDateCell(aCol, aRow: Integer; const AText: string;
      out ANormalized: string; out AError: string): Boolean;
    function CommitLoanDateValue(aCol, aRow: Integer; ADate: TDateTime;
      out AError: string): Boolean;
    procedure EditSelectedLoanDate(AForceCol: Integer);
    procedure OpenLoanCopy(ALoan: TLoan);
    procedure OpenLoanBook(ALoan: TLoan);
    procedure OpenLoanReader(ALoan: TLoan);
    procedure ApplyLibraryTitle;
  public
    property DB: TLibraryDB read FDB write FDB;
  end;

var
  MainForm: TMainForm;

implementation

{$R *.lfm}

uses
  FileUtil, LazFileUtils, StrUtils, Math, LCLIntf;

const
  MIN_BOOK_COPY_PANEL_HEIGHT = 120;
  ACTIVE_MARKER_COL = 0;
  DATA_FIRST_COL = 1;
  ACTIVE_MARKER_WIDTH = 24;
  ACTIVE_MARKER = '▶';
  { RGB(139,69,19) — коричневый для подписи активной закладки }
  ACTIVE_TAB_CAPTION_COLOR = TColor($0013458B);

procedure TPageControl.LMDrawItem(var Message: TLMDrawItems);
var
  DIS: PDrawItemStruct;
  C: TCanvas;
  R: TRect;
  PgIdx, ImgIdx, X, Y: Integer;
  Pg: TCustomPage;
  IsActive: Boolean;
  S: string;
begin
  DIS := Message.DrawItemStruct;
  if DIS = nil then
    Exit;
  PgIdx := TabToPageIndex(Integer(DIS^.itemID));
  if (PgIdx < 0) or (PgIdx >= PageCount) then
    Exit;
  Pg := GetPage(PgIdx);
  IsActive := ((DIS^.itemState and ODS_SELECTED) <> 0) or
    (Pg = ActivePageComponent);

  C := TCanvas.Create;
  try
    C.Handle := DIS^._hDC;
    R := DIS^.rcItem;
    C.Brush.Color := clBtnFace;
    C.FillRect(R);
    C.Font.Assign(Font);
    if IsActive then
      C.Font.Color := ACTIVE_TAB_CAPTION_COLOR
    else
      C.Font.Color := clWindowText;

    ImgIdx := GetImageIndex(PgIdx);
    if (Images <> nil) and (ImgIdx >= 0) then
    begin
      X := R.Left + 4;
      Y := R.Top + (R.Bottom - R.Top - Images.Height) div 2;
      Images.Draw(C, X, Y, ImgIdx, True);
      Inc(R.Left, Images.Width + 6);
    end;

    S := Pg.Caption;
    C.Brush.Style := bsClear;
    C.TextOut(R.Left, R.Top + (R.Bottom - R.Top - C.TextHeight(S)) div 2, S);
    Message.Result := 1;
  finally
    C.Handle := 0;
    C.Free;
  end;
end;

procedure TMainForm.SetupGrid(G: TStringGrid; const Cols: array of string);
var
  I: Integer;
  W: Integer;
  TS: TTextStyle;
begin
  G.FixedRows := 1;
  G.RowCount := 2;
  G.ColCount := Length(Cols) + 1;
  G.Options := G.Options
    + [goThumbTracking, goColSizing, goDrawFocusSelected]
    - [goRowSelect, goRangeSelect];
  G.SelectedColor := clHighlight;
  G.AutoFillColumns := False;
  G.FixedCols := 0;
  TS := G.DefaultTextStyle;
  TS.Wordbreak := True;
  TS.SingleLine := False;
  TS.Clipping := True;
  TS.Layout := tlTop;
  TS.EndEllipsis := False;
  G.DefaultTextStyle := TS;
  G.Options := G.Options - [goCellEllipsis];
  G.OnHeaderSized := @GridHeaderSized;
  G.OnPrepareCanvas := @GridPrepareCanvas;
  G.OnSelection := @gridAnySelection;
  G.Cells[ACTIVE_MARKER_COL, 0] := '';
  G.ColWidths[ACTIVE_MARKER_COL] := ACTIVE_MARKER_WIDTH;
  for I := 0 to High(Cols) do
  begin
    G.Cells[I + DATA_FIRST_COL, 0] := Cols[I];
    W := G.Canvas.TextWidth(Cols[I] + 'WWWW');
    if W < 90 then
      W := 90;
    if W > 280 then
      W := 280;
    G.ColWidths[I + DATA_FIRST_COL] := W;
  end;
end;

function TMainForm.GridRowHasData(G: TStringGrid; ARow: Integer): Boolean;
var
  C: Integer;
begin
  Result := False;
  if (G = nil) or (ARow < G.FixedRows) or (ARow >= G.RowCount) then
    Exit;
  if G.Objects[ACTIVE_MARKER_COL, ARow] <> nil then
    Exit(True);
  for C := DATA_FIRST_COL to G.ColCount - 1 do
    if Trim(G.Cells[C, ARow]) <> '' then
      Exit(True);
end;

procedure TMainForm.UpdateGridActiveMarker(G: TStringGrid);
var
  R: Integer;
begin
  if (G = nil) or (G.ColCount <= ACTIVE_MARKER_COL) then
    Exit;
  G.ColWidths[ACTIVE_MARKER_COL] := ACTIVE_MARKER_WIDTH;
  for R := G.FixedRows to G.RowCount - 1 do
    if GridRowHasData(G, R) and (R = G.Row) then
      G.Cells[ACTIVE_MARKER_COL, R] := ACTIVE_MARKER
    else
      G.Cells[ACTIVE_MARKER_COL, R] := '';
end;

function TMainForm.FindGridRowByID(G: TStringGrid; AID: TId): Integer;
var
  R: Integer;
begin
  Result := 0;
  if (G = nil) or (AID <= 0) then
    Exit;
  for R := G.FixedRows to G.RowCount - 1 do
    if (G.Objects[ACTIVE_MARKER_COL, R] is TEntity) and
       (TEntity(G.Objects[ACTIVE_MARKER_COL, R]).ID = AID) then
      Exit(R);
end;

procedure TMainForm.SelectGridRow(G: TStringGrid; ARow: Integer; ASetFocus: Boolean);
var
  Vis: Integer;
begin
  if (G = nil) or (G.RowCount <= G.FixedRows) then
    Exit;
  if ARow < G.FixedRows then
    ARow := G.FixedRows;
  if ARow >= G.RowCount then
    ARow := G.RowCount - 1;
  if not GridRowHasData(G, ARow) then
  begin
    UpdateGridActiveMarker(G);
    Exit;
  end;
  G.Row := ARow;
  if G.ColCount > DATA_FIRST_COL then
    G.Col := DATA_FIRST_COL
  else
    G.Col := ACTIVE_MARKER_COL;
  Vis := G.VisibleRowCount;
  if Vis < 1 then
    Vis := 1;
  if ARow < G.TopRow then
    G.TopRow := ARow
  else if ARow >= G.TopRow + Vis then
    G.TopRow := Max(G.FixedRows, ARow - Vis + 1);
  UpdateGridActiveMarker(G);
  if ASetFocus and G.CanFocus then
    G.SetFocus;
end;

procedure TMainForm.SelectNearestGridRow(G: TStringGrid; APreferredRow: Integer; ASetFocus: Boolean);
var
  R: Integer;
begin
  if G = nil then
    Exit;
  if APreferredRow >= G.RowCount then
    APreferredRow := G.RowCount - 1;
  for R := APreferredRow downto G.FixedRows do
    if GridRowHasData(G, R) then
    begin
      SelectGridRow(G, R, ASetFocus);
      Exit;
    end;
  for R := G.FixedRows to G.RowCount - 1 do
    if GridRowHasData(G, R) then
    begin
      SelectGridRow(G, R, ASetFocus);
      Exit;
    end;
  UpdateGridActiveMarker(G);
end;

procedure TMainForm.SelectGridEntity(G: TStringGrid; AID: TId; ASetFocus: Boolean);
var
  Row: Integer;
begin
  Row := FindGridRowByID(G, AID);
  if Row > 0 then
    SelectGridRow(G, Row, ASetFocus)
  else
    SelectNearestGridRow(G, G.Row, ASetFocus);
end;

procedure TMainForm.GridPrepareCanvas(Sender: TObject; aCol, aRow: Integer;
  aState: TGridDrawState);
var
  G: TStringGrid;
  TS: TTextStyle;
begin
  { PrepareCanvas LCL всегда ставит SingleLine:=True без Columns — из‑за этого
    Wordbreak не работает. Принудительно включаем многострочный перенос. }
  G := Sender as TStringGrid;
  TS := G.Canvas.TextStyle;
  if aCol = ACTIVE_MARKER_COL then
  begin
    TS.Wordbreak := False;
    TS.SingleLine := True;
    TS.Alignment := taCenter;
    TS.Layout := tlCenter;
    TS.EndEllipsis := False;
  end
  else
  begin
    TS.Wordbreak := True;
    TS.SingleLine := False;
    TS.Clipping := True;
    TS.Layout := tlTop;
    TS.EndEllipsis := False;
  end;
  G.Canvas.TextStyle := TS;
  if (aRow >= G.FixedRows) and
     ((gdSelected in aState) or (gdFocused in aState)) then
  begin
    G.Canvas.Brush.Color := clHighlight;
    G.Canvas.Font.Color := clHighlightText;
  end;
end;

procedure TMainForm.RecalcGridRowHeights(G: TStringGrid);
var
  R, C, MaxH, CellH, BaseH, W: Integer;
  CalcRect: TRect;
  S: string;
begin
  if (G = nil) or (G.ColCount <= 0) or (G.RowCount <= 0) then
    Exit;
  BaseH := G.Canvas.TextHeight('Ag') + 8;
  if BaseH < 22 then
    BaseH := 22;
  for R := 0 to G.RowCount - 1 do
  begin
    MaxH := BaseH;
    for C := DATA_FIRST_COL to G.ColCount - 1 do
    begin
      S := G.Cells[C, R];
      if S = '' then
        Continue;
      W := G.ColWidths[C] - 6;
      if W < 20 then
        W := 20;
      CalcRect := Classes.Rect(0, 0, W, 0);
      DrawText(G.Canvas.Handle, PChar(S), -1, CalcRect,
        DT_CALCRECT or DT_LEFT or DT_WORDBREAK or DT_NOPREFIX);
      CellH := (CalcRect.Bottom - CalcRect.Top) + 8;
      if CellH > MaxH then
        MaxH := CellH;
    end;
    if MaxH > 160 then
      MaxH := 160;
    G.RowHeights[R] := MaxH;
  end;
end;

procedure TMainForm.GridHeaderSized(Sender: TObject; IsColumn: Boolean; Index: Integer);
begin
  if IsColumn and (Index = ACTIVE_MARKER_COL) then
  begin
    (Sender as TStringGrid).ColWidths[ACTIVE_MARKER_COL] := ACTIVE_MARKER_WIDTH;
    Exit;
  end;
  if IsColumn then
    RecalcGridRowHeights(Sender as TStringGrid);
end;

procedure TMainForm.SetupLoansGridEditing;
begin
  { даты выбираются через календарь; текстовая правка оставлена как запасной вариант }
  gridLoans.Options := gridLoans.Options - [goRowSelect] +
    [goEditing, goThumbTracking, goColSizing, goDrawFocusSelected];
  gridLoans.OnSelectCell := @gridLoansSelectCell;
  gridLoans.OnValidateEntry := @gridLoansValidateEntry;
  gridLoans.OnEditingDone := @gridLoansEditingDone;
  gridLoans.OnDblClick := @gridLoansDblClick;
  gridLoans.OnKeyDown := @gridLoansKeyDown;
end;

procedure TMainForm.SaveGridLayouts;
var
  SL: TStringList;
  Fn: string;

  function UserKey(const AName: string): string;
  begin
    Result := 'User.' + IntToStr(FDB.CurrentUser.ID) + '.' + AName;
  end;

  procedure SaveOne(G: TStringGrid; const AName: string);
  var
    I: Integer;
    S: string;
  begin
    if (G = nil) or (G.ColCount <= 0) then
      Exit;
    S := '';
    G.ColWidths[ACTIVE_MARKER_COL] := ACTIVE_MARKER_WIDTH;
    for I := DATA_FIRST_COL to G.ColCount - 1 do
    begin
      if I > DATA_FIRST_COL then
        S := S + ',';
      S := S + IntToStr(G.ColWidths[I]);
    end;
    SL.Values[UserKey(AName)] := S;
  end;

begin
  if (FDB = nil) or (FDB.CurrentUser = nil) then
    Exit;
  Fn := FDB.Paths.UserLayoutFile;
  SL := TStringList.Create;
  try
    try
      if FileExists(Fn) then
        SL.LoadFromFile(Fn);
      SaveOne(gridBooks, 'Books');
      SaveOne(gridCopies, 'Copies');
      SaveOne(gridReaders, 'Readers');
      SaveOne(gridLoans, 'Loans');
      SaveOne(gridOverdue, 'Overdue');
      SaveOne(gridCategories, 'Categories');
      SaveOne(gridLocations, 'Locations');
      SaveOne(gridUsers, 'Users');
      SaveOne(gridJournal, 'Journal');
      if pnlCopiesBottom <> nil then
        SL.Values[UserKey('BooksCopiesPanelHeight')] := IntToStr(pnlCopiesBottom.Height);
      SL.Values[UserKey('ShowDeleted')] := BoolToStr(chkShowDeleted.Checked, '1', '0');
      SL.Values[UserKey('LoansOnlyLoaned')] := BoolToStr(chkLoansOnlyLoaned.Checked, '1', '0');
      if pcMain.ActivePage <> nil then
        SL.Values[UserKey('ActivePage')] := pcMain.ActivePage.Name;
      SL.Values[UserKey('BookSearch')] := edtBookSearch.Text;
      SL.Values[UserKey('BookSearchInv')] := edtBookSearchInv.Text;
      SL.Values[UserKey('ReaderSearch')] := edtReaderSearch.Text;
      SL.SaveToFile(Fn);
    except
      { настройки ширины не критичны }
    end;
  finally
    SL.Free;
  end;
end;

procedure TMainForm.LoadGridLayouts;
var
  SL, Parts: TStringList;
  Fn: string;

  function UserKey(const AName: string): string;
  begin
    Result := 'User.' + IntToStr(FDB.CurrentUser.ID) + '.' + AName;
  end;

  function ReadValue(const AName: string): string;
  begin
    Result := Trim(SL.Values[UserKey(AName)]);
    if Result = '' then
      Result := Trim(SL.Values[AName]);
  end;

  function ReadBoolValue(const AName: string; ADefault: Boolean): Boolean;
  var
    Raw: string;
  begin
    Raw := ReadValue(AName);
    if Raw = '' then
      Result := ADefault
    else
      Result := Raw = '1';
  end;

  procedure LoadActivePage;
  var
    I: Integer;
    PageName: string;
  begin
    PageName := ReadValue('ActivePage');
    if PageName = '' then
      Exit;
    for I := 0 to pcMain.PageCount - 1 do
      if SameText(pcMain.Pages[I].Name, PageName) and pcMain.Pages[I].TabVisible then
      begin
        pcMain.ActivePage := pcMain.Pages[I];
        Exit;
      end;
  end;

  procedure LoadOne(G: TStringGrid; const AName: string);
  var
    I, W, N, TargetCol: Integer;
    Raw: string;
  begin
    if (G = nil) or (G.ColCount <= 0) then
      Exit;
    G.ColWidths[ACTIVE_MARKER_COL] := ACTIVE_MARKER_WIDTH;
    Raw := ReadValue(AName);
    if Raw = '' then
      Exit;
    Parts.Clear;
    Parts.StrictDelimiter := True;
    Parts.Delimiter := ',';
    Parts.DelimitedText := Raw;
    N := Parts.Count;
    if N > G.ColCount - DATA_FIRST_COL then
      N := G.ColCount - DATA_FIRST_COL;
    for I := 0 to N - 1 do
    begin
      TargetCol := I + DATA_FIRST_COL;
      W := StrToIntDef(Trim(Parts[I]), G.ColWidths[TargetCol]);
      if W < 40 then
        W := 40;
      if W > 2000 then
        W := 2000;
      G.ColWidths[TargetCol] := W;
    end;
    G.ColWidths[ACTIVE_MARKER_COL] := ACTIVE_MARKER_WIDTH;
  end;

begin
  if (FDB = nil) or (FDB.CurrentUser = nil) then
    Exit;
  Fn := FDB.Paths.UserLayoutFile;
  if not FileExists(Fn) then
    Fn := FDB.Paths.GridLayoutFile;
  if not FileExists(Fn) then
    Exit;
  SL := TStringList.Create;
  Parts := TStringList.Create;
  try
    try
      SL.LoadFromFile(Fn);
      LoadOne(gridBooks, 'Books');
      LoadOne(gridCopies, 'Copies');
      LoadOne(gridReaders, 'Readers');
      LoadOne(gridLoans, 'Loans');
      LoadOne(gridOverdue, 'Overdue');
      LoadOne(gridCategories, 'Categories');
      LoadOne(gridLocations, 'Locations');
      LoadOne(gridUsers, 'Users');
      LoadOne(gridJournal, 'Journal');
      if pnlCopiesBottom <> nil then
        pnlCopiesBottom.Height := StrToIntDef(ReadValue('BooksCopiesPanelHeight'),
          pnlCopiesBottom.Height);
      chkShowDeleted.Checked := ReadBoolValue('ShowDeleted', chkShowDeleted.Checked);
      chkLoansOnlyLoaned.Checked := ReadBoolValue('LoansOnlyLoaned', chkLoansOnlyLoaned.Checked);
      edtBookSearch.Text := ReadValue('BookSearch');
      edtBookSearchInv.Text := ReadValue('BookSearchInv');
      edtReaderSearch.Text := ReadValue('ReaderSearch');
      LoadActivePage;
      ClampBooksCopiesPanelHeight;
    except
      { игнорируем повреждённый файл раскладки }
    end;
  finally
    Parts.Free;
    SL.Free;
  end;
end;

function TMainForm.CommitLoanDateValue(aCol, aRow: Integer; ADate: TDateTime;
  out AError: string): Boolean;
var
  L: TLoan;
begin
  Result := False;
  AError := '';
  if (aCol <> FLoanDueCol) and (aCol <> FLoanIssuedCol) then
    Exit;
  if aRow <= 0 then
    Exit;
  L := TLoan(gridLoans.Objects[0, aRow]);
  if (L = nil) or L.Deleted or (L.State <> lsLoaned) then
  begin
    AError := 'Даты можно изменять только для открытой выдачи.';
    Exit;
  end;
  if aCol = FLoanIssuedCol then
  begin
    if not FDB.UpdateLoanIssuedDate(L, ADate, AError) then
      Exit;
    gridLoans.Cells[aCol, aRow] := FormatDateRu(L.IssuedAt);
  end
  else
  begin
    if not FDB.UpdateLoanDueDate(L, ADate, AError) then
      Exit;
    gridLoans.Cells[aCol, aRow] := FormatDateRu(L.DueAt);
  end;
  Result := True;
  RefreshOverdue;
  RefreshJournal;
end;

procedure TMainForm.EditSelectedLoanDate(AForceCol: Integer);
var
  Col, Row: Integer;
  L: TLoan;
  D: TDateTime;
  Title, Err: string;
begin
  Row := gridLoans.Row;
  if AForceCol >= 0 then
    Col := AForceCol
  else
    Col := gridLoans.Col;
  if (Col <> FLoanDueCol) and (Col <> FLoanIssuedCol) then
  begin
    if AForceCol < 0 then
      Col := FLoanDueCol
    else
    begin
      MessageDlg('Выберите ячейку «Выдана» или «Срок».', mtInformation, [mbOK], 0);
      Exit;
    end;
  end;
  if Row <= 0 then
  begin
    MessageDlg('Выберите выдачу в таблице.', mtInformation, [mbOK], 0);
    Exit;
  end;
  L := TLoan(gridLoans.Objects[0, Row]);
  if (L = nil) or L.Deleted or (L.State <> lsLoaned) then
  begin
    MessageDlg('Даты можно изменять только для открытой выдачи.', mtWarning, [mbOK], 0);
    Exit;
  end;
  if Col = FLoanIssuedCol then
  begin
    Title := 'Дата выдачи';
    D := L.IssuedAt;
  end
  else
  begin
    Title := 'Срок возврата';
    D := L.DueAt;
  end;
  if D <= 0 then
    D := Date;
  if not PickDateDialog(FDB, Title, D) then
    Exit;
  if not CommitLoanDateValue(Col, Row, D, Err) then
  begin
    if Err <> '' then
      MessageDlg(Err, mtError, [mbOK], 0);
    Exit;
  end;
  gridLoans.Col := Col;
end;

function TMainForm.CommitLoanDateCell(aCol, aRow: Integer; const AText: string;
  out ANormalized: string; out AError: string): Boolean;
var
  L: TLoan;
  NewDate: TDateTime;
begin
  Result := False;
  ANormalized := AText;
  AError := '';
  if (aCol <> FLoanDueCol) and (aCol <> FLoanIssuedCol) then
    Exit;
  if aRow <= 0 then
    Exit;
  L := TLoan(gridLoans.Objects[0, aRow]);
  if (L = nil) or L.Deleted or (L.State <> lsLoaned) then
  begin
    AError := 'Даты можно изменять только для открытой выдачи.';
    Exit;
  end;
  if not ParseDateRu(AText, NewDate) then
  begin
    AError := 'Введите дату в формате ДД.ММ.ГГГГ или ДД.ММ.';
    Exit;
  end;
  if aCol = FLoanIssuedCol then
  begin
    if not FDB.UpdateLoanIssuedDate(L, NewDate, AError) then
      Exit;
    ANormalized := FormatDateRu(L.IssuedAt);
  end
  else
  begin
    if not FDB.UpdateLoanDueDate(L, NewDate, AError) then
      Exit;
    ANormalized := FormatDateRu(L.DueAt);
  end;
  Result := True;
  RefreshOverdue;
  RefreshJournal;
end;

procedure TMainForm.gridLoansSelectCell(Sender: TObject; aCol, aRow: Integer;
  var CanSelect: Boolean);
var
  L: TLoan;
  AllowEdit: Boolean;
begin
  CanSelect := True;
  AllowEdit := False;
  if (aRow > 0) and ((aCol = FLoanDueCol) or (aCol = FLoanIssuedCol)) then
  begin
    L := TLoan(gridLoans.Objects[0, aRow]);
    AllowEdit := (L <> nil) and (not L.Deleted) and (L.State = lsLoaned);
  end;
  if AllowEdit then
    gridLoans.Options := gridLoans.Options + [goEditing]
  else
    gridLoans.Options := gridLoans.Options - [goEditing];
end;

procedure TMainForm.gridLoansValidateEntry(Sender: TObject; aCol, aRow: Integer;
  const OldValue: string; var NewValue: String);
var
  Normalized, Err: string;
begin
  if (aCol <> FLoanDueCol) and (aCol <> FLoanIssuedCol) then
  begin
    NewValue := OldValue;
    Exit;
  end;
  if aRow <= 0 then
    Exit;
  if not CommitLoanDateCell(aCol, aRow, NewValue, Normalized, Err) then
  begin
    NewValue := OldValue;
    if Err <> '' then
      MessageDlg(Err, mtError, [mbOK], 0);
    Exit;
  end;
  NewValue := Normalized;
end;

procedure TMainForm.gridLoansEditingDone(Sender: TObject);
var
  Col, Row: Integer;
  Normalized, Err, Cur: string;
  L: TLoan;
  Expected: string;
begin
  Col := gridLoans.Col;
  Row := gridLoans.Row;
  if (Col <> FLoanDueCol) and (Col <> FLoanIssuedCol) then
    Exit;
  if Row <= 0 then
    Exit;
  L := TLoan(gridLoans.Objects[0, Row]);
  if L = nil then
    Exit;
  Cur := Trim(gridLoans.Cells[Col, Row]);
  if Col = FLoanIssuedCol then
    Expected := FormatDateRu(L.IssuedAt)
  else
    Expected := FormatDateRu(L.DueAt);
  if Cur = Expected then
    Exit;
  if not CommitLoanDateCell(Col, Row, Cur, Normalized, Err) then
  begin
    gridLoans.Cells[Col, Row] := Expected;
    if Err <> '' then
      MessageDlg(Err, mtError, [mbOK], 0);
    Exit;
  end;
  gridLoans.Cells[Col, Row] := Normalized;
end;

procedure TMainForm.gridLoansDblClick(Sender: TObject);
begin
  if gridLoans.Col = DATA_FIRST_COL then
    OpenLoanCopy(SelectedLoan)
  else if gridLoans.Col = DATA_FIRST_COL + 1 then
    OpenLoanBook(SelectedLoan)
  else if gridLoans.Col = DATA_FIRST_COL + 2 then
    OpenLoanReader(SelectedLoan)
  else if (gridLoans.Col = FLoanIssuedCol) or (gridLoans.Col = FLoanDueCol) then
    EditSelectedLoanDate(gridLoans.Col);
end;

procedure TMainForm.gridOverdueDblClick(Sender: TObject);
begin
  if gridOverdue.Col = DATA_FIRST_COL then
    OpenLoanCopy(SelectedOverdue)
  else if gridOverdue.Col = DATA_FIRST_COL + 1 then
    OpenLoanBook(SelectedOverdue)
  else if gridOverdue.Col = DATA_FIRST_COL + 2 then
    OpenLoanReader(SelectedOverdue);
end;

procedure TMainForm.gridLoansKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if (Key = VK_F2) or (Key = VK_RETURN) then
    if (gridLoans.Col = FLoanIssuedCol) or (gridLoans.Col = FLoanDueCol) then
    begin
      Key := 0;
      EditSelectedLoanDate(gridLoans.Col);
    end;
end;

procedure TMainForm.btnLoanDateClick(Sender: TObject);
begin
  EditSelectedLoanDate(-1);
end;

procedure TMainForm.FormCreate(Sender: TObject);
begin
  Caption := APP_NAME;
  WindowState := wsMaximized;
  pcMain.OwnerDraw := True;
  if pcMain.HandleAllocated then
    RecreateWnd(pcMain);
  SetupUIIcons;
  SetupGrid(gridBooks, ['Название', 'Автор', 'Издательство', 'Категория', 'Год', 'ISBN', 'Удалён']);
  gridBooks.OnDblClick := @btnBookEditClick;
  edtBookSearch.Hint := 'Поиск по названию, автору или ISBN';
  edtBookSearchInv.Hint := 'Поиск по инвентарному номеру экземпляра';
  edtBookSearch.Placeholder := 'По названию';
  edtBookSearchInv.Placeholder := 'По инв. №';
  edtBookSearchInv.OnKeyPress := @edtBookSearchInvKeyPress;
  SetupGrid(gridCopies, ['Инв. №', 'Статус', 'Место', 'Состояние', 'Удалён']);
  gridCopies.OnDblClick := @btnCopyEditClick;
  gridBooks.OnSelection := @gridBooksSelection;
  splBooksCopies.OnMoved := @splBooksCopiesMoved;
  SetupGrid(gridReaders, ['ФИО', 'Телефон', 'Статус', 'Регистрация', 'Удалён']);
  gridReaders.OnDblClick := @btnReaderEditClick;
  SetupGrid(gridLoans, ['Инв. №', 'Книга', 'Читатель', 'Выдана', 'Срок', 'Состояние']);
  FLoanIssuedCol := DATA_FIRST_COL + 3;
  FLoanDueCol := DATA_FIRST_COL + 4;
  SetupLoansGridEditing;
  SetupGrid(gridOverdue, ['Инв. №', 'Книга', 'Читатель', 'Срок', 'Дней']);
  gridOverdue.OnDblClick := @gridOverdueDblClick;
  SetupGrid(gridUsers, ['Логин', 'Имя', 'Роль', 'Активен', 'Удалён']);
  gridUsers.OnDblClick := @btnUserEditClick;
  SetupGrid(gridJournal, ['Дата', 'Пользователь', 'Действие', 'Описание']);
  SetupGrid(gridCategories, ['Наименование', 'Шифр', 'Описание', 'Удалён']);
  gridCategories.OnDblClick := @btnCatEditClick;
  SetupGrid(gridLocations, ['Наименование', 'Описание', 'Удалён']);
  gridLocations.OnDblClick := @btnLocEditClick;
  SetupGrid(gridReport, ['']);
  FReportLines := TStringList.Create;
  cbReport.Items.Clear;
  cbReport.Items.Add('Каталог книг');
  cbReport.Items.Add('Экземпляры');
  cbReport.Items.Add('Свободные экземпляры');
  cbReport.Items.Add('Книги на руках');
  cbReport.Items.Add('Просроченные выдачи');
  cbReport.Items.Add('История выдач');
  cbReport.Items.Add('Список читателей');
  cbReport.Items.Add('Журнал действий');
  cbReport.ItemIndex := 0;
end;

procedure TMainForm.ApplyButtonIcon(AButton: TBitBtn; AIndex: Integer);
var
  Bmp: TBitmap;
begin
  if (AButton = nil) or (FIcons = nil) then
    Exit;
  Bmp := TBitmap.Create;
  try
    FIcons.GetBitmap(AIndex, Bmp);
    AButton.Glyph.Assign(Bmp);
    AButton.NumGlyphs := 1;
    AButton.Layout := blGlyphLeft;
    AButton.Spacing := 4;
  finally
    Bmp.Free;
  end;
end;

procedure TMainForm.SetupUIIcons;
begin
  if FIcons = nil then
    FIcons := TImageList.Create(Self);
  BuildAppIcons(FIcons);

  pcMain.Images := FIcons;
  tsBooks.ImageIndex := icoBooks;
  tsReaders.ImageIndex := icoReaders;
  tsLoans.ImageIndex := icoLoans;
  tsOverdue.ImageIndex := icoOverdue;
  tsCategories.ImageIndex := icoCategories;
  tsLocations.ImageIndex := icoLocations;
  tsReports.ImageIndex := icoReports;
  tsUsers.ImageIndex := icoUsers;
  tsSettings.ImageIndex := icoSettings;
  tsBackup.ImageIndex := icoBackup;
  tsJournal.ImageIndex := icoJournal;

  ApplyButtonIcon(btnBookSearch, icoSearch);
  ApplyButtonIcon(btnBookAdd, icoAdd);
  ApplyButtonIcon(btnBookRecognize, icoRun);
  ApplyButtonIcon(btnBookEdit, icoEdit);
  ApplyButtonIcon(btnBookDelete, icoDelete);
  ApplyButtonIcon(btnBookRestore, icoRestore);
  ApplyButtonIcon(btnCopyAdd, icoAdd);
  ApplyButtonIcon(btnCopyEdit, icoEdit);
  ApplyButtonIcon(btnCopyDelete, icoDelete);

  ApplyButtonIcon(btnReaderSearch, icoSearch);
  ApplyButtonIcon(btnReaderAdd, icoAdd);
  ApplyButtonIcon(btnReaderEdit, icoEdit);
  ApplyButtonIcon(btnReaderDelete, icoDelete);
  ApplyButtonIcon(btnReaderRestore, icoRestore);

  ApplyButtonIcon(btnLoanIssue, icoIssue);
  ApplyButtonIcon(btnLoanReturn, icoReturn);
  ApplyButtonIcon(btnLoanRenew, icoRenew);
  ApplyButtonIcon(btnLoanDate, icoCalendar);

  ApplyButtonIcon(btnCatAdd, icoAdd);
  ApplyButtonIcon(btnCatEdit, icoEdit);
  ApplyButtonIcon(btnCatDelete, icoDelete);

  ApplyButtonIcon(btnLocAdd, icoAdd);
  ApplyButtonIcon(btnLocEdit, icoEdit);
  ApplyButtonIcon(btnLocDelete, icoDelete);

  ApplyButtonIcon(btnReportShow, icoRun);
  ApplyButtonIcon(btnReportSave, icoCsv);

  ApplyButtonIcon(btnUserAdd, icoAdd);
  ApplyButtonIcon(btnUserEdit, icoEdit);
  ApplyButtonIcon(btnUserDelete, icoDelete);

  ApplyButtonIcon(btnSaveSettings, icoSave);
  ApplyButtonIcon(btnTestOpenRouter, icoTest);
  ApplyButtonIcon(btnSelectOpenRouterModel, icoTest);
  ApplyButtonIcon(btnBackupNow, icoBackup);
  ApplyButtonIcon(btnRestoreBackup, icoRestore);
end;

procedure TMainForm.ApplyLibraryTitle;
var
  Title: string;
begin
  if FDB = nil then
    Exit;
  Title := EffectiveLibraryTitle(FDB.Settings.LibraryName);
  Caption := Title;
  Application.Title := Title;
end;

procedure TMainForm.ClampBooksCopiesPanelHeight;
var
  MaxBottomHeight: Integer;
begin
  if (tsBooks = nil) or (pnlBooksTop = nil) or (splBooksCopies = nil) or
    (pnlCopiesBottom = nil) then
    Exit;

  MaxBottomHeight := tsBooks.ClientHeight - pnlBooksTop.Height -
    splBooksCopies.Height - MIN_BOOK_COPY_PANEL_HEIGHT;
  if MaxBottomHeight < MIN_BOOK_COPY_PANEL_HEIGHT then
    MaxBottomHeight := MIN_BOOK_COPY_PANEL_HEIGHT;

  if pnlCopiesBottom.Height < MIN_BOOK_COPY_PANEL_HEIGHT then
    pnlCopiesBottom.Height := MIN_BOOK_COPY_PANEL_HEIGHT
  else if pnlCopiesBottom.Height > MaxBottomHeight then
    pnlCopiesBottom.Height := MaxBottomHeight;
end;

procedure TMainForm.gridBooksSelection(Sender: TObject; aCol, aRow: Integer);
begin
  UpdateGridActiveMarker(Sender as TStringGrid);
  RefreshCopies;
end;

procedure TMainForm.gridAnySelection(Sender: TObject; aCol, aRow: Integer);
begin
  UpdateGridActiveMarker(Sender as TStringGrid);
end;

procedure TMainForm.splBooksCopiesMoved(Sender: TObject);
begin
  ClampBooksCopiesPanelHeight;
end;

procedure TPlaceholderEdit.SetPlaceholder(const Value: string);
begin
  if FPlaceholder <> Value then
  begin
    FPlaceholder := Value;
    Invalidate;
  end;
end;

procedure TPlaceholderEdit.WndProc(var Message: TLMessage);
var
  DC: HDC;
  C: TCanvas;
begin
  inherited WndProc(Message);
  if (Message.Msg = LM_PAINT) and (Text = '') and not Focused and (FPlaceholder <> '') then
  begin
    DC := GetDC(Handle);
    if DC <> 0 then
    try
      C := TCanvas.Create;
      try
        C.Handle := DC;
        C.Brush.Style := bsClear;
        C.Font.Color := clGray;
        C.Font.Style := [fsItalic];
        C.TextRect(ClientRect, 4, 2, FPlaceholder);
      finally
        C.Handle := 0;
        C.Free;
      end;
    finally
      ReleaseDC(Handle, DC);
    end;
  end;
end;

procedure TMainForm.FormShow(Sender: TObject);
begin
  FReports := TReportService.Create(FDB);
  ApplyUIFontSize;
  ApplyRoleUI;
  LoadGridLayouts;
  edtBookSearch.OnChange := @edtBookSearchChange;
  edtBookSearchInv.OnChange := @edtBookSearchInvChange;
  ClampBooksCopiesPanelHeight;
  RefreshAll;
  ApplyLibraryTitle;
  statusBar.SimpleText := 'Пользователь: ' + FDB.CurrentUser.DisplayName +
    ' | ' + EffectiveLibraryTitle(FDB.Settings.LibraryName);
end;

procedure TMainForm.FormClose(Sender: TObject; var CloseAction: TCloseAction);
var
  Path, Err: string;
begin
  SaveGridLayouts;
  if FDB <> nil then
  begin
    if FDB.MaybeAutoBackup(Path, Err) then
      MessageDlg('Создана еженедельная резервная копия:' + LineEnding + Path, mtInformation, [mbOK], 0)
    else if Err <> '' then
      MessageDlg(Err, mtWarning, [mbOK], 0);
  end;
  FreeAndNil(FReports);
  FreeAndNil(FReportLines);
end;

procedure TMainForm.ApplyRoleUI;
var
  IsAdmin: Boolean;
begin
  IsAdmin := (FDB.CurrentUser <> nil) and (FDB.CurrentUser.Role = urAdmin);
  tsUsers.TabVisible := IsAdmin;
  tsJournal.TabVisible := IsAdmin;
  tsSettings.TabVisible := IsAdmin;
end;

procedure TMainForm.RefreshAll;
begin
  RefreshBooks;
  RefreshCopies;
  RefreshReaders;
  RefreshLoans;
  RefreshOverdue;
  RefreshUsers;
  RefreshSettings;
  RefreshBackups;
  RefreshJournal;
  RefreshCategories;
  RefreshLocations;
end;

procedure TMainForm.RefreshBooks;
var
  List: TList;
  I: Integer;
  B: TBook;
  C: TCategory;
  CatName: string;
  KeepID: TId;
begin
  KeepID := 0;
  if SelectedBook <> nil then
    KeepID := SelectedBook.ID;
  List := TList.Create;
  try
    FDB.SearchBooks(Trim(edtBookSearch.Text), Trim(edtBookSearchInv.Text), List, chkShowDeleted.Checked);
    gridBooks.RowCount := Max(2, List.Count + 1);
    if List.Count = 0 then
    begin
      gridBooks.Rows[1].Clear;
      gridBooks.Objects[0, 1] := nil;
    end;
    for I := 0 to List.Count - 1 do
    begin
      B := TBook(List[I]);
      C := FDB.FindCategory(B.CategoryID);
      if C <> nil then CatName := C.Name else CatName := '';
      gridBooks.Cells[DATA_FIRST_COL, I + 1] := B.Title;
      gridBooks.Cells[DATA_FIRST_COL + 1, I + 1] := B.Authors;
      gridBooks.Cells[DATA_FIRST_COL + 2, I + 1] := B.Publisher;
      gridBooks.Cells[DATA_FIRST_COL + 3, I + 1] := CatName;
      gridBooks.Cells[DATA_FIRST_COL + 4, I + 1] := IntToStr(B.Year);
      gridBooks.Cells[DATA_FIRST_COL + 5, I + 1] := B.ISBN;
      gridBooks.Cells[DATA_FIRST_COL + 6, I + 1] := BoolToStr(B.Deleted, 'да', '');
      gridBooks.Objects[0, I + 1] := B;
    end;
  finally
    List.Free;
  end;
  RecalcGridRowHeights(gridBooks);
  if KeepID > 0 then
    SelectGridEntity(gridBooks, KeepID, False)
  else
    SelectNearestGridRow(gridBooks, gridBooks.Row, False);
  RefreshCopies;
end;

procedure TMainForm.RefreshCopies;
var
  I, Row: Integer;
  C: TCopy;
  B: TBook;
  L: TLocation;
  LocName: string;
  KeepID: TId;
begin
  KeepID := 0;
  if SelectedCopy <> nil then
    KeepID := SelectedCopy.ID;
  gridCopies.RowCount := 2;
  B := SelectedBook;
  if B = nil then
  begin
    gridCopies.Rows[1].Clear;
    gridCopies.Objects[0, 1] := nil;
    RecalcGridRowHeights(gridCopies);
    UpdateGridActiveMarker(gridCopies);
    Exit;
  end;

  Row := 1;
  for I := 0 to FDB.Copies.Count - 1 do
  begin
    C := TCopy(FDB.Copies[I]);
    if C.Deleted and (not chkShowDeleted.Checked) then Continue;
    if C.BookID <> B.ID then Continue;
    if Row >= gridCopies.RowCount then
      gridCopies.RowCount := Row + 1;
    L := FDB.FindLocation(C.LocationID);
    if L <> nil then LocName := L.Name else LocName := '';
    gridCopies.Cells[DATA_FIRST_COL, Row] := C.InventoryNo;
    gridCopies.Cells[DATA_FIRST_COL + 1, Row] := CopyStatusToStr(C.Status);
    gridCopies.Cells[DATA_FIRST_COL + 2, Row] := LocName;
    gridCopies.Cells[DATA_FIRST_COL + 3, Row] := C.Condition;
    gridCopies.Cells[DATA_FIRST_COL + 4, Row] := BoolToStr(C.Deleted, 'да', '');
    gridCopies.Objects[0, Row] := C;
    Inc(Row);
  end;
  if Row = 1 then
  begin
    gridCopies.Rows[1].Clear;
    gridCopies.Objects[0, 1] := nil;
  end
  else
    gridCopies.RowCount := Row;
  RecalcGridRowHeights(gridCopies);
  if KeepID > 0 then
    SelectGridEntity(gridCopies, KeepID, False)
  else
    SelectNearestGridRow(gridCopies, 1, False);
end;

procedure TMainForm.RefreshReaders;
var
  List: TList;
  I: Integer;
  R: TReader;
  KeepID: TId;
begin
  KeepID := 0;
  if SelectedReader <> nil then
    KeepID := SelectedReader.ID;
  List := TList.Create;
  try
    FDB.SearchReaders(Trim(edtReaderSearch.Text), List, chkShowDeleted.Checked);
    gridReaders.RowCount := Max(2, List.Count + 1);
    if List.Count = 0 then
    begin
      gridReaders.Rows[1].Clear;
      gridReaders.Objects[0, 1] := nil;
    end;
    for I := 0 to List.Count - 1 do
    begin
      R := TReader(List[I]);
      gridReaders.Cells[DATA_FIRST_COL, I + 1] := R.FullName;
      gridReaders.Cells[DATA_FIRST_COL + 1, I + 1] := R.Phone;
      gridReaders.Cells[DATA_FIRST_COL + 2, I + 1] := ReaderStatusToStr(R.Status);
      gridReaders.Cells[DATA_FIRST_COL + 3, I + 1] := FormatDateRu(R.RegisteredAt);
      gridReaders.Cells[DATA_FIRST_COL + 4, I + 1] := BoolToStr(R.Deleted, 'да', '');
      gridReaders.Objects[0, I + 1] := R;
    end;
  finally
    List.Free;
  end;
  RecalcGridRowHeights(gridReaders);
  if KeepID > 0 then
    SelectGridEntity(gridReaders, KeepID, False)
  else
    SelectNearestGridRow(gridReaders, gridReaders.Row, False);
end;

procedure TMainForm.RefreshLoans;
var
  I, Row: Integer;
  L: TLoan;
  C: TCopy;
  R: TReader;
  B: TBook;
  KeepID: TId;
begin
  KeepID := 0;
  if SelectedLoan <> nil then
    KeepID := SelectedLoan.ID;
  gridLoans.RowCount := 2;
  Row := 1;
  for I := 0 to FDB.Loans.Count - 1 do
  begin
    L := TLoan(FDB.Loans[I]);
    if L.Deleted then Continue;
    if chkLoansOnlyLoaned.Checked and (L.State <> lsLoaned) then Continue;
    if Row >= gridLoans.RowCount then
      gridLoans.RowCount := Row + 1;
    C := FDB.FindCopy(L.CopyID);
    R := FDB.FindReader(L.ReaderID);
    B := nil;
    if C <> nil then B := FDB.FindBook(C.BookID);
    gridLoans.Cells[DATA_FIRST_COL, Row] := IfThen(C <> nil, C.InventoryNo, '');
    gridLoans.Cells[DATA_FIRST_COL + 1, Row] := IfThen(B <> nil, B.Title, '');
    gridLoans.Cells[DATA_FIRST_COL + 2, Row] := IfThen(R <> nil, R.FullName, '');
    gridLoans.Cells[DATA_FIRST_COL + 3, Row] := FormatDateRu(L.IssuedAt);
    gridLoans.Cells[DATA_FIRST_COL + 4, Row] := FormatDateRu(L.DueAt);
    gridLoans.Cells[DATA_FIRST_COL + 5, Row] := LoanStateToStr(L.State);
    gridLoans.Objects[0, Row] := L;
    Inc(Row);
  end;
  if Row = 1 then
  begin
    gridLoans.Rows[1].Clear;
    gridLoans.Objects[0, 1] := nil;
  end
  else
    gridLoans.RowCount := Row;
  RecalcGridRowHeights(gridLoans);
  if KeepID > 0 then
    SelectGridEntity(gridLoans, KeepID, False)
  else
    SelectNearestGridRow(gridLoans, gridLoans.Row, False);
end;

procedure TMainForm.RefreshOverdue;
var
  List: TList;
  I: Integer;
  L: TLoan;
  C: TCopy;
  R: TReader;
  B: TBook;
  KeepID: TId;
begin
  KeepID := 0;
  if SelectedOverdue <> nil then
    KeepID := SelectedOverdue.ID;
  List := TList.Create;
  try
    FDB.CollectOverdue(List);
    gridOverdue.RowCount := Max(2, List.Count + 1);
    if List.Count = 0 then
    begin
      gridOverdue.Rows[1].Clear;
      gridOverdue.Objects[0, 1] := nil;
    end;
    for I := 0 to List.Count - 1 do
    begin
      L := TLoan(List[I]);
      C := FDB.FindCopy(L.CopyID);
      R := FDB.FindReader(L.ReaderID);
      B := nil;
      if C <> nil then B := FDB.FindBook(C.BookID);
      gridOverdue.Cells[DATA_FIRST_COL, I + 1] := IfThen(C <> nil, C.InventoryNo, '');
      gridOverdue.Cells[DATA_FIRST_COL + 1, I + 1] := IfThen(B <> nil, B.Title, '');
      gridOverdue.Cells[DATA_FIRST_COL + 2, I + 1] := IfThen(R <> nil, R.FullName, '');
      gridOverdue.Cells[DATA_FIRST_COL + 3, I + 1] := FormatDateRu(L.DueAt);
      gridOverdue.Cells[DATA_FIRST_COL + 4, I + 1] := IntToStr(Trunc(Date - Trunc(L.DueAt)));
      gridOverdue.Objects[0, I + 1] := L;
    end;
  finally
    List.Free;
  end;
  RecalcGridRowHeights(gridOverdue);
  if KeepID > 0 then
    SelectGridEntity(gridOverdue, KeepID, False)
  else
    SelectNearestGridRow(gridOverdue, gridOverdue.Row, False);
end;

procedure TMainForm.RefreshUsers;
var
  I, Row: Integer;
  U: TUser;
  KeepID: TId;
begin
  if not tsUsers.TabVisible then Exit;
  KeepID := 0;
  if SelectedUser <> nil then
    KeepID := SelectedUser.ID;
  gridUsers.RowCount := 2;
  Row := 1;
  for I := 0 to FDB.Users.Count - 1 do
  begin
    U := TUser(FDB.Users[I]);
    if U.Deleted and (not chkShowDeleted.Checked) then Continue;
    if Row >= gridUsers.RowCount then
      gridUsers.RowCount := Row + 1;
    gridUsers.Cells[DATA_FIRST_COL, Row] := U.Login;
    gridUsers.Cells[DATA_FIRST_COL + 1, Row] := U.DisplayName;
    gridUsers.Cells[DATA_FIRST_COL + 2, Row] := RoleToStr(U.Role);
    gridUsers.Cells[DATA_FIRST_COL + 3, Row] := BoolToStr(U.Active, 'да', 'нет');
    gridUsers.Cells[DATA_FIRST_COL + 4, Row] := BoolToStr(U.Deleted, 'да', '');
    gridUsers.Objects[0, Row] := U;
    Inc(Row);
  end;
  if Row = 1 then
  begin
    gridUsers.Rows[1].Clear;
    gridUsers.Objects[0, 1] := nil;
  end
  else
    gridUsers.RowCount := Row;
  RecalcGridRowHeights(gridUsers);
  if KeepID > 0 then
    SelectGridEntity(gridUsers, KeepID, False)
  else
    SelectNearestGridRow(gridUsers, gridUsers.Row, False);
end;

procedure TMainForm.RefreshSettings;
begin
  edtLibName.Text := FDB.Settings.LibraryName;
  edtLoanDays.Text := IntToStr(FDB.Settings.LoanDays);
  edtMaxBooks.Text := IntToStr(FDB.Settings.MaxBooksPerReader);
  edtMaxRenew.Text := IntToStr(FDB.Settings.MaxRenewals);
  chkAutoBackup.Checked := FDB.Settings.AutoBackupEnabled;
  seUIFontSize.Value := ClampUIFontSize(FDB.Settings.UIFontSize);
  RefreshOpenRouterModelList;
  SetOpenRouterModel(FDB.Settings.OpenRouterModel);
  edtOpenRouterApiKey.Text := FDB.Settings.OpenRouterApiKey;
  if FDB.Settings.InventoryStartNo < 1 then
    seInventoryStart.Value := 1
  else if FDB.Settings.InventoryStartNo > seInventoryStart.MaxValue then
    seInventoryStart.Value := seInventoryStart.MaxValue
  else
    seInventoryStart.Value := FDB.Settings.InventoryStartNo;
end;

procedure TMainForm.RefreshOpenRouterModelList;
var
  i: Integer;
  Current: string;
begin
  Current := cbOpenRouterModel.Text;
  cbOpenRouterModel.Items.BeginUpdate;
  try
    cbOpenRouterModel.Items.Clear;
    for i := 0 to FDB.Settings.OpenRouterFavoriteModels.Count - 1 do
      cbOpenRouterModel.Items.Add(FDB.Settings.OpenRouterFavoriteModels[i]);
    cbOpenRouterModel.ItemIndex := cbOpenRouterModel.Items.IndexOf(Trim(Current));
    cbOpenRouterModel.Text := Current;
  finally
    cbOpenRouterModel.Items.EndUpdate;
  end;
end;

procedure TMainForm.SetOpenRouterModel(const AModel: string);
begin
  cbOpenRouterModel.ItemIndex := cbOpenRouterModel.Items.IndexOf(Trim(AModel));
  cbOpenRouterModel.Text := AModel;
end;

procedure TMainForm.ReflowToolbarPanel(APanel: TPanel);
var
  List: TList;
  I, J: Integer;
  C, Tmp: TControl;
  TextH, FieldH, Gap, Pad, X, Y, MaxBottom, W, GlyphW: Integer;
  Btn: TBitBtn;
begin
  if APanel = nil then
    Exit;
  TextH := Canvas.TextHeight('Ag');
  FieldH := TextH + 12;
  Gap := 8;
  Pad := 8;
  List := TList.Create;
  try
    for I := 0 to APanel.ControlCount - 1 do
    begin
      C := APanel.Controls[I];
      if not C.Visible then
        Continue;
      List.Add(C);
    end;
    for I := 0 to List.Count - 2 do
      for J := I + 1 to List.Count - 1 do
        if TControl(List[J]).Left < TControl(List[I]).Left then
        begin
          Tmp := TControl(List[I]);
          List[I] := List[J];
          List[J] := Tmp;
        end;

    X := Pad;
    Y := Pad;
    MaxBottom := Pad;
    for I := 0 to List.Count - 1 do
    begin
      C := TControl(List[I]);
      if C is TBitBtn then
      begin
        Btn := TBitBtn(C);
        GlyphW := 0;
        if (Btn.Glyph <> nil) and (not Btn.Glyph.Empty) then
          GlyphW := Btn.Glyph.Width + Btn.Spacing;
        W := Canvas.TextWidth(Btn.Caption) + GlyphW + 24;
        if W < 72 then
          W := 72;
        Btn.SetBounds(X, Y, W, Max(FieldH, ICON_SIZE + 10));
      end
      else if C is TSpeedButton then
      begin
        W := Max(FieldH, Canvas.TextWidth(TSpeedButton(C).Caption) + 12);
        C.SetBounds(X, Y, W, FieldH);
      end
      else if C is TEdit then
      begin
        W := Max(C.Width, 120);
        C.SetBounds(X, Y, W, FieldH);
      end
      else if C is TComboBox then
      begin
        W := Max(C.Width, 140);
        C.SetBounds(X, Y, W, FieldH);
      end
      else if C is TCheckBox then
      begin
        TCheckBox(C).AutoSize := True;
        C.Top := Y + Max(0, (FieldH - C.Height) div 2);
        C.Left := X;
        C.Height := Max(C.Height, TextH + 6);
        W := Max(C.Width, Canvas.TextWidth(TCheckBox(C).Caption) + 28);
        C.Width := W;
      end
      else
        C.SetBounds(X, Y, Max(C.Width, 40), FieldH);

      X := C.Left + C.Width + Gap;
      if C.Top + C.Height > MaxBottom then
        MaxBottom := C.Top + C.Height;
    end;
    APanel.Height := MaxBottom + Pad;
  finally
    List.Free;
  end;
end;

procedure TMainForm.ReflowSettingsPanel;
var
  TextH, FieldH, Gap, Margin, Y, W: Integer;
begin
  if pnlSettings = nil then
    Exit;
  TextH := Canvas.TextHeight('Ag');
  FieldH := TextH + 12;
  Gap := Max(10, TextH);
  Margin := 24;

  lblLibName.AutoSize := True;
  lblLoanDays.AutoSize := True;
  lblMaxBooks.AutoSize := True;
  lblMaxRenew.AutoSize := True;
  lblUIFontSize.AutoSize := True;
  lblInventoryStart.AutoSize := True;
  lblOpenRouterModel.AutoSize := True;
  lblOpenRouterApiKey.AutoSize := True;

  Y := Margin;
  lblLibName.SetBounds(Margin, Y, lblLibName.Width, TextH + 2);
  Y := lblLibName.Top + lblLibName.Height + 4;
  edtLibName.SetBounds(Margin, Y, Max(400, Canvas.TextWidth('W') * 28), FieldH);

  Y := edtLibName.Top + edtLibName.Height + Gap;
  lblLoanDays.SetBounds(Margin, Y, lblLoanDays.Width, TextH + 2);
  Y := lblLoanDays.Top + lblLoanDays.Height + 4;
  edtLoanDays.SetBounds(Margin, Y, Max(120, Canvas.TextWidth('0000') + 24), FieldH);

  Y := edtLoanDays.Top + edtLoanDays.Height + Gap;
  lblMaxBooks.SetBounds(Margin, Y, lblMaxBooks.Width, TextH + 2);
  Y := lblMaxBooks.Top + lblMaxBooks.Height + 4;
  edtMaxBooks.SetBounds(Margin, Y, edtLoanDays.Width, FieldH);

  Y := edtMaxBooks.Top + edtMaxBooks.Height + Gap;
  lblMaxRenew.SetBounds(Margin, Y, lblMaxRenew.Width, TextH + 2);
  Y := lblMaxRenew.Top + lblMaxRenew.Height + 4;
  edtMaxRenew.SetBounds(Margin, Y, edtLoanDays.Width, FieldH);

  Y := edtMaxRenew.Top + edtMaxRenew.Height + Gap;
  chkAutoBackup.AutoSize := True;
  chkAutoBackup.Left := Margin;
  chkAutoBackup.Top := Y;
  chkAutoBackup.Height := Max(chkAutoBackup.Height, TextH + 8);
  W := Canvas.TextWidth(chkAutoBackup.Caption) + 28;
  if chkAutoBackup.Width < W then
    chkAutoBackup.Width := W;

  Y := chkAutoBackup.Top + chkAutoBackup.Height + Gap;
  lblUIFontSize.SetBounds(Margin, Y, lblUIFontSize.Width, TextH + 2);
  Y := lblUIFontSize.Top + lblUIFontSize.Height + 4;
  seUIFontSize.SetBounds(Margin, Y, edtLoanDays.Width, FieldH);

  Y := seUIFontSize.Top + seUIFontSize.Height + Gap;
  lblInventoryStart.SetBounds(Margin, Y, lblInventoryStart.Width, TextH + 2);
  Y := lblInventoryStart.Top + lblInventoryStart.Height + 4;
  seInventoryStart.SetBounds(Margin, Y, edtLoanDays.Width, FieldH);

  Y := seInventoryStart.Top + seInventoryStart.Height + Gap;
  lblOpenRouterModel.SetBounds(Margin, Y, lblOpenRouterModel.Width, TextH + 2);
  Y := lblOpenRouterModel.Top + lblOpenRouterModel.Height + 4;
  cbOpenRouterModel.SetBounds(Margin, Y, Max(400, Canvas.TextWidth('W') * 28), FieldH);

  W := Canvas.TextWidth(btnSelectOpenRouterModel.Caption) + ICON_SIZE + 28;
  if W < 140 then
    W := 140;
  btnSelectOpenRouterModel.SetBounds(
    cbOpenRouterModel.Left + cbOpenRouterModel.Width + Gap,
    cbOpenRouterModel.Top, W, Max(FieldH, ICON_SIZE + 12));

  Y := cbOpenRouterModel.Top + cbOpenRouterModel.Height + Gap;
  lblOpenRouterApiKey.SetBounds(Margin, Y, lblOpenRouterApiKey.Width, TextH + 2);
  Y := lblOpenRouterApiKey.Top + lblOpenRouterApiKey.Height + 4;
  edtOpenRouterApiKey.SetBounds(Margin, Y, Max(400, Canvas.TextWidth('W') * 28), FieldH);

  W := Canvas.TextWidth(btnTestOpenRouter.Caption) + ICON_SIZE + 28;
  if W < 160 then
    W := 160;
  btnTestOpenRouter.SetBounds(
    edtOpenRouterApiKey.Left + edtOpenRouterApiKey.Width + Gap,
    edtOpenRouterApiKey.Top, W, Max(FieldH, ICON_SIZE + 12));

  Y := edtOpenRouterApiKey.Top + edtOpenRouterApiKey.Height + Gap;
  W := Canvas.TextWidth(btnSaveSettings.Caption) + ICON_SIZE + 28;
  if W < 140 then
    W := 140;
  btnSaveSettings.SetBounds(Margin, Y, W, Max(FieldH, ICON_SIZE + 12));
  pnlSettings.Height := btnSaveSettings.Top + btnSaveSettings.Height + Margin;
end;

procedure TMainForm.ApplyUIFontSize;
var
  Sz, TextH: Integer;
begin
  Sz := ClampUIFontSize(FDB.Settings.UIFontSize);
  Screen.SystemFont.Size := Sz;
  Font.Size := Sz;
  TextH := Canvas.TextHeight('Ag');

  pcMain.MultiLine := True;
  if FIcons <> nil then
    pcMain.TabHeight := Max(FIcons.Height + 8, TextH + 10)
  else
    pcMain.TabHeight := TextH + 10;

  statusBar.Height := TextH + 10;

  ReflowToolbarPanel(pnlBooksTop);
  ReflowToolbarPanel(pnlCopiesTop);
  ReflowToolbarPanel(pnlReadersTop);
  ReflowToolbarPanel(pnlLoansTop);
  ReflowToolbarPanel(pnlCatTop);
  ReflowToolbarPanel(pnlLocTop);
  ReflowToolbarPanel(pnlUsersTop);
  ReflowToolbarPanel(pnlReports);
  ReflowToolbarPanel(pnlBackup);
  ReflowSettingsPanel;
  ClampBooksCopiesPanelHeight;

  RecalcGridRowHeights(gridBooks);
  RecalcGridRowHeights(gridCopies);
  RecalcGridRowHeights(gridReaders);
  RecalcGridRowHeights(gridLoans);
  RecalcGridRowHeights(gridOverdue);
  RecalcGridRowHeights(gridUsers);
  RecalcGridRowHeights(gridJournal);
  RecalcGridRowHeights(gridCategories);
  RecalcGridRowHeights(gridLocations);
  RecalcGridRowHeights(gridReport);
end;

procedure TMainForm.RefreshBackups;
var
  SR: TSearchRec;
begin
  lstBackups.Items.Clear;
  if FindFirst(FDB.Paths.BackupDir + '*', faDirectory, SR) = 0 then
  try
    repeat
      if ((SR.Attr and faDirectory) <> 0) and (SR.Name <> '.') and (SR.Name <> '..') then
        if DirectoryExists(FDB.Paths.BackupDir + SR.Name + PathDelim + 'Data') then
          lstBackups.Items.Add(SR.Name);
    until FindNext(SR) <> 0;
  finally
    FindClose(SR);
  end;
end;

procedure TMainForm.RefreshJournal;
var
  I, Row: Integer;
  A: TActionLogItem;
begin
  if not tsJournal.TabVisible then Exit;
  gridJournal.RowCount := 2;
  Row := 1;
  for I := FDB.Actions.Count - 1 downto 0 do
  begin
    A := TActionLogItem(FDB.Actions[I]);
    if Row >= gridJournal.RowCount then
      gridJournal.RowCount := Row + 1;
    gridJournal.Cells[DATA_FIRST_COL, Row] := FormatDateTimeRu(A.When);
    gridJournal.Cells[DATA_FIRST_COL + 1, Row] := A.UserName;
    gridJournal.Cells[DATA_FIRST_COL + 2, Row] := ActionTypeToStr(A.Action);
    gridJournal.Cells[DATA_FIRST_COL + 3, Row] := A.Description;
    Inc(Row);
    if Row > 500 then Break;
  end;
  if Row = 1 then
    gridJournal.Rows[1].Clear
  else
    gridJournal.RowCount := Row;
  RecalcGridRowHeights(gridJournal);
  SelectNearestGridRow(gridJournal, gridJournal.Row, False);
end;

procedure TMainForm.RefreshCategories;
var
  I, Row: Integer;
  C: TCategory;
  KeepID: TId;
begin
  KeepID := 0;
  if SelectedCategory <> nil then
    KeepID := SelectedCategory.ID;
  gridCategories.RowCount := 2;
  Row := 1;
  for I := 0 to FDB.Categories.Count - 1 do
  begin
    C := TCategory(FDB.Categories[I]);
    if C.Deleted and (not chkShowDeleted.Checked) then Continue;
    if Row >= gridCategories.RowCount then
      gridCategories.RowCount := Row + 1;
    gridCategories.Cells[DATA_FIRST_COL, Row] := C.Name;
    gridCategories.Cells[DATA_FIRST_COL + 1, Row] := C.Code;
    gridCategories.Cells[DATA_FIRST_COL + 2, Row] := C.Description;
    gridCategories.Cells[DATA_FIRST_COL + 3, Row] := BoolToStr(C.Deleted, 'да', '');
    gridCategories.Objects[0, Row] := C;
    Inc(Row);
  end;
  if Row = 1 then
  begin
    gridCategories.Rows[1].Clear;
    gridCategories.Objects[0, 1] := nil;
  end
  else
    gridCategories.RowCount := Row;
  RecalcGridRowHeights(gridCategories);
  if KeepID > 0 then
    SelectGridEntity(gridCategories, KeepID, False)
  else
    SelectNearestGridRow(gridCategories, gridCategories.Row, False);
end;

procedure TMainForm.RefreshLocations;
var
  I, Row: Integer;
  L: TLocation;
  KeepID: TId;
begin
  KeepID := 0;
  if SelectedLocation <> nil then
    KeepID := SelectedLocation.ID;
  gridLocations.RowCount := 2;
  Row := 1;
  for I := 0 to FDB.Locations.Count - 1 do
  begin
    L := TLocation(FDB.Locations[I]);
    if L.Deleted and (not chkShowDeleted.Checked) then Continue;
    if Row >= gridLocations.RowCount then
      gridLocations.RowCount := Row + 1;
    gridLocations.Cells[DATA_FIRST_COL, Row] := L.Name;
    gridLocations.Cells[DATA_FIRST_COL + 1, Row] := L.Description;
    gridLocations.Cells[DATA_FIRST_COL + 2, Row] := BoolToStr(L.Deleted, 'да', '');
    gridLocations.Objects[0, Row] := L;
    Inc(Row);
  end;
  if Row = 1 then
  begin
    gridLocations.Rows[1].Clear;
    gridLocations.Objects[0, 1] := nil;
  end
  else
    gridLocations.RowCount := Row;
  RecalcGridRowHeights(gridLocations);
  if KeepID > 0 then
    SelectGridEntity(gridLocations, KeepID, False)
  else
    SelectNearestGridRow(gridLocations, gridLocations.Row, False);
end;

function TMainForm.SelectedBook: TBook;
begin
  Result := nil;
  if (gridBooks.Row > 0) and (gridBooks.Objects[0, gridBooks.Row] <> nil) then
    Result := TBook(gridBooks.Objects[0, gridBooks.Row]);
end;

function TMainForm.SelectedCopy: TCopy;
begin
  Result := nil;
  if (gridCopies.Row > 0) and (gridCopies.Objects[0, gridCopies.Row] <> nil) then
    Result := TCopy(gridCopies.Objects[0, gridCopies.Row]);
end;

function TMainForm.SelectedReader: TReader;
begin
  Result := nil;
  if (gridReaders.Row > 0) and (gridReaders.Objects[0, gridReaders.Row] <> nil) then
    Result := TReader(gridReaders.Objects[0, gridReaders.Row]);
end;

function TMainForm.SelectedLoan: TLoan;
begin
  Result := nil;
  if (gridLoans.Row > 0) and (gridLoans.Objects[0, gridLoans.Row] <> nil) then
    Result := TLoan(gridLoans.Objects[0, gridLoans.Row]);
end;

function TMainForm.SelectedOverdue: TLoan;
begin
  Result := nil;
  if (gridOverdue.Row > 0) and (gridOverdue.Objects[0, gridOverdue.Row] <> nil) then
    Result := TLoan(gridOverdue.Objects[0, gridOverdue.Row]);
end;

function TMainForm.SelectedUser: TUser;
begin
  Result := nil;
  if (gridUsers.Row > 0) and (gridUsers.Objects[0, gridUsers.Row] <> nil) then
    Result := TUser(gridUsers.Objects[0, gridUsers.Row]);
end;

function TMainForm.SelectedCategory: TCategory;
begin
  Result := nil;
  if (gridCategories.Row > 0) and (gridCategories.Objects[0, gridCategories.Row] <> nil) then
    Result := TCategory(gridCategories.Objects[0, gridCategories.Row]);
end;

function TMainForm.SelectedLocation: TLocation;
begin
  Result := nil;
  if (gridLocations.Row > 0) and (gridLocations.Objects[0, gridLocations.Row] <> nil) then
    Result := TLocation(gridLocations.Objects[0, gridLocations.Row]);
end;

procedure TMainForm.btnBookSearchClearClick(Sender: TObject);
begin
  edtBookSearch.Text := '';
  edtBookSearchInv.Text := '';
  RefreshBooks;
  edtBookSearch.SetFocus;
end;

procedure TMainForm.edtBookSearchChange(Sender: TObject);
begin
  RefreshBooks;
end;

procedure TMainForm.edtBookSearchInvChange(Sender: TObject);
begin
  RefreshBooks;
end;

procedure TMainForm.edtBookSearchInvKeyPress(Sender: TObject; var Key: char);
begin
  if Key = #13 then
  begin
    Key := #0;
    RefreshBooks;
  end;
end;

procedure TMainForm.btnBookSearchClick(Sender: TObject);
begin
  RefreshBooks;
end;

procedure TMainForm.btnBookAddClick(Sender: TObject);
var
  ID: TId;
begin
  if EditBookDialog(FDB, nil, ID) then
  begin
    RefreshAll;
    SelectGridEntity(gridBooks, ID, True);
  end;
end;

procedure TMainForm.btnBookRecognizeClick(Sender: TObject);
var
  OpenDlg: TOpenDialog;
  Results: TObjectList;
  Failures: TStringList;
  I: Integer;
  Recognized: TRecognizedBook;
  Err, FileName: string;
begin
  if (Trim(FDB.Settings.OpenRouterModel) = '') or
     (Trim(FDB.Settings.OpenRouterApiKey) = '') then
  begin
    pcMain.ActivePage := tsSettings;
    MessageDlg('Заполните «Модель OpenRouter» и «OpenRouter API Key» в настройках, затем сохраните их.',
      mtWarning, [mbOK], 0);
    Exit;
  end;

  OpenDlg := TOpenDialog.Create(Self);
  try
    OpenDlg.Title := 'Выберите фотографии книг';
    OpenDlg.Filter := 'Изображения|*.jpg;*.jpeg;*.png;*.webp;*.gif|Все файлы|*.*';
    OpenDlg.Options := [ofFileMustExist, ofEnableSizing, ofAllowMultiSelect];
    if not OpenDlg.Execute then
      Exit;
    Results := TObjectList.Create(True);
    Failures := TStringList.Create;
    try
      Screen.Cursor := crHourGlass;
      for I := 0 to OpenDlg.Files.Count - 1 do
      begin
        FileName := OpenDlg.Files[I];
        statusBar.SimpleText := 'Распознавание ' + IntToStr(I + 1) + ' из ' +
          IntToStr(OpenDlg.Files.Count) + ': ' + ExtractFileName(FileName);
        Application.ProcessMessages;
        Recognized := nil;
        if RecognizeBookImage(FileName, FDB.Settings.OpenRouterModel,
          FDB.Settings.OpenRouterApiKey, Recognized, Err) then
        begin
          Recognized.SourceFile := FileName;
          Results.Add(Recognized);
        end
        else
          Failures.Add(ExtractFileName(FileName) + ': ' + Err);
      end;
    finally
      Screen.Cursor := crDefault;
    end;
    try
      if Results.Count = 0 then
      begin
        MessageDlg('Не удалось распознать выбранные изображения.' + LineEnding +
          Failures.Text, mtError, [mbOK], 0);
        Exit;
      end;
      if ImportRecognizedBooksDialog(FDB, Results, Failures) then
      begin
        RefreshBooks;
        RefreshCopies;
      end;
    finally
      Failures.Free;
      Results.Free;
      statusBar.SimpleText := 'Пользователь: ' + FDB.CurrentUser.DisplayName +
        ' | ' + EffectiveLibraryTitle(FDB.Settings.LibraryName);
    end;
  finally
    OpenDlg.Free;
  end;
end;

procedure TMainForm.btnBookEditClick(Sender: TObject);
var
  B: TBook;
  ID: TId;
begin
  B := SelectedBook;
  if B = nil then
  begin
    MessageDlg('Выберите книгу.', mtInformation, [mbOK], 0);
    Exit;
  end;
  if EditBookDialog(FDB, B, ID) then
  begin
    RefreshAll;
    SelectGridEntity(gridBooks, ID, True);
  end;
end;

procedure TMainForm.btnBookDeleteClick(Sender: TObject);
var
  B: TBook;
  ID: TId;
  Err: string;
begin
  B := SelectedBook;
  if B = nil then Exit;
  ID := B.ID;
  if MessageDlg('Удалить книгу «' + B.Title + '»?', mtConfirmation, [mbYes, mbNo], 0) <> mrYes then Exit;
  if not FDB.DeleteBook(B, Err) then
    MessageDlg(Err, mtError, [mbOK], 0)
  else
  begin
    RefreshAll;
    SelectGridEntity(gridBooks, ID, True);
  end;
end;

procedure TMainForm.btnBookRestoreClick(Sender: TObject);
var
  B: TBook;
  ID: TId;
  Err: string;
begin
  B := SelectedBook;
  if (B = nil) or (not B.Deleted) then Exit;
  ID := B.ID;
  if not FDB.RestoreBook(B, Err) then
    MessageDlg(Err, mtError, [mbOK], 0)
  else
  begin
    RefreshAll;
    SelectGridEntity(gridBooks, ID, True);
  end;
end;

procedure TMainForm.btnCopyAddClick(Sender: TObject);
var
  B: TBook;
  CopyID: TId;
begin
  B := SelectedBook;
  if B = nil then
  begin
    MessageDlg('Сначала выберите книгу.', mtInformation, [mbOK], 0);
    Exit;
  end;
  if EditCopyDialog(FDB, nil, B.ID, CopyID) then
  begin
    RefreshAll;
    SelectGridEntity(gridBooks, B.ID, False);
    SelectGridEntity(gridCopies, CopyID, True);
  end;
end;

procedure TMainForm.btnCopyEditClick(Sender: TObject);
var
  C: TCopy;
  CopyID, BookID: TId;
begin
  C := SelectedCopy;
  if C = nil then
  begin
    MessageDlg('Выберите экземпляр.', mtInformation, [mbOK], 0);
    Exit;
  end;
  BookID := C.BookID;
  if EditCopyDialog(FDB, C, BookID, CopyID) then
  begin
    RefreshAll;
    SelectGridEntity(gridBooks, BookID, False);
    SelectGridEntity(gridCopies, CopyID, True);
  end;
end;

procedure TMainForm.btnCopyDeleteClick(Sender: TObject);
var
  C: TCopy;
  BookID, CopyID: TId;
  Err: string;
begin
  C := SelectedCopy;
  if C = nil then Exit;
  BookID := C.BookID;
  CopyID := C.ID;
  if MessageDlg('Удалить экземпляр инв. № ' + C.InventoryNo + '?', mtConfirmation, [mbYes, mbNo], 0) <> mrYes then Exit;
  if not FDB.DeleteCopy(C, Err) then
    MessageDlg(Err, mtError, [mbOK], 0)
  else
  begin
    RefreshAll;
    SelectGridEntity(gridBooks, BookID, False);
    SelectGridEntity(gridCopies, CopyID, True);
  end;
end;

procedure TMainForm.btnReaderSearchClearClick(Sender: TObject);
begin
  edtReaderSearch.Text := '';
  RefreshReaders;
  edtReaderSearch.SetFocus;
end;

procedure TMainForm.btnReaderSearchClick(Sender: TObject);
begin
  RefreshReaders;
end;

procedure TMainForm.btnReaderAddClick(Sender: TObject);
var
  ID: TId;
begin
  if EditReaderDialog(FDB, nil, ID) then
  begin
    RefreshAll;
    SelectGridEntity(gridReaders, ID, True);
  end;
end;

procedure TMainForm.btnReaderEditClick(Sender: TObject);
var
  R: TReader;
  ID: TId;
begin
  R := SelectedReader;
  if R = nil then Exit;
  if EditReaderDialog(FDB, R, ID) then
  begin
    RefreshAll;
    SelectGridEntity(gridReaders, ID, True);
  end;
end;

procedure TMainForm.btnReaderDeleteClick(Sender: TObject);
var
  R: TReader;
  ID: TId;
  Err: string;
begin
  R := SelectedReader;
  if R = nil then Exit;
  ID := R.ID;
  if MessageDlg('Удалить читателя «' + R.FullName + '»?', mtConfirmation, [mbYes, mbNo], 0) <> mrYes then Exit;
  if not FDB.DeleteReader(R, Err) then
    MessageDlg(Err, mtError, [mbOK], 0)
  else
  begin
    RefreshAll;
    SelectGridEntity(gridReaders, ID, True);
  end;
end;

procedure TMainForm.btnReaderRestoreClick(Sender: TObject);
var
  R: TReader;
  ID: TId;
  Err: string;
begin
  R := SelectedReader;
  if (R = nil) or (not R.Deleted) then Exit;
  ID := R.ID;
  if not FDB.RestoreReader(R, Err) then
    MessageDlg(Err, mtError, [mbOK], 0)
  else
  begin
    RefreshAll;
    SelectGridEntity(gridReaders, ID, True);
  end;
end;

procedure TMainForm.btnLoanIssueClick(Sender: TObject);
var
  ID: TId;
begin
  if IssueLoanDialog(FDB, ID) then
  begin
    RefreshAll;
    SelectGridEntity(gridLoans, ID, True);
  end;
end;

procedure TMainForm.btnLoanReturnClick(Sender: TObject);
var
  L: TLoan;
  ID: TId;
  Err: string;
begin
  L := SelectedLoan;
  if L = nil then
  begin
    MessageDlg('Выберите выдачу.', mtInformation, [mbOK], 0);
    Exit;
  end;
  if MessageDlg('Вернуть выбранную выдачу?', mtConfirmation, [mbYes, mbNo], 0) <> mrYes then Exit;
  ID := L.ID;
  if not FDB.ReturnLoan(L, '', Err) then
    MessageDlg(Err, mtError, [mbOK], 0)
  else
  begin
    RefreshAll;
    SelectGridEntity(gridLoans, ID, True);
  end;
end;

procedure TMainForm.btnLoanRenewClick(Sender: TObject);
var
  L: TLoan;
  ID: TId;
  Err: string;
begin
  L := SelectedLoan;
  if L = nil then Exit;
  if MessageDlg('Продлить выбранную выдачу?', mtConfirmation, [mbYes, mbNo], 0) <> mrYes then Exit;
  ID := L.ID;
  if not FDB.RenewLoan(L, Err) then
    MessageDlg(Err, mtError, [mbOK], 0)
  else
  begin
    RefreshAll;
    SelectGridEntity(gridLoans, ID, True);
  end;
end;

procedure TMainForm.OpenLoanCopy(ALoan: TLoan);
var
  C: TCopy;
  ID: TId;
  EditedID: TId;
begin
  if ALoan = nil then
  begin
    MessageDlg('Выберите выдачу.', mtInformation, [mbOK], 0);
    Exit;
  end;
  C := FDB.FindCopy(ALoan.CopyID);
  if C = nil then
  begin
    MessageDlg('Экземпляр для выбранной выдачи не найден.', mtError, [mbOK], 0);
    Exit;
  end;
  ID := ALoan.ID;
  if EditCopyDialog(FDB, C, C.BookID, EditedID) then
  begin
    RefreshAll;
    SelectGridEntity(gridLoans, ID, True);
  end;
end;

procedure TMainForm.OpenLoanBook(ALoan: TLoan);
var
  C: TCopy;
  B: TBook;
  ID: TId;
  EditedID: TId;
begin
  if ALoan = nil then
  begin
    MessageDlg('Выберите выдачу.', mtInformation, [mbOK], 0);
    Exit;
  end;
  C := FDB.FindCopy(ALoan.CopyID);
  if C = nil then
  begin
    MessageDlg('Экземпляр для выбранной выдачи не найден.', mtError, [mbOK], 0);
    Exit;
  end;
  B := FDB.FindBook(C.BookID);
  if B = nil then
  begin
    MessageDlg('Книга для выбранной выдачи не найдена.', mtError, [mbOK], 0);
    Exit;
  end;
  ID := ALoan.ID;
  if EditBookDialog(FDB, B, EditedID) then
  begin
    RefreshAll;
    SelectGridEntity(gridLoans, ID, True);
  end;
end;

procedure TMainForm.OpenLoanReader(ALoan: TLoan);
var
  R: TReader;
  ID: TId;
  EditedID: TId;
begin
  if ALoan = nil then
  begin
    MessageDlg('Выберите выдачу.', mtInformation, [mbOK], 0);
    Exit;
  end;
  R := FDB.FindReader(ALoan.ReaderID);
  if R = nil then
  begin
    MessageDlg('Читатель для выбранной выдачи не найден.', mtError, [mbOK], 0);
    Exit;
  end;
  ID := ALoan.ID;
  if EditReaderDialog(FDB, R, EditedID) then
  begin
    RefreshAll;
    SelectGridEntity(gridLoans, ID, True);
  end;
end;

procedure TMainForm.ShowReportTable(ALines: TStrings);
var
  Parts: TStringList;
  R, C, MaxCols: Integer;
begin
  if FReportLines = nil then
    FReportLines := TStringList.Create;
  FReportLines.Assign(ALines);

  Parts := TStringList.Create;
  try
    Parts.StrictDelimiter := True;
    Parts.Delimiter := ';';
    Parts.QuoteChar := '"';
    MaxCols := 1;
    for R := 0 to ALines.Count - 1 do
    begin
      Parts.DelimitedText := ALines[R];
      if Parts.Count > MaxCols then
        MaxCols := Parts.Count;
    end;

    gridReport.FixedRows := Ord(ALines.Count > 0);
    gridReport.ColCount := MaxCols + DATA_FIRST_COL;
    gridReport.RowCount := Max(1, ALines.Count);
    gridReport.ColWidths[ACTIVE_MARKER_COL] := ACTIVE_MARKER_WIDTH;
    for R := 0 to gridReport.RowCount - 1 do
      for C := 0 to gridReport.ColCount - 1 do
        gridReport.Cells[C, R] := '';

    for R := 0 to ALines.Count - 1 do
    begin
      Parts.DelimitedText := ALines[R];
      for C := 0 to Parts.Count - 1 do
        gridReport.Cells[C + DATA_FIRST_COL, R] := Parts[C];
    end;
  finally
    Parts.Free;
  end;
  RecalcGridRowHeights(gridReport);
  UpdateGridActiveMarker(gridReport);
end;

procedure TMainForm.btnReportShowClick(Sender: TObject);
var
  SL: TStringList;
begin
  SL := nil;
  case cbReport.ItemIndex of
    0: SL := FReports.BooksCatalog;
    1: SL := FReports.CopiesByStatus;
    2: SL := FReports.AvailableCopies;
    3: SL := FReports.BooksOnHands;
    4: SL := FReports.OverdueLoans;
    5: SL := FReports.LoansHistory(0, 0);
    6: SL := FReports.ReadersList;
    7: SL := FReports.ActionsLog(0, 0);
  end;
  if SL <> nil then
  try
    ShowReportTable(SL);
  finally
    SL.Free;
  end;
end;

procedure TMainForm.btnReportSaveClick(Sender: TObject);
var
  SD: TSaveDialog;
begin
  if (FReportLines = nil) or (FReportLines.Count = 0) then
    btnReportShowClick(Sender);
  SD := TSaveDialog.Create(Self);
  try
    SD.Filter := 'CSV|*.csv|Текст|*.txt';
    SD.DefaultExt := 'csv';
    if SD.Execute then
      FReportLines.SaveToFile(SD.FileName);
  finally
    SD.Free;
  end;
end;

procedure TMainForm.btnUserAddClick(Sender: TObject);
var
  ID: TId;
begin
  if EditUserDialog(FDB, nil, ID) then
  begin
    RefreshUsers;
    SelectGridEntity(gridUsers, ID, True);
  end;
end;

procedure TMainForm.btnUserEditClick(Sender: TObject);
var
  U: TUser;
  ID: TId;
begin
  U := SelectedUser;
  if U = nil then Exit;
  if EditUserDialog(FDB, U, ID) then
  begin
    RefreshUsers;
    SelectGridEntity(gridUsers, ID, True);
  end;
end;

procedure TMainForm.btnUserDeleteClick(Sender: TObject);
var
  U: TUser;
  ID: TId;
  Err: string;
begin
  U := SelectedUser;
  if U = nil then Exit;
  ID := U.ID;
  if MessageDlg('Удалить пользователя «' + U.Login + '»?', mtConfirmation, [mbYes, mbNo], 0) <> mrYes then Exit;
  if not FDB.DeleteUser(U, Err) then
    MessageDlg(Err, mtError, [mbOK], 0)
  else
  begin
    RefreshUsers;
    SelectGridEntity(gridUsers, ID, True);
  end;
end;

procedure TMainForm.btnSaveSettingsClick(Sender: TObject);
var
  Err: string;
begin
  if not FDB.UpdateSettings(edtLibName.Text, StrToIntDef(edtLoanDays.Text, 14),
    StrToIntDef(edtMaxBooks.Text, 5), StrToIntDef(edtMaxRenew.Text, 2),
    chkAutoBackup.Checked, seUIFontSize.Value,
    Int64(seInventoryStart.Value), cbOpenRouterModel.Text,
    edtOpenRouterApiKey.Text, Err) then
    MessageDlg(Err, mtError, [mbOK], 0)
  else
  begin
    ApplyUIFontSize;
    ApplyLibraryTitle;
    statusBar.SimpleText := 'Пользователь: ' + FDB.CurrentUser.DisplayName +
      ' | ' + EffectiveLibraryTitle(FDB.Settings.LibraryName);
    MessageDlg('Настройки сохранены.', mtInformation, [mbOK], 0);
  end;
end;

procedure TMainForm.btnTestOpenRouterClick(Sender: TObject);
var
  ApiKey, Model, Err, Msg: string;
  Count: Integer;
  ModelOk: Boolean;
begin
  ApiKey := Trim(edtOpenRouterApiKey.Text);
  Model := Trim(cbOpenRouterModel.Text);
  if ApiKey = '' then
  begin
    MessageDlg('Введите OpenRouter API Key, чтобы выполнить проверку.',
      mtWarning, [mbOK], 0);
    edtOpenRouterApiKey.SetFocus;
    Exit;
  end;

  btnTestOpenRouter.Enabled := False;
  btnTestOpenRouter.Caption := 'Проверка...';
  Screen.Cursor := crHourGlass;
  try
    if TestOpenRouterConnection(ApiKey, Model, Err, Count, ModelOk) then
    begin
      Msg := 'Соединение с OpenRouter установлено.' + LineEnding + LineEnding +
        'Доступно моделей: ' + IntToStr(Count) + '.';
      if Model <> '' then
      begin
        if ModelOk then
          Msg := Msg + LineEnding + LineEnding + 'Модель «' + Model + '» доступна.'
        else
          Msg := Msg + LineEnding + LineEnding +
            'Модель «' + Model + '» не найдена в списке доступных.';
      end;
      MessageDlg(Msg, mtInformation, [mbOK], 0);
    end
    else
    begin
      if Err <> '' then
        MessageDlg(Err, mtError, [mbOK], 0)
      else
        MessageDlg('Не удалось подключиться к OpenRouter.', mtError, [mbOK], 0);
    end;
  finally
    Screen.Cursor := crDefault;
    btnTestOpenRouter.Caption := 'Тест соединения';
    btnTestOpenRouter.Enabled := True;
  end;
end;

procedure TMainForm.btnSelectOpenRouterModelClick(Sender: TObject);
var
  ApiKey, Current, Selected: string;
  Favorites: TStringList;
begin
  ApiKey := Trim(edtOpenRouterApiKey.Text);
  if ApiKey = '' then
  begin
    MessageDlg('Сначала введите OpenRouter API Key, чтобы получить список моделей.',
      mtWarning, [mbOK], 0);
    edtOpenRouterApiKey.SetFocus;
    Exit;
  end;

  btnSelectOpenRouterModel.Enabled := False;
  btnSelectOpenRouterModel.Caption := 'Загрузка...';
  Screen.Cursor := crHourGlass;
  Current := Trim(cbOpenRouterModel.Text);
  Favorites := nil;
  try
    if SelectOpenRouterModelDialog(ApiKey, Current,
      FDB.Settings.OpenRouterFavoriteModels, Selected, Favorites) then
    begin
      FDB.Settings.OpenRouterFavoriteModels.Assign(Favorites);
      RefreshOpenRouterModelList;
      if Selected <> '' then
        SetOpenRouterModel(Selected);
    end;
  finally
    Favorites.Free;
    Screen.Cursor := crDefault;
    btnSelectOpenRouterModel.Caption := '...';
    btnSelectOpenRouterModel.Enabled := True;
  end;
end;

procedure TMainForm.btnBackupNowClick(Sender: TObject);
var
  Path, Err: string;
begin
  if MessageDlg('Создать резервную копию сейчас?', mtConfirmation, [mbYes, mbNo], 0) <> mrYes then Exit;
  if FDB.CreateBackup(Path, Err) then
  begin
    MessageDlg('Резервная копия создана:' + LineEnding + Path, mtInformation, [mbOK], 0);
    RefreshBackups;
  end
  else
    MessageDlg(Err, mtError, [mbOK], 0);
end;

procedure TMainForm.btnRestoreBackupClick(Sender: TObject);
var
  Err: string;
  Dir: string;
begin
  if lstBackups.ItemIndex < 0 then
  begin
    MessageDlg('Выберите резервную копию.', mtInformation, [mbOK], 0);
    Exit;
  end;
  if MessageDlg('Восстановить выбранную копию? Текущие данные будут сохранены в страховочную копию.',
    mtConfirmation, [mbYes, mbNo], 0) <> mrYes then Exit;
  Dir := FDB.Paths.BackupDir + lstBackups.Items[lstBackups.ItemIndex];
  if FDB.RestoreBackup(Dir, Err) then
  begin
    MessageDlg('Данные восстановлены.', mtInformation, [mbOK], 0);
    RefreshAll;
  end
  else
    MessageDlg(Err, mtError, [mbOK], 0);
end;

procedure TMainForm.btnCatAddClick(Sender: TObject);
var
  ID: TId;
begin
  if EditCategoryDialog(FDB, nil, ID) then
  begin
    RefreshAll;
    SelectGridEntity(gridCategories, ID, True);
  end;
end;

procedure TMainForm.btnCatEditClick(Sender: TObject);
var
  C: TCategory;
  ID: TId;
begin
  C := SelectedCategory;
  if C = nil then Exit;
  if EditCategoryDialog(FDB, C, ID) then
  begin
    RefreshAll;
    SelectGridEntity(gridCategories, ID, True);
  end;
end;

procedure TMainForm.btnCatDeleteClick(Sender: TObject);
var
  C: TCategory;
  ID: TId;
  Err: string;
begin
  C := SelectedCategory;
  if C = nil then Exit;
  ID := C.ID;
  if MessageDlg('Удалить категорию «' + C.Name + '»?', mtConfirmation, [mbYes, mbNo], 0) <> mrYes then Exit;
  if not FDB.DeleteCategory(C, Err) then
    MessageDlg(Err, mtError, [mbOK], 0)
  else
  begin
    RefreshAll;
    SelectGridEntity(gridCategories, ID, True);
  end;
end;

procedure TMainForm.btnLocAddClick(Sender: TObject);
var
  ID: TId;
begin
  if EditLocationDialog(FDB, nil, ID) then
  begin
    RefreshAll;
    SelectGridEntity(gridLocations, ID, True);
  end;
end;

procedure TMainForm.btnLocEditClick(Sender: TObject);
var
  L: TLocation;
  ID: TId;
begin
  L := SelectedLocation;
  if L = nil then Exit;
  if EditLocationDialog(FDB, L, ID) then
  begin
    RefreshAll;
    SelectGridEntity(gridLocations, ID, True);
  end;
end;

procedure TMainForm.btnLocDeleteClick(Sender: TObject);
var
  L: TLocation;
  ID: TId;
  Err: string;
begin
  L := SelectedLocation;
  if L = nil then Exit;
  ID := L.ID;
  if MessageDlg('Удалить место хранения «' + L.Name + '»?', mtConfirmation, [mbYes, mbNo], 0) <> mrYes then Exit;
  if not FDB.DeleteLocation(L, Err) then
    MessageDlg(Err, mtError, [mbOK], 0)
  else
  begin
    RefreshAll;
    SelectGridEntity(gridLocations, ID, True);
  end;
end;

procedure TMainForm.pcMainChange(Sender: TObject);
begin
  pcMain.Invalidate;
  if pcMain.ActivePage = tsOverdue then RefreshOverdue
  else if pcMain.ActivePage = tsJournal then RefreshJournal
  else if pcMain.ActivePage = tsBackup then RefreshBackups;
end;

procedure TMainForm.chkShowDeletedChange(Sender: TObject);
begin
  RefreshAll;
end;

procedure TMainForm.chkLoansOnlyLoanedChange(Sender: TObject);
begin
  RefreshLoans;
end;

end.
