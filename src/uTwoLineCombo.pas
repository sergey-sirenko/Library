unit uTwoLineCombo;

{$mode objfpc}{$H+}

interface

uses Classes, StdCtrls, LMessages;

type
  { Высота редактируемой части независима от двухстрочных пунктов списка. }
  TTwoLineCombo = class(TComboBox)
  private
    procedure LMMeasureItem(var Message: TLMMeasureItem); message LM_MEASUREITEM;
  end;

implementation

uses LCLType;

procedure TTwoLineCombo.LMMeasureItem(var Message: TLMMeasureItem);
begin
  if Message.MeasureItemStruct^.ItemID = UINT(-1) then
    Message.MeasureItemStruct^.ItemHeight := Abs(Font.Height) + 6
  else
    Message.MeasureItemStruct^.ItemHeight := Abs(Font.Height) * 2 + 10;
end;

initialization
  RegisterClass(TTwoLineCombo);

end.
