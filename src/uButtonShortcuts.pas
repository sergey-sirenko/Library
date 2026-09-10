unit uButtonShortcuts;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls;

type
  TButtonShortcut = (bsAdd, bsEdit, bsDelete, bsFind, bsSave, bsCancel,
    bsFill, bsGenerate);

  TButtonShortcuts = class(TComponent)
  private
    type
      TBinding = record
        Button: TCustomButton;
        Shortcut: TButtonShortcut;
        FocusScopes: array of TControl;
      end;
    var
      FForm: TCustomForm;
      FBindings: array of TBinding;
      FExecuting: Boolean;
    procedure KeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
  protected
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    class function ForForm(AForm: TCustomForm): TButtonShortcuts;
    procedure Bind(AButton: TCustomButton; AShortcut: TButtonShortcut;
      const AFocusScopes: array of TControl);
    function ResolveButton(AFocus: TControl; Key: Word;
      Shift: TShiftState): TCustomButton;
  end;

procedure BindButtonShortcut(AButton: TCustomButton; AShortcut: TButtonShortcut);

implementation

uses
  Math, Buttons, ComCtrls, Grids, LCLType;

type
  TButtonAccess = class(TCustomButton);

const
  SHORTCUT_LABELS: array[TButtonShortcut] of string =
    ('Ins', 'F2', 'Del', 'F3', 'Ctrl+Enter', 'Esc', 'F4', 'Ctrl+Enter');
  SHORTCUT_KEYS: array[TButtonShortcut] of Word =
    (VK_INSERT, VK_F2, VK_DELETE, VK_F3, VK_RETURN, VK_ESCAPE, VK_F4, VK_RETURN);

function WithinControl(AControl, ARoot: TControl): Boolean;
begin
  while AControl <> nil do
  begin
    if AControl = ARoot then Exit(True);
    AControl := AControl.Parent;
  end;
  Result := False;
end;

function AvailablePage(AControl: TControl; AForm: TCustomForm): Boolean;
begin
  while (AControl <> nil) and (AControl <> AForm) do
  begin
    if not AControl.Visible then Exit(False);
    if AControl is TTabSheet then
      if (TTabSheet(AControl).PageControl = nil) or
        (TTabSheet(AControl).PageControl.ActivePage <> AControl) then Exit(False);
    AControl := AControl.Parent;
  end;
  Result := AControl = AForm;
end;

constructor TButtonShortcuts.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FForm := AOwner as TCustomForm;
  Application.AddOnKeyDownBeforeHandler(@KeyDown);
end;

destructor TButtonShortcuts.Destroy;
begin
  Application.RemoveOnKeyDownBeforeHandler(@KeyDown);
  inherited Destroy;
end;

class function TButtonShortcuts.ForForm(AForm: TCustomForm): TButtonShortcuts;
var
  I: Integer;
begin
  for I := 0 to AForm.ComponentCount - 1 do
    if AForm.Components[I] is TButtonShortcuts then
      Exit(TButtonShortcuts(AForm.Components[I]));
  Result := TButtonShortcuts.Create(AForm);
end;

procedure TButtonShortcuts.Bind(AButton: TCustomButton;
  AShortcut: TButtonShortcut; const AFocusScopes: array of TControl);
var
  I, N, W: Integer;
  Suffix: string;
begin
  N := Length(FBindings);
  SetLength(FBindings, N + 1);
  FBindings[N].Button := AButton;
  FBindings[N].Shortcut := AShortcut;
  SetLength(FBindings[N].FocusScopes, Length(AFocusScopes));
  for I := 0 to High(AFocusScopes) do
  begin
    FBindings[N].FocusScopes[I] := AFocusScopes[I];
    AFocusScopes[I].FreeNotification(Self);
  end;
  AButton.FreeNotification(Self);
  Suffix := ' (' + SHORTCUT_LABELS[AShortcut] + ')';
  with TButtonAccess(AButton) do
  begin
    if Copy(Caption, Length(Caption) - Length(Suffix) + 1, Length(Suffix)) <> Suffix then
      Caption := Caption + Suffix;
    FForm.Canvas.Font.Assign(Font);
    W := FForm.Canvas.TextWidth(Caption) + 28;
    if AButton is TBitBtn then
      if not TBitBtn(AButton).Glyph.Empty then
        Inc(W, TBitBtn(AButton).Glyph.Width + TBitBtn(AButton).Spacing);
    Width := Max(Width, W);
    Height := Max(Height, FForm.Canvas.TextHeight('Ag') + 12);
  end;
  FForm.Canvas.Font.Assign(FForm.Font);
end;

procedure TButtonShortcuts.Notification(AComponent: TComponent;
  Operation: TOperation);
var
  I, J: Integer;
begin
  inherited Notification(AComponent, Operation);
  if Operation <> opRemove then Exit;
  for I := 0 to High(FBindings) do
  begin
    if FBindings[I].Button = AComponent then FBindings[I].Button := nil;
    for J := 0 to High(FBindings[I].FocusScopes) do
      if FBindings[I].FocusScopes[J] = AComponent then
        FBindings[I].FocusScopes[J] := nil;
  end;
end;

function TButtonShortcuts.ResolveButton(AFocus: TControl; Key: Word;
  Shift: TShiftState): TCustomButton;
var
  I, J, Score, BestScore: Integer;
  ExpectedShift: TShiftState;
  C: TControl;
begin
  Result := nil;
  { Не отбираем удаление текста и закрытие выпадающего списка. }
  C := AFocus;
  while C <> nil do
  begin
    if (Key = VK_DELETE) and ((C is TCustomEdit) or
      (C is TCustomComboBox) or
      ((C is TStringGrid) and TStringGrid(C).EditorMode)) then Exit;
    if (Key = VK_ESCAPE) and (C is TCustomComboBox) then
      if TCustomComboBox(C).DroppedDown then Exit;
    C := C.Parent;
  end;
  BestScore := -1;
  for I := 0 to High(FBindings) do
  begin
    if (FBindings[I].Button = nil) or
      (SHORTCUT_KEYS[FBindings[I].Shortcut] <> Key) then Continue;
    ExpectedShift := [];
    if FBindings[I].Shortcut in [bsSave, bsGenerate] then ExpectedShift := [ssCtrl];
    if Shift <> ExpectedShift then Continue;
    if not AvailablePage(FBindings[I].Button, FForm) then Continue;
    Score := 0;
    if Length(FBindings[I].FocusScopes) > 0 then
    begin
      Score := -1;
      for J := 0 to High(FBindings[I].FocusScopes) do
        if (FBindings[I].FocusScopes[J] <> nil) and
          WithinControl(AFocus, FBindings[I].FocusScopes[J]) then Score := 1;
    end;
    if Score > BestScore then
    begin
      BestScore := Score;
      Result := FBindings[I].Button;
    end;
  end;
  { Недоступная контекстная кнопка не должна запускать действие другого списка. }
  if (Result <> nil) and not Result.IsEnabled then Result := nil;
end;

procedure TButtonShortcuts.KeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
var
  Button: TCustomButton;
begin
  if FExecuting or (Key = 0) or (Screen.ActiveCustomForm <> FForm) or
    not FForm.Enabled or not FForm.Visible then Exit;
  if not (Sender is TControl) then Exit;
  if GetParentForm(TControl(Sender)) <> FForm then Exit;
  Button := ResolveButton(TControl(Sender), Key, Shift);
  if Button = nil then Exit;
  Key := 0;
  FExecuting := True;
  try
    Button.Click;
  finally
    FExecuting := False;
  end;
end;

procedure BindButtonShortcut(AButton: TCustomButton; AShortcut: TButtonShortcut);
begin
  TButtonShortcuts.ForForm(GetParentForm(AButton)).Bind(AButton, AShortcut, []);
end;

end.
