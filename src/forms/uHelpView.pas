unit uHelpView;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, ComCtrls, ExtCtrls, Graphics,
  uHelpContent;

type
  { Обычный LCL-контрол ссылки: доступен мышью, Tab, Enter и пробелом. }
  THelpLink = class(TCustomControl)
  protected
    procedure Paint; override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure DoEnter; override;
    procedure DoExit; override;
  public
    constructor Create(AOwner: TComponent); override;
  end;

  THelpView = class(TCustomPanel)
  private
    FNavigation: THelpNavigation;
    FToolbar, FSearchbar: TFlowPanel;
    FLeft: TPanel;
    FTree: TTreeView;
    FArticle, FResults: TScrollBox;
    FQuery: TEdit;
    FStatus: TLabel;
    FBack, FForward: TButton;
    FChanging, FLayoutBusy: Boolean;
    FNodes: array of TTreeNode;
    function AddButton(AParent: TWinControl; const ACaption: string;
      AClick: TNotifyEvent): TButton;
    procedure AddText(AParent: TScrollBox; const AText: string; AHeading: Boolean);
    procedure AddLink(AParent: TScrollBox; ATopic: Integer);
    procedure ClearPage(APage: TScrollBox);
    procedure LayoutPage(APage: TScrollBox);
    procedure ShowCurrent;
    procedure TreeChanged(Sender: TObject; Node: TTreeNode);
    procedure LinkClick(Sender: TObject);
    procedure OpenLinkAsync(AIndex: PtrInt);
    procedure BackClick(Sender: TObject);
    procedure ForwardClick(Sender: TObject);
    procedure HomeClick(Sender: TObject);
    procedure SearchClick(Sender: TObject);
    procedure ClearClick(Sender: TObject);
    procedure QueryKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure QueryChange(Sender: TObject);
    procedure PageResize(Sender: TObject);
    procedure ViewResize(Sender: TObject);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure ApplyFontSize(ASize: Integer);
    procedure FocusNavigation;
  end;

implementation

uses
  Math, LCLType, LCLIntf;

constructor THelpLink.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  TabStop := True;
  Cursor := crHandPoint;
  Font.Color := clHotLight;
  Font.Style := [fsUnderline];
end;

procedure THelpLink.Paint;
var
  R: TRect;
begin
  Canvas.Brush.Color := Color;
  Canvas.FillRect(ClientRect);
  Canvas.Font.Assign(Font);
  R := Rect(3, 3, ClientWidth - 3, ClientHeight - 3);
  DrawText(Canvas.Handle, PChar(Caption), Length(Caption), R,
    DT_WORDBREAK or DT_NOPREFIX);
  if Focused then Canvas.DrawFocusRect(ClientRect);
end;

procedure THelpLink.KeyDown(var Key: Word; Shift: TShiftState);
begin
  if (Shift = []) and ((Key = VK_RETURN) or (Key = VK_SPACE)) then
  begin
    Key := 0;
    Click;
    Exit;
  end;
  inherited KeyDown(Key, Shift);
end;

procedure THelpLink.DoEnter;
begin
  inherited DoEnter;
  if Parent is TScrollBox then TScrollBox(Parent).ScrollInView(Self);
  Invalidate;
end;

procedure THelpLink.DoExit;
begin
  inherited DoExit;
  Invalidate;
end;

function THelpView.AddButton(AParent: TWinControl; const ACaption: string;
  AClick: TNotifyEvent): TButton;
begin
  Result := TButton.Create(Self);
  Result.Parent := AParent;
  Result.Caption := ACaption;
  Result.AutoSize := True;
  Result.BorderSpacing.Around := 4;
  Result.OnClick := AClick;
end;

constructor THelpView.Create(AOwner: TComponent);
var
  I, ParentIndex: Integer;
  Splitter: TSplitter;
  Topic: THelpTopic;
  SearchLabel: TLabel;
begin
  inherited Create(AOwner);
  BevelOuter := bvNone;
  if AOwner is TWinControl then Parent := TWinControl(AOwner);
  FNavigation := THelpNavigation.Create;
  Align := alClient;
  FChanging := True;
  try
    FToolbar := TFlowPanel.Create(Self);
    FToolbar.Parent := Self;
    FToolbar.Align := alTop;
    FToolbar.BevelOuter := bvNone;
    FToolbar.AutoSize := True;
    FBack := AddButton(FToolbar, 'Назад', @BackClick);
    FForward := AddButton(FToolbar, 'Вперёд', @ForwardClick);
    AddButton(FToolbar, 'Содержание', @HomeClick);

    FSearchbar := TFlowPanel.Create(Self);
    FSearchbar.Parent := Self;
    FSearchbar.Top := FToolbar.Height + 1;
    FSearchbar.Align := alTop;
    FSearchbar.BevelOuter := bvNone;
    FSearchbar.AutoSize := True;
    SearchLabel := TLabel.Create(Self);
    SearchLabel.Parent := FSearchbar;
    SearchLabel.Caption := 'Поиск по справке:';
    SearchLabel.BorderSpacing.Around := 6;
    FQuery := TEdit.Create(Self);
    FQuery.Parent := FSearchbar;
    FQuery.Width := 240;
    FQuery.BorderSpacing.Around := 4;
    FQuery.TextHint := 'Слова из названия или текста';
    FQuery.OnKeyDown := @QueryKeyDown;
    FQuery.OnChange := @QueryChange;
    SearchLabel.FocusControl := FQuery;
    AddButton(FSearchbar, 'Найти', @SearchClick);
    AddButton(FSearchbar, 'Очистить', @ClearClick);

    FLeft := TPanel.Create(Self);
    FLeft.Parent := Self;
    FLeft.Align := alLeft;
    FLeft.Width := 290;
    FLeft.Constraints.MinWidth := 140;
    FLeft.BevelOuter := bvNone;
    FStatus := TLabel.Create(Self);
    FStatus.Parent := FLeft;
    FStatus.Align := alTop;
    FStatus.BorderSpacing.Around := 6;
    FStatus.WordWrap := True;
    FStatus.Caption := 'Содержание';
    FTree := TTreeView.Create(Self);
    FTree.Parent := FLeft;
    FTree.Align := alClient;
    FTree.ReadOnly := True;
    FTree.HideSelection := False;
    FTree.OnChange := @TreeChanged;
    FTree.ShowHint := True;
    FTree.Hint := 'Выберите раздел. Стрелки раскрывают и перемещают оглавление.';
    SetLength(FNodes, HelpTopicCount);
    for I := 0 to HelpTopicCount - 1 do
    begin
      Topic := HelpTopic(I);
      ParentIndex := FindHelpTopic(Topic.ParentID);
      if ParentIndex < 0 then
        FNodes[I] := FTree.Items.Add(nil, Topic.Title)
      else
        FNodes[I] := FTree.Items.AddChild(FNodes[ParentIndex], Topic.Title);
      FNodes[I].Data := Pointer(PtrUInt(I + 1));
    end;
    FResults := TScrollBox.Create(Self);
    FResults.Parent := FLeft;
    FResults.Align := alClient;
    FResults.HorzScrollBar.Visible := False;
    FResults.Visible := False;
    FResults.OnResize := @PageResize;

    Splitter := TSplitter.Create(Self);
    Splitter.Parent := Self;
    Splitter.Left := FLeft.Width;
    Splitter.Align := alLeft;
    Splitter.Width := 6;
    Splitter.MinSize := 140;
    FArticle := TScrollBox.Create(Self);
    FArticle.Parent := Self;
    FArticle.Align := alClient;
    FArticle.Color := clWindow;
    FArticle.ParentColor := False;
    FArticle.HorzScrollBar.Visible := False;
    FArticle.TabStop := True;
    FArticle.OnResize := @PageResize;
    OnResize := @ViewResize;
  finally
    FChanging := False;
  end;
  ShowCurrent;
end;

destructor THelpView.Destroy;
begin
  FChanging := True;
  Application.RemoveAsyncCalls(Self);
  FreeAndNil(FNavigation);
  inherited Destroy;
end;

procedure THelpView.AddText(AParent: TScrollBox; const AText: string;
  AHeading: Boolean);
var
  Paragraph: TLabel;
begin
  Paragraph := TLabel.Create(AParent);
  Paragraph.Parent := AParent;
  Paragraph.AutoSize := False;
  Paragraph.WordWrap := True;
  Paragraph.ShowAccelChar := False;
  Paragraph.Caption := AText;
  Paragraph.Font.Assign(Font);
  Paragraph.Font.Color := clWindowText;
  if AHeading then
  begin
    Paragraph.Font.Style := [fsBold];
    Paragraph.Font.Size := Font.Size + 2;
    Paragraph.Tag := 1;
  end;
end;

procedure THelpView.AddLink(AParent: TScrollBox; ATopic: Integer);
var
  Link: THelpLink;
begin
  if ATopic < 0 then Exit;
  Link := THelpLink.Create(AParent);
  Link.Parent := AParent;
  Link.Color := AParent.Color;
  Link.Font.Size := Font.Size;
  Link.Caption := HelpTopic(ATopic).Title;
  Link.AccessibleName := Link.Caption;
  Link.Tag := ATopic;
  Link.OnClick := @LinkClick;
end;

procedure THelpView.ClearPage(APage: TScrollBox);
begin
  if APage.ContainsControl(Screen.ActiveControl) and APage.CanFocus then
    APage.SetFocus;
  APage.VertScrollBar.Position := 0;
  while APage.ControlCount > 0 do APage.Controls[APage.ControlCount - 1].Free;
end;

procedure THelpView.LayoutPage(APage: TScrollBox);
var
  I, Y, W, OldPosition: Integer;
  R: TRect;
  C: TControl;
begin
  if FLayoutBusy or (APage = nil) or (csDestroying in ComponentState) then Exit;
  FLayoutBusy := True;
  try
    OldPosition := APage.VertScrollBar.Position;
    APage.DisableAlign;
    try
      APage.VertScrollBar.Position := 0;
      // Резерв под вертикальную полосу исключает колебания ширины при её появлении.
      W := Max(40, APage.Width - 48);
      Y := 12;
      for I := 0 to APage.ControlCount - 1 do
      begin
        C := APage.Controls[I];
        Canvas.Font.Assign(C.Font);
        R := Rect(0, 0, W - 6, 0);
        DrawText(Canvas.Handle, PChar(C.Caption), Length(C.Caption), R,
          DT_CALCRECT or DT_WORDBREAK or DT_NOPREFIX);
        C.SetBounds(12, Y, W, Max(Canvas.TextHeight('Ая'), R.Bottom) + 8);
        Inc(Y, C.Height + 10);
      end;
    finally
      APage.EnableAlign;
    end;
    APage.VertScrollBar.Range := Y;
    APage.VertScrollBar.Position := OldPosition;
  finally
    FLayoutBusy := False;
  end;
end;

procedure THelpView.ShowCurrent;
var
  Topic: THelpTopic;
  Parts, Links: TStringList;
  I: Integer;
  HasChildren: Boolean;
begin
  if FChanging or (FNavigation = nil) then Exit;
  Topic := HelpTopic(FNavigation.Current);
  FChanging := True;
  try
    ClearPage(FArticle);
    AddText(FArticle, Topic.Title, True);
    Parts := TStringList.Create;
    Links := TStringList.Create;
    try
      Parts.Text := Topic.Body;
      for I := 0 to Parts.Count - 1 do
        if Trim(Parts[I]) <> '' then AddText(FArticle, Parts[I], False);
      HasChildren := False;
      for I := 0 to HelpTopicCount - 1 do
        if HelpTopic(I).ParentID = Topic.ID then
        begin
          if not HasChildren then AddText(FArticle, 'В этом разделе', True);
          HasChildren := True;
          AddLink(FArticle, I);
        end;
      Links.Delimiter := '|';
      Links.StrictDelimiter := True;
      Links.DelimitedText := Topic.Links;
      if Links.Count > 0 then AddText(FArticle, 'См. также', True);
      for I := 0 to Links.Count - 1 do
        AddLink(FArticle, FindHelpTopic(Links[I]));
      if Topic.ParentID <> '' then
      begin
        AddText(FArticle, 'К разделу', True);
        AddLink(FArticle, FindHelpTopic(Topic.ParentID));
      end;
    finally
      Links.Free;
      Parts.Free;
    end;
    FTree.Selected := FNodes[FNavigation.Current];
    FTree.Selected.MakeVisible;
    FBack.Enabled := FNavigation.CanBack;
    FForward.Enabled := FNavigation.CanForward;
  finally
    FChanging := False;
  end;
  LayoutPage(FArticle);
end;

procedure THelpView.TreeChanged(Sender: TObject; Node: TTreeNode);
begin
  if FChanging or (Node = nil) then Exit;
  if FNavigation.OpenTopic(Integer(PtrUInt(Node.Data)) - 1) then ShowCurrent;
end;

procedure THelpView.LinkClick(Sender: TObject);
begin
  // Текст страницы содержит саму ссылку: пересоздаём его после окончания
  // обработки мыши/клавиатуры, чтобы не уничтожить отправителя события в стеке LCL.
  Application.QueueAsyncCall(@OpenLinkAsync, TControl(Sender).Tag);
end;

procedure THelpView.OpenLinkAsync(AIndex: PtrInt);
begin
  if FNavigation.OpenTopic(AIndex) then ShowCurrent;
end;

procedure THelpView.BackClick(Sender: TObject);
begin
  if FNavigation.Back then ShowCurrent;
end;

procedure THelpView.ForwardClick(Sender: TObject);
begin
  if FNavigation.Forward then ShowCurrent;
end;

procedure THelpView.HomeClick(Sender: TObject);
begin
  ClearClick(nil);
  FNavigation.OpenTopic(FindHelpTopic('start'));
  ShowCurrent;
  FocusNavigation;
end;

procedure THelpView.SearchClick(Sender: TObject);
var
  Hits: THelpSearchHits;
  I: Integer;
begin
  if Trim(FQuery.Text) = '' then
  begin
    ClearClick(nil);
    Exit;
  end;
  Hits := SearchHelp(FQuery.Text);
  ClearPage(FResults);
  FTree.Visible := False;
  FResults.Visible := True;
  FStatus.Caption := Format('Найдено разделов: %d', [Length(Hits)]);
  if Length(Hits) = 0 then
    AddText(FResults, 'Ничего не найдено. Попробуйте другие слова или очистите поиск.', False);
  for I := 0 to High(Hits) do
  begin
    AddLink(FResults, Hits[I].TopicIndex);
    AddText(FResults, Hits[I].Snippet, False);
  end;
  LayoutPage(FResults);
end;

procedure THelpView.ClearClick(Sender: TObject);
begin
  FQuery.Text := '';
  FResults.Visible := False;
  FTree.Visible := True;
  FStatus.Caption := 'Содержание';
end;

procedure THelpView.QueryKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if (Key = VK_RETURN) and (Shift = []) then
  begin
    Key := 0;
    SearchClick(nil);
  end;
end;

procedure THelpView.QueryChange(Sender: TObject);
begin
  if Trim(FQuery.Text) = '' then ClearClick(nil);
end;

procedure THelpView.PageResize(Sender: TObject);
begin
  if not FChanging then LayoutPage(TScrollBox(Sender));
end;

procedure THelpView.ViewResize(Sender: TObject);
begin
  if FChanging or (FLeft = nil) then Exit;
  FLeft.Constraints.MaxWidth := Max(140, ClientWidth div 2);
  LayoutPage(FArticle);
  LayoutPage(FResults);
end;

procedure THelpView.ApplyFontSize(ASize: Integer);
var
  I, J: Integer;
  Page: TScrollBox;
  C: TControl;
begin
  Font.Size := ASize;
  for J := 0 to 1 do
  begin
    if J = 0 then Page := FArticle else Page := FResults;
    for I := 0 to Page.ControlCount - 1 do
    begin
      C := Page.Controls[I];
      C.Font.Size := ASize;
      if (C is TLabel) and (C.Tag = 1) then C.Font.Size := ASize + 2;
    end;
    LayoutPage(Page);
  end;
end;

procedure THelpView.FocusNavigation;
begin
  if FTree.Visible and FTree.CanFocus then FTree.SetFocus
  else if FQuery.CanFocus then FQuery.SetFocus;
end;

end.
