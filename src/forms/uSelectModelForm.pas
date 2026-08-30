unit uSelectModelForm;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, Grids, Buttons,
  ExtCtrls, Windows,
  uOpenRouterModels;

{ Открывает диалог выбора модели OpenRouter. Список моделей загружается по AApiKey.
  При успехе возвращает True и подставляет выбранный Id в ASelectedId.
  При отказе или ошибке загрузки — False. }
function SelectOpenRouterModelDialog(const AApiKey, ACurrentId: string;
  const AFavoriteModels: TStrings; out ASelectedId: string;
  out ASelectedFavoriteModels: TStringList): Boolean;

implementation

uses
  LCLType;

const
  COL_FAVORITE = 0;
  COL_ID = 1;
  COL_PROMPT = 2;
  COL_COMPLETION = 3;
  COL_COUNT = 4;
  MAX_MODELS_IN_DIALOG = 200;

type
  TModelsLoadThread = class(TThread)
  private
    FApiKey: string;
    FModels: TModelInfoArray;
    FError: string;
    FCompleted: LongInt;
  protected
    procedure Execute; override;
  public
    constructor Create(const AApiKey: string);
    function IsCompleted: Boolean;
    property Models: TModelInfoArray read FModels;
    property ErrorText: string read FError;
  end;

  TModelsLoadingForm = class(TForm)
  private
    FTimer: TTimer;
    FStatus: TLabel;
    FCancel: TBitBtn;
    FStep: Integer;
    FWorker: TModelsLoadThread;
    procedure TimerTick(Sender: TObject);
    procedure CancelClick(Sender: TObject);
  public
    constructor Create(AOwner: TComponent; AWorker: TModelsLoadThread); reintroduce;
  end;

  TSelectModelForm = class(TForm)
    edtFilter: TEdit;
    grid: TStringGrid;
    btnOK: TBitBtn;
    btnCancel: TBitBtn;
    lblHint: TLabel;
    lblStatus: TLabel;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure FormShow(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure edtFilterChange(Sender: TObject);
    procedure edtFilterKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure gridDblClick(Sender: TObject);
    procedure gridMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure gridKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure gridSelectCell(Sender: TObject; aCol, aRow: Integer;
      var CanSelect: Boolean);
  private
    FAllModels: TModelInfoArray;
    FCurrentId: string;
    FLoading: Boolean;
    FFilter: string;
    FFavoriteModels: TStringList;
    procedure LoadGrid(const APreferredId: string = ''; ASelectFirst: Boolean = False);
    procedure UpdateStatus;
    function IsFavorite(const AModelId: string): Boolean;
    procedure ToggleFavorite(const AModelId: string);
    function GetSelectedId: string;
  end;

function SelectOpenRouterModelDialog(const AApiKey, ACurrentId: string;
  const AFavoriteModels: TStrings; out ASelectedId: string;
  out ASelectedFavoriteModels: TStringList): Boolean;
var
  F: TSelectModelForm;
  LoadingForm: TModelsLoadingForm;
  Worker: TModelsLoadThread;
  Models: TModelInfoArray;
  Err: string;
begin
  Result := False;
  ASelectedId := '';
  ASelectedFavoriteModels := nil;
  Worker := TModelsLoadThread.Create(AApiKey);
  LoadingForm := TModelsLoadingForm.Create(nil, Worker);
  try
    Worker.Start;
    if LoadingForm.ShowModal <> mrOK then
    begin
      if not Worker.IsCompleted then
      begin
        Worker.FreeOnTerminate := True;
        Worker := nil;
      end;
      Exit;
    end;
    Worker.WaitFor;
    Models := Worker.Models;
    Err := Worker.ErrorText;
  finally
    LoadingForm.Free;
    Worker.Free;
  end;
  if Err <> '' then
  begin
    MessageDlg('Не удалось получить список моделей OpenRouter.' + LineEnding +
      LineEnding + Err, mtError, [mbOK], 0);
    Exit;
  end;
  { В диалоге показываем только платные модели от популярных провайдеров —
    бесплатные и мелкие провайдеры убраны за ненадобностью. }
  FilterPopularPaid(Models);
  SortModelsByPromptPrice(Models);
  F := TSelectModelForm.Create(nil);
  try
    F.FAllModels := Models;
    F.FCurrentId := ACurrentId;
    F.FFavoriteModels.Assign(AFavoriteModels);
    F.Caption := 'Выбор модели OpenRouter';
    F.OnShow := @F.FormShow;
    if F.ShowModal = mrOK then
    begin
      ASelectedId := F.GetSelectedId;
      ASelectedFavoriteModels := TStringList.Create;
      ASelectedFavoriteModels.Assign(F.FFavoriteModels);
      Result := True;
    end;
  finally
    F.Free;
  end;
end;

{ TModelsLoadThread }

constructor TModelsLoadThread.Create(const AApiKey: string);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FApiKey := AApiKey;
end;

procedure TModelsLoadThread.Execute;
begin
  try
    if FetchOpenRouterModels(FApiKey, FModels, FError) then
    begin
      FilterPopularPaid(FModels);
      SortModelsByPromptPrice(FModels);
      { Ограничиваем каталог, чтобы TStringGrid не блокировал интерфейс
        при создании тысяч строк. Модель вне списка можно ввести вручную. }
      if Length(FModels) > MAX_MODELS_IN_DIALOG then
        SetLength(FModels, MAX_MODELS_IN_DIALOG);
    end;
  except
    on E: Exception do
      FError := 'Непредвиденная ошибка загрузки: ' + E.Message;
  end;
  InterlockedExchange(FCompleted, 1);
end;

function TModelsLoadThread.IsCompleted: Boolean;
begin
  Result := InterlockedCompareExchange(FCompleted, 0, 0) <> 0;
end;

{ TModelsLoadingForm }

constructor TModelsLoadingForm.Create(AOwner: TComponent;
  AWorker: TModelsLoadThread);
begin
  inherited CreateNew(AOwner);
  FWorker := AWorker;
  Caption := 'Загрузка моделей OpenRouter';
  Position := poScreenCenter;
  BorderStyle := bsDialog;
  BorderIcons := [biSystemMenu];
  ClientWidth := 380;
  ClientHeight := 118;

  FStatus := TLabel.Create(Self);
  FStatus.Parent := Self;
  FStatus.Left := 16;
  FStatus.Top := 20;
  FStatus.Caption := 'Получаем список моделей';

  FCancel := TBitBtn.Create(Self);
  FCancel.Parent := Self;
  FCancel.Kind := bkCancel;
  FCancel.Caption := 'Отмена';
  FCancel.SetBounds(ClientWidth - 116, ClientHeight - 48, 100, 32);
  FCancel.OnClick := @CancelClick;

  FTimer := TTimer.Create(Self);
  FTimer.Interval := 350;
  FTimer.OnTimer := @TimerTick;
  FTimer.Enabled := True;
end;

procedure TModelsLoadingForm.TimerTick(Sender: TObject);
const
  DOTS: array[0..3] of string = ('', '.', '..', '...');
begin
  if FWorker.IsCompleted then
  begin
    FTimer.Enabled := False;
    ModalResult := mrOK;
    Exit;
  end;
  FStatus.Caption := 'Получаем список моделей' + DOTS[FStep];
  FStep := (FStep + 1) mod (High(DOTS) + 1);
end;

procedure TModelsLoadingForm.CancelClick(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

{ TSelectModelForm }

constructor TSelectModelForm.Create(AOwner: TComponent);
const
  FORM_W = 760;
  FORM_H = 540;
  MARGIN = 12;
  BTN_H = 32;
  ROW_H = 26;
begin
  { Без CreateNew LCL не даст форму без .lfm при включённом RequireDerivedFormResource. }
  inherited CreateNew(AOwner);
  FLoading := True;
  FFavoriteModels := TStringList.Create;
  KeyPreview := True;
  Position := poScreenCenter;
  BorderStyle := bsDialog;
  ClientWidth := FORM_W;
  ClientHeight := FORM_H;
  Constraints.MinWidth := 600;
  Constraints.MinHeight := 380;

  lblHint := TLabel.Create(Self);
  lblHint.Parent := Self;
  lblHint.Left := MARGIN;
  lblHint.Top := MARGIN + 3;
  lblHint.Caption := 'Поиск:';
  lblHint.AutoSize := True;

  edtFilter := TEdit.Create(Self);
  edtFilter.Parent := Self;
  edtFilter.Left := MARGIN + 60;
  edtFilter.Top := MARGIN;
  edtFilter.Width := ClientWidth - (MARGIN + 60) - MARGIN;
  edtFilter.OnChange := @edtFilterChange;
  edtFilter.OnKeyDown := @edtFilterKeyDown;

  lblStatus := TLabel.Create(Self);
  lblStatus.Parent := Self;
  lblStatus.Left := MARGIN;
  lblStatus.Top := MARGIN + 32;
  lblStatus.AutoSize := True;
  lblStatus.Caption := '';

  grid := TStringGrid.Create(Self);
  grid.Parent := Self;
  grid.Left := MARGIN;
  grid.Top := MARGIN + 56;
  grid.Width := ClientWidth - 2 * MARGIN;
  grid.Height := ClientHeight - (MARGIN + 56) - MARGIN - BTN_H - MARGIN;
  grid.ColCount := COL_COUNT;
  grid.RowCount := 1;
  grid.FixedRows := 1;
  grid.FixedCols := 0;
  grid.DefaultRowHeight := ROW_H;
  grid.Options := grid.Options + [goRowSelect] - [goEditing, goAlwaysShowEditor];
  grid.Cells[COL_FAVORITE, 0] := '★';
  grid.Cells[COL_ID, 0] := 'Модель';
  grid.Cells[COL_PROMPT, 0] := 'Вход $ / 1M';
  grid.Cells[COL_COMPLETION, 0] := 'Выход $ / 1M';
  grid.ColWidths[COL_FAVORITE] := 38;
  grid.ColWidths[COL_ID] := 382;
  grid.ColWidths[COL_PROMPT] := 150;
  grid.ColWidths[COL_COMPLETION] := 150;
  grid.ColumnClickSorts := False;
  grid.OnDblClick := @gridDblClick;
  grid.OnMouseDown := @gridMouseDown;
  grid.OnKeyDown := @gridKeyDown;
  grid.OnSelectCell := @gridSelectCell;

  btnCancel := TBitBtn.Create(Self);
  btnCancel.Parent := Self;
  btnCancel.Kind := bkCancel;
  btnCancel.Caption := 'Отмена';
  btnCancel.Left := ClientWidth - MARGIN - 140;
  btnCancel.Top := ClientHeight - MARGIN - BTN_H;
  btnCancel.Width := 140;
  btnCancel.Height := BTN_H;

  btnOK := TBitBtn.Create(Self);
  btnOK.Parent := Self;
  btnOK.Kind := bkOK;
  btnOK.Caption := 'Готово';
  btnOK.Left := ClientWidth - MARGIN - 140 - 8 - 140;
  btnOK.Top := ClientHeight - MARGIN - BTN_H;
  btnOK.Width := 140;
  btnOK.Height := BTN_H;
  btnOK.Enabled := True;
  btnOK.ModalResult := mrOK;
end;

destructor TSelectModelForm.Destroy;
begin
  FFavoriteModels.Free;
  inherited Destroy;
end;

procedure TSelectModelForm.FormShow(Sender: TObject);
begin
  FLoading := False;
  LoadGrid;
  edtFilter.SetFocus;
end;

procedure TSelectModelForm.FormKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if Key = VK_ESCAPE then
    ModalResult := mrCancel
  else if (Key = VK_RETURN) and (grid.Focused) and (grid.Row > 0) then
    ModalResult := mrOK;
end;

procedure TSelectModelForm.edtFilterKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if Key = VK_DOWN then
  begin
    if grid.RowCount > 1 then
    begin
      if grid.Row < grid.RowCount - 1 then
        grid.Row := grid.Row + 1
      else
        grid.Row := 1;
      grid.SetFocus;
    end;
    Key := 0;
  end
  else if Key = VK_UP then
  begin
    if grid.RowCount > 1 then
    begin
      if grid.Row > 1 then
        grid.Row := grid.Row - 1
      else
        grid.Row := grid.RowCount - 1;
      grid.SetFocus;
    end;
    Key := 0;
  end
  else if (Key = VK_RETURN) and (grid.Row > 0) then
  begin
    ModalResult := mrOK;
    Key := 0;
  end;
end;

procedure TSelectModelForm.edtFilterChange(Sender: TObject);
begin
  if FLoading then
    Exit;
  FFilter := LowerCase(Trim(edtFilter.Text));
  LoadGrid;
end;

procedure TSelectModelForm.gridSelectCell(Sender: TObject; aCol, aRow: Integer;
  var CanSelect: Boolean);
begin
  btnOK.Enabled := aRow > 0;
end;

procedure TSelectModelForm.gridDblClick(Sender: TObject);
begin
  if (grid.Row > 0) and (grid.Col <> COL_FAVORITE) then
    ModalResult := mrOK;
end;

procedure TSelectModelForm.gridMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  Col, Row: Integer;
begin
  grid.MouseToCell(X, Y, Col, Row);
  if (Button = mbLeft) and (Col = COL_FAVORITE) and (Row > 0) then
    ToggleFavorite(grid.Cells[COL_ID, Row]);
end;

procedure TSelectModelForm.gridKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if (Key = VK_SPACE) and (grid.Row > 0) then
  begin
    ToggleFavorite(grid.Cells[COL_ID, grid.Row]);
    Key := 0;
  end;
end;

procedure TSelectModelForm.LoadGrid(const APreferredId: string;
  ASelectFirst: Boolean);
var
  i, Row, Pass: Integer;
  M: TModelInfo;
  SelectedId: string;
begin
  grid.RowCount := 1;
  Row := 1;
  { FAllModels уже отсортирован по цене. Двумя проходами выносим избранное
    вверх, сохраняя сортировку по цене в обеих группах. }
  for Pass := 0 to 1 do
    for i := 0 to High(FAllModels) do
    begin
      M := FAllModels[i];
      if IsFavorite(M.Id) <> (Pass = 0) then
        Continue;
      if (FFilter <> '') and (Pos(FFilter, LowerCase(M.Id)) = 0) then
        Continue;
      grid.RowCount := Row + 1;
      if IsFavorite(M.Id) then
        grid.Cells[COL_FAVORITE, Row] := '☑'
      else
        grid.Cells[COL_FAVORITE, Row] := '☐';
      grid.Cells[COL_ID, Row] := M.Id;
      grid.Cells[COL_PROMPT, Row] := FormatModelPrice(M.PromptPrice);
      grid.Cells[COL_COMPLETION, Row] := FormatModelPrice(M.CompletionPrice);
      Inc(Row);
    end;
  if ASelectFirst and (grid.RowCount > 1) then
  begin
    grid.Row := 1;
    grid.TopRow := 1;
  end
  else
  begin
    if APreferredId <> '' then
      SelectedId := APreferredId
    else
      SelectedId := FCurrentId;
    { Если целевая модель есть в списке — выделим и прокрутим к ней. }
    if SelectedId <> '' then
      for Row := 1 to grid.RowCount - 1 do
        if grid.Cells[COL_ID, Row] = SelectedId then
        begin
          grid.Row := Row;
          grid.TopRow := Row;
          Break;
        end;
  end;
  UpdateStatus;
end;

function TSelectModelForm.IsFavorite(const AModelId: string): Boolean;
begin
  Result := FFavoriteModels.IndexOf(AModelId) >= 0;
end;

procedure TSelectModelForm.ToggleFavorite(const AModelId: string);
var
  i: Integer;
begin
  i := FFavoriteModels.IndexOf(AModelId);
  if i >= 0 then
  begin
    FFavoriteModels.Delete(i);
    LoadGrid('', True);
  end
  else
  begin
    FFavoriteModels.Add(AModelId);
    LoadGrid(AModelId);
  end;
end;

procedure TSelectModelForm.UpdateStatus;
var
  Total, Shown: Integer;
begin
  Total := Length(FAllModels);
  Shown := grid.RowCount - 1;
  if FFilter <> '' then
    lblStatus.Caption := Format('Показано %d из %d моделей (фильтр: «%s»).',
      [Shown, Total, FFilter])
  else
    lblStatus.Caption := Format('Всего моделей: %d.', [Total]);
end;

function TSelectModelForm.GetSelectedId: string;
begin
  Result := '';
  if grid.Row > 0 then
    Result := grid.Cells[COL_ID, grid.Row];
end;

end.
