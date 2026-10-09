unit VectorMapRenderer;

{$MODE Delphi}

interface

uses
  Graphics;

const
  VECTOR_MAP_TRANSPARENT = TColor($00FF00FF);

procedure RenderSVGToBitmap(const FileName: string; Dest: TBitmap;
  TransparentBackground: Boolean = False; TargetWidth: Integer = 0;
  TargetHeight: Integer = 0);

implementation

uses
  SysUtils, Types, FPVectorial, SVGVectorialReader, FPVectorial2Canvas;

procedure RenderSVGToBitmap(const FileName: string; Dest: TBitmap;
  TransparentBackground: Boolean; TargetWidth: Integer; TargetHeight: Integer);
const
  SVG_PIXELS_PER_MM = 96.0 / 25.4;
var
  Document: TvVectorialDocument;
  Page: TvPage;
  MeasureBitmap: TBitmap;
  Width, Height, OffsetX, OffsetY: Integer;
  SourceWidth, SourceHeight: Integer;
  ScaleX, ScaleY: Double;
begin
  if not FileExists(FileName) then
    raise EFileNotFoundException.CreateFmt('SVG map not found: %s', [FileName]);

  Document := TvVectorialDocument.Create;
  MeasureBitmap := TBitmap.Create;
  try
    Document.ReadFromFile(FileName);
    if Document.GetPageCount = 0 then
      raise Exception.CreateFmt('SVG map has no renderable page: %s', [FileName]);

    Page := Document.GetPage(0);
    MeasureBitmap.SetSize(1, 1);
    Page.Render(MeasureBitmap.Canvas, 0, 0, SVG_PIXELS_PER_MM,
      SVG_PIXELS_PER_MM, False);

    Width := Page.RenderInfo.EntityCanvasMaxXY.X -
      Page.RenderInfo.EntityCanvasMinXY.X;
    Height := Page.RenderInfo.EntityCanvasMaxXY.Y -
      Page.RenderInfo.EntityCanvasMinXY.Y;
    if (Width <= 0) or (Height <= 0) then
      raise Exception.CreateFmt('SVG map has invalid dimensions: %s', [FileName]);
    SourceWidth := Width;
    SourceHeight := Height;
    OffsetX := -Page.RenderInfo.EntityCanvasMinXY.X;
    OffsetY := -Page.RenderInfo.EntityCanvasMinXY.Y;
    if (TargetWidth > 0) and (TargetHeight > 0) then begin
      Width := TargetWidth;
      Height := TargetHeight;
    end;
    if (Width > 20000) or (Height > 20000) then
      raise Exception.CreateFmt('SVG map dimensions exceed 20000 pixels: %s',
        [FileName]);

    Dest.PixelFormat := pf24bit;
    Dest.SetSize(Width, Height);
    if TransparentBackground then begin
      Dest.Canvas.Brush.Color := VECTOR_MAP_TRANSPARENT;
      Dest.Canvas.FillRect(Rect(0, 0, Width, Height));
    end
    else begin
      Dest.Canvas.Brush.Color := clWhite;
      Dest.Canvas.FillRect(Rect(0, 0, Width, Height));
      Page.DrawBackground(Dest.Canvas);
    end;
    ScaleX := Width / SourceWidth;
    ScaleY := Height / SourceHeight;
    Page.Render(Dest.Canvas, Round(OffsetX * ScaleX), Round(OffsetY * ScaleY),
      SVG_PIXELS_PER_MM * ScaleX, SVG_PIXELS_PER_MM * ScaleY);
    if TransparentBackground then begin
      Dest.TransparentColor := VECTOR_MAP_TRANSPARENT;
      Dest.Transparent := True;
    end;
  finally
    MeasureBitmap.Free;
    Document.Free;
  end;
end;

end.
