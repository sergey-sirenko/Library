unit uGridSorting;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Grids;

type
  TGridSortKind = (gskText, gskNumber, gskDate);
  TGridSortKeyEvent = function(ACol, ARow: Integer): string of object;

  { Состояние принадлежит таблице и живёт только до закрытия окна. }
  TGridSorting = class(TComponent)
  private
    FGrid: TStringGrid;
    FFirstCol, FColumn: Integer;
    FDescending, FSorting: Boolean;
    FSchema: string;
    FAfterSort: TNotifyEvent;
    FKey: TGridSortKeyEvent;
    FEditingDone: TNotifyEvent;
    procedure HeaderClick(Sender: TObject; IsColumn: Boolean; Index: Integer);
    procedure EditingDone(Sender: TObject);
    procedure UpdateHeaders;
  public
    constructor CreateFor(AGrid: TStringGrid; AFirstCol: Integer;
      AAfterSort: TNotifyEvent);
    procedure Apply;
    procedure ClickColumn(AColumn: Integer);
    property OnKey: TGridSortKeyEvent read FKey write FKey;
    property Column: Integer read FColumn;
    property Descending: Boolean read FDescending;
  end;

function GridSortKind(const ACaption: string): TGridSortKind;
function CompareGridValues(const A, B: string; AKind: TGridSortKind): Integer;
function GridSorting(AGrid: TStringGrid): TGridSorting;
procedure ApplyGridSorting(AGrid: TStringGrid);

implementation

uses
  LazUTF8;

type
  TSortingGridAccess = class(TStringGrid);

function PlainCaption(const S: string): string;
begin
  Result := StringReplace(StringReplace(S, ' ▲', '', [rfReplaceAll]),
    ' ▼', '', [rfReplaceAll]);
end;

function GridSortKind(const ACaption: string): TGridSortKind;
var
  S: string;
begin
  S := PlainCaption(ACaption);
  if (S = 'Год') or (S = 'Дней') or (S = 'Дней просрочки') or
    (S = 'Вход $ / 1M') or (S = 'Выход $ / 1M') then
    Exit(gskNumber);
  if (Pos('Дата', S) = 1) or (S = 'Регистрация') or (S = 'Выдана') or
    (S = 'Срок') or (S = 'Срок возврата') or (S = 'Возврат') then
    Exit(gskDate);
  Result := gskText;
end;

function CompareGridValues(const A, B: string; AKind: TGridSortKind): Integer;
var
  SA, SB: string;
  VA, VB: Double;
  DA, DB: TDateTime;
  OKA, OKB: Boolean;
  FS: TFormatSettings;
begin
  SA := Trim(A);
  SB := Trim(B);
  if (SA = '') or (SB = '') then
  begin
    if SA = SB then Exit(0);
    if SA = '' then Exit(-1);
    Exit(1);
  end;
  FS := DefaultFormatSettings;
  OKA := False;
  OKB := False;
  VA := 0;
  VB := 0;
  case AKind of
    gskNumber:
      begin
        FS.DecimalSeparator := '.';
        OKA := TryStrToFloat(StringReplace(SA, ',', '.', []), VA, FS);
        OKB := TryStrToFloat(StringReplace(SB, ',', '.', []), VB, FS);
      end;
    gskDate:
      begin
        FS.DateSeparator := '.';
        FS.ShortDateFormat := 'dd.mm.yyyy';
        FS.TimeSeparator := ':';
        OKA := TryStrToDateTime(SA, DA, FS);
        OKB := TryStrToDateTime(SB, DB, FS);
        if OKA then VA := DA;
        if OKB then VB := DB;
      end;
  end;
  if OKA and OKB then
  begin
    if VA < VB then Exit(-1);
    if VA > VB then Exit(1);
    Exit(0);
  end;
  { Некорректные значения образуют отдельную группу: сравнение транзитивно. }
  if OKA <> OKB then
  begin
    if OKA then Exit(-1);
    Exit(1);
  end;
  Result := UTF8CompareText(SA, SB);
end;

constructor TGridSorting.CreateFor(AGrid: TStringGrid; AFirstCol: Integer;
  AAfterSort: TNotifyEvent);
begin
  inherited Create(AGrid);
  FGrid := AGrid;
  FFirstCol := AFirstCol;
  FColumn := AFirstCol;
  FAfterSort := AAfterSort;
  FGrid.ColumnClickSorts := False;
  FGrid.Options := FGrid.Options + [goHeaderHotTracking, goHeaderPushedLook];
  FGrid.OnHeaderClick := @HeaderClick;
  FEditingDone := FGrid.OnEditingDone;
  FGrid.OnEditingDone := @EditingDone;
end;

procedure TGridSorting.UpdateHeaders;
var
  C: Integer;
  S: string;
begin
  if FGrid.FixedRows = 0 then Exit;
  for C := FFirstCol to FGrid.ColCount - 1 do
  begin
    S := PlainCaption(FGrid.Cells[C, 0]);
    if (C = FColumn) and (S <> '') then
    begin
      if FDescending then S := S + ' ▼' else S := S + ' ▲';
    end;
    FGrid.Cells[C, 0] := S;
    if FGrid.Columns.Enabled then
      TSortingGridAccess(FGrid).ColumnFromGridColumn(C).Title.Caption := S;
  end;
end;

procedure TGridSorting.HeaderClick(Sender: TObject; IsColumn: Boolean; Index: Integer);
begin
  if IsColumn then ClickColumn(Index);
end;

procedure TGridSorting.ClickColumn(AColumn: Integer);
begin
  if FSorting then Exit;
  if (AColumn < FFirstCol) or (AColumn >= FGrid.ColCount) or
    (FGrid.FixedRows = 0) or (PlainCaption(FGrid.Cells[AColumn, 0]) = '') then Exit;
  { Сначала завершаем ввод на прежней записи, до перемещения строк. }
  FSorting := True;
  try
    FGrid.EditorMode := False;
    if Assigned(FEditingDone) then FEditingDone(FGrid);
  finally
    FSorting := False;
  end;
  if FColumn = AColumn then FDescending := not FDescending
  else
  begin
    FColumn := AColumn;
    FDescending := False;
  end;
  Apply;
end;

procedure TGridSorting.EditingDone(Sender: TObject);
begin
  if FSorting then Exit;
  if Assigned(FEditingDone) then FEditingDone(Sender);
  Apply;
end;

procedure TGridSorting.Apply;
type
  TRowData = record
    Cells: TStringList;
    Key: string;
    Height, OriginalRow: Integer;
  end;
var
  Rows: array of TRowData;
  Order, Temp: array of Integer;
  I, C, N, SelectedRow, NewRow: Integer;
  Schema, Caption: string;
  Kind: TGridSortKind;
  SelectionEvent: TOnSelectEvent;

  procedure MergeSort(L, R: Integer);
  var
    M, A, B, K, Comparison: Integer;
  begin
    if L >= R then Exit;
    M := (L + R) div 2;
    MergeSort(L, M);
    MergeSort(M + 1, R);
    A := L;
    B := M + 1;
    for K := L to R do
    begin
      if (A <= M) and (B <= R) then
      begin
        Comparison := CompareGridValues(Rows[Order[A]].Key,
          Rows[Order[B]].Key, Kind);
        if FDescending then Comparison := -Comparison;
      end
      else Comparison := 0;
      if (A <= M) and ((B > R) or (Comparison <= 0)) then
      begin
        Temp[K] := Order[A];
        Inc(A);
      end
      else
      begin
        Temp[K] := Order[B];
        Inc(B);
      end;
    end;
    for K := L to R do Order[K] := Temp[K];
  end;

begin
  if FSorting or (FGrid.FixedRows = 0) then Exit;
  Schema := '';
  for C := FFirstCol to FGrid.ColCount - 1 do
    Schema := Schema + PlainCaption(FGrid.Cells[C, 0]) + #9;
  if Schema <> FSchema then
  begin
    FSchema := Schema;
    FColumn := FFirstCol;
    FDescending := False;
    for C := FFirstCol to FGrid.ColCount - 1 do
    begin
      Caption := PlainCaption(FGrid.Cells[C, 0]);
      if (Caption = 'Название') or (Caption = 'Наименование') or
        (Caption = 'ФИО') or (Caption = 'Имя') or (Caption = 'Книга') or
        (Caption = 'Модель') then
      begin
        FColumn := C;
        Break;
      end;
    end;
  end;
  if FColumn >= FGrid.ColCount then Exit;
  Kind := GridSortKind(FGrid.Cells[FColumn, 0]);
  FSorting := True;
  FGrid.EditorMode := False;
  SelectionEvent := FGrid.OnSelection;
  FGrid.OnSelection := nil;
  N := FGrid.RowCount - FGrid.FixedRows;
  SetLength(Rows, N);
  SetLength(Order, N);
  SetLength(Temp, N);
  SelectedRow := FGrid.Row;
  NewRow := SelectedRow;
  FGrid.BeginUpdate;
  try
    for I := 0 to N - 1 do
    begin
      Rows[I].OriginalRow := I + FGrid.FixedRows;
      Rows[I].Cells := TStringList.Create;
      Rows[I].Cells.Assign(FGrid.Rows[Rows[I].OriginalRow]);
      Rows[I].Height := FGrid.RowHeights[Rows[I].OriginalRow];
      if Assigned(FKey) then Rows[I].Key := FKey(FColumn, Rows[I].OriginalRow)
      else Rows[I].Key := FGrid.Cells[FColumn, Rows[I].OriginalRow];
      Order[I] := I;
    end;
    MergeSort(0, N - 1);
    for I := 0 to N - 1 do
    begin
      FGrid.Rows[I + FGrid.FixedRows].Assign(Rows[Order[I]].Cells);
      FGrid.RowHeights[I + FGrid.FixedRows] := Rows[Order[I]].Height;
      if Rows[Order[I]].OriginalRow = SelectedRow then
        NewRow := I + FGrid.FixedRows;
    end;
    FGrid.Row := NewRow;
    UpdateHeaders;
  finally
    for I := 0 to N - 1 do Rows[I].Cells.Free;
    FGrid.EndUpdate;
    FGrid.OnSelection := SelectionEvent;
    FSorting := False;
  end;
  if Assigned(FAfterSort) then FAfterSort(FGrid);
end;

function GridSorting(AGrid: TStringGrid): TGridSorting;
var
  I: Integer;
begin
  for I := 0 to AGrid.ComponentCount - 1 do
    if AGrid.Components[I] is TGridSorting then
      Exit(TGridSorting(AGrid.Components[I]));
  Result := nil;
end;

procedure ApplyGridSorting(AGrid: TStringGrid);
var
  Sorting: TGridSorting;
begin
  Sorting := GridSorting(AGrid);
  if Sorting <> nil then Sorting.Apply;
end;

end.
