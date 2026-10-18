program BooksSelectionTests;

{$mode objfpc}{$H+}

uses Interfaces, Forms, Classes, SysUtils, Controls, FileUtil,
  uMainForm, uDatabase, uEntities, uTypes, uBookSearch, uBookSearchHistory,
  uGridSorting;

var Checks: Integer;

procedure Check(Value: Boolean; const Msg: string);
begin
  Inc(Checks);
  if not Value then raise Exception.Create(Msg);
end;

procedure AddBook(DB: TLibraryDB; ID: TId; const Title: string);
var B: TBook;
begin
  B := TBook.Create;
  B.ID := ID;
  B.Title := Title;
  DB.Books.Add(B);
end;

procedure AddCopy(DB: TLibraryDB; ID, BookID: TId; Deleted: Boolean = False);
var C: TCopy;
begin
  C := TCopy.Create;
  C.ID := ID;
  C.BookID := BookID;
  C.InventoryNo := IntToStr(ID);
  C.Deleted := Deleted;
  DB.Copies.Add(C);
end;

procedure CheckCopies(F: TMainForm; BookID: TId; Expected: Integer);
var I, Count: Integer; C: TCopy;
begin
  Count := 0;
  for I := 1 to F.gridCopies.RowCount - 1 do
  begin
    C := TCopy(F.gridCopies.Objects[0, I]);
    if C = nil then Continue;
    Inc(Count);
    Check(C.BookID = BookID, 'экземпляр принадлежит выбранной книге');
  end;
  Check(Count = Expected, 'нижний список обновлён для книги ' + IntToStr(BookID));
end;

procedure CheckToolbar(F: TMainForm);
var Controls: array[0..7] of TControl; I: Integer;
begin
  Controls[0] := F.edtBookSearch;
  Controls[1] := F.edtBookSearchInv;
  Controls[2] := F.btnBookSearchClear;
  Controls[3] := F.btnBookAdd;
  Controls[4] := F.btnBookActions;
  Controls[5] := F.chkShowDeleted;
  Controls[6] := F.edtBookInformation;
  Controls[7] := F.btnBookSearch;
  for I := 1 to High(Controls) do
    Check((Controls[I].Top > Controls[I-1].Top + 4) or
      ((Abs(Controls[I].Top - Controls[I-1].Top) <= 4) and
       (Controls[I].Left > Controls[I-1].Left)), 'порядок элементов панели ' + IntToStr(I));
end;

procedure TestSelection(const Root: string);
var DB: TLibraryDB; F: TMainForm; Entry: TBookSearchHistoryEntry;
  Err: string; I, HistoryIndex, SavedWidth: Integer; CloseAction: TCloseAction;
  B: TBook;
begin
  DB := TLibraryDB.Create(Root);
  F := nil;
  Entry := TBookSearchHistoryEntry.Create;
  try
    Check(DB.Open(Err), 'создание отдельной временной базы: ' + Err);
    Check(DB.Login(DEFAULT_ADMIN_LOGIN, DEFAULT_ADMIN_PASSWORD, Err), 'вход в искусственную базу');
    DB.Settings.AutoBackupEnabled := False;
    AddBook(DB, 1, 'Альфа');
    AddBook(DB, 2, 'Бета');
    AddBook(DB, 3, 'Гамма');
    AddCopy(DB, 11, 1);
    AddCopy(DB, 12, 1);
    AddCopy(DB, 21, 2);
    AddCopy(DB, 22, 2, True);
    F := TMainForm.Create(nil);
    F.DB := DB;
    // Инициализация без Show/ShowModal, сетевых обращений и имитации ввода.
    F.FormShow(nil);
    Check(not F.Visible, 'форма не показывается при проверке');
    Entry.Query := 'Искусственная тема';
    Entry.Model := 'test/model';
    Entry.CreatedAt := Now;
    Entry.Fingerprint := CurrentBookSearchFingerprint(DB, '', '', False);
    Entry.Response.Status := 'ok';
    SetLength(Entry.Response.Matches, 3);
    Entry.Response.Matches[0].BookID := 2;
    Entry.Response.Matches[1].BookID := 1;
    Entry.Response.Matches[2].BookID := 3;
    for I := 0 to 2 do
    begin
      Entry.Response.Matches[I].Relevance := 'high';
      Entry.Response.Matches[I].Reason := 'Причина ' + IntToStr(Entry.Response.Matches[I].BookID);
      Entry.Response.Matches[I].Location := 'место не установлено';
    end;
    HistoryIndex := F.edtBookInformation.Items.AddObject(Entry.Caption, Entry);
    F.edtBookInformation.ItemIndex := HistoryIndex;
    F.HistoryComboSelect(nil);
    Check(F.gridBooks.ColCount = 12, 'состав колонок подборки сохранён');
    Check(TBook(F.gridBooks.Objects[0, 1]).ID = 2, 'порядок модели сохранён');
    CheckCopies(F, 2, 1);
    F.gridBooks.Row := 2;
    CheckCopies(F, 1, 2);
    F.gridBooks.Row := 3;
    CheckCopies(F, 3, 0);
    F.gridBooks.Row := 1;
    F.chkShowDeletedCopies.Checked := True;
    CheckCopies(F, 2, 2);
    F.chkShowDeletedCopies.Checked := False;
    CheckCopies(F, 2, 1);
    GridSorting(F.gridBooks).ClickColumn(2);
    F.gridBooks.Row := 1;
    CheckCopies(F, 1, 2);
    F.gridBooks.Row := 2;
    CheckCopies(F, 2, 1);
    for I := 1 to 3 do
    begin
      B := TBook(F.gridBooks.Objects[0, I]);
      Check(F.gridBooks.Cells[9, I] = 'Причина ' + IntToStr(B.ID), 'обоснование связано с книгой после сортировки');
      if B.ID = 2 then Check(F.gridBooks.Cells[1, I] = '1', 'исходный ранг сохранён');
    end;
    F.edtBookInformation.Text := '';
    F.edtBookSearchChange(nil);
    Check(F.gridBooks.ColCount = 8, 'состав колонок обычного каталога сохранён');
    F.gridBooks.Row := 2;
    CheckCopies(F, 2, 1);
    F.gridBooks.Row := 1;
    CheckCopies(F, 1, 2);
    F.edtBookInformation.ItemIndex := HistoryIndex;
    F.HistoryComboSelect(nil);
    F.gridBooks.Row := 2;
    CheckCopies(F, 1, 2);
    F.gridBooks.Row := 3;
    CheckCopies(F, 3, 0);
    Check(F.edtBookInformation.Items.Count = 1, 'история сохранена после переключений');
    Check(F.edtBookSearch.TabOrder < F.edtBookSearchInv.TabOrder, 'начало порядка Tab');
    Check((F.edtBookSearchInv.TabOrder < F.btnBookAdd.TabOrder) and
      (F.btnBookAdd.TabOrder < F.btnBookActions.TabOrder) and
      (F.btnBookActions.TabOrder < F.chkShowDeleted.TabOrder) and
      (F.chkShowDeleted.TabOrder < F.edtBookInformation.TabOrder) and
      (F.edtBookInformation.TabOrder < F.btnBookSearch.TabOrder), 'Tab соответствует новому порядку панели');
    SavedWidth := F.edtBookInformation.Width;
    F.pnlBooksTop.Width := 1600;
    CheckToolbar(F);
    F.pnlBooksTop.Width := 650;
    CheckToolbar(F);
    F.pnlBooksTop.Width := 1600;
    CheckToolbar(F);
    Check(F.edtBookInformation.Width = SavedWidth, 'ширина поиска по содержанию сохранена');
  finally
    if F <> nil then
    begin
      F.edtBookInformation.Items.Clear;
      CloseAction := caNone;
      F.FormClose(nil, CloseAction);
      F.OnClose := nil;
      F.Free;
    end;
    Entry.Free;
    DB.Free;
  end;
end;

var Root: string; Failed: Boolean;
begin
  Application.Initialize;
  RequireDerivedFormResource := True;
  Root := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'LibraryBooksSelectionTests-' + IntToStr(GetTickCount64) + PathDelim;
  ForceDirectories(Root);
  try
    try
      TestSelection(Root);
      WriteLn('OK: ', Checks, ' checks');
    except
      on E: Exception do
      begin
        WriteLn('FAIL: ', E.ClassName, ': ', E.Message);
        Failed := True;
      end;
    end;
  finally
    if Pos(IncludeTrailingPathDelimiter(GetTempDir(False)) + 'LibraryBooksSelectionTests-',
      ExpandFileName(Root)) = 1 then DeleteDirectory(Root, False);
  end;
  if Failed then Halt(1);
end.
