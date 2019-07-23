unit floodfilltest;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FPimage, IntfGraphics, Graphics, GraphType;

procedure FloodFill(Canvas:Graphics.TCanvas; X, Y: Integer; lColor: TColor;
  FillStyle: TFillStyle);
procedure FPFloodFill(Image: TFPCustomImage; X, Y: Integer; lColor, lBrushColor: TFPColor;
  FillStyle: TFillStyle);


implementation

type
  ByteRA = array [1..1] of byte;
  Bytep = ^ByteRA;
  LongIntRA = array [1..1] of LongInt;
  LongIntp = ^LongIntRA;


procedure FPFloodFill(Image: TFPCustomImage; X, Y: Integer; lColor, lBrushColor: TFPColor;
  FillStyle: TFillStyle);
//Written by Chris Rorden
// Very slow, because uses Image.Pixels.
//A simple first-in-first-out circular buffer (the queue) for flood-filling contiguous voxels.
//This algorithm avoids stack problems associated simple recursive algorithms
//http://steve.hollasch.net/cgindex/polygons/floodfill.html [^]
const
  kFill = 0; //pixels we will want to flood fill
  kFillable = 128; //voxels we might flood fill
  kUnfillable = 255; //voxels we can not flood fill
var
  lWid,lHt,lQSz,lQHead,lQTail: integer;
  lQRA: LongIntP;
  lMaskRA: ByteP;

  procedure IncQra(var lVal, lQSz: integer);//nested inside FloodFill
  begin
      inc(lVal);
      if lVal >= lQSz then
         lVal := 1;
  end; //nested Proc IncQra

  function Pos2XY (lPos: integer): TPoint;
  begin
      result.X := ((lPos-1) mod lWid)+1; //horizontal position
      result.Y := ((lPos-1) div lWid)+1; //vertical position
  end; //nested Proc Pos2XY

  procedure TestPixel(lPos: integer);
  begin
       if (lMaskRA^[lPos]=kFillable) then begin
          lMaskRA^[lPos] := kFill;
          lQra^[lQHead] := lPos;
          incQra(lQHead,lQSz);
       end;
  end; //nested Proc TestPixel

  procedure RetirePixel; //nested inside FloodFill
  var
     lVal: integer;
     lXY : TPoint;
  begin
     lVal := lQra^[lQTail];
     lXY := Pos2XY(lVal);
     if lXY.Y > 1 then
          TestPixel (lVal-lWid);//pixel above
     if lXY.Y < lHt then
        TestPixel (lVal+lWid);//pixel below
     if lXY.X > 1 then
          TestPixel (lVal-1); //pixel to left
     if lXY.X < lWid then
        TestPixel (lVal+1); //pixel to right
     incQra(lQTail,lQSz); //done with this pixel
  end; //nested proc RetirePixel

var
   lTargetColorVal,lDefaultVal: byte;
   lX,lY,lPos: integer;
begin //FloodFill
  if FillStyle = fsSurface then begin
     //fill only target color with brush - bounded by nontarget color.
     if Image.Colors[X,Y] <> lColor then exit;
     lTargetColorVal := kFillable;
     lDefaultVal := kUnfillable;
  end else begin //fsBorder
      //fill non-target color with brush - bounded by target-color
     if Image.Colors[X,Y] = lColor then exit;
     lTargetColorVal := kUnfillable;
     lDefaultVal := kFillable;
  end;
  //if (lPt < 1) or (lPt > lMaskSz) or (lMaskP[lPt] <> 128) then exit;
  lHt := Image.Height;
  lWid := Image.Width;
  lQSz := lHt * lWid;
  //Qsz should be more than the most possible simultaneously active pixels
  //Worst case scenario is a click at the center of a 3x3 image: all 9 pixels will be active simultaneously
  //for larger images, only a tiny fraction of pixels will be active at one instance.
  //perhaps lQSz = ((lHt*lWid) div 4) + 32; would be safe and more memory efficient
  if (lHt < 1) or (lWid < 1) then exit;
  getmem(lQra,lQSz*sizeof(longint)); //very wasteful -
  getmem(lMaskRA,lHt*lWid*sizeof(byte));
  for lPos := 1 to (lHt*lWid) do
      lMaskRA^[lPos] := lDefaultVal; //assume all voxels are non targets
  lPos := 0;
  // MG: it is very slow to access the whole (!) Image with pixels
  for lY := 0 to (lHt-1) do
      for lX := 0 to (lWid-1) do begin
          lPos := lPos + 1;
          if Image.Colors[lX,lY] = lColor then
             lMaskRA^[lPos] := lTargetColorVal;
      end;
  lQHead := 2;
  lQTail := 1;
  lQra^[lQTail] := ((Y * lWid)+X+1); //NOTE: both X and Y start from 0 not 1
  lMaskRA^[lQra^[lQTail]] := kFill;
  RetirePixel;
  while lQHead <> lQTail do
        RetirePixel;

  lPos := 0;
  for lY := 0 to (lHt-1) do
      for lX := 0 to (lWid-1) do begin
          lPos := lPos + 1;
          if lMaskRA^[lPos] = kFill then
             Image.Colors[lX,lY] := lBrushColor;
      end;
  freemem(lMaskRA);
  freemem(lQra);
end;


procedure FloodFill(Canvas:Graphics.TCanvas; X, Y: Integer; lColor: TColor;
  FillStyle: TFillStyle);
var Li:TLazIntfImage;
   Bmp:Graphics.TBitmap;
begin
    Li:=TLazIntfImage.Create(Canvas.Width,Canvas.Height);
    Li.LoadFromDevice(Canvas.Handle);
    Li.UsePalette:=false;
    FPFloodFill(Li, X,Y,TColorToFPColor(lColor),TColorToFPColor(Canvas.Brush.Color),FillStyle);
    Bmp:=TBitmap.Create;
    Bmp.LoadFromIntfImage(Li);
    Li.free;
    Canvas.Draw(0,0,Bmp);
    Bmp.free;
end;


end.

