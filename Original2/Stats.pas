unit Stats;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  Grids, Menus;

type
  TfStats = class(TForm)
    grdStats: TStringGrid;
    mnuStats: TPopupMenu;
    mnuStaTer: TMenuItem;
    mnuStaArm: TMenuItem;
    mnuStaCon: TMenuItem;
    mnuStaCar: TMenuItem;
    mnuStaCTIV: TMenuItem;
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure mnuStaTerClick(Sender: TObject);
    procedure mnuStaArmClick(Sender: TObject);
    procedure mnuStaConClick(Sender: TObject);
    procedure mnuStaCarClick(Sender: TObject);
    procedure grdStatsDrawCell(Sender: TObject; ACol, ARow: Integer;
      Rect: TRect; State: TGridDrawState);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure mnuStaCTIVClick(Sender: TObject);
  private
    bReady: boolean;
    procedure GridSetup;
  public
    { Public declarations }
  end;

var
  fStats: TfStats;

  // Aggiorna visualizzazione statistiche
procedure UpdateStats;

// Aggiorna riga selezionata griglia
procedure UpdateGridPos;

implementation

{$R *.DFM}

uses Globals, Main, ExpSubr;

procedure TfStats.FormCreate(Sender: TObject);
begin
  with grdStats do begin
    Cells[0, 0] := 'Player';
    Cells[1, 0] := 'Territ.';
    Cells[2, 0] := 'Armies';
    Cells[3, 0] := 'Continents';
    Cells[4, 0] := 'Cards';
    Cells[5, 0] := 'CTIV';
  end;
end;

procedure TfStats.FormShow(Sender: TObject);
begin
  bReady := false;
  mnuStaTer.Checked := bStOpTer;
  mnuStaArm.Checked := bStOpArm;
  mnuStaCon.Checked := bStOpCon;
  mnuStaCar.Checked := bStOpCar;
  mnuStaCTIV.Checked := bStOpCTIV;
  GridSetup;
  UpdateStats;
  bReady := true;
  fMain.mnuVieStats.Checked := true;
  fMain.cmdStatistics.Down := true;
end;

procedure TfStats.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  fMain.mnuVieStats.Checked := false;
  fMain.cmdStatistics.Down := false;
end;

// Aggiorna visualizzazione statistiche
procedure UpdateStats;
var
  iG, iG2, iT: Integer;
  tCont: TContId;
begin
  if not fStats.Visible then
    exit;
  with fStats.grdStats do begin

    if GameState = gsStopped then begin

      for iG := 1 to MAXPLAYERS do begin
        Cells[0, iG] := '-';
        Cells[1, iG] := '-';
        Cells[2, iG] := '-';
        Cells[3, iG] := '-';
        Cells[4, iG] := '-';
        Cells[5, iG] := '-';
      end;

    end
    else begin

      for iG := 1 to MAXPLAYERS do begin
        iG2 := aiTurnList[iG];
        Cells[0, iG] := arPlayer[iG2].Name;
        if arPlayer[iG2].Active then begin
          Cells[1, iG] := IntToStr(arPlayer[iG2].Territ);
          Cells[3, iG] := '';
          arPlayer[iG2].Army := 0;
          Cells[4, iG] := IntToStr
          (arPlayer[iG2].Cards[caInf] + arPlayer[iG2].Cards[caCav] + arPlayer
            [iG2].Cards[caArt] + arPlayer[iG2].Cards[caJok]);
          if (RCardsValueType = cvConstant) or not PAlive(iG2) then
            Cells[5, iG] := '-'
          else
            Cells[5, iG] := IntToStr(PCardTurnInValue(iG2));
        end
        else begin
          Cells[1, iG] := '-';
          Cells[2, iG] := '-';
          Cells[3, iG] := '-';
          Cells[4, iG] := '-';
          Cells[5, iG] := '-';
        end;
      end;
      for iT := 1 to MAXTERRITORIES do begin
        inc(arPlayer[arTerritory[iT].Owner].Army, arTerritory[iT].Army);
      end;
      for iG := 1 to MAXPLAYERS do begin
        iG2 := aiTurnList[iG];
        if arPlayer[iG2].Active then begin
          Cells[2, iG] := IntToStr(arPlayer[iG2].Army) + ' (' + IntToStr
          (arPlayer[iG2].NewArmy) + ')';
        end;
      end;
      for tCont := coNA to coAU do begin
        iG2 := arContinent[tCont].Owner;
        iG := 0;
        if iG2 > 0 then begin
          repeat
            inc(iG);
          until aiTurnList[iG] = iG2;
          Cells[3, iG] := Cells[3, iG] + arContinent[tCont].Name + ' ';
        end;
      end;

    end;
  end;

end;

// Aggiorna riga selezionata griglia
procedure UpdateGridPos;
var
  Selez: TGridRect;
begin
  if not fStats.Visible then
    exit;
  Selez.Top := iTurn;
  Selez.Left := 1;
  Selez.Bottom := iTurn;
  Selez.Right := 1;
  fStats.grdStats.Selection := Selez;
end;

procedure TfStats.GridSetup;
begin
  with fStats.grdStats do begin
    ColWidths[0] := 65;
    if bStOpTer then
      ColWidths[1] := 35
    else
      ColWidths[1] := 0;
    if bStOpArm then
      ColWidths[2] := 50
    else
      ColWidths[2] := 0;
    if bStOpCon then
      ColWidths[3] := 100
    else
      ColWidths[3] := 0;
    if bStOpCar then
      ColWidths[4] := 35
    else
      ColWidths[4] := 0;
    if bStOpCTIV then
      ColWidths[5] := 35
    else
      ColWidths[5] := 0;
    Width := ColWidths[0] + ColWidths[1] + ColWidths[2] + ColWidths[3]
    + ColWidths[4] + ColWidths[5] + GridlineWidth * 5;
    fStats.ClientWidth := Width;
  end;
end;

procedure TfStats.grdStatsDrawCell(Sender: TObject; ACol, ARow: Integer;
  Rect: TRect; State: TGridDrawState);
var
  tBG, tFG: TColor;
begin
  with grdStats.Canvas do begin
    if ARow = 0 then begin
      tBG := clLtGray;
      tFG := clBlack;
    end
    else if (GameState <> gsStopped) and (ACol = 0) and
    (arPlayer[aiTurnList[ARow]].Active) then begin
      tBG := arPlayer[aiTurnList[ARow]].Color;
      tFG := BestTextColor(tBG);
    end
    else begin
      tBG := clWhite;
      tFG := clBlack;
    end;
    Brush.Color := tBG;
    Font.Color := tFG;
    FillRect(Rect);
    if (ARow = 0) or (arPlayer[aiTurnList[ARow]].Active) then begin
      TextOut(Rect.Left + 1, Rect.Top + 1, grdStats.Cells[ACol, ARow]);
    end;
  end;
end;

procedure TfStats.mnuStaTerClick(Sender: TObject);
begin
  if not bReady then
    exit;
  bStOpTer := not bStOpTer;
  mnuStaTer.Checked := bStOpTer;
  GridSetup;
end;

procedure TfStats.mnuStaArmClick(Sender: TObject);
begin
  if not bReady then
    exit;
  bStOpArm := not bStOpArm;
  mnuStaArm.Checked := bStOpArm;
  GridSetup;
end;

procedure TfStats.mnuStaConClick(Sender: TObject);
begin
  if not bReady then
    exit;
  bStOpCon := not bStOpCon;
  mnuStaCon.Checked := bStOpCon;
  GridSetup;
end;

procedure TfStats.mnuStaCTIVClick(Sender: TObject);
begin
  if not bReady then
    exit;
  bStOpCTIV := not bStOpCTIV;
  mnuStaCTIV.Checked := bStOpCTIV;
  GridSetup;
end;

procedure TfStats.mnuStaCarClick(Sender: TObject);
begin
  if not bReady then
    exit;
  bStOpCar := not bStOpCar;
  mnuStaCar.Checked := bStOpCar;
  GridSetup;
end;

end.
