program TRMapWorkflowTests;

{$MODE Delphi}

uses
  Interfaces, Forms, SysUtils, Classes, Graphics, Controls, IniFiles,
  FPVectorial, VectorMapRenderer, TRMapForm;

procedure Check(ACondition: Boolean; const AMessage: string);
begin
  if not ACondition then
    raise Exception.Create(AMessage);
end;

procedure WriteTextFile(const AFileName, AText: string);
var
  Stream: TStringStream;
begin
  Stream := TStringStream.Create(AText);
  try
    Stream.SaveToFile(AFileName);
  finally
    Stream.Free;
  end;
end;

procedure TestBitmapImportSaveReload(const ADirectory: string);
var
  SourceBitmap, SavedBackground, RenderedVector: TBitmap;
  Editor, Reopened: TfTRMap;
  Ini: TIniFile;
  Document: TvVectorialDocument;
  Page: TvVectorialPage;
  TerritoryPath: TPath;
  SourceName, MapName, SVGName, BackgroundName: string;
begin
  SourceName := IncludeTrailingPathDelimiter(ADirectory) + 'flat-territories.bmp';
  MapName := IncludeTrailingPathDelimiter(ADirectory) + 'bitmap-map.trm';
  SVGName := IncludeTrailingPathDelimiter(ADirectory) + 'bitmap-map.svg';
  BackgroundName := IncludeTrailingPathDelimiter(ADirectory) + 'bitmap-map.bmp';

  SourceBitmap := TBitmap.Create;
  try
    SourceBitmap.PixelFormat := pf24bit;
    SourceBitmap.SetSize(100, 80);
    SourceBitmap.Canvas.Brush.Color := clWhite;
    SourceBitmap.Canvas.FillRect(Rect(0, 0, 100, 80));
    SourceBitmap.Canvas.Brush.Color := RGBToColor(204, 34, 17);
    SourceBitmap.Canvas.FillRect(Rect(10, 12, 41, 43));
    SourceBitmap.SaveToFile(SourceName);
  finally
    SourceBitmap.Free;
  end;

  Editor := TfTRMap.Create(nil);
  try
    Editor.ImportMapFile(SourceName);
    Editor.TerritoryList.ItemIndex := 0;
    Editor.ActiveViewCombo.ItemIndex := 1;
    Editor.ActiveViewComboChange(Editor.ActiveViewCombo);
    Editor.MapImageMouseDown(Editor.MapImage, mbLeft, [], 20, 20);
    Editor.AutoFindButtonClick(Editor.AutoFindButton);
    Editor.SaveMapFile(MapName);
  finally
    Editor.Free;
  end;

  Check(FileExists(MapName), 'BMP import did not save a TRM file.');
  Check(FileExists(SVGName), 'BMP import did not save its SVG territory layer.');
  Check(FileExists(BackgroundName), 'BMP import did not save the raster background.');

  Ini := TIniFile.Create(MapName);
  try
    Check(Ini.ReadString('Map', 'VectorFile', '') = 'bitmap-map.svg',
      'Saved TRM does not reference the generated SVG.');
    Check(Ini.ReadString('Map', 'BackgroundFile', '') = 'bitmap-map.bmp',
      'Saved TRM does not reference the raster background.');
    Check(Ini.ReadInteger('Territory_1', 'FFCount', 0) = 1,
      'Saved TRM did not preserve the clicked floodfill seed.');
    Check(Ini.ReadInteger('Territory_1', 'FF1x', -1) = 20,
      'Saved TRM changed the floodfill seed X coordinate.');
    Check(Ini.ReadInteger('Territory_1', 'FF1y', -1) = 20,
      'Saved TRM changed the floodfill seed Y coordinate.');
    Check(Ini.ReadInteger('Territory_1', 'Color', clBlack) =
      Integer(RGBToColor(204, 34, 17)),
      'Saved territory color does not match the imported bitmap region.');
  finally
    Ini.Free;
  end;

  SavedBackground := TBitmap.Create;
  try
    SavedBackground.LoadFromFile(BackgroundName);
    Check((SavedBackground.Width = 100) and (SavedBackground.Height = 80),
      'Saved raster background dimensions changed.');
    Check(SavedBackground.Canvas.Pixels[20, 20] = RGBToColor(204, 34, 17),
      'Saved raster background lost the imported territory color.');
    Check(SavedBackground.Canvas.Pixels[2, 2] = clWhite,
      'Saved raster background lost the original artwork.');
  finally
    SavedBackground.Free;
  end;

  Document := TvVectorialDocument.Create;
  try
    Document.ReadFromFile(SVGName);
    Check(Document.GetPageCount = 1, 'Generated SVG has no page.');
    Page := Document.GetPage(0) as TvVectorialPage;
    TerritoryPath := TPath(Page.FindEntityWithNameAndType(
      'tr-territory-1', TPath, True));
    Check(TerritoryPath <> nil, 'Generated SVG is missing territory 1.');
    Check(TPath(Page.FindEntityWithNameAndType(
      'tr-map-canvas', TPath, True)) <> nil,
      'Generated SVG is missing the complete-map bounds path.');
  finally
    Document.Free;
  end;

  RenderedVector := TBitmap.Create;
  try
    RenderSVGToBitmap(SVGName, RenderedVector, True, 100, 80);
    Check(RenderedVector.Canvas.Pixels[20, 20] <> VECTOR_MAP_TRANSPARENT,
      'Generated SVG path does not cover its original seed after rendering.');
    Check(RenderedVector.Canvas.Pixels[2, 2] = VECTOR_MAP_TRANSPARENT,
      'Generated SVG path was stretched beyond the traced territory.');
  finally
    RenderedVector.Free;
  end;

  Reopened := TfTRMap.Create(nil);
  try
    Reopened.OpenMapFile(MapName);
    Check((Reopened.MapImage.Picture.Bitmap.Width = 100) and
      (Reopened.MapImage.Picture.Bitmap.Height = 80),
      'Reopened TRM did not preserve the map dimensions.');
    Check(Reopened.TerritoryList.Items[0] = '1 - Alaska',
      'Reopened TRM did not restore the territory list.');
  finally
    Reopened.Free;
  end;
end;

procedure TestSVGImportSaveReload(const ADirectory: string);
var
  Editor, Reopened: TfTRMap;
  Document: TvVectorialDocument;
  Page: TvVectorialPage;
  SourceName, MapName, SVGName: string;
begin
  SourceName := IncludeTrailingPathDelimiter(ADirectory) + 'two-territories.svg';
  MapName := IncludeTrailingPathDelimiter(ADirectory) + 'svg-map.trm';
  SVGName := IncludeTrailingPathDelimiter(ADirectory) + 'svg-map.svg';
  WriteTextFile(SourceName,
    '<svg xmlns="http://www.w3.org/2000/svg" width="100" height="80" ' +
    'viewBox="0 0 100 80">' +
    '<path id="north" d="M 5,5 L 45,5 L 45,45 L 5,45 Z" fill="#cc2211"/>' +
    '<path id="south" d="M 55,5 L 95,5 L 95,45 L 55,45 Z" fill="#1122cc"/>' +
    '</svg>');

  Editor := TfTRMap.Create(nil);
  try
    Editor.ImportMapFile(SourceName);
    Editor.TerritoryList.ItemIndex := 0;
    Editor.ActiveViewCombo.ItemIndex := 1;
    Editor.ActiveViewComboChange(Editor.ActiveViewCombo);
    Editor.MapImageMouseDown(Editor.MapImage, mbLeft, [], 20, 20);
    Editor.SaveMapFile(MapName);
  finally
    Editor.Free;
  end;

  Check(FileExists(MapName) and FileExists(SVGName),
    'SVG import did not save a complete map package.');
  Document := TvVectorialDocument.Create;
  try
    Document.ReadFromFile(SVGName);
    Check(Document.GetPageCount = 1, 'Saved SVG import has no page.');
    Page := Document.GetPage(0) as TvVectorialPage;
    Check(TPath(Page.FindEntityWithNameAndType(
      'tr-territory-1', TPath, True)) <> nil,
      'Saved SVG import did not assign territory 1.');
    Check(TPath(Page.FindEntityWithNameAndType(
      'south', TPath, True)) <> nil,
      'Saving the assigned SVG path lost an unassigned territory shape.');
  finally
    Document.Free;
  end;

  Reopened := TfTRMap.Create(nil);
  try
    Reopened.OpenMapFile(MapName);
    Check(Reopened.MapImage.Picture.Bitmap.Width > 0,
      'Reopened SVG-backed TRM did not render.');
    Check(Reopened.TerritoryList.Items[0] = '1 - Alaska',
      'Reopened SVG-backed TRM did not restore its territory metadata.');
  finally
    Reopened.Free;
  end;
end;

var
  TempDirectory: string;
  TestGuid: TGuid;
  TestFiles: array[0..6] of string = (
    'flat-territories.bmp', 'bitmap-map.trm', 'bitmap-map.svg',
    'bitmap-map.bmp', 'two-territories.svg', 'svg-map.trm', 'svg-map.svg');
  I: Integer;
begin
  try
    if CreateGUID(TestGuid) <> 0 then
      raise Exception.Create('Could not generate a unique workflow-test directory.');
    TempDirectory := IncludeTrailingPathDelimiter(GetTempDir(False)) +
      'TRMapWorkflow-' + GUIDToString(TestGuid);
    TempDirectory := StringReplace(TempDirectory, '{', '', [rfReplaceAll]);
    TempDirectory := StringReplace(TempDirectory, '}', '', [rfReplaceAll]);
    if not ForceDirectories(TempDirectory) then
      raise Exception.CreateFmt('Could not create test directory %s.',
        [TempDirectory]);
    Application.Initialize;
    try
      TestBitmapImportSaveReload(TempDirectory);
      TestSVGImportSaveReload(TempDirectory);
      WriteLn('TRMap import/save/reopen workflow tests passed.');
    finally
      for I := Low(TestFiles) to High(TestFiles) do
        DeleteFile(IncludeTrailingPathDelimiter(TempDirectory) + TestFiles[I]);
      RemoveDir(TempDirectory);
    end;
  except
    on E: Exception do begin
      WriteLn(StdErr, 'TRMap workflow test failed: ', E.Message);
      DumpExceptionBackTrace(StdErr);
      Halt(1);
    end;
  end;
end.
