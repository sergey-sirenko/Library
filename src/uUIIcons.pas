unit uUIIcons;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Graphics, ImgList, Controls;

const
  { вкладки }
  icoBooks = 0;
  icoReaders = 1;
  icoLoans = 2;
  icoOverdue = 3;
  icoCategories = 4;
  icoLocations = 5;
  icoReports = 6;
  icoUsers = 7;
  icoSettings = 8;
  icoBackup = 9;
  icoJournal = 10;
  { кнопки }
  icoSearch = 11;
  icoAdd = 12;
  icoEdit = 13;
  icoDelete = 14;
  icoRestore = 15;
  icoIssue = 16;
  icoReturn = 17;
  icoRenew = 18;
  icoCalendar = 19;
  icoRun = 20;
  icoCsv = 21;
  icoSave = 22;
  icoTest = 23;
  icoRefresh = 24;

  ICON_COUNT = 25;
  ICON_SIZE = 16;

procedure BuildAppIcons(AImages: TCustomImageList);

implementation

const
  CInk: TColor = $555555;
  CMask: TColor = clFuchsia;

procedure Prepare(Bmp: TBitmap; out C: TCanvas);
begin
  Bmp.SetSize(ICON_SIZE, ICON_SIZE);
  Bmp.PixelFormat := pf24bit;
  Bmp.Transparent := True;
  Bmp.TransparentColor := CMask;
  C := Bmp.Canvas;
  C.Brush.Color := CMask;
  C.FillRect(Rect(0, 0, ICON_SIZE, ICON_SIZE));
  C.Pen.Color := CInk;
  C.Pen.Width := 1;
  C.Brush.Style := bsClear;
  C.Font.Color := CInk;
  C.Font.Name := 'Segoe UI';
  C.Font.Size := 7;
  C.Font.Style := [fsBold];
end;

procedure AddBmp(AImages: TCustomImageList; Bmp: TBitmap);
begin
  AImages.AddMasked(Bmp, CMask);
end;

procedure DrawBooks(C: TCanvas);
begin
  C.Brush.Style := bsSolid;
  C.Brush.Color := CInk;
  C.FrameRect(Rect(3, 2, 8, 14));
  C.FrameRect(Rect(8, 3, 13, 14));
  C.Brush.Style := bsClear;
  C.MoveTo(8, 3);
  C.LineTo(8, 14);
end;

procedure DrawPersonAt(C: TCanvas; AX: Integer);
begin
  C.Ellipse(5 + AX, 2, 11 + AX, 8);
  C.Arc(3 + AX, 8, 13 + AX, 16, 13 + AX, 11, 3 + AX, 11);
end;

procedure DrawPerson(C: TCanvas);
begin
  DrawPersonAt(C, 0);
end;

procedure DrawSwap(C: TCanvas);
begin
  C.MoveTo(2, 5);
  C.LineTo(11, 5);
  C.LineTo(9, 3);
  C.MoveTo(11, 5);
  C.LineTo(9, 7);
  C.MoveTo(14, 11);
  C.LineTo(5, 11);
  C.LineTo(7, 9);
  C.MoveTo(5, 11);
  C.LineTo(7, 13);
end;

procedure DrawWarning(C: TCanvas);
begin
  C.MoveTo(8, 2);
  C.LineTo(14, 13);
  C.LineTo(2, 13);
  C.LineTo(8, 2);
  C.MoveTo(8, 6);
  C.LineTo(8, 10);
  C.Pixels[8, 12] := CInk;
end;

procedure DrawTag(C: TCanvas);
begin
  C.Polygon([Point(2, 8), Point(8, 2), Point(14, 2), Point(14, 8), Point(8, 14)]);
  C.Ellipse(10, 4, 13, 7);
end;

procedure DrawPin(C: TCanvas);
begin
  C.Ellipse(5, 2, 11, 8);
  C.MoveTo(8, 8);
  C.LineTo(8, 14);
  C.MoveTo(5, 5);
  C.LineTo(11, 5);
end;

procedure DrawChart(C: TCanvas);
begin
  C.MoveTo(2, 13);
  C.LineTo(14, 13);
  C.MoveTo(2, 13);
  C.LineTo(2, 2);
  C.Brush.Style := bsSolid;
  C.Brush.Color := CInk;
  C.FillRect(Rect(4, 8, 6, 13));
  C.FillRect(Rect(7, 5, 9, 13));
  C.FillRect(Rect(10, 3, 12, 13));
  C.Brush.Style := bsClear;
end;

procedure DrawPeople(C: TCanvas);
begin
  DrawPersonAt(C, -2);
  C.Ellipse(9, 3, 14, 8);
  C.Arc(7, 8, 15, 15, 15, 11, 7, 11);
end;

procedure DrawGear(C: TCanvas);
begin
  C.Ellipse(5, 5, 11, 11);
  C.MoveTo(8, 1);
  C.LineTo(8, 4);
  C.MoveTo(8, 12);
  C.LineTo(8, 15);
  C.MoveTo(1, 8);
  C.LineTo(4, 8);
  C.MoveTo(12, 8);
  C.LineTo(15, 8);
  C.MoveTo(3, 3);
  C.LineTo(5, 5);
  C.MoveTo(11, 11);
  C.LineTo(13, 13);
  C.MoveTo(13, 3);
  C.LineTo(11, 5);
  C.MoveTo(5, 11);
  C.LineTo(3, 13);
end;

procedure DrawDisk(C: TCanvas);
begin
  C.Rectangle(2, 2, 14, 14);
  C.Rectangle(4, 2, 12, 7);
  C.Rectangle(5, 9, 11, 13);
end;

procedure DrawClipboard(C: TCanvas);
begin
  C.Rectangle(3, 3, 13, 14);
  C.Rectangle(5, 1, 11, 4);
  C.MoveTo(5, 7);
  C.LineTo(11, 7);
  C.MoveTo(5, 10);
  C.LineTo(11, 10);
end;

procedure DrawSearch(C: TCanvas);
begin
  C.Ellipse(2, 2, 10, 10);
  C.Pen.Width := 2;
  C.MoveTo(9, 9);
  C.LineTo(14, 14);
  C.Pen.Width := 1;
end;

procedure DrawPlus(C: TCanvas);
begin
  C.Pen.Width := 2;
  C.MoveTo(8, 3);
  C.LineTo(8, 13);
  C.MoveTo(3, 8);
  C.LineTo(13, 8);
  C.Pen.Width := 1;
end;

procedure DrawPencil(C: TCanvas);
begin
  C.MoveTo(3, 13);
  C.LineTo(5, 13);
  C.LineTo(13, 5);
  C.LineTo(11, 3);
  C.LineTo(3, 11);
  C.LineTo(3, 13);
  C.MoveTo(9, 4);
  C.LineTo(12, 7);
end;

procedure DrawTrash(C: TCanvas);
begin
  C.Rectangle(4, 5, 12, 14);
  C.MoveTo(3, 5);
  C.LineTo(13, 5);
  C.Rectangle(6, 2, 10, 5);
  C.MoveTo(6, 7);
  C.LineTo(6, 12);
  C.MoveTo(8, 7);
  C.LineTo(8, 12);
  C.MoveTo(10, 7);
  C.LineTo(10, 12);
end;

procedure DrawUndo(C: TCanvas);
begin
  C.Arc(3, 3, 13, 13, 13, 8, 5, 4);
  C.MoveTo(3, 3);
  C.LineTo(3, 7);
  C.LineTo(7, 7);
end;

procedure DrawIssue(C: TCanvas);
begin
  C.Pen.Width := 2;
  C.MoveTo(2, 8);
  C.LineTo(11, 8);
  C.LineTo(8, 5);
  C.MoveTo(11, 8);
  C.LineTo(8, 11);
  C.Pen.Width := 1;
end;

procedure DrawReturn(C: TCanvas);
begin
  C.Pen.Width := 2;
  C.MoveTo(14, 8);
  C.LineTo(5, 8);
  C.LineTo(8, 5);
  C.MoveTo(5, 8);
  C.LineTo(8, 11);
  C.Pen.Width := 1;
end;

procedure DrawClock(C: TCanvas);
begin
  C.Ellipse(2, 2, 14, 14);
  C.MoveTo(8, 8);
  C.LineTo(8, 4);
  C.MoveTo(8, 8);
  C.LineTo(11, 10);
end;

procedure DrawCalendar(C: TCanvas);
begin
  C.Rectangle(2, 3, 14, 14);
  C.MoveTo(2, 6);
  C.LineTo(14, 6);
  C.MoveTo(5, 1);
  C.LineTo(5, 4);
  C.MoveTo(11, 1);
  C.LineTo(11, 4);
  C.Brush.Style := bsSolid;
  C.Brush.Color := CInk;
  C.FillRect(Rect(4, 8, 6, 10));
  C.FillRect(Rect(7, 8, 9, 10));
  C.FillRect(Rect(10, 8, 12, 10));
  C.Brush.Style := bsClear;
end;

procedure DrawPlay(C: TCanvas);
begin
  C.Brush.Style := bsSolid;
  C.Brush.Color := CInk;
  C.Polygon([Point(4, 3), Point(13, 8), Point(4, 13)]);
  C.Brush.Style := bsClear;
end;

procedure DrawDoc(C: TCanvas);
begin
  C.MoveTo(4, 2);
  C.LineTo(10, 2);
  C.LineTo(13, 5);
  C.LineTo(13, 14);
  C.LineTo(4, 14);
  C.LineTo(4, 2);
  C.MoveTo(10, 2);
  C.LineTo(10, 5);
  C.LineTo(13, 5);
  C.MoveTo(6, 8);
  C.LineTo(11, 8);
  C.MoveTo(6, 11);
  C.LineTo(11, 11);
end;

procedure DrawSave(C: TCanvas);
begin
  DrawDisk(C);
end;

procedure DrawCheck(C: TCanvas);
begin
  C.Pen.Width := 2;
  C.MoveTo(3, 8);
  C.LineTo(7, 12);
  C.LineTo(13, 4);
  C.Pen.Width := 1;
end;

procedure DrawRefresh(C: TCanvas);
begin
  C.Arc(2, 2, 14, 14, 13, 5, 4, 4);
  C.MoveTo(13, 3);
  C.LineTo(13, 7);
  C.LineTo(9, 7);
  C.Arc(2, 2, 14, 14, 3, 11, 12, 12);
  C.MoveTo(3, 13);
  C.LineTo(3, 9);
  C.LineTo(7, 9);
end;

type
  TIconDrawProc = procedure(C: TCanvas);

procedure AddIcon(AImages: TCustomImageList; ADraw: TIconDrawProc);
var
  Bmp: TBitmap;
  C: TCanvas;
begin
  Bmp := TBitmap.Create;
  try
    Prepare(Bmp, C);
    ADraw(C);
    AddBmp(AImages, Bmp);
  finally
    Bmp.Free;
  end;
end;

procedure BuildAppIcons(AImages: TCustomImageList);
begin
  AImages.Clear;
  AImages.Width := ICON_SIZE;
  AImages.Height := ICON_SIZE;
  AddIcon(AImages, @DrawBooks);
  AddIcon(AImages, @DrawPerson);
  AddIcon(AImages, @DrawSwap);
  AddIcon(AImages, @DrawWarning);
  AddIcon(AImages, @DrawTag);
  AddIcon(AImages, @DrawPin);
  AddIcon(AImages, @DrawChart);
  AddIcon(AImages, @DrawPeople);
  AddIcon(AImages, @DrawGear);
  AddIcon(AImages, @DrawDisk);
  AddIcon(AImages, @DrawClipboard);
  AddIcon(AImages, @DrawSearch);
  AddIcon(AImages, @DrawPlus);
  AddIcon(AImages, @DrawPencil);
  AddIcon(AImages, @DrawTrash);
  AddIcon(AImages, @DrawUndo);
  AddIcon(AImages, @DrawIssue);
  AddIcon(AImages, @DrawReturn);
  AddIcon(AImages, @DrawClock);
  AddIcon(AImages, @DrawCalendar);
  AddIcon(AImages, @DrawPlay);
  AddIcon(AImages, @DrawDoc);
  AddIcon(AImages, @DrawSave);
  AddIcon(AImages, @DrawCheck);
  AddIcon(AImages, @DrawRefresh);
end;

end.
