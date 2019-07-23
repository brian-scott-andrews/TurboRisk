unit Territ;

interface

// Load a map from file
procedure LoadMap;

// Resize main window according to map and toolbar
procedure ResizeMainWindow;

// Setup static info about territories
procedure SetupTerritories;

// Determina indice territorio in base alle coordinate di un punto sulla mappa
function TrovaTerritorio(iX, iY: integer): integer;

// Visualizza un territorio
procedure DisplayTerritory(iTerritory: integer);

// Assegnazione territorio ad un giocatore
procedure AssegnaTerritorio(iT, iG: integer);

// Collocazione di n armate su un territorio
procedure CollocaArmata(iT, iG, iArmies: integer);

// Verifica se due territori sono confinanti
function Confinante(iFrom, iTo: integer): boolean;

// Verifica se un territorio è proprio e confina con territori nemici
function Confine(iT: integer): boolean;

implementation

uses Forms, Graphics, SysUtils, Classes, ExtCtrls, IniFiles, Math,
  Globals, Main, Stats, Log, Sim, SimMap;

// Resize main window according to map and toolbar
procedure ResizeMainWindow;
begin
  with fMain do begin
    if bPrefShowToolbar then begin
      ClientWidth := max(fMain.panMap.Width + 2,
        cmdEndTurn.Left + cmdEndTurn.Width + 5);
      panMap.Top := tlbToolbar.Height;
      ClientHeight := panMap.Height + 21 + tlbToolbar.Height;
    end
    else begin
      ClientWidth := fMain.panMap.Width + 2;
      panMap.Top := 0;
      ClientHeight := panMap.Height + 21;
    end;
  end;
end;

// Load a map from file
procedure LoadMap;
var
  IniFile: TIniFile;
  i, iT: integer;
  sBitmapFile, sSection: string;
begin

  // load bitmap
  sBitmapFile := ChangeFileExt(sG_AppPath + 'maps\' + sMapFile, '.bmp');
  BaseMap.LoadFromFile(sBitmapFile);
  if bG_TRSim then begin // TRSim
    fSimMap.imgMap.Picture.Assign(BaseMap);
  end
  else begin // TurboRisk
    fMain.imgMap.Picture.Assign(BaseMap);
    // resize main window according to map
    ResizeMainWindow;
  end;
  // load map data
  IniFile := TIniFile.Create(sG_AppPath + 'maps\' + sMapFile);
  try
    with IniFile do begin
      // load general info
      sMapDesc := ReadString('Map', 'Desc', '');
      sMapFontName := ReadString('Map', 'FontName', 'Courier New');
      iMapFontSize := ReadInteger('Map', 'FontSize', 8);
      tMapTextFG := ReadInteger('Map', 'TextFG', clBlack);
      tMapTextBG := ReadInteger('Map', 'TextBG', clWhite);
      // load territories
      for iT := 1 to MAXTERRITORIES do begin
        with arTerritory[iT] do begin
          sSection := 'Territory_' + IntToStr(iT);
          Color := ReadInteger(sSection, 'Color', clBlack);
          Coord := Point(ReadInteger(sSection, 'Tx', 0),
            ReadInteger(sSection, 'Ty', 0));
          NOrig := ReadInteger(sSection, 'FFCount', 0);
          for i := 1 to NOrig do
            Orig[i] := Point(ReadInteger(sSection, 'FF' + IntToStr(i) + 'x',
                0), ReadInteger(sSection, 'FF' + IntToStr(i) + 'y', 0));
        end;
      end;
    end;
  finally
    IniFile.Free;
  end;
end;

// Setup static info about territories
procedure SetupTerritories;
var
  i: integer;
begin
  with arTerritory[1] do begin
    Name := 'Alaska';
    NBord := 3;
    Bord[1] := 2;
    Bord[2] := 4;
    Bord[3] := 37;
  end;
  with arTerritory[2] do begin
    Name := 'Northwest Territory';
    NBord := 4;
    Bord[1] := 1;
    Bord[2] := 3;
    Bord[3] := 4;
    Bord[4] := 5;
  end;
  with arTerritory[3] do begin
    Name := 'Greenland';
    NBord := 4;
    Bord[1] := 2;
    Bord[2] := 5;
    Bord[3] := 6;
    Bord[4] := 20;
  end;
  with arTerritory[4] do begin
    Name := 'Alberta';
    NBord := 4;
    Bord[1] := 1;
    Bord[2] := 2;
    Bord[3] := 5;
    Bord[4] := 7;
  end;
  with arTerritory[5] do begin
    Name := 'Ontario';
    NBord := 6;
    Bord[1] := 2;
    Bord[2] := 3;
    Bord[3] := 4;
    Bord[4] := 6;
    Bord[5] := 7;
    Bord[6] := 8;
  end;
  with arTerritory[6] do begin
    Name := 'Quebec';
    NBord := 3;
    Bord[1] := 3;
    Bord[2] := 5;
    Bord[3] := 8;
  end;
  with arTerritory[7] do begin
    Name := 'Western US';
    NBord := 4;
    Bord[1] := 4;
    Bord[2] := 5;
    Bord[3] := 8;
    Bord[4] := 9;
  end;
  with arTerritory[8] do begin
    Name := 'Eastern US';
    NBord := 4;
    Bord[1] := 5;
    Bord[2] := 6;
    Bord[3] := 7;
    Bord[4] := 9;
  end;
  with arTerritory[9] do begin
    Name := 'Central America';
    NBord := 3;
    Bord[1] := 7;
    Bord[2] := 8;
    Bord[3] := 10;
  end;
  with arTerritory[10] do begin
    Name := 'Venezuela';
    NBord := 3;
    Bord[1] := 9;
    Bord[2] := 11;
    Bord[3] := 12;
  end;
  with arTerritory[11] do begin
    Name := 'Peru';
    NBord := 3;
    Bord[1] := 10;
    Bord[2] := 12;
    Bord[3] := 13;
  end;
  with arTerritory[12] do begin
    Name := 'Brazil';
    NBord := 4;
    Bord[1] := 10;
    Bord[2] := 11;
    Bord[3] := 13;
    Bord[4] := 14;
  end;
  with arTerritory[13] do begin
    Name := 'Argentina';
    NBord := 2;
    Bord[1] := 11;
    Bord[2] := 12;
  end;
  with arTerritory[14] do begin
    Name := 'North Africa';
    NBord := 6;
    Bord[1] := 25;
    Bord[2] := 26;
    Bord[3] := 12;
    Bord[4] := 15;
    Bord[5] := 16;
    Bord[6] := 17;
  end;
  with arTerritory[15] do begin
    Name := 'Egypt';
    NBord := 4;
    Bord[1] := 14;
    Bord[2] := 16;
    Bord[3] := 26;
    Bord[4] := 27;
  end;
  with arTerritory[16] do begin
    Name := 'East Africa';
    NBord := 6;
    Bord[1] := 14;
    Bord[2] := 15;
    Bord[3] := 17;
    Bord[4] := 18;
    Bord[5] := 19;
    Bord[6] := 27;
  end;
  with arTerritory[17] do begin
    Name := 'Congo';
    NBord := 3;
    Bord[1] := 14;
    Bord[2] := 16;
    Bord[3] := 18;
  end;
  with arTerritory[18] do begin
    Name := 'South Africa';
    NBord := 3;
    Bord[1] := 16;
    Bord[2] := 17;
    Bord[3] := 19;
  end;
  with arTerritory[19] do begin
    Name := 'Madagascar';
    NBord := 2;
    Bord[1] := 16;
    Bord[2] := 18;
  end;
  with arTerritory[20] do begin
    Name := 'Iceland';
    NBord := 3;
    Bord[1] := 3;
    Bord[2] := 21;
    Bord[3] := 24;
  end;
  with arTerritory[21] do begin
    Name := 'Scandinavia';
    NBord := 4;
    Bord[1] := 20;
    Bord[2] := 22;
    Bord[3] := 23;
    Bord[4] := 24;
  end;
  with arTerritory[22] do begin
    Name := 'Ukraine';
    NBord := 6;
    Bord[1] := 21;
    Bord[2] := 23;
    Bord[3] := 26;
    Bord[4] := 27;
    Bord[5] := 28;
    Bord[6] := 29;
  end;
  with arTerritory[23] do begin
    Name := 'Northern Europe';
    NBord := 5;
    Bord[1] := 21;
    Bord[2] := 22;
    Bord[3] := 24;
    Bord[4] := 25;
    Bord[5] := 26;
  end;
  with arTerritory[24] do begin
    Name := 'Great Britain';
    NBord := 4;
    Bord[1] := 20;
    Bord[2] := 21;
    Bord[3] := 23;
    Bord[4] := 25;
  end;
  with arTerritory[25] do begin
    Name := 'Western Europe';
    NBord := 4;
    Bord[1] := 23;
    Bord[2] := 24;
    Bord[3] := 26;
    Bord[4] := 14;
  end;
  with arTerritory[26] do begin
    Name := 'Southern Europe';
    NBord := 6;
    Bord[1] := 22;
    Bord[2] := 23;
    Bord[3] := 25;
    Bord[4] := 27;
    Bord[5] := 14;
    Bord[6] := 15;
  end;
  with arTerritory[27] do begin
    Name := 'Middle East';
    NBord := 6;
    Bord[1] := 22;
    Bord[2] := 26;
    Bord[3] := 15;
    Bord[4] := 16;
    Bord[5] := 29;
    Bord[6] := 30;
  end;
  with arTerritory[28] do begin
    Name := 'Yamal-Nemets';
    NBord := 4;
    Bord[1] := 22;
    Bord[2] := 29;
    Bord[3] := 33;
    Bord[4] := 34;
  end;
  with arTerritory[29] do begin
    Name := 'Kazakhstan';
    NBord := 5;
    Bord[1] := 22;
    Bord[2] := 28;
    Bord[3] := 27;
    Bord[4] := 30;
    Bord[5] := 32;
  end;
  with arTerritory[30] do begin
    Name := 'India';
    NBord := 4;
    Bord[1] := 27;
    Bord[2] := 29;
    Bord[3] := 31;
    Bord[4] := 32;
  end;
  with arTerritory[31] do begin
    Name := 'Siam';
    NBord := 3;
    Bord[1] := 30;
    Bord[2] := 32;
    Bord[3] := 39;
  end;
  with arTerritory[32] do begin
    Name := 'China';
    NBord := 4;
    Bord[1] := 29;
    Bord[2] := 30;
    Bord[3] := 31;
    Bord[4] := 33;
  end;
  with arTerritory[33] do begin
    Name := 'Mongolia';
    NBord := 6;
    Bord[1] := 28;
    Bord[2] := 32;
    Bord[3] := 34;
    Bord[4] := 36;
    Bord[5] := 37;
    Bord[6] := 38;
  end;
  with arTerritory[34] do begin
    Name := 'Taymyr';
    NBord := 4;
    Bord[1] := 28;
    Bord[2] := 33;
    Bord[3] := 35;
    Bord[4] := 36;
  end;
  with arTerritory[35] do begin
    Name := 'Yakut';
    NBord := 3;
    Bord[1] := 34;
    Bord[2] := 36;
    Bord[3] := 37;
  end;
  with arTerritory[36] do begin
    Name := 'Buryat';
    NBord := 4;
    Bord[1] := 33;
    Bord[2] := 34;
    Bord[3] := 35;
    Bord[4] := 37;
  end;
  with arTerritory[37] do begin
    Name := 'Koryak';
    NBord := 5;
    Bord[1] := 1;
    Bord[2] := 33;
    Bord[3] := 35;
    Bord[4] := 36;
    Bord[5] := 38;
  end;
  with arTerritory[38] do begin
    Name := 'Japan';
    NBord := 2;
    Bord[1] := 33;
    Bord[2] := 37;
  end;
  with arTerritory[39] do begin
    Name := 'Indonesia';
    NBord := 3;
    Bord[1] := 31;
    Bord[2] := 40;
    Bord[3] := 42;
  end;
  with arTerritory[40] do begin
    Name := 'Western Australia';
    NBord := 3;
    Bord[1] := 39;
    Bord[2] := 41;
    Bord[3] := 42;
  end;
  with arTerritory[41] do begin
    Name := 'Eastern Australia';
    NBord := 2;
    Bord[1] := 40;
    Bord[2] := 42;
  end;
  with arTerritory[42] do begin
    Name := 'New Guinea';
    NBord := 3;
    Bord[1] := 39;
    Bord[2] := 40;
    Bord[3] := 41;
  end;

  // Assign territories to continents
  for i := 1 to 9 do
    arTerritory[i].Contin := coNA;
  for i := 10 to 13 do
    arTerritory[i].Contin := coSA;
  for i := 14 to 19 do
    arTerritory[i].Contin := coAF;
  for i := 20 to 26 do
    arTerritory[i].Contin := coEU;
  for i := 27 to 38 do
    arTerritory[i].Contin := coAS;
  for i := 39 to 42 do
    arTerritory[i].Contin := coAU;

  // Continent names
  arContinent[coNA].Name := 'NA';
  arContinent[coSA].Name := 'SA';
  arContinent[coAF].Name := 'Af';
  arContinent[coEU].Name := 'Eu';
  arContinent[coAS].Name := 'As';
  arContinent[coAU].Name := 'Au';

  // Bonus armies per continent
  arContinent[coNA].Bonus := 5;
  arContinent[coSA].Bonus := 2;
  arContinent[coAF].Bonus := 3;
  arContinent[coEU].Bonus := 5;
  arContinent[coAS].Bonus := 7;
  arContinent[coAU].Bonus := 2;
end;

// Determina indice territorio in base alle coordinate di un punto sulla mappa
function TrovaTerritorio(iX, iY: integer): integer;
var
  ColoreBase: TColor;
  i: integer;
begin
  ColoreBase := BaseMap.Canvas.Pixels[iX, iY];
  for i := 1 to MAXTERRITORIES do begin
    if arTerritory[i].Color = ColoreBase then begin
      Result := i;
      exit;
    end;
  end;
  Result := 0;
end;

// Visualizza un territorio
procedure DisplayTerritory(iTerritory: integer);
var
  iOrig: integer;
  ColoPrec: TColor;
  sArmies: string;
  imgDynMap: TImage;
begin
  if bG_TRSim then begin // TRSim
    if not fSim.chkShowMap.Checked then
      exit;
    imgDynMap := fSimMap.imgMap;
  end
  else begin // TurboRisk
    imgDynMap := fMain.imgMap;
  end;
  with imgDynMap, arTerritory[iTerritory] do begin
    // Color
    if (iTerritory = GetFromTerritory) or (iTerritory = GetToTerritory) then
    begin
      if bPrefMapSelected then
        Canvas.Brush.Color := ChangeColor(arPlayer[Owner].Color,
          iPrefMapSelected)
      else
        Canvas.Brush.Color := arPlayer[Owner].Color;
    end
    else if bPrefMapHoover and (iTerritory = GetHooverTerritory) then begin
      Canvas.Brush.Color := ChangeColor(arPlayer[Owner].Color, iPrefMapHoover);
    end
    else begin
      Canvas.Brush.Color := arPlayer[Owner].Color;
    end;
    ColoPrec := Canvas.Pixels[Orig[1].X, Orig[1].Y];
    for iOrig := 1 to NOrig do
      Canvas.FloodFill(Orig[iOrig].X, Orig[iOrig].Y, ColoPrec, fsSurface);

    // Armies
    Canvas.Font.Name := sMapFontName;
    Canvas.Font.Size := iMapFontSize;
    Canvas.Font.Color := tMapTextFG;
    Canvas.Brush.Color := tMapTextBG;
    sArmies := FormatFloat('000', Army);
    if length(sArmies) > 3 then
      sArmies := copy(sArmies, 1, 3);
    Canvas.TextOut(Coord.X, Coord.Y, sArmies);
  end;
end;

// Assegnazione territorio ad un giocatore
procedure AssegnaTerritorio(iT, iG: integer);
var
  iT2, iProp2: integer;
begin
  with arTerritory[iT] do begin
    // Se il territorio era vergine, riduco il numero di territori da assegnare
    if (Owner = 0) and (iToAssign > 0) then
      dec(iToAssign);
    // Se apparteneva ad un altro giocatore, riduco il suo numero di territori posseduti
    if Owner > 0 then
      dec(arPlayer[Owner].Territ);
    // Assegno la proprietà
    Owner := iG;
    // Incremento il contatore di territori posseduti
    inc(arPlayer[iG].Territ);
  end;

  // Aggiorno il controllo del continente
  iProp2 := iG;
  for iT2 := 1 to MAXTERRITORIES do begin
    if arTerritory[iT2].Contin = arTerritory[iT].Contin then begin
      if arTerritory[iT2].Owner <> iProp2 then begin
        iProp2 := 0;
        break;
      end;
    end;
  end;
  arContinent[arTerritory[iT].Contin].Owner := iProp2;

  // Aggiornamento statistiche
  UpdateStats;
end;

// Collocazione di n armate su un territorio
procedure CollocaArmata(iT, iG, iArmies: integer);
begin
  if iArmies > arPlayer[iG].NewArmy then
    iArmies := arPlayer[iG].NewArmy;
  inc(arTerritory[iT].Army, iArmies);
  dec(arPlayer[iG].NewArmy, iArmies);
  // Log
  if arPlayer[iTurn].KeepLog then
    ScriviLog(IntToStr(iArmies) + ' army(s) placed in ' + arTerritory[iT]
      .Name + '.');
  // Aggiornamento display e statistiche
  DisplayTerritory(iT);
  UpdateStats;
  Application.ProcessMessages;
end;

// Verifica se due territori sono confinanti
function Confinante(iFrom, iTo: integer): boolean;
var
  iT: integer;
begin
  for iT := 1 to arTerritory[iFrom].NBord do
    if arTerritory[iFrom].Bord[iT] = iTo then begin
      Result := true;
      exit;
    end;
  Result := false;
end;

// Verifica se un territorio è proprio e confina con territori nemici
function Confine(iT: integer): boolean;
var
  iC: integer;
begin
  if arTerritory[iT].Owner = iTurn then begin
    for iC := 1 to arTerritory[iT].NBord do begin
      if arTerritory[arTerritory[iT].Bord[iC]].Owner <> iTurn then begin
        Result := true;
        exit;
      end;
    end;
  end;
  Result := false;
end;

end.
