unit TRMapForm;

{$MODE Delphi}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ComCtrls, ExtCtrls,
  StdCtrls, Menus, Spin, Types, IniFiles, FPVectorial;

type
  TMapView = (mvOriginal, mvTerritories, mvTextBoxes, mvLinks, mvSimulation);

  TMapTerritory = record
    Color: TColor;
    TextPoint: TPoint;
    FloodPoints: array of TPoint;
    Name: string;
    Continent: Integer;
    Borders: array of Integer;
  end;
  TMapTerritories = array[1..42] of TMapTerritory;

  { TfTRMap }
  TfTRMap = class(TForm)
    MainMenu: TMainMenu;
    FileMenu: TMenuItem;
    NewMenu: TMenuItem;
    OpenMenu: TMenuItem;
    SaveMenu: TMenuItem;
    SaveAsMenu: TMenuItem;
    ExitMenu: TMenuItem;
    MapLayout: TPanel;
    ToolPanel: TPanel;
    MapImage: TImage;
    Splitter: TSplitter;
    ToolPages: TPageControl;
    MapTab: TTabSheet;
    TerritoriesTab: TTabSheet;
    UtilitiesTab: TTabSheet;
    DescriptionEdit: TEdit;
    AuthorEdit: TEdit;
    RevisionEdit: TEdit;
    FontNameEdit: TEdit;
    FontSizeEdit: TSpinEdit;
    TerritoryList: TListBox;
    ActiveViewCombo: TComboBox;
    SimulationColorButton: TButton;
    ValidateButton: TButton;
    AutoFindButton: TButton;
    ClearAllButton: TButton;
    NewVersionButton: TButton;
    TransformXEdit: TFloatSpinEdit;
    TransformYEdit: TFloatSpinEdit;
    TransformButton: TButton;
    ImportBMPButton: TButton;
    StatusBar: TStatusBar;
    OpenDialog: TOpenDialog;
    SaveDialog: TSaveDialog;
    ColorDialog: TColorDialog;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormResize(Sender: TObject);
    procedure NewMenuClick(Sender: TObject);
    procedure OpenMenuClick(Sender: TObject);
    procedure SaveMenuClick(Sender: TObject);
    procedure SaveAsMenuClick(Sender: TObject);
    procedure ExitMenuClick(Sender: TObject);
    procedure ImportBMPButtonClick(Sender: TObject);
    procedure ActiveViewComboChange(Sender: TObject);
    procedure TerritoryListClick(Sender: TObject);
    procedure MapImageMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure AutoFindButtonClick(Sender: TObject);
    procedure ClearAllButtonClick(Sender: TObject);
    procedure TransformButtonClick(Sender: TObject);
    procedure NewVersionButtonClick(Sender: TObject);
    procedure ValidateButtonClick(Sender: TObject);
    procedure SimulationColorButtonClick(Sender: TObject);
  public
    procedure ImportMapFile(const AFileName: string);
    procedure OpenMapFile(const AFileName: string);
    procedure SaveMapFile(const AFileName: string);
    procedure ClearFloodPoints;
    procedure TransformMapPoints(ScaleX, ScaleY: Double);
    function ValidateMap(out AReport: string): Boolean;
  private
    FBitmap: TBitmap;
    FSVGDocument: TvVectorialDocument;
    FSVGPage: TvVectorialPage;
    FFileName: string;
    FBitmapFileName: string;
    FIsNewMap: Boolean;
    FSourceIsSVG: Boolean;
    FView: TMapView;
    FTerritories: TMapTerritories;
    FSimulationColor: TColor;
    FUpdating: Boolean;
    procedure BuildInterface;
    procedure UpdateTerritoryList;
    procedure LoadTRM(const AFileName: string);
    procedure ImportNewMap(const AFileName: string);
    procedure LoadBitmap(const AFileName: string);
    procedure InitializeSVGBitmap;
    procedure AddSVGMapBounds;
    procedure SaveTRM(const AFileName: string);
    procedure SaveSVG(const AFileName: string);
    procedure RenderMap;
    procedure DrawSVGBackground;
    function CanvasToMapPoint(X, Y: Integer): TPoint;
    function MapWidth: Integer;
    function MapHeight: Integer;
    function HitTestTerritory(const APoint: TPoint): Integer;
    function FindSVGPathAtPoint(const APoint: TPoint): TPath;
    function FindBitmapRegion(ATerritory: Integer; const ASeed: TPoint;
      ATargetColor: TColor; out APath: TPath): Boolean;
    function RenderSVGPage(ACanvas: TCanvas; AWidth, AHeight: Integer): Boolean;
    function IsMapPoint(const APoint: TPoint): Boolean;
    procedure AddFloodPoint(ATerritory: Integer; const APoint: TPoint);
    procedure UpdateStatus(const AText: string);
  end;

var
  fTRMap: TfTRMap;

implementation

{$R *.lfm}

uses
  Math, FPImage, SVGVectorialReader, SVGVectorialWriter;

const
  TERRITORY_COUNT = 42;
  MAX_BORDERS = 6;
  MAX_FLOOD_POINTS = 20;
  MAX_MAP_DIMENSION = 20000;
  MAX_MAP_PIXELS = 10000000;

const
  TerritoryNames: array[1..TERRITORY_COUNT] of string = (
    'Alaska', 'Northwest Territory', 'Greenland', 'Alberta', 'Ontario',
    'Quebec', 'Western US', 'Eastern US', 'Central America', 'Venezuela',
    'Peru', 'Brazil', 'Argentina', 'North Africa', 'Egypt', 'East Africa',
    'Congo', 'South Africa', 'Madagascar', 'Iceland', 'Scandinavia',
    'Ukraine', 'Northern Europe', 'Great Britain', 'Western Europe',
    'Southern Europe', 'Middle East', 'Yamal-Nemets', 'Kazakhstan', 'India',
    'Siam', 'China', 'Mongolia', 'Taymyr', 'Yakut', 'Buryat', 'Koryak',
    'Japan', 'Indonesia', 'Western Australia', 'Eastern Australia',
    'New Guinea');
  TerritoryContinents: array[1..TERRITORY_COUNT] of Integer = (
    1,1,1,1,1,1,1,1,1,2,2,2,2,3,3,3,3,3,3,4,4,4,4,4,4,4,5,5,5,5,5,5,5,
    5,5,5,5,5,6,6,6,6);
  TerritoryBorderCounts: array[1..TERRITORY_COUNT] of Integer = (
    3,4,4,4,6,3,4,4,3,3,3,4,2,6,4,6,3,3,2,3,4,6,5,4,4,6,6,4,5,4,3,4,6,
    4,3,4,5,2,3,3,2,3);
  TerritoryBorders: array[1..TERRITORY_COUNT,1..MAX_BORDERS] of Integer = (
    (2,4,37,0,0,0),(1,3,4,5,0,0),(2,5,6,20,0,0),(1,2,5,7,0,0),
    (2,3,4,6,7,8),(3,5,8,0,0,0),(4,5,8,9,0,0),(5,6,7,9,0,0),
    (7,8,10,0,0,0),(9,11,12,0,0,0),(10,12,13,0,0,0),
    (10,11,13,14,0,0),(11,12,0,0,0,0),(25,26,12,15,16,17),
    (14,16,26,27,0,0),(14,15,17,18,19,27),(14,16,18,0,0,0),
    (16,17,19,0,0,0),(16,18,0,0,0,0),(3,21,24,0,0,0),
    (20,22,23,24,0,0),(21,23,26,27,28,29),(21,22,24,25,26,0),
    (20,21,23,25,0,0),(23,24,26,14,0,0),(22,23,25,27,14,15),
    (22,26,15,16,29,30),(22,29,33,34,0,0),(22,28,27,30,32,0),
    (27,29,31,32,0,0),(30,32,39,0,0,0),(29,30,31,33,0,0),
    (28,32,34,36,37,38),(28,33,35,36,0,0),(34,36,37,0,0,0),
    (33,34,35,37,0,0),(1,33,35,36,38,0),(33,37,0,0,0,0),
    (31,40,42,0,0,0),(39,41,42,0,0,0),(40,42,0,0,0,0),
    (39,40,41,0,0,0));

procedure TfTRMap.FormCreate(Sender: TObject);
begin
  FBitmap := TBitmap.Create;
  FSVGDocument := nil;
  FSVGPage := nil;
  FFileName := '';
  FBitmapFileName := '';
  FIsNewMap := False;
  FSourceIsSVG := False;
  FView := mvOriginal;
  FSimulationColor := RGBToColor(0, 128, 255);
  BuildInterface;
  UpdateTerritoryList;
end;

procedure TfTRMap.FormDestroy(Sender: TObject);
begin
  FreeAndNil(FSVGDocument);
  FreeAndNil(FBitmap);
end;

procedure TfTRMap.BuildInterface;
var
  i: Integer;
begin
  Caption := 'TRMap - TurboRisk Map Editor';
  Width := 1300;
  Height := 850;
  Position := poScreenCenter;
  MainMenu := TMainMenu.Create(Self);
  FileMenu := TMenuItem.Create(MainMenu);
  FileMenu.Caption := '&File';
  MainMenu.Items.Add(FileMenu);

  NewMenu := TMenuItem.Create(FileMenu);
  NewMenu.Caption := '&New from SVG or BMP...';
  NewMenu.OnClick := NewMenuClick;
  FileMenu.Add(NewMenu);
  OpenMenu := TMenuItem.Create(FileMenu);
  OpenMenu.Caption := '&Open map...';
  OpenMenu.OnClick := OpenMenuClick;
  FileMenu.Add(OpenMenu);
  SaveMenu := TMenuItem.Create(FileMenu);
  SaveMenu.Caption := '&Save';
  SaveMenu.OnClick := SaveMenuClick;
  FileMenu.Add(SaveMenu);
  SaveAsMenu := TMenuItem.Create(FileMenu);
  SaveAsMenu.Caption := 'Save &As...';
  SaveAsMenu.OnClick := SaveAsMenuClick;
  FileMenu.Add(SaveAsMenu);
  ExitMenu := TMenuItem.Create(FileMenu);
  ExitMenu.Caption := 'E&xit';
  ExitMenu.OnClick := ExitMenuClick;
  FileMenu.Add(ExitMenu);

  OpenDialog := TOpenDialog.Create(Self);
  OpenDialog.Filter := 'TurboRisk maps (*.trm)|*.trm|SVG images (*.svg)|*.svg|Bitmap images (*.bmp)|*.bmp';
  SaveDialog := TSaveDialog.Create(Self);
  SaveDialog.Filter := 'TurboRisk map package (*.trm)|*.trm';
  SaveDialog.DefaultExt := 'trm';

  MapLayout := TPanel.Create(Self);
  MapLayout.Parent := Self;
  MapLayout.Align := alClient;
  MapLayout.BevelOuter := bvNone;
  ToolPanel := TPanel.Create(Self);
  ToolPanel.Parent := MapLayout;
  ToolPanel.Align := alRight;
  ToolPanel.Width := 400;
  ToolPanel.BevelOuter := bvNone;
  Splitter := TSplitter.Create(Self);
  Splitter.Parent := MapLayout;
  Splitter.Align := alRight;
  MapImage := TImage.Create(Self);
  MapImage.Parent := MapLayout;
  MapImage.Align := alClient;
  MapImage.Stretch := False;
  MapImage.Proportional := False;
  MapImage.OnMouseDown := MapImageMouseDown;

  ToolPages := TPageControl.Create(Self);
  ToolPages.Parent := ToolPanel;
  ToolPages.Align := alClient;
  MapTab := TTabSheet.Create(Self);
  MapTab.PageControl := ToolPages;
  MapTab.Caption := 'Map';
  TerritoriesTab := TTabSheet.Create(Self);
  TerritoriesTab.PageControl := ToolPages;
  TerritoriesTab.Caption := 'Territories';
  UtilitiesTab := TTabSheet.Create(Self);
  UtilitiesTab.PageControl := ToolPages;
  UtilitiesTab.Caption := 'Utilities';

  DescriptionEdit := TEdit.Create(Self);
  DescriptionEdit.Parent := MapTab;
  DescriptionEdit.SetBounds(12, 32, 360, 26);
  DescriptionEdit.TextHint := 'Description';
  AuthorEdit := TEdit.Create(Self);
  AuthorEdit.Parent := MapTab;
  AuthorEdit.SetBounds(12, 76, 360, 26);
  AuthorEdit.TextHint := 'Author';
  RevisionEdit := TEdit.Create(Self);
  RevisionEdit.Parent := MapTab;
  RevisionEdit.SetBounds(12, 120, 360, 26);
  RevisionEdit.TextHint := 'Revision';
  FontNameEdit := TEdit.Create(Self);
  FontNameEdit.Parent := MapTab;
  FontNameEdit.SetBounds(12, 164, 240, 26);
  FontNameEdit.Text := 'Courier New';
  FontSizeEdit := TSpinEdit.Create(Self);
  FontSizeEdit.Parent := MapTab;
  FontSizeEdit.SetBounds(264, 164, 80, 26);
  FontSizeEdit.MinValue := 4;
  FontSizeEdit.MaxValue := 72;
  FontSizeEdit.Value := 12;
  ImportBMPButton := TButton.Create(Self);
  ImportBMPButton.Parent := MapTab;
  ImportBMPButton.SetBounds(12, 212, 200, 32);
  ImportBMPButton.Caption := 'Import BMP artwork...';
  ImportBMPButton.OnClick := ImportBMPButtonClick;
  TerritoriesTab.OnResize := nil;

  TerritoryList := TListBox.Create(Self);
  TerritoryList.Parent := TerritoriesTab;
  TerritoryList.Align := alTop;
  TerritoryList.Height := 370;
  TerritoryList.OnClick := TerritoryListClick;
  ActiveViewCombo := TComboBox.Create(Self);
  ActiveViewCombo.Parent := TerritoriesTab;
  ActiveViewCombo.SetBounds(12, 382, 360, 28);
  ActiveViewCombo.Style := csDropDownList;
  ActiveViewCombo.Items.Add('Nothing (original artwork)');
  ActiveViewCombo.Items.Add('Floodfill points');
  ActiveViewCombo.Items.Add('Text box points');
  ActiveViewCombo.Items.Add('Territory links');
  ActiveViewCombo.Items.Add('Simulation');
  ActiveViewCombo.ItemIndex := 0;
  ActiveViewCombo.OnChange := ActiveViewComboChange;
  SimulationColorButton := TButton.Create(Self);
  SimulationColorButton.Parent := TerritoriesTab;
  SimulationColorButton.SetBounds(12, 422, 200, 30);
  SimulationColorButton.Caption := 'Simulation color...';
  SimulationColorButton.OnClick := SimulationColorButtonClick;
  ColorDialog := TColorDialog.Create(Self);

  AutoFindButton := TButton.Create(Self);
  AutoFindButton.Parent := UtilitiesTab;
  AutoFindButton.SetBounds(12, 16, 330, 32);
  AutoFindButton.Caption := 'Floodfill points - Autofind';
  AutoFindButton.OnClick := AutoFindButtonClick;
  ClearAllButton := TButton.Create(Self);
  ClearAllButton.Parent := UtilitiesTab;
  ClearAllButton.SetBounds(12, 58, 330, 32);
  ClearAllButton.Caption := 'Floodfill points - Clear all';
  ClearAllButton.OnClick := ClearAllButtonClick;
  NewVersionButton := TButton.Create(Self);
  NewVersionButton.Parent := UtilitiesTab;
  NewVersionButton.SetBounds(12, 100, 330, 32);
  NewVersionButton.Caption := 'Import replacement bitmap...';
  NewVersionButton.OnClick := NewVersionButtonClick;
  TransformXEdit := TFloatSpinEdit.Create(Self);
  TransformXEdit.Parent := UtilitiesTab;
  TransformXEdit.SetBounds(12, 156, 120, 28);
  TransformXEdit.MinValue := 0.01;
  TransformXEdit.MaxValue := 100;
  TransformXEdit.Increment := 0.1;
  TransformXEdit.Value := 1;
  TransformYEdit := TFloatSpinEdit.Create(Self);
  TransformYEdit.Parent := UtilitiesTab;
  TransformYEdit.SetBounds(148, 156, 120, 28);
  TransformYEdit.MinValue := 0.01;
  TransformYEdit.MaxValue := 100;
  TransformYEdit.Increment := 0.1;
  TransformYEdit.Value := 1;
  TransformButton := TButton.Create(Self);
  TransformButton.Parent := UtilitiesTab;
  TransformButton.SetBounds(12, 198, 330, 32);
  TransformButton.Caption := 'Map point coordinates - Transform';
  TransformButton.OnClick := TransformButtonClick;
  ValidateButton := TButton.Create(Self);
  ValidateButton.Parent := UtilitiesTab;
  ValidateButton.SetBounds(12, 248, 330, 36);
  ValidateButton.Caption := 'Validate map';
  ValidateButton.OnClick := ValidateButtonClick;

  StatusBar := TStatusBar.Create(Self);
  StatusBar.Parent := Self;
  StatusBar.Align := alBottom;
  StatusBar.SimplePanel := True;
  StatusBar.SimpleText := 'Open an SVG, BMP, or TRM map to begin.';
  FUpdating := True;
  try
    for i := 1 to TERRITORY_COUNT do
      FTerritories[i].Name := TerritoryNames[i];
  finally
    FUpdating := False;
  end;
end;

procedure TfTRMap.FormResize(Sender: TObject);
begin
  RenderMap;
end;

procedure TfTRMap.UpdateTerritoryList;
var
  i: Integer;
begin
  if TerritoryList = nil then
    Exit;
  FUpdating := True;
  try
    TerritoryList.Items.BeginUpdate;
    try
      TerritoryList.Clear;
      for i := 1 to TERRITORY_COUNT do
        TerritoryList.Items.Add(Format('%d - %s', [i, FTerritories[i].Name]));
      if TerritoryList.ItemIndex < 0 then
        TerritoryList.ItemIndex := 0;
    finally
      TerritoryList.Items.EndUpdate;
    end;
  finally
    FUpdating := False;
  end;
end;

procedure TfTRMap.UpdateStatus(const AText: string);
begin
  StatusBar.SimpleText := AText;
end;

function TfTRMap.MapWidth: Integer;
begin
  if FBitmap <> nil then
    Result := FBitmap.Width
  else
    Result := 0;
end;

function TfTRMap.MapHeight: Integer;
begin
  if FBitmap <> nil then
    Result := FBitmap.Height
  else
    Result := 0;
end;

function TfTRMap.IsMapPoint(const APoint: TPoint): Boolean;
begin
  Result := (APoint.X >= 0) and (APoint.Y >= 0) and
    (APoint.X < MapWidth) and (APoint.Y < MapHeight);
end;

function TfTRMap.CanvasToMapPoint(X, Y: Integer): TPoint;
var
  ScaleX, ScaleY: Double;
begin
  if (MapImage.Picture.Bitmap.Width <= 0) or
     (MapImage.Picture.Bitmap.Height <= 0) then
    Exit(Point(-1, -1));
  ScaleX := MapWidth / MapImage.Picture.Bitmap.Width;
  ScaleY := MapHeight / MapImage.Picture.Bitmap.Height;
  Result := Point(Round(X * ScaleX), Round(Y * ScaleY));
end;

function TfTRMap.HitTestTerritory(const APoint: TPoint): Integer;
var
  i: Integer;
  RenderBitmap: TBitmap;
begin
  Result := 0;
  if not IsMapPoint(APoint) then
    Exit;
  if FIsNewMap then begin
    RenderBitmap := TBitmap.Create;
    try
      RenderBitmap.SetSize(MapWidth, MapHeight);
      RenderSVGPage(RenderBitmap.Canvas, MapWidth, MapHeight);
      for i := 1 to TERRITORY_COUNT do
        if (FTerritories[i].Color <> clBlack) and
           (RenderBitmap.Canvas.Pixels[APoint.X, APoint.Y] =
             FTerritories[i].Color) then
          Exit(i);
    finally
      RenderBitmap.Free;
    end;
  end
  else if FBitmap <> nil then begin
    for i := 1 to TERRITORY_COUNT do
      if (FTerritories[i].Color <> clBlack) and
         (FBitmap.Canvas.Pixels[APoint.X, APoint.Y] = FTerritories[i].Color) then
        Exit(i);
  end;
end;

function TfTRMap.FindSVGPathAtPoint(const APoint: TPoint): TPath;
var
  I: Integer;
  RenderBitmap: TBitmap;
  function TestEntity(Entity: TvEntity): TPath; forward;
  function SearchContainer(AContainer: TvEntityWithSubEntities): TPath;
  var
    I: Integer;
    Entity: TvEntity;
  begin
    Result := nil;
    for I := AContainer.GetEntitiesCount - 1 downto 0 do begin
      Entity := AContainer.GetEntity(I);
      Result := TestEntity(Entity);
      if Result <> nil then Exit;
    end;
  end;
  function TestEntity(Entity: TvEntity): TPath;
  var
    Candidate: TPath;
    SavedBrush: TvBrush;
  begin
    Result := nil;
    if Entity is TPath then begin
      Candidate := TPath(Entity);
      if Candidate.Name = 'tr-map-canvas' then
        Exit;
      SavedBrush := Candidate.Brush;
      try
        Candidate.Brush.Kind := bkSimpleBrush;
        Candidate.Brush.Style := bsSolid;
        Candidate.Brush.Color := TColorToFPColor(clFuchsia);
        RenderBitmap.Canvas.Brush.Color := clWhite;
        RenderBitmap.Canvas.FillRect(Rect(0, 0, MapWidth, MapHeight));
        RenderSVGPage(RenderBitmap.Canvas, MapWidth, MapHeight);
        if RenderBitmap.Canvas.Pixels[APoint.X, APoint.Y] = clFuchsia then
          Result := Candidate;
      finally
        Candidate.Brush := SavedBrush;
      end;
    end
    else if Entity is TvEntityWithSubEntities then
      Result := SearchContainer(TvEntityWithSubEntities(Entity));
  end;
begin
  Result := nil;
  if (FSVGPage = nil) or not IsMapPoint(APoint) then
    Exit;
  RenderBitmap := TBitmap.Create;
  try
    RenderBitmap.SetSize(MapWidth, MapHeight);
    for I := FSVGPage.GetEntitiesCount - 1 downto 0 do begin
      Result := TestEntity(FSVGPage.GetEntity(I));
      if Result <> nil then
        Break;
    end;
  finally
    RenderBitmap.Free;
  end;
end;

function TfTRMap.RenderSVGPage(ACanvas: TCanvas; AWidth,
  AHeight: Integer): Boolean;
const
  SVG_PIXELS_PER_MM = 96.0 / 25.4;
var
  SourceWidth, SourceHeight, OffsetX, OffsetY: Integer;
  ScaleX, ScaleY: Double;
begin
  Result := (FSVGPage <> nil);
  if not Result then Exit;
  FSVGPage.Render(ACanvas, 0, 0, SVG_PIXELS_PER_MM, SVG_PIXELS_PER_MM,
    False);
  SourceWidth := Max(1, FSVGPage.RenderInfo.EntityCanvasMaxXY.X -
    FSVGPage.RenderInfo.EntityCanvasMinXY.X);
  SourceHeight := Max(1, FSVGPage.RenderInfo.EntityCanvasMaxXY.Y -
    FSVGPage.RenderInfo.EntityCanvasMinXY.Y);
  OffsetX := -FSVGPage.RenderInfo.EntityCanvasMinXY.X;
  OffsetY := -FSVGPage.RenderInfo.EntityCanvasMinXY.Y;
  ScaleX := AWidth / SourceWidth;
  ScaleY := AHeight / SourceHeight;
  FSVGPage.Render(ACanvas, Round(OffsetX * ScaleX), Round(OffsetY * ScaleY),
    SVG_PIXELS_PER_MM * ScaleX, SVG_PIXELS_PER_MM * ScaleY);
end;

procedure TfTRMap.AddSVGMapBounds;
var
  Bounds: TPath;
  TransparentColor: TFPColor;
begin
  if FSVGPage = nil then
    Exit;
  Bounds := TPath(FSVGPage.FindEntityWithNameAndType('tr-map-canvas', TPath));
  if Bounds <> nil then
    Exit;
  Bounds := TPath.Create(FSVGPage);
  Bounds.Name := 'tr-map-canvas';
  Bounds.Pen.Style := psClear;
  Bounds.Brush.Style := bsSolid;
  TransparentColor := TColorToFPColor(clWhite);
  TransparentColor.Alpha := 0;
  Bounds.Brush.Color := TransparentColor;
  Bounds.AppendMoveToSegment(0, 0);
  Bounds.AppendLineToSegment(MapWidth, 0);
  Bounds.AppendLineToSegment(MapWidth, MapHeight);
  Bounds.AppendLineToSegment(0, MapHeight);
  Bounds.AppendLineToSegment(0, 0);
  FSVGPage.AddEntity(Bounds);
  if (FSVGDocument.Width <= 0) or (FSVGDocument.Height <= 0) then begin
    FSVGDocument.Width := MapWidth;
    FSVGDocument.Height := MapHeight;
    FSVGPage.Width := MapWidth;
    FSVGPage.Height := MapHeight;
  end;
end;

procedure TfTRMap.DrawSVGBackground;
begin
  if (FSVGDocument <> nil) and (FSVGDocument.GetPageCount > 0) then
    FSVGPage := FSVGDocument.GetPage(0) as TvVectorialPage;
end;

procedure TfTRMap.RenderMap;
var
  i, j: Integer;
  P: TPoint;
begin
  if (MapImage = nil) or (MapWidth <= 0) or (MapHeight <= 0) then
    Exit;
  MapImage.Picture.Bitmap.PixelFormat := pf24bit;
  MapImage.Picture.Bitmap.SetSize(MapWidth, MapHeight);
  MapImage.Canvas.Brush.Color := clWhite;
  MapImage.Canvas.FillRect(Rect(0, 0, MapWidth, MapHeight));
  if FIsNewMap and (FSVGPage <> nil) then begin
    DrawSVGBackground;
    if (FBitmap <> nil) and (FBitmapFileName <> '') then
      MapImage.Canvas.StretchDraw(Rect(0, 0, MapWidth, MapHeight), FBitmap);
    RenderSVGPage(MapImage.Canvas, MapWidth, MapHeight);
  end
  else if FBitmap <> nil then
    MapImage.Canvas.Draw(0, 0, FBitmap);

  case FView of
    mvTerritories:
      begin
        for i := 1 to TERRITORY_COUNT do
          for j := 0 to High(FTerritories[i].FloodPoints) do begin
            P := FTerritories[i].FloodPoints[j];
            MapImage.Canvas.Pen.Color := clWhite;
            MapImage.Canvas.MoveTo(P.X - 5, P.Y);
            MapImage.Canvas.LineTo(P.X + 6, P.Y);
            MapImage.Canvas.MoveTo(P.X, P.Y - 5);
            MapImage.Canvas.LineTo(P.X, P.Y + 6);
          end;
      end;
    mvTextBoxes:
      begin
        MapImage.Canvas.Pen.Color := clRed;
        for i := 1 to TERRITORY_COUNT do
          if IsMapPoint(FTerritories[i].TextPoint) then begin
            MapImage.Canvas.Rectangle(FTerritories[i].TextPoint.X,
              FTerritories[i].TextPoint.Y,
              FTerritories[i].TextPoint.X + 36,
              FTerritories[i].TextPoint.Y + 16);
            MapImage.Canvas.TextOut(FTerritories[i].TextPoint.X,
              FTerritories[i].TextPoint.Y, IntToStr(i));
          end;
      end;
    mvLinks:
      begin
        MapImage.Canvas.Pen.Color := clWhite;
        for i := 1 to TERRITORY_COUNT do
          if Length(FTerritories[i].FloodPoints) > 0 then
            for j := 1 to TerritoryBorderCounts[i] do
              if (TerritoryBorders[i,j] > i) and
                 (Length(FTerritories[TerritoryBorders[i,j]].FloodPoints) > 0)
              then begin
              P := FTerritories[i].FloodPoints[0];
              MapImage.Canvas.MoveTo(P.X, P.Y);
              MapImage.Canvas.LineTo(
                FTerritories[TerritoryBorders[i,j]].FloodPoints[0].X,
                FTerritories[TerritoryBorders[i,j]].FloodPoints[0].Y);
            end;
      end;
    mvSimulation:
      begin
        MapImage.Canvas.Brush.Color := FSimulationColor;
        for i := 1 to TERRITORY_COUNT do
          for j := 0 to High(FTerritories[i].FloodPoints) do
            MapImage.Canvas.FloodFill(FTerritories[i].FloodPoints[j].X,
              FTerritories[i].FloodPoints[j].Y, FTerritories[i].Color,
              fsSurface);
      end;
  end;
  MapImage.Refresh;
end;

procedure TfTRMap.LoadTRM(const AFileName: string);
var
  Ini: TMemIniFile;
  I, J, Count: Integer;
  Section, VectorName, BackgroundName: string;
begin
  FreeAndNil(FSVGDocument);
  FSVGPage := nil;
  FIsNewMap := False;
  FSourceIsSVG := False;
  FBitmapFileName := '';
  Ini := TMemIniFile.Create(AFileName);
  try
    DescriptionEdit.Text := Ini.ReadString('Map', 'Desc', '');
    AuthorEdit.Text := Ini.ReadString('Map', 'Author', '');
    RevisionEdit.Text := Ini.ReadString('Map', 'Revision', '');
    FontNameEdit.Text := Ini.ReadString('Map', 'FontName', 'Courier New');
    FontSizeEdit.Value := Ini.ReadInteger('Map', 'FontSize', 12);
    VectorName := Ini.ReadString('Map', 'VectorFile', '');
    BackgroundName := Ini.ReadString('Map', 'BackgroundFile', '');
    for I := 1 to TERRITORY_COUNT do begin
      Section := 'Territory_' + IntToStr(I);
      FTerritories[I].Name := Ini.ReadString(Section, 'Name', TerritoryNames[I]);
      FTerritories[I].Continent := Ini.ReadInteger(Section, 'Cont', TerritoryContinents[I]);
      FTerritories[I].Color := Ini.ReadInteger(Section, 'Color', clBlack);
      FTerritories[I].TextPoint := Point(Ini.ReadInteger(Section, 'Tx', 0),
        Ini.ReadInteger(Section, 'Ty', 0));
      Count := Ini.ReadInteger(Section, 'FFCount', 0);
      if (Count < 0) or (Count > MAX_FLOOD_POINTS) then
        raise Exception.CreateFmt('%s has invalid floodfill point count %d.',
          [Section, Count]);
      SetLength(FTerritories[I].FloodPoints, Count);
      for J := 1 to Count do
        FTerritories[I].FloodPoints[J - 1] := Point(
          Ini.ReadInteger(Section, 'FF' + IntToStr(J) + 'x', 0),
          Ini.ReadInteger(Section, 'FF' + IntToStr(J) + 'y', 0));
      SetLength(FTerritories[I].Borders, TerritoryBorderCounts[I]);
      for J := 1 to TerritoryBorderCounts[I] do
        FTerritories[I].Borders[J - 1] := TerritoryBorders[I,J];
    end;
  finally
    Ini.Free;
  end;
  if VectorName <> '' then begin
    VectorName := ExpandFileName(ExtractFilePath(AFileName) + VectorName);
    if not FileExists(VectorName) then
      raise Exception.CreateFmt('Map vector file not found: %s', [VectorName]);
    FSVGDocument := TvVectorialDocument.Create;
    FSVGDocument.ReadFromFile(VectorName);
    if FSVGDocument.GetPageCount = 0 then
      raise Exception.CreateFmt('Map vector file has no renderable page: %s',
        [VectorName]);
    FSVGPage := FSVGDocument.GetPage(0) as TvVectorialPage;
    FIsNewMap := True;
    FSourceIsSVG := True;
    if BackgroundName <> '' then
      FBitmapFileName := ExpandFileName(
        ExtractFilePath(AFileName) + BackgroundName);
    if FBitmapFileName <> '' then
      LoadBitmap(FBitmapFileName)
    else
      InitializeSVGBitmap;
  end
  else begin
    if BackgroundName <> '' then
      FBitmapFileName := ExpandFileName(
        ExtractFilePath(AFileName) + BackgroundName)
    else
      FBitmapFileName := ChangeFileExt(AFileName, '.bmp');
    LoadBitmap(FBitmapFileName);
  end;
  FFileName := AFileName;
  UpdateTerritoryList;
  RenderMap;
end;

procedure TfTRMap.LoadBitmap(const AFileName: string);
begin
  if not FileExists(AFileName) then
    raise Exception.CreateFmt('Map bitmap not found: %s', [AFileName]);
  FBitmap.LoadFromFile(AFileName);
  if (FBitmap.Width <= 0) or (FBitmap.Height <= 0) or
     (FBitmap.Width > MAX_MAP_DIMENSION) or
     (FBitmap.Height > MAX_MAP_DIMENSION) or
     (Int64(FBitmap.Width) * FBitmap.Height > MAX_MAP_PIXELS) then
    raise Exception.CreateFmt('Map bitmap dimensions are too large: %d x %d.',
      [FBitmap.Width, FBitmap.Height]);
end;

procedure TfTRMap.InitializeSVGBitmap;
const
  SVG_PIXELS_PER_MM = 96.0 / 25.4;
var
  Width, Height: Integer;
begin
  FSVGPage.Render(FBitmap.Canvas, 0, 0, SVG_PIXELS_PER_MM,
    SVG_PIXELS_PER_MM, False);
  Width := Max(1, FSVGPage.RenderInfo.EntityCanvasMaxXY.X -
    FSVGPage.RenderInfo.EntityCanvasMinXY.X);
  Height := Max(1, FSVGPage.RenderInfo.EntityCanvasMaxXY.Y -
    FSVGPage.RenderInfo.EntityCanvasMinXY.Y);
  if (Width > MAX_MAP_DIMENSION) or (Height > MAX_MAP_DIMENSION) or
     (Int64(Width) * Height > MAX_MAP_PIXELS) then
    raise Exception.CreateFmt('SVG map dimensions are too large: %d x %d.',
      [Width, Height]);
  FBitmap.SetSize(Width, Height);
  FBitmap.Canvas.Brush.Color := clWhite;
  FBitmap.Canvas.FillRect(Rect(0, 0, Width, Height));
  RenderSVGPage(FBitmap.Canvas, Width, Height);
end;

procedure TfTRMap.NewMenuClick(Sender: TObject);
begin
  OpenDialog.Filter := 'SVG or bitmap images (*.svg;*.bmp)|*.svg;*.bmp|SVG images (*.svg)|*.svg|Bitmap images (*.bmp)|*.bmp';
  if not OpenDialog.Execute then
    Exit;
  try
    ImportNewMap(OpenDialog.FileName);
  except
    on E: Exception do
      MessageDlg('Could not import map: ' + E.Message, mtError, [mbOK], 0);
  end;
end;

procedure TfTRMap.ImportMapFile(const AFileName: string);
begin
  ImportNewMap(AFileName);
end;

procedure TfTRMap.OpenMapFile(const AFileName: string);
begin
  LoadTRM(AFileName);
end;

procedure TfTRMap.SaveMapFile(const AFileName: string);
begin
  SaveTRM(AFileName);
end;

procedure TfTRMap.ImportNewMap(const AFileName: string);
var
  I, J: Integer;
begin
  FSourceIsSVG := SameText(ExtractFileExt(AFileName), '.svg');
  if FSourceIsSVG then begin
    FreeAndNil(FSVGDocument);
    FSVGDocument := TvVectorialDocument.Create;
    FSVGDocument.ReadFromFile(AFileName);
    if FSVGDocument.GetPageCount = 0 then
      raise Exception.Create('SVG contains no renderable page.');
    FSVGPage := FSVGDocument.GetPage(0) as TvVectorialPage;
    InitializeSVGBitmap;
    FBitmapFileName := '';
    FIsNewMap := True;
  end
  else begin
    LoadBitmap(AFileName);
    FBitmapFileName := AFileName;
    FreeAndNil(FSVGDocument);
    FSVGPage := nil;
    FIsNewMap := True;
  end;
  FFileName := '';
  for I := 1 to TERRITORY_COUNT do begin
    FTerritories[I].Name := TerritoryNames[I];
    FTerritories[I].Continent := TerritoryContinents[I];
    FTerritories[I].Color := clBlack;
    FTerritories[I].TextPoint := Point(0, 0);
    SetLength(FTerritories[I].FloodPoints, 0);
    SetLength(FTerritories[I].Borders, TerritoryBorderCounts[I]);
    for J := 1 to TerritoryBorderCounts[I] do
      FTerritories[I].Borders[J - 1] := TerritoryBorders[I,J];
  end;
  DescriptionEdit.Text := ChangeFileExt(ExtractFileName(AFileName), '');
  AuthorEdit.Clear;
  RevisionEdit.Text := '1.0';
  UpdateTerritoryList;
  RenderMap;
  UpdateStatus('Imported ' + AFileName +
    '. Select Floodfill points, choose a territory, and click its shape to assign it.');
end;

procedure TfTRMap.ImportBMPButtonClick(Sender: TObject);
var
  ImportDialog: TOpenDialog;
begin
  if Sender = nil then begin
    if SameText(ExtractFileExt(OpenDialog.FileName), '.bmp') then
      LoadBitmap(OpenDialog.FileName);
    Exit;
  end;
  ImportDialog := TOpenDialog.Create(Self);
  try
    ImportDialog.Filter := 'Bitmap images (*.bmp)|*.bmp';
    if not ImportDialog.Execute then
      Exit;
    LoadBitmap(ImportDialog.FileName);
    FBitmapFileName := ImportDialog.FileName;
    FSourceIsSVG := False;
    FreeAndNil(FSVGDocument);
    FSVGDocument := TvVectorialDocument.Create;
    FSVGPage := FSVGDocument.AddPage as TvVectorialPage;
    FBitmapFileName := ImportDialog.FileName;
    FSourceIsSVG := False;
    FIsNewMap := True;
    AddSVGMapBounds;
    RenderMap;
    UpdateStatus('BMP imported as raster artwork. Place floodfill points in flat-color regions, then run Autofind to trace them.');
  finally
    ImportDialog.Free;
  end;
end;

procedure TfTRMap.OpenMenuClick(Sender: TObject);
begin
  OpenDialog.Filter := 'TurboRisk map or SVG (*.trm;*.svg)|*.trm;*.svg|TurboRisk maps (*.trm)|*.trm|SVG images (*.svg)|*.svg';
  if not OpenDialog.Execute then
    Exit;
  try
    if SameText(ExtractFileExt(OpenDialog.FileName), '.trm') then
      LoadTRM(OpenDialog.FileName)
    else
      ImportNewMap(OpenDialog.FileName);
  except
    on E: Exception do
      MessageDlg('Could not open map: ' + E.Message, mtError, [mbOK], 0);
  end;
end;

procedure TfTRMap.SaveTRM(const AFileName: string);
var
  Ini: TMemIniFile;
  I, J: Integer;
  Section, VectorName, BackgroundName: string;
begin
  if FBitmap = nil then
    raise Exception.Create('Open or import a map before saving.');
  if FSVGPage <> nil then
    VectorName := ChangeFileExt(ExtractFileName(AFileName), '.svg')
  else
    VectorName := '';
  BackgroundName := '';
  if FBitmapFileName <> '' then
    BackgroundName := ChangeFileExt(ExtractFileName(AFileName), '.bmp');
  if FSVGPage <> nil then
    SaveSVG(IncludeTrailingPathDelimiter(ExtractFilePath(AFileName)) +
      VectorName);
  if FBitmapFileName <> '' then
    FBitmap.SaveToFile(IncludeTrailingPathDelimiter(ExtractFilePath(AFileName)) +
      BackgroundName);
  Ini := TMemIniFile.Create(AFileName);
  try
    Ini.WriteString('Map', 'Desc', DescriptionEdit.Text);
    Ini.WriteString('Map', 'Author', AuthorEdit.Text);
    Ini.WriteString('Map', 'Revision', RevisionEdit.Text);
    Ini.WriteString('Map', 'FontName', FontNameEdit.Text);
    Ini.WriteInteger('Map', 'FontSize', FontSizeEdit.Value);
    Ini.WriteInteger('Map', 'TextFG', clBlack);
    Ini.WriteInteger('Map', 'TextBG', clWhite);
    Ini.WriteString('Map', 'VectorFile', VectorName);
    Ini.WriteString('Map', 'BackgroundFile', BackgroundName);
    for I := 1 to TERRITORY_COUNT do begin
      Section := 'Territory_' + IntToStr(I);
      Ini.WriteString(Section, 'Name', FTerritories[I].Name);
      Ini.WriteInteger(Section, 'Cont', FTerritories[I].Continent);
      Ini.WriteInteger(Section, 'Color', FTerritories[I].Color);
      Ini.WriteInteger(Section, 'BCount', Length(FTerritories[I].Borders));
      for J := 0 to TerritoryBorderCounts[I] - 1 do
        Ini.WriteInteger(Section, 'B_' + IntToStr(J + 1),
          TerritoryBorders[I,J + 1]);
      Ini.WriteInteger(Section, 'Tx', FTerritories[I].TextPoint.X);
      Ini.WriteInteger(Section, 'Ty', FTerritories[I].TextPoint.Y);
      Ini.WriteInteger(Section, 'FFCount', Length(FTerritories[I].FloodPoints));
      for J := 0 to High(FTerritories[I].FloodPoints) do begin
        Ini.WriteInteger(Section, 'FF' + IntToStr(J + 1) + 'x',
          FTerritories[I].FloodPoints[J].X);
        Ini.WriteInteger(Section, 'FF' + IntToStr(J + 1) + 'y',
          FTerritories[I].FloodPoints[J].Y);
      end;
    end;
    Ini.UpdateFile;
  finally
    Ini.Free;
  end;
  FFileName := AFileName;
end;

function EscapeXMLAttribute(const AValue: string): string;
begin
  Result := StringReplace(AValue, '&', '&amp;', [rfReplaceAll]);
  Result := StringReplace(Result, '"', '&quot;', [rfReplaceAll]);
  Result := StringReplace(Result, '<', '&lt;', [rfReplaceAll]);
  Result := StringReplace(Result, '>', '&gt;', [rfReplaceAll]);
end;

procedure PreserveSVGEntityNames(AEntity: TvEntity; APathIDs: TStrings;
  var APathIndex: Integer);
var
  Layer: TvLayer;
  Child: TvEntity;
  OldID, NewID: string;
begin
  if AEntity is TPath then begin
    Inc(APathIndex);
    if TPath(AEntity).Name <> '' then begin
      OldID := 'id="path' + IntToStr(APathIndex) + '"';
      NewID := 'id="' + EscapeXMLAttribute(TPath(AEntity).Name) + '"';
      APathIDs.Text := StringReplace(APathIDs.Text, OldID, NewID,
        [rfReplaceAll]);
    end;
  end else if AEntity is TvLayer then begin
    Layer := TvLayer(AEntity);
    Child := Layer.GetFirstEntity;
    while Child <> nil do begin
      PreserveSVGEntityNames(Child, APathIDs, APathIndex);
      Child := Layer.GetNextEntity;
    end;
  end;
end;

procedure TfTRMap.SaveSVG(const AFileName: string);
var
  SVG: TStringList;
  I, PathIndex: Integer;
begin
  if FSVGDocument = nil then
    raise Exception.Create('No SVG document is loaded.');
  FSVGDocument.WriteToFile(AFileName, vfSVG);
  SVG := TStringList.Create;
  try
    SVG.LoadFromFile(AFileName);
    PathIndex := 1;
    for I := 0 to FSVGPage.GetEntitiesCount - 1 do
      PreserveSVGEntityNames(FSVGPage.GetEntity(I), SVG, PathIndex);
    SVG.SaveToFile(AFileName);
  finally
    SVG.Free;
  end;
end;

procedure TfTRMap.SaveMenuClick(Sender: TObject);
begin
  if FFileName = '' then
    SaveAsMenuClick(Sender)
  else
    try
      SaveTRM(FFileName);
      UpdateStatus('Saved ' + FFileName);
    except
      on E: Exception do
        MessageDlg('Could not save map: ' + E.Message, mtError, [mbOK], 0);
    end;
end;

procedure TfTRMap.SaveAsMenuClick(Sender: TObject);
begin
  if SaveDialog.Execute then
    try
      SaveTRM(SaveDialog.FileName);
      UpdateStatus('Saved ' + SaveDialog.FileName);
    except
      on E: Exception do
        MessageDlg('Could not save map: ' + E.Message, mtError, [mbOK], 0);
    end;
end;

procedure TfTRMap.ExitMenuClick(Sender: TObject);
begin
  Close;
end;

procedure TfTRMap.ActiveViewComboChange(Sender: TObject);
begin
  FView := TMapView(ActiveViewCombo.ItemIndex);
  RenderMap;
end;

procedure TfTRMap.TerritoryListClick(Sender: TObject);
begin
  RenderMap;
end;

procedure TfTRMap.AddFloodPoint(ATerritory: Integer; const APoint: TPoint);
var
  N: Integer;
begin
  N := Length(FTerritories[ATerritory].FloodPoints);
  if N >= MAX_FLOOD_POINTS then
    raise Exception.CreateFmt('%s already has the maximum of %d floodfill points.',
      [FTerritories[ATerritory].Name, MAX_FLOOD_POINTS]);
  SetLength(FTerritories[ATerritory].FloodPoints, N + 1);
  FTerritories[ATerritory].FloodPoints[N] := APoint;
  RenderMap;
end;

procedure TfTRMap.MapImageMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  P: TPoint;
  Territory, I, ExistingTerritory: Integer;
  Color: TColor;
  SVGPath: TPath;
begin
  if (Button <> mbLeft) or (MapWidth = 0) then
    Exit;
  P := CanvasToMapPoint(X, Y);
  if not IsMapPoint(P) then
    Exit;
  Territory := TerritoryList.ItemIndex + 1;
  if (FView in [mvTerritories, mvTextBoxes]) and
     ((Territory < 1) or (Territory > TERRITORY_COUNT)) then begin
    UpdateStatus('Select a territory before adding map points.');
    Exit;
  end;
  case FView of
    mvTerritories:
      begin
        if FIsNewMap then begin
          if FTerritories[Territory].Color = clBlack then begin
            Color := RGBToColor((Territory * 73) mod 220 + 24,
              (Territory * 117) mod 220 + 24,
              (Territory * 151) mod 220 + 24);
            FTerritories[Territory].Color := Color;
          end;
          if not FSourceIsSVG then begin
            Color := FBitmap.Canvas.Pixels[P.X, P.Y];
            for I := 1 to TERRITORY_COUNT do
              if (I <> Territory) and
                 (Length(FTerritories[I].FloodPoints) > 0) and
                 (FBitmap.Canvas.Pixels[
                   FTerritories[I].FloodPoints[0].X,
                   FTerritories[I].FloodPoints[0].Y] = Color) then begin
                UpdateStatus('That flat-color region is already assigned to ' +
                  FTerritories[I].Name + '.');
                Exit;
              end;
            FTerritories[Territory].Color := Color;
          end
          else begin
            ExistingTerritory := HitTestTerritory(P);
            if (ExistingTerritory > 0) and
               (ExistingTerritory <> Territory) then begin
              UpdateStatus('That SVG shape is already assigned to ' +
                FTerritories[ExistingTerritory].Name + '.');
              Exit;
            end;
            if ExistingTerritory = 0 then begin
              SVGPath := FindSVGPathAtPoint(P);
              if SVGPath = nil then begin
                UpdateStatus('Click inside a filled SVG territory shape to assign it.');
                Exit;
              end;
              SVGPath.Name := 'tr-territory-' + IntToStr(Territory);
              SVGPath.Brush.Style := bsSolid;
              SVGPath.Brush.Color :=
                TColorToFPColor(FTerritories[Territory].Color);
            end;
          end;
          AddFloodPoint(Territory, P);
          UpdateStatus('Assigned region to ' + FTerritories[Territory].Name + '.');
        end
        else if Length(FTerritories[Territory].FloodPoints) > 0 then begin
          Color := FBitmap.Canvas.Pixels[P.X, P.Y];
          if (FTerritories[Territory].Color <> clBlack) and
             (Color <> FTerritories[Territory].Color) then begin
            UpdateStatus('The selected point color does not match this territory. Choose a point in the matching region.');
            Exit;
          end;
          FTerritories[Territory].Color := Color;
          AddFloodPoint(Territory, P);
        end
        else begin
          FTerritories[Territory].Color := FBitmap.Canvas.Pixels[P.X, P.Y];
          AddFloodPoint(Territory, P);
        end;
      end;
    mvTextBoxes:
      FTerritories[Territory].TextPoint := P;
    mvSimulation:
      begin
        Territory := HitTestTerritory(P);
        if Territory = 0 then Exit;
        FSimulationColor := RGBToColor(Random(220) + 24, Random(220) + 24,
          Random(220) + 24);
      end;
  end;
  RenderMap;
end;

function TfTRMap.FindBitmapRegion(ATerritory: Integer; const ASeed: TPoint;
  ATargetColor: TColor; out APath: TPath): Boolean;
const
  DX: array[0..7] of Integer = (1, 1, 0, -1, -1, -1, 0, 1);
  DY: array[0..7] of Integer = (0, 1, 1, 1, 0, -1, -1, -1);
var
  Queue: array of TPoint;
  Outline: array of TPoint;
  Seen: array of Boolean;
  Head, Tail, I, MinX, MinY, MaxX, MaxY, StartIndex: Integer;
  P, N, Current, Previous, NewPrevious: TPoint;
  SourceColor: TColor;
  Steps, BackIndex, CandidateIndex, PreviousIndex, OutlineCount: Integer;
  FoundNext, IsBoundary: Boolean;
begin
  Result := False;
  APath := nil;
  if not IsMapPoint(ASeed) or (FSVGPage = nil) then
    Exit;
  SourceColor := FBitmap.Canvas.Pixels[ASeed.X, ASeed.Y];
  SetLength(Seen, MapWidth * MapHeight);
  SetLength(Queue, MapWidth * MapHeight);
  Head := 0;
  Tail := 1;
  Queue[0] := ASeed;
  Seen[ASeed.Y * MapWidth + ASeed.X] := True;
  MinX := ASeed.X; MaxX := ASeed.X;
  MinY := ASeed.Y; MaxY := ASeed.Y;
  while Head < Tail do begin
    P := Queue[Head];
    Inc(Head);
    MinX := Min(MinX, P.X); MaxX := Max(MaxX, P.X);
    MinY := Min(MinY, P.Y); MaxY := Max(MaxY, P.Y);
    for I := 0 to 3 do begin
      case I of
        0: N := Point(P.X - 1, P.Y);
        1: N := Point(P.X + 1, P.Y);
        2: N := Point(P.X, P.Y - 1);
        else N := Point(P.X, P.Y + 1);
      end;
      if IsMapPoint(N) and not Seen[N.Y * MapWidth + N.X] and
         (FBitmap.Canvas.Pixels[N.X, N.Y] = SourceColor) then begin
        Seen[N.Y * MapWidth + N.X] := True;
        Queue[Tail] := N;
        Inc(Tail);
      end;
    end;
  end;
  if Tail < 9 then
    Exit;
  if ((MaxX - MinX) > MapWidth * 3 div 4) or
     ((MaxY - MinY) > MapHeight * 3 div 4) then
    Exit;

  StartIndex := -1;
  for I := 0 to Tail - 1 do begin
    P := Queue[I];
    IsBoundary := False;
    for CandidateIndex := 0 to 3 do begin
      case CandidateIndex of
        0: N := Point(P.X - 1, P.Y);
        1: N := Point(P.X + 1, P.Y);
        2: N := Point(P.X, P.Y - 1);
        else N := Point(P.X, P.Y + 1);
      end;
      if not IsMapPoint(N) or not Seen[N.Y * MapWidth + N.X] then begin
        IsBoundary := True;
        Break;
      end;
    end;
    if IsBoundary and ((StartIndex < 0) or (P.Y < Queue[StartIndex].Y) or
       ((P.Y = Queue[StartIndex].Y) and (P.X < Queue[StartIndex].X))) then
      StartIndex := I;
  end;
  if StartIndex < 0 then
    Exit;

  Current := Queue[StartIndex];
  Previous := Point(Current.X - 1, Current.Y);
  SetLength(Outline, 16);
  OutlineCount := 0;
  Steps := 0;
  repeat
    if OutlineCount = Length(Outline) then
      SetLength(Outline, Length(Outline) * 2);
    Outline[OutlineCount] := Current;
    Inc(OutlineCount);
    BackIndex := 4;
    for I := 0 to 7 do
      if (Current.X + DX[I] = Previous.X) and
         (Current.Y + DY[I] = Previous.Y) then begin
        BackIndex := I;
        Break;
      end;
    FoundNext := False;
    for I := 1 to 8 do begin
      CandidateIndex := (BackIndex + I) mod 8;
      N := Point(Current.X + DX[CandidateIndex],
        Current.Y + DY[CandidateIndex]);
      if IsMapPoint(N) and Seen[N.Y * MapWidth + N.X] then begin
        PreviousIndex := (CandidateIndex + 7) mod 8;
        NewPrevious := Point(Current.X + DX[PreviousIndex],
          Current.Y + DY[PreviousIndex]);
        FoundNext := True;
        Break;
      end;
    end;
    if not FoundNext then
      Break;
    if (N.X = Queue[StartIndex].X) and (N.Y = Queue[StartIndex].Y) then
      Break;
    Previous := NewPrevious;
    Current := N;
    Inc(Steps);
  until Steps > Tail * 8;

  if (OutlineCount < 4) or (Steps > Tail * 8) then
    Exit;
  SetLength(Outline, OutlineCount);
  APath := TPath.Create(FSVGPage);
  APath.Name := 'tr-territory-' + IntToStr(ATerritory);
  APath.Pen.Style := psClear;
  APath.Brush.Style := bsSolid;
  APath.Brush.Color := TColorToFPColor(ATargetColor);
  APath.AppendMoveToSegment(Outline[0].X, MapHeight - Outline[0].Y);
  for I := 1 to High(Outline) do
    APath.AppendLineToSegment(Outline[I].X, MapHeight - Outline[I].Y);
  APath.AppendLineToSegment(Outline[0].X, MapHeight - Outline[0].Y);
  Result := APath.Len > 3;
end;

procedure TfTRMap.AutoFindButtonClick(Sender: TObject);
var
  Territory, I, J, Found: Integer;
  P: TPoint;
  Color: TColor;
  Path: TPath;
begin
  if FBitmap = nil then
    Exit;
  if FIsNewMap and not FSourceIsSVG then begin
    FreeAndNil(FSVGDocument);
    FSVGDocument := TvVectorialDocument.Create;
    FSVGPage := FSVGDocument.AddPage as TvVectorialPage;
    AddSVGMapBounds;
    FIsNewMap := True;
    Found := 0;
    for Territory := 1 to TERRITORY_COUNT do begin
      if Length(FTerritories[Territory].FloodPoints) = 0 then
        Continue;
      Color := FTerritories[Territory].Color;
      for J := 0 to High(FTerritories[Territory].FloodPoints) do begin
        P := FTerritories[Territory].FloodPoints[J];
        if FindBitmapRegion(Territory, P, Color, Path) then begin
          FSVGPage.AddEntity(Path);
          Inc(Found);
        end
        else
          Path.Free;
      end;
    end;
    UpdateStatus(Format('Traced %d flat-color regions to vector paths. Review and edit complex or connected artwork before using.', [Found]));
  end
  else if FIsNewMap then
    UpdateStatus('SVG territory shapes are already vector. Add more territory shapes by assigning them in the map view.')
  else begin
    Found := 0;
    for Territory := 1 to TERRITORY_COUNT do begin
      if Length(FTerritories[Territory].FloodPoints) = 0 then
        Continue;
      Color := FTerritories[Territory].Color;
      P := FTerritories[Territory].FloodPoints[0];
      for I := 1 to MAX_FLOOD_POINTS do
        if (P.X + I < MapWidth) and (P.Y + I < MapHeight) and
           (FBitmap.Canvas.Pixels[P.X + I, P.Y] = Color) then begin
          AddFloodPoint(Territory, Point(P.X + I, P.Y));
          Inc(Found);
          Break;
        end;
    end;
    UpdateStatus(Format('Added %d additional same-color floodfill points.', [Found]));
  end;
  RenderMap;
end;

procedure TfTRMap.ClearFloodPoints;
var
  I: Integer;
begin
  for I := 1 to TERRITORY_COUNT do
    SetLength(FTerritories[I].FloodPoints, 0);
  RenderMap;
end;

procedure TfTRMap.ClearAllButtonClick(Sender: TObject);
begin
  if MessageDlg('Clear all territory floodfill points?', mtConfirmation,
    [mbYes, mbNo], 0) <> mrYes then
    Exit;
  ClearFloodPoints;
end;

procedure TfTRMap.TransformMapPoints(ScaleX, ScaleY: Double);
var
  I, J: Integer;
begin
  for I := 1 to TERRITORY_COUNT do begin
    FTerritories[I].TextPoint.X := Round(FTerritories[I].TextPoint.X *
      ScaleX);
    FTerritories[I].TextPoint.Y := Round(FTerritories[I].TextPoint.Y *
      ScaleY);
    for J := 0 to High(FTerritories[I].FloodPoints) do begin
      FTerritories[I].FloodPoints[J].X := Round(
        FTerritories[I].FloodPoints[J].X * ScaleX);
      FTerritories[I].FloodPoints[J].Y := Round(
        FTerritories[I].FloodPoints[J].Y * ScaleY);
    end;
  end;
  RenderMap;
end;

procedure TfTRMap.TransformButtonClick(Sender: TObject);
begin
  TransformMapPoints(TransformXEdit.Value, TransformYEdit.Value);
end;

procedure TfTRMap.NewVersionButtonClick(Sender: TObject);
begin
  ImportBMPButtonClick(Sender);
end;

procedure TfTRMap.ValidateButtonClick(Sender: TObject);
var
  Report: string;
begin
  ValidateMap(Report);
  MessageDlg(Report, mtInformation, [mbOK], 0);
end;

function TfTRMap.ValidateMap(out AReport: string): Boolean;
var
  I, J, Errors, Warnings: Integer;
  P, Q: TPoint;
  Found: Boolean;
  Report: TStringList;
begin
  Errors := 0;
  Warnings := 0;
  Result := False;
  Report := TStringList.Create;
  try
    if (FSVGPage = nil) and (FBitmap = nil) then begin
      Report.Add('ERROR: No bitmap/vector artwork is loaded.');
      Inc(Errors);
    end;
    for I := 1 to TERRITORY_COUNT do begin
      if FTerritories[I].Continent <> TerritoryContinents[I] then begin
        Report.Add(Format('ERROR: Territory %d has an unexpected continent.', [I]));
        Inc(Errors);
      end;
      if Length(FTerritories[I].FloodPoints) = 0 then begin
        Report.Add(Format('ERROR: Territory %d (%s) has no floodfill point.',
          [I, FTerritories[I].Name]));
        Inc(Errors);
      end;
      if FIsNewMap and ((FSVGPage = nil) or
         (FSVGPage.FindEntityWithNameAndType('tr-territory-' + IntToStr(I),
           TPath, True) = nil)) then begin
        Report.Add(Format('ERROR: Territory %d has no assigned vector shape.', [I]));
        Inc(Errors);
      end;
      if Length(FTerritories[I].FloodPoints) > MAX_FLOOD_POINTS then begin
        Report.Add(Format('ERROR: Territory %d exceeds the floodfill point limit.',
          [I]));
        Inc(Errors);
      end;
      if (FTerritories[I].TextPoint.X < 0) or
         (FTerritories[I].TextPoint.Y < 0) or
         (FTerritories[I].TextPoint.X >= MapWidth) or
         (FTerritories[I].TextPoint.Y >= MapHeight) then begin
        Report.Add(Format('WARNING: Territory %d text position is outside the map.',
          [I]));
        Inc(Warnings);
      end;
      for J := 0 to High(FTerritories[I].FloodPoints) do begin
        P := FTerritories[I].FloodPoints[J];
        if not IsMapPoint(P) then begin
          Report.Add(Format('ERROR: Territory %d has a floodfill point outside the map.',
            [I]));
          Inc(Errors);
          Continue;
        end;
        if not FIsNewMap and (FSVGPage = nil) and (FBitmap <> nil) and
           (FBitmap.Canvas.Pixels[P.X, P.Y] <> FTerritories[I].Color) then begin
          Report.Add(Format('ERROR: Territory %d floodfill point %d has the wrong bitmap color.',
            [I, J + 1]));
          Inc(Errors);
        end;
      end;
      if Length(FTerritories[I].Borders) <> TerritoryBorderCounts[I] then begin
        Report.Add(Format('ERROR: Territory %d does not match the fixed Risk topology.', [I]));
        Inc(Errors);
      end
      else
        for J := 0 to TerritoryBorderCounts[I] - 1 do begin
          Q := Point(FTerritories[I].Borders[J], 0);
          if (Q.X < 1) or (Q.X > TERRITORY_COUNT) or
             (Q.X <> TerritoryBorders[I,J + 1]) then begin
            Report.Add(Format('ERROR: Territory %d has invalid border %d.',
              [I, Q.X]));
            Inc(Errors);
          end;
        end;
      Found := False;
      for J := 1 to TerritoryBorderCounts[I] do
        if TerritoryBorders[I,J] = I then
          Found := True;
      if Found then begin
        Report.Add(Format('ERROR: Territory %d borders itself.', [I]));
        Inc(Errors);
      end;
    end;
    if (Errors = 0) and (Warnings = 0) then
      Report.Add('Map validation passed.');
    Report.Insert(0, Format('Validation: %d error(s), %d warning(s).',
      [Errors, Warnings]));
    AReport := Report.Text;
    Result := (Errors = 0) and (Warnings = 0);
  finally
    Report.Free;
  end;
end;

procedure TfTRMap.SimulationColorButtonClick(Sender: TObject);
begin
  ColorDialog.Color := FSimulationColor;
  if ColorDialog.Execute then begin
    FSimulationColor := ColorDialog.Color;
    RenderMap;
  end;
end;

end.
