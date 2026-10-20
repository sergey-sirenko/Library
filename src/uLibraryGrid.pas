unit uLibraryGrid;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Grids, Controls, Menus;

type
  { Код форм обращается к постоянным номерам полей. LCL рисует и редактирует
    физические колонки; переопределять виртуальные GetCells/SetCells нельзя. }
  TLibraryGrid = class(TStringGrid)
  private
    FOrder, FWidths, FDefaults: array of Integer;
    FHidden, FAllowed, FDefaultHidden: array of Boolean;
    FFileName, FKey: string;
    FFirst: Integer;
    FDefaultsCaptured: Boolean;
    FChanged: TNotifyEvent;
    FMenu: TPopupMenu;
    procedure EnsureMapping;
    function ReadCell(C, R: Integer): string;
    procedure WriteCell(C, R: Integer; const S: string);
    function ReadObject(C, R: Integer): TObject;
    procedure WriteObject(C, R: Integer; O: TObject);
    function ReadWidth(C: Integer): Integer;
    procedure WriteWidth(C, W: Integer);
    function ReadCol: Integer;
    procedure WriteCol(C: Integer);
    procedure ContextPopup(Sender: TObject; MousePos: TPoint; var Handled: Boolean);
    procedure ConfigureClick(Sender: TObject);
    procedure ApplyVisibility(C: Integer);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function LogicalColumn(C: Integer): Integer;
    function PhysicalColumn(C: Integer): Integer;
    procedure MoveField(C, Position: Integer);
    procedure SetFieldVisible(C: Integer; AVisible: Boolean);
    procedure SetFieldDefaultVisible(C: Integer; AVisible: Boolean);
    function FieldVisible(C: Integer): Boolean;
    procedure SetFieldAllowed(C: Integer; AAllowed: Boolean);
    procedure Configure(const AFileName, AKey: string; AFirst: Integer;
      AChanged: TNotifyEvent = nil);
    procedure SaveLayout;
    procedure CaptureDefaults;
    procedure ResetLayout;
    procedure BeginSchema;
    procedure ConfigureColumns;
    property Cells[C, R: Integer]: string read ReadCell write WriteCell;
    property Objects[C, R: Integer]: TObject read ReadObject write WriteObject;
    property ColWidths[C: Integer]: Integer read ReadWidth write WriteWidth;
    property Col: Integer read ReadCol write WriteCol;
  end;

implementation

uses Forms, StdCtrls, CheckLst, Dialogs;

type
  TColumnDialog = class(TForm)
  public
    List: TCheckListBox;
    Grid: TLibraryGrid;
    ResetWidths: Boolean;
    procedure MoveUp(Sender: TObject);
    procedure MoveDown(Sender: TObject);
    procedure Restore(Sender: TObject);
    procedure MoveItem(Delta: Integer);
  end;

constructor TLibraryGrid.Create(AOwner: TComponent);
var Item: TMenuItem;
begin
  inherited Create(AOwner);
  FMenu := TPopupMenu.Create(Self);
  Item := TMenuItem.Create(FMenu);
  Item.Caption := 'Настроить колонки…';
  Item.OnClick := @ConfigureClick;
  FMenu.Items.Add(Item);
  OnContextPopup := @ContextPopup;
end;

destructor TLibraryGrid.Destroy;
begin
  SaveLayout;
  inherited Destroy;
end;

procedure TLibraryGrid.EnsureMapping;
var I: Integer;
begin
  if Length(FOrder) = ColCount then Exit;
  FDefaultsCaptured := False;
  SetLength(FOrder, ColCount);
  SetLength(FWidths, ColCount);
  SetLength(FDefaults, ColCount);
  SetLength(FHidden, ColCount);
  SetLength(FDefaultHidden, ColCount);
  SetLength(FAllowed, ColCount);
  for I := 0 to ColCount - 1 do
  begin
    FOrder[I] := I;
    FWidths[I] := inherited ColWidths[I];
    FDefaults[I] := FWidths[I];
    FHidden[I] := False;
    FDefaultHidden[I] := False;
    FAllowed[I] := True;
  end;
end;

function TLibraryGrid.LogicalColumn(C: Integer): Integer;
begin
  EnsureMapping;
  if (C >= 0) and (C < Length(FOrder)) then Result := FOrder[C]
  else Result := C;
end;

function TLibraryGrid.PhysicalColumn(C: Integer): Integer;
var I: Integer;
begin
  EnsureMapping;
  for I := 0 to High(FOrder) do
    if FOrder[I] = C then Exit(I);
  Result := C;
end;

function TLibraryGrid.ReadCell(C, R: Integer): string;
begin
  Result := inherited Cells[PhysicalColumn(C), R];
end;
procedure TLibraryGrid.WriteCell(C, R: Integer; const S: string);
begin
  inherited Cells[PhysicalColumn(C), R] := S;
end;
function TLibraryGrid.ReadObject(C, R: Integer): TObject;
begin
  Result := inherited Objects[PhysicalColumn(C), R];
end;
procedure TLibraryGrid.WriteObject(C, R: Integer; O: TObject);
begin
  inherited Objects[PhysicalColumn(C), R] := O;
end;
function TLibraryGrid.ReadWidth(C: Integer): Integer;
begin
  Result := inherited ColWidths[PhysicalColumn(C)];
end;
procedure TLibraryGrid.WriteWidth(C, W: Integer);
begin
  EnsureMapping;
  if W > 0 then FWidths[C] := W;
  if FHidden[C] or not FAllowed[C] then W := 0;
  inherited ColWidths[PhysicalColumn(C)] := W;
end;
function TLibraryGrid.ReadCol: Integer;
begin
  Result := LogicalColumn(inherited Col);
end;
procedure TLibraryGrid.WriteCol(C: Integer);
var I: Integer;
begin
  if ReadWidth(C) <= 0 then
    for I := FFirst to ColCount - 1 do
      if ReadWidth(LogicalColumn(I)) > 0 then
      begin
        C := LogicalColumn(I);
        Break;
      end;
  inherited Col := PhysicalColumn(C);
end;

procedure TLibraryGrid.MoveField(C, Position: Integer);
var P, I, Selected: Integer;
begin
  EnsureMapping;
  if (C < FFirst) or (C >= ColCount) or (Position < FFirst) or
    (Position >= ColCount) then Exit;
  EditorMode := False;
  Selected := Col;
  P := PhysicalColumn(C);
  MoveColRow(True, P, Position);
  if P < Position then
    for I := P to Position - 1 do FOrder[I] := FOrder[I + 1]
  else
    for I := P downto Position + 1 do FOrder[I] := FOrder[I - 1];
  FOrder[Position] := C;
  Col := Selected;
end;

procedure TLibraryGrid.ApplyVisibility(C: Integer);
var W: Integer;
begin
  W := ReadWidth(C);
  if W > 0 then FWidths[C] := W;
  if FHidden[C] or not FAllowed[C] then W := 0
  else W := FWidths[C];
  inherited ColWidths[PhysicalColumn(C)] := W;
end;

procedure TLibraryGrid.SetFieldVisible(C: Integer; AVisible: Boolean);
begin
  EnsureMapping;
  if (C < FFirst) or (C >= ColCount) then Exit;
  FHidden[C] := not AVisible;
  ApplyVisibility(C);
end;

procedure TLibraryGrid.SetFieldDefaultVisible(C: Integer; AVisible: Boolean);
begin
  EnsureMapping;
  if (C < FFirst) or (C >= ColCount) then Exit;
  FDefaultHidden[C] := not AVisible;
  SetFieldVisible(C, AVisible);
end;

function TLibraryGrid.FieldVisible(C: Integer): Boolean;
begin
  EnsureMapping;
  Result := not FHidden[C];
end;

procedure TLibraryGrid.SetFieldAllowed(C: Integer; AAllowed: Boolean);
begin
  EnsureMapping;
  FAllowed[C] := AAllowed;
  ApplyVisibility(C);
end;

procedure TLibraryGrid.ResetLayout;
var I: Integer;
begin
  EnsureMapping;
  for I := FFirst to ColCount - 1 do
  begin
    MoveField(I, I);
    FHidden[I] := FDefaultHidden[I];
    FWidths[I] := FDefaults[I];
    inherited ColWidths[I] := 0;
    ApplyVisibility(I);
  end;
end;

procedure TLibraryGrid.BeginSchema;
begin
  SaveLayout;
  ResetLayout;
  FKey := '';
  FDefaultsCaptured := False;
  SetLength(FOrder, 0);
end;

procedure TLibraryGrid.CaptureDefaults;
var I: Integer;
begin
  EnsureMapping;
  for I := 0 to ColCount - 1 do
    FDefaults[I] := FWidths[I];
  FDefaultsCaptured := True;
end;

procedure TLibraryGrid.Configure(const AFileName, AKey: string;
  AFirst: Integer; AChanged: TNotifyEvent);
var SL, Parts: TStringList; I, J, C, W, VisibleCount: Integer; Raw: string;
begin
  EnsureMapping;
  FFileName := AFileName;
  FKey := AKey + '.ColumnsV1';
  FFirst := AFirst;
  FChanged := AChanged;
  if not FDefaultsCaptured then CaptureDefaults;
  SL := TStringList.Create;
  Parts := TStringList.Create;
  try
    try
      if not FileExists(FFileName) then Exit;
      SL.LoadFromFile(FFileName);
      Raw := SL.Values[FKey + '.Order'];
      Parts.StrictDelimiter := True;
      Parts.Delimiter := ',';
      Parts.DelimitedText := Raw;
      { Старую полную перестановку полей сохраняем при добавлении колонок в конец.
        Повреждённые настройки игнорируем до применения перестановки. }
      if (Parts.Count > 0) and (Parts.Count <= ColCount - FFirst) then
      begin
        for I := 0 to Parts.Count - 1 do
        begin
          C := StrToIntDef(Parts[I], -1);
          if (C < FFirst) or (C >= FFirst + Parts.Count) then Exit;
          for J := 0 to I - 1 do
            if StrToIntDef(Parts[J], -1) = C then Exit;
        end;
        for I := 0 to Parts.Count - 1 do
          MoveField(StrToInt(Parts[I]), I + FFirst);
      end;
      for I := FFirst to ColCount - 1 do
      begin
        W := StrToIntDef(SL.Values[FKey + '.Width.' + IntToStr(I)], FWidths[I]);
        if (W >= 20) and (W <= 2000) then WriteWidth(I, W);
        Raw := SL.Values[FKey + '.Hidden.' + IntToStr(I)];
        if Raw <> '' then SetFieldVisible(I, Raw <> '1');
      end;
      VisibleCount := 0;
      for I := FFirst to ColCount - 1 do
        if ReadWidth(I) > 0 then Inc(VisibleCount);
      if VisibleCount = 0 then
        for I := FFirst to ColCount - 1 do
          if FAllowed[I] then
          begin
            SetFieldVisible(I, True);
            Break;
          end;
    except
      { Повреждённая раскладка не мешает работе с данными. }
    end;
  finally
    Parts.Free;
    SL.Free;
  end;
end;

procedure TLibraryGrid.SaveLayout;
var SL: TStringList; I: Integer; S: string;
begin
  if (FFileName = '') or (FKey = '') or (Length(FOrder) <> ColCount) then Exit;
  SL := TStringList.Create;
  try
    try
      if FileExists(FFileName) then SL.LoadFromFile(FFileName);
      S := '';
      for I := FFirst to ColCount - 1 do
      begin
        if I > FFirst then S := S + ',';
        S := S + IntToStr(FOrder[I]);
        if ReadWidth(I) > 0 then FWidths[I] := ReadWidth(I);
        SL.Values[FKey + '.Width.' + IntToStr(I)] := IntToStr(FWidths[I]);
        SL.Values[FKey + '.Hidden.' + IntToStr(I)] := BoolToStr(FHidden[I], '1', '0');
      end;
      SL.Values[FKey + '.Order'] := S;
      SL.SaveToFile(FFileName);
    except
      { Настройки интерфейса не критичны. }
    end;
  finally
    SL.Free;
  end;
end;

procedure TLibraryGrid.ContextPopup(Sender: TObject; MousePos: TPoint;
  var Handled: Boolean);
var C, R: Integer; P: TPoint;
begin
  MouseToCell(MousePos.X, MousePos.Y, C, R);
  if (MousePos.X < 0) or (R < FixedRows) then
  begin
    Handled := True;
    if MousePos.X < 0 then MousePos := Point(0, 0);
    P := ClientToScreen(MousePos);
    FMenu.PopUp(P.X, P.Y);
  end;
end;

procedure TLibraryGrid.ConfigureClick(Sender: TObject);
begin
  ConfigureColumns;
end;

procedure TColumnDialog.MoveItem(Delta: Integer);
var I, J: Integer;
begin
  I := List.ItemIndex;
  J := I + Delta;
  if (I < 0) or (J < 0) or (J >= List.Count) then Exit;
  List.Exchange(I, J);
  List.ItemIndex := J;
end;
procedure TColumnDialog.MoveUp(Sender: TObject);
begin
  MoveItem(-1);
end;
procedure TColumnDialog.MoveDown(Sender: TObject);
begin
  MoveItem(1);
end;
procedure TColumnDialog.Restore(Sender: TObject);
var I, J: Integer;
begin
  for I := 0 to List.Count - 1 do
    for J := I to List.Count - 1 do
      if PtrInt(List.Items.Objects[J]) = I + Tag then
      begin
        List.Items.Move(J, I);
        Break;
      end;
  for I := 0 to List.Count - 1 do
    List.Checked[I] := not Grid.FDefaultHidden[PtrInt(List.Items.Objects[I])];
  ResetWidths := True;
end;

procedure TLibraryGrid.ConfigureColumns;
var D: TColumnDialog; I, C, VisibleCount: Integer;
  procedure Button(const CaptionText: string; Y, ResultCode: Integer; Click: TNotifyEvent);
  var B: TButton;
  begin
    B := TButton.Create(D);
    B.Parent := D;
    B.Caption := CaptionText;
    B.SetBounds(300, Y, 170, 34);
    B.ModalResult := ResultCode;
    B.OnClick := Click;
    B.Default := ResultCode = mrOK;
    B.Cancel := ResultCode = mrCancel;
  end;
begin
  EnsureMapping;
  EditorMode := False;
  D := TColumnDialog.CreateNew(Self);
  try
    D.Font.Assign(Font);
    D.Caption := 'Настроить колонки';
    D.Position := poScreenCenter;
    D.BorderStyle := bsDialog;
    D.ClientWidth := 486;
    D.ClientHeight := 350;
    D.Tag := FFirst;
    D.Grid := Self;
    D.List := TCheckListBox.Create(D);
    D.List.Parent := D;
    D.List.SetBounds(16, 16, 270, 318);
    for I := FFirst to ColCount - 1 do
    begin
      C := FOrder[I];
      D.List.Items.AddObject(StringReplace(StringReplace(Cells[C, 0], ' ▲', '', []),
        ' ▼', '', []), TObject(PtrInt(C)));
      D.List.Checked[I - FFirst] := FieldVisible(C);
    end;
    Button('Выше', 16, mrNone, @D.MoveUp);
    Button('Ниже', 58, mrNone, @D.MoveDown);
    Button('Стандартный вид', 120, mrNone, @D.Restore);
    Button('Применить', 258, mrOK, nil);
    Button('Отмена', 300, mrCancel, nil);
    repeat
      I := D.ShowModal;
      if I <> mrOK then Exit;
      VisibleCount := 0;
      for C := 0 to D.List.Count - 1 do
        if D.List.Checked[C] and FAllowed[PtrInt(D.List.Items.Objects[C])] then Inc(VisibleCount);
      if VisibleCount = 0 then
        MessageDlg('Оставьте видимой хотя бы одну доступную колонку.', mtInformation, [mbOK], 0);
    until VisibleCount > 0;
    BeginUpdate;
    try
      if D.ResetWidths then ResetLayout;
      for I := 0 to D.List.Count - 1 do
      begin
        C := PtrInt(D.List.Items.Objects[I]);
        MoveField(C, I + FFirst);
        SetFieldVisible(C, D.List.Checked[I]);
      end;
      for I := FFirst to ColCount - 1 do
        if ReadWidth(FOrder[I]) > 0 then
        begin
          inherited Col := I;
          Break;
        end;
    finally
      EndUpdate;
    end;
    SaveLayout;
    if Assigned(FChanged) then FChanged(Self);
  finally
    D.Free;
  end;
end;

initialization
  RegisterClass(TLibraryGrid);
end.
