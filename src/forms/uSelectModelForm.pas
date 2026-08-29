unit uSelectModelForm;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, Grids, Buttons,
  uOpenRouterModels;

{ Открывает диалог выбора модели OpenRouter. Список моделей загружается по AApiKey.
  При успехе возвращает True и подставляет выбранный Id в ASelectedId.
  При отказе или ошибке загрузки — False. }
function SelectOpenRouterModelDialog(const AApiKey, ACurrentId: string;
  out ASelectedId: string): Boolean;

implementation

uses
  LCLType;

const
  COL_ID = 0;
  COL_PROMPT = 1;
  COL_COMPLETION = 2;
  COL_COUNT = 3;

type
  TSelectModelForm = class(TForm)
    edtFilter: TEdit;
    grid: TStringGrid;
    btnOK: TBitBtn;
    btnCancel: TBitBtn;
    lblHint: TLabel;
    lblStatus: TLabel;
    constructor Create(AOwner: TComponent); override;
    procedure FormShow(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure edtFilterChange(Sender: TObject);
    procedure edtFilterKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure gridDblClick(Sender: TObject);
    procedure gridSelectCell(Sender: TObject; aCol, aRow: Integer;
      var CanSelect: Boolean);
  private
    FAllModels: TModelInfoArray;
    FCurrentId: string;
    FLoading: Boolean;
    FFilter: string;
    procedure LoadGrid;
    procedure UpdateStatus;
    function GetSelectedId: string;
  end;

function SelectOpenRouterModelDialog(const AApiKey, ACurrentId: string;
  out ASelectedId: string): Boolean;
var
  F: TSelectModelForm;
  Models: TModelInfoArray;
  Err: string;
begin
  Result := False;
  ASelectedId := '';
  if not FetchOpenRouterModels(AApiKey, Models, Err) then
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
    F.Caption := 'Выбор модели OpenRouter';
    if F.ShowModal = mrOK then
    begin
      ASelectedId := F.GetSelectedId;
      Result := ASelectedId <> '';
    end;
  finally
    F.Free;
  end;
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
  grid.Cells[COL_ID, 0] := 'Модель';
  grid.Cells[COL_PROMPT, 0] := 'Вход $ / 1M';
  grid.Cells[COL_COMPLETION, 0] := 'Выход $ / 1M';
  grid.ColWidths[COL_ID] := 420;
  grid.ColWidths[COL_PROMPT] := 150;
  grid.ColWidths[COL_COMPLETION] := 150;
  grid.ColumnClickSorts := False;
  grid.OnDblClick := @gridDblClick;
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
  btnOK.Caption := 'Выбрать';
  btnOK.Left := ClientWidth - MARGIN - 140 - 8 - 140;
  btnOK.Top := ClientHeight - MARGIN - BTN_H;
  btnOK.Width := 140;
  btnOK.Height := BTN_H;
  btnOK.Enabled := False;
  btnOK.ModalResult := mrOK;
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
  if grid.Row > 0 then
    ModalResult := mrOK;
end;

procedure TSelectModelForm.LoadGrid;
var
  i, Row: Integer;
  M: TModelInfo;
begin
  grid.RowCount := 1;
  Row := 1;
  for i := 0 to High(FAllModels) do
  begin
    M := FAllModels[i];
    if (FFilter <> '') and (Pos(FFilter, LowerCase(M.Id)) = 0) then
      Continue;
    grid.RowCount := Row + 1;
    grid.Cells[COL_ID, Row] := M.Id;
    grid.Cells[COL_PROMPT, Row] := FormatModelPrice(M.PromptPrice);
    grid.Cells[COL_COMPLETION, Row] := FormatModelPrice(M.CompletionPrice);
    Inc(Row);
  end;
  { Если текущая модель есть в списке — подсветим. }
  if (FCurrentId <> '') and (grid.RowCount > 1) then
  begin
    for Row := 1 to grid.RowCount - 1 do
      if grid.Cells[COL_ID, Row] = FCurrentId then
      begin
        grid.Row := Row;
        Break;
      end;
  end;
  UpdateStatus;
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
