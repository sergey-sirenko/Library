unit uBookLookupDialogs;

{$mode objfpc}{$H+}

interface

uses uOpenLibrary;

type
  TBookFieldChange = record
    Name, OldValue, NewValue: string;
    Apply: Boolean;
  end;
  TBookFieldChanges = array of TBookFieldChange;

function SelectISBNBook(const Items: TBookCandidates; FontSize: Integer): Integer;
function ReviewISBNBook(const Data: TOpenLibraryBookData; const Warning: string;
  var Fields: TBookFieldChanges; FontSize: Integer): Boolean;

implementation

uses Classes, SysUtils, Forms, Controls, StdCtrls, ExtCtrls, CheckLst,
  LCLIntf, uUIFont;

type
  TLookupReview = class
    Form: TForm;
    List: TCustomListBox;
    Memo: TMemo;
    Details, URLs: TStringList;
    OpenButton, OKButton: TButton;
    constructor Create(const Title: string; FontSize: Integer; Checks: Boolean);
    destructor Destroy; override;
    procedure Changed(Sender: TObject);
    procedure SelectionChanged(Sender: TObject; User: Boolean);
    procedure OpenSource(Sender: TObject);
  end;

constructor TLookupReview.Create(const Title: string; FontSize: Integer; Checks: Boolean);
var Panel: TPanel; Cancel: TButton;
begin
  inherited Create;
  Details := TStringList.Create;
  URLs := TStringList.Create;
  Form := TForm.Create(nil);
  ApplyFormUIFont(Form, FontSize);
  Form.Caption := Title;
  Form.Position := poScreenCenter;
  Form.ClientWidth := 780;
  Form.ClientHeight := 540;
  Form.Constraints.MinWidth := 600;
  Form.Constraints.MinHeight := 420;
  Panel := TPanel.Create(Form);
  Panel.Parent := Form;
  Panel.Align := alBottom;
  Panel.Height := 52;
  Panel.BevelOuter := bvNone;
  OpenButton := TButton.Create(Form);
  OpenButton.Parent := Panel;
  OpenButton.SetBounds(12, 10, 210, 32);
  OpenButton.Caption := 'Открыть источник';
  OpenButton.OnClick := @OpenSource;
  OKButton := TButton.Create(Form);
  OKButton.Parent := Panel;
  OKButton.SetBounds(Panel.Width - 280, 10, 130, 32);
  OKButton.Anchors := [akRight, akTop];
  OKButton.Caption := 'Выбрать';
  OKButton.ModalResult := mrOK;
  OKButton.Default := True;
  Cancel := TButton.Create(Form);
  Cancel.Parent := Panel;
  Cancel.SetBounds(Panel.Width - 140, 10, 130, 32);
  Cancel.Anchors := [akRight, akTop];
  Cancel.Caption := 'Отмена';
  Cancel.ModalResult := mrCancel;
  Cancel.Cancel := True;
  if Checks then List := TCheckListBox.Create(Form)
  else List := TListBox.Create(Form);
  List.Parent := Form;
  List.Align := alTop;
  List.Height := 190;
  List.OnClick := @Changed;
  List.OnSelectionChange := @SelectionChanged;
  Memo := TMemo.Create(Form);
  Memo.Parent := Form;
  Memo.Align := alClient;
  Memo.ReadOnly := True;
  Memo.ScrollBars := ssAutoVertical;
end;

destructor TLookupReview.Destroy;
begin
  Form.Free;
  URLs.Free;
  Details.Free;
  inherited Destroy;
end;

procedure TLookupReview.Changed(Sender: TObject);
var I: Integer;
begin
  I := List.ItemIndex;
  if (I >= 0) and (I < Details.Count) then Memo.Text := Details[I];
  OpenButton.Enabled := (I >= 0) and (I < URLs.Count) and
    (Pos('https://', URLs[I]) = 1);
  OKButton.Enabled := I >= 0;
end;

procedure TLookupReview.SelectionChanged(Sender: TObject; User: Boolean);
begin
  Changed(Sender);
end;

procedure TLookupReview.OpenSource(Sender: TObject);
begin
  if OpenButton.Enabled then OpenURL(URLs[List.ItemIndex]);
end;

function SelectISBNBook(const Items: TBookCandidates; FontSize: Integer): Integer;
var D: TLookupReview; I: Integer; YearText: string;
begin
  Result := -1;
  D := TLookupReview.Create('Найдено несколько книг — выберите запись', FontSize, False);
  try
    for I := 0 to High(Items) do
    begin
      YearText := '';
      if Items[I].Year > 0 then YearText := IntToStr(Items[I].Year);
      D.List.Items.Add(Items[I].Title + ' — ' + Items[I].Authors + ' — ' + YearText);
      D.Details.Add(Items[I].Title + LineEnding + Items[I].Authors + LineEnding +
        Items[I].Publisher + ', ' + YearText + LineEnding +
        'ISBN: ' + Items[I].NormalizedISBN + LineEnding +
        Items[I].SourceURL + LineEnding + Items[I].Warnings);
      D.URLs.Add(Items[I].SourceURL);
    end;
    D.List.ItemIndex := 0;
    D.Changed(nil);
    if D.Form.ShowModal = mrOK then Result := D.List.ItemIndex;
  finally
    D.Free;
  end;
end;

function ReviewISBNBook(const Data: TOpenLibraryBookData; const Warning: string;
  var Fields: TBookFieldChanges; FontSize: Integer): Boolean;
var D: TLookupReview; I, J: Integer; Checks: TCheckListBox;
begin
  Result := False;
  D := TLookupReview.Create('Заполнение книги — отметьте поля для применения', FontSize, True);
  try
    Checks := TCheckListBox(D.List);
    D.OKButton.Caption := 'Применить';
    for I := 0 to High(Fields) do
    begin
      Fields[I].Apply := False;
      if (Fields[I].NewValue = '') or (Fields[I].NewValue = Fields[I].OldValue) then Continue;
      J := Checks.Items.AddObject(Fields[I].Name, TObject(PtrInt(I)));
      Checks.Checked[J] := Fields[I].OldValue = '';
      D.Details.Add('Источник: ' + BookSourceName(Data) + LineEnding + Data.SourceURL +
        LineEnding + LineEnding + Fields[I].Name + LineEnding +
        'Сейчас: ' + Fields[I].OldValue + LineEnding + LineEnding +
        'Получено: ' + Fields[I].NewValue + LineEnding + LineEnding + Warning);
      D.URLs.Add(Data.SourceURL);
    end;
    if Checks.Count = 0 then
    begin
      Checks.Items.AddObject('Новых значений нет', TObject(PtrInt(-1)));
      Checks.ItemEnabled[0] := False;
      D.Details.Add('Источник: ' + BookSourceName(Data) + LineEnding + Data.SourceURL +
        LineEnding + Warning);
      D.URLs.Add(Data.SourceURL);
    end;
    Checks.ItemIndex := 0;
    D.Changed(nil);
    if D.Form.ShowModal <> mrOK then Exit;
    for J := 0 to Checks.Count - 1 do
    begin
      I := PtrInt(Checks.Items.Objects[J]);
      if I >= 0 then Fields[I].Apply := Checks.Checked[J];
    end;
    Result := True;
  finally
    D.Free;
  end;
end;

end.
