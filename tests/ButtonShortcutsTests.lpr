program ButtonShortcutsTests;

{$mode objfpc}{$H+}

uses
  Interfaces, Forms, Classes, SysUtils, Controls, StdCtrls, ExtCtrls,
  ComCtrls, Grids, LCLType, uButtonShortcuts;

var
  Checks: Integer;

procedure Check(Value: Boolean; const MessageText: string);
begin
  Inc(Checks);
  if not Value then raise Exception.Create(MessageText);
end;

function Button(AParent: TWinControl; const ACaption: string): TButton;
begin
  Result := TButton.Create(AParent);
  Result.Parent := AParent;
  Result.Caption := ACaption;
end;

procedure TestRouting;
var
  F: TForm;
  Pages: TPageControl;
  Books, Readers, Reports: TTabSheet;
  Copies: TPanel;
  BookAdd, CopyAdd, ReaderAdd, DeleteButton, SaveButton, GenerateButton,
    CancelButton, FillButton, EditButton, FindBook, FindReader: TButton;
  ISBN, ReaderSearch: TEdit;
  Memo: TMemo;
  Combo: TComboBox;
  Grid: TStringGrid;
  Router: TButtonShortcuts;
begin
  F := TForm.CreateNew(nil);
  try
    Pages := TPageControl.Create(F);
    Pages.Parent := F;
    Books := TTabSheet.Create(F);
    Books.PageControl := Pages;
    Readers := TTabSheet.Create(F);
    Readers.PageControl := Pages;
    Reports := TTabSheet.Create(F);
    Reports.PageControl := Pages;
    Pages.ActivePage := Books;
    Copies := TPanel.Create(F);
    Copies.Parent := Books;
    BookAdd := Button(Books, 'Добавить');
    CopyAdd := Button(Copies, 'Добавить экз.');
    ReaderAdd := Button(Readers, 'Добавить');
    DeleteButton := Button(Books, 'Удалить');
    EditButton := Button(Books, 'Изменить');
    SaveButton := Button(Readers, 'Сохранить');
    GenerateButton := Button(Reports, 'Сформировать');
    CancelButton := Button(F, 'Отмена');
    FillButton := Button(Books, 'Заполнить');
    FindBook := Button(Books, 'Найти');
    FindReader := Button(Books, 'Найти');
    ISBN := TEdit.Create(F);
    ISBN.Parent := Books;
    ReaderSearch := TEdit.Create(F);
    ReaderSearch.Parent := Books;
    Memo := TMemo.Create(F);
    Memo.Parent := Books;
    Combo := TComboBox.Create(F);
    Combo.Parent := Books;
    Grid := TStringGrid.Create(F);
    Grid.Parent := Copies;
    Router := TButtonShortcuts.ForForm(F);
    Router.Bind(BookAdd, bsAdd, []);
    Router.Bind(CopyAdd, bsAdd, [Copies]);
    Router.Bind(ReaderAdd, bsAdd, []);
    Router.Bind(DeleteButton, bsDelete, []);
    Router.Bind(EditButton, bsEdit, []);
    Router.Bind(SaveButton, bsSave, []);
    Router.Bind(GenerateButton, bsGenerate, []);
    Router.Bind(CancelButton, bsCancel, []);
    Router.Bind(FillButton, bsFill, []);
    Router.Bind(FindReader, bsFind, []);
    Router.Bind(FindBook, bsFind, [ISBN, FindBook]);

    Check(BookAdd.Caption = 'Добавить (Ins)', 'Подпись Ins');
    Check(CopyAdd.Caption = 'Добавить экз. (Ins)', 'Подпись экземпляра');
    Check(DeleteButton.Caption = 'Удалить (Del)', 'Подпись Del');
    Check(EditButton.Caption = 'Изменить (F2)', 'Подпись F2');
    Check(SaveButton.Caption = 'Сохранить (Ctrl+Enter)', 'Подпись сохранения');
    Check(GenerateButton.Caption = 'Сформировать (Ctrl+Enter)', 'Подпись отчёта');
    Check(CancelButton.Caption = 'Отмена (Esc)', 'Подпись Esc');
    Check(FillButton.Caption = 'Заполнить (F4)', 'Подпись F4');
    Check(FindBook.Caption = 'Найти (F3)', 'Подпись F3');
    Check(Router.ResolveButton(BookAdd, VK_INSERT, []) = BookAdd, 'Книги');
    Check(Router.ResolveButton(Grid, VK_INSERT, []) = CopyAdd, 'Экземпляры');
    Check(Router.ResolveButton(CopyAdd, VK_INSERT, []) = CopyAdd, 'Панель экземпляров');
    CopyAdd.Enabled := False;
    Check(Router.ResolveButton(Grid, VK_INSERT, []) = nil, 'Нет перехода к книгам');
    CopyAdd.Enabled := True;
    Copies.Enabled := False;
    Check(Router.ResolveButton(Grid, VK_INSERT, []) = nil, 'Недоступный родитель');
    Copies.Enabled := True;
    BookAdd.Visible := False;
    Check(Router.ResolveButton(Books, VK_INSERT, []) = nil, 'Скрытая кнопка');
    BookAdd.Visible := True;
    Check(Router.ResolveButton(ISBN, VK_DELETE, []) = nil, 'Del в тексте');
    Check(Router.ResolveButton(Memo, VK_DELETE, []) = nil, 'Del в заметках');
    Check(Router.ResolveButton(Combo, VK_DELETE, []) = nil, 'Del в комбинированном поле');
    Check(Router.ResolveButton(Grid, VK_DELETE, []) = DeleteButton, 'Del в таблице');
    Check(Router.ResolveButton(Grid, VK_DELETE, [ssCtrl]) = nil, 'Точные модификаторы');
    Check(Router.ResolveButton(ISBN, VK_F3, []) = FindBook, 'Поиск экземпляра');
    Check(Router.ResolveButton(FindBook, VK_F3, []) = FindBook, 'Кнопка поиска экземпляра');
    Check(Router.ResolveButton(ReaderSearch, VK_F3, []) = FindReader, 'Поиск читателя');
    Check(Router.ResolveButton(Grid, VK_F3, []) = FindReader, 'Поиск по умолчанию');
    Check(Router.ResolveButton(ISBN, VK_F4, []) = FillButton, 'Заполнение');
    Check(Router.ResolveButton(Grid, VK_F2, []) = EditButton, 'Изменение');
    Check(Router.ResolveButton(Grid, VK_ESCAPE, []) = CancelButton, 'Отмена');
    Check(Router.ResolveButton(Grid, VK_RETURN, []) = nil, 'Обычный Enter сохранён');
    Check(Router.ResolveButton(Grid, VK_RETURN, [ssCtrl]) = nil, 'Скрытое сохранение');
    Pages.ActivePage := Readers;
    Check(Router.ResolveButton(Readers, VK_INSERT, []) = ReaderAdd, 'Другая вкладка');
    Check(Router.ResolveButton(Readers, VK_RETURN, [ssCtrl]) = SaveButton, 'Сохранение');
    Pages.ActivePage := Reports;
    Check(Router.ResolveButton(Reports, VK_RETURN, [ssCtrl]) = GenerateButton, 'Формирование');
    Check(Router.ResolveButton(Reports, VK_RETURN, [ssCtrl, ssShift]) = nil, 'Ctrl+Shift не совпадает');
    GenerateButton.Free;
    Check(Router.ResolveButton(Reports, VK_RETURN, [ssCtrl]) = nil, 'Удалённая кнопка');
  finally
    F.Free;
  end;
end;

begin
  Application.Initialize;
  try
    TestRouting;
    WriteLn('OK: ', Checks, ' checks');
  except
    on E: Exception do
    begin
      WriteLn('FAIL: ', E.Message);
      Halt(1);
    end;
  end;
end.
