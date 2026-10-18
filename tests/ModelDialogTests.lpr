program ModelDialogTests;

{$mode objfpc}{$H+}

uses Interfaces, Forms, Classes, SysUtils, Controls, StdCtrls, Buttons, LCLType, LMessages, Windows,
  uLibraryGrid, uOpenRouterModels, uSelectModelForm, uTwoLineCombo;

var Checks: Integer;

procedure Check(Value: Boolean; const Msg: string);
begin
  Inc(Checks);
  if not Value then raise Exception.Create(Msg);
end;

procedure TestDialog;
var F: TForm; Models: TModelInfoArray; Favorites: TStringList;
  Grid: TLibraryGrid; OK: TBitBtn; Filter: TEdit; I: Integer;
begin
  Favorites := TStringList.Create;
  try
    Favorites.Add('test/b');
    SetLength(Models, 2);
    Models[0].Id := 'test/a';
    Models[0].PromptPrice := 2;
    Models[1].Id := 'test/b';
    Models[1].PromptPrice := 10;
    // Создание/наполнение без Show/ShowModal, сети, данных и действий пользователя.
    F := CreateModelSelectionForm(Models, 'test/b', Favorites);
    try
      Check(not F.Visible, 'заполненная форма не показывается при создании');
      Grid := nil;
      OK := nil;
      Filter := nil;
      for I := 0 to F.ComponentCount - 1 do
      begin
        if F.Components[I] is TLibraryGrid then Grid := TLibraryGrid(F.Components[I]);
        if (F.Components[I] is TBitBtn) and
          (TBitBtn(F.Components[I]).ModalResult = mrOK) then OK := TBitBtn(F.Components[I]);
        if F.Components[I] is TEdit then Filter := TEdit(F.Components[I]);
      end;
      Check((Grid <> nil) and (OK <> nil) and (Filter <> nil), 'таблица и обе зависимости созданы');
      Check(Grid.RowCount = 3, 'модели загружены без события показа');
      Check(Grid.Cells[1, Grid.Row] = 'test/b', 'текущая модель выделена');
      Check(Grid.Cells[0, Grid.Row] = '☑', 'избранное восстановлено');
      Check(OK.Enabled, 'готово доступно для выбранной модели');
      Check(Favorites.Count = 1, 'исходное избранное не изменяется');
      Filter.Text := 'несуществующая';
      Check(Grid.RowCount = 1, 'пустой фильтр результатов не вызывает исключение');
      Check(not OK.Enabled, 'готово недоступно без результатов');
      Filter.Text := '';
      Check((Grid.RowCount = 3) and OK.Enabled, 'таблица восстанавливается после очистки фильтра');
    finally
      F.Free;
    end;
    Models := nil;
    F := CreateModelSelectionForm(Models, '', Favorites);
    try Check(not F.Visible, 'пустой каталог безопасно создаётся');
    finally F.Free; end;
    Check(True, 'освобождение заполненной и пустой формы без исключений');
  finally Favorites.Free; end;
end;

function MeasuredHeight(Combo: TTwoLineCombo; ID: UINT): UINT;
var Measure: TMeasureItemStruct;
begin
  FillChar(Measure, SizeOf(Measure), 0);
  Measure.ItemID := ID;
  Combo.Perform(LM_MEASUREITEM, 0, LPARAM(@Measure));
  Result := Measure.ItemHeight;
end;

procedure TestCombo;
var Combo: TTwoLineCombo; EditHeight, ListHeight: UINT; F: TForm;
begin
  F := TForm.CreateNew(nil);
  Combo := TTwoLineCombo.Create(F);
  try
    Combo.Parent := F;
    Combo.Style := csOwnerDrawEditableFixed;
    Combo.Font.Size := 12;
    Combo.Text := 'google/gemini-3.8-flash';
    EditHeight := MeasuredHeight(Combo, UINT(-1));
    ListHeight := MeasuredHeight(Combo, 0);
    Check(ListHeight > EditHeight, 'редактируемая часть ниже двухстрочного пункта');
    Check(EditHeight > 0, 'редактируемая часть имеет ненулевую высоту');
    Check(Windows.SendMessage(Combo.Handle, CB_GETITEMHEIGHT, WPARAM(-1), 0) <
      Windows.SendMessage(Combo.Handle, CB_GETITEMHEIGHT, 0, 0),
      'Win32 использует разную высоту поля и строк списка');
    Combo.Font.Size := 24;
    Check(MeasuredHeight(Combo, UINT(-1)) > EditHeight, 'высота поля следует размеру шрифта');
    Check(MeasuredHeight(Combo, 0) > ListHeight, 'высота пунктов следует размеру шрифта');
    Check(Combo.Text = 'google/gemini-3.8-flash', 'измерение не меняет ID модели');
    Check(Windows.SendMessage(Combo.Handle, CB_GETITEMHEIGHT, WPARAM(-1), 0) <
      Windows.SendMessage(Combo.Handle, CB_GETITEMHEIGHT, 0, 0),
      'пересоздание Win32-контрола после изменения шрифта сохраняет разделение высот');
  finally F.Free; end;
end;

begin
  Application.Initialize;
  try
    TestDialog;
    TestCombo;
    WriteLn('OK: ', Checks, ' checks');
  except
    on E: Exception do
    begin
      WriteLn('FAIL: ', E.ClassName, ': ', E.Message);
      Halt(1);
    end;
  end;
end.
