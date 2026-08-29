unit uUIFont;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, uTypes;

procedure ApplyFormUIFont(AForm: TForm; ASize: Integer);

implementation

procedure ApplyControlFontSize(AControl: TControl; ASize: Integer);
var
  I: Integer;
  WC: TWinControl;
begin
  { явно задаём Size всем контролам — надёжнее, чем полагаться на ParentFont/SystemFont }
  AControl.Font.Size := ASize;
  if AControl is TWinControl then
  begin
    WC := TWinControl(AControl);
    for I := 0 to WC.ControlCount - 1 do
      ApplyControlFontSize(WC.Controls[I], ASize);
  end;
end;

procedure ApplyFormUIFont(AForm: TForm; ASize: Integer);
begin
  if AForm = nil then
    Exit;
  ASize := ClampUIFontSize(ASize);
  AForm.Font.Size := ASize;
  ApplyControlFontSize(AForm, ASize);
  AForm.Canvas.Font.Assign(AForm.Font);
end;

end.
