unit uReportFooter;

{$mode objfpc}{$H+}

interface

uses Classes, Controls, Graphics, uLibraryGrid, uReportTotals;

type
  { Подвал отдельно от строк данных: не сортируется и не прокручивается по вертикали. }
  TReportFooter = class(TCustomControl)
  private
    FSource: TLibraryGrid;
    FTotals: TReportTotals;
  protected
    procedure Paint; override;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    constructor Create(AOwner: TComponent; ASource: TLibraryGrid); reintroduce;
    procedure UpdateTotals(ALines: TStrings);
    function ColumnBounds(ALogicalColumn: Integer): TRect;
  end;

implementation

uses SysUtils, Math;

constructor TReportFooter.Create(AOwner: TComponent; ASource: TLibraryGrid);
begin
  inherited Create(AOwner);
  Visible := False;
  Align := alBottom;
  Height := 48;
  FSource := ASource;
  if FSource <> nil then FSource.FreeNotification(Self);
end;

procedure TReportFooter.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if (Operation = opRemove) and (AComponent = FSource) then FSource := nil;
end;

procedure TReportFooter.UpdateTotals(ALines: TStrings);
begin
  FTotals := CalculateReportTotals(ALines);
  Canvas.Font.Assign(Font);
  Canvas.Font.Style := Canvas.Font.Style + [fsBold];
  Height := Canvas.TextHeight('Ag') * 2 + 16;
  Visible := FTotals.HasTotals;
  Invalidate;
end;

function TReportFooter.ColumnBounds(ALogicalColumn: Integer): TRect;
begin
  Result := Classes.Rect(0, 0, 0, 0);
  if (FSource = nil) or (ALogicalColumn < 0) or
    (ALogicalColumn >= FSource.ColCount) or (FSource.RowCount = 0) or
    (FSource.ColWidths[ALogicalColumn] <= 0) then Exit;
  Result := FSource.CellRect(FSource.PhysicalColumn(ALogicalColumn), 0);
  Result.Top := Height div 2;
  Result.Bottom := Height - 1;
end;

procedure TReportFooter.Paint;
var C, RightEdge: Integer; R: TRect; Style: TTextStyle;
begin
  Canvas.Brush.Color := clBtnFace;
  Canvas.FillRect(ClientRect);
  Canvas.Font.Assign(Font);
  Canvas.Font.Style := Canvas.Font.Style + [fsBold];
  Canvas.Pen.Color := clBtnShadow;
  Canvas.Line(0, 0, ClientWidth, 0);
  Canvas.TextOut(8, 4, 'Сумма по строкам');
  if FSource = nil then Exit;
  RightEdge := Min(ClientWidth, FSource.ClientWidth);
  Style := Canvas.TextStyle;
  Style.Alignment := taRightJustify;
  Style.Layout := tlCenter;
  Style.SingleLine := True;
  Style.Clipping := True;
  Style.Opaque := False;
  Style.EndEllipsis := True;
  for C := 0 to High(FTotals.Cells) do
  begin
    if FTotals.Cells[C] = '' then Continue;
    R := ColumnBounds(C + 1);
    if (R.Right <= 0) or (R.Left >= RightEdge) or (R.Right <= R.Left) then Continue;
    R.Left := Max(0, R.Left);
    R.Right := Min(R.Right, RightEdge);
    Canvas.Rectangle(R);
    Inc(R.Left, 4);
    Dec(R.Right, 4);
    Canvas.TextRect(R, R.Left, R.Top, FTotals.Cells[C], Style);
  end;
end;

end.
