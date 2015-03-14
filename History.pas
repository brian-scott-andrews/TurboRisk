unit History;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, Grids, ComCtrls, JvExGrids, JvStringGrid, Contnrs, ExtCtrls,
  StdCtrls, Buttons;

type
  TPStat = class(TObject)
  public
    player: string; // player's name
    games, // number of games played
    won, // number of games won
    points: integer; // points
  end;

type
  TfHistory = class(TForm)
    pagHistory: TPageControl;
    tbsHistory: TTabSheet;
    lstHistory: TListView;
    tbsRanking: TTabSheet;
    grdRanking: TJvStringGrid;
    tbsCompare: TTabSheet;
    cboPlayer1: TComboBox;
    Label1: TLabel;
    Label2: TLabel;
    cboPlayer2: TComboBox;
    Label3: TLabel;
    cmdAnalyze: TBitBtn;
    Bevel1: TBevel;
    Bevel2: TBevel;
    panAnalyze: TPanel;
    prbPlayer2: TProgressBar;
    prbPlayer1: TProgressBar;
    lblAnalyze: TLabel;
    lblPlayer1: TLabel;
    lblPlayer2: TLabel;
    procedure FormShow(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure grdRankingCaptionClick(Sender: TJvStringGrid;
      AColumn, ARow: integer);
    procedure grdRankingDrawCell(Sender: TObject; ACol, ARow: integer;
      Rect: TRect; State: TGridDrawState);
    procedure cmdAnalyzeClick(Sender: TObject);
    procedure lstHistoryColumnClick(Sender: TObject; Column: TListColumn);
    procedure lstHistoryCompare(Sender: TObject; Item1, Item2: TListItem;
      Data: integer; var Compare: integer);
  private
    uHRanking: TObjectList;
    iColumnClicked, iSortCol, iTotGames: integer;
    bAscending: boolean;
    procedure LoadHistoryFile;
    function SearchPlayer(const sKey: string; uList: TObjectList): integer;
  public
    { Public declarations }
  end;

var
  fHistory: TfHistory;

implementation

{$R *.dfm}

uses Globals, StdPas;

procedure TfHistory.FormCreate(Sender: TObject);
var
  i: integer;
begin
  with lstHistory.Columns.Add do begin
    Caption := 'Date';
    Width := 65;
  end;
  with lstHistory.Columns.Add do begin
    Caption := 'Players';
    Width := 50;
  end;
  with lstHistory.Columns.Add do begin
    Caption := 'Winner';
    Width := 80;
  end;
  with lstHistory.Columns.Add do begin
    Caption := '2nd';
    Width := 80;
  end;
  with lstHistory.Columns.Add do begin
    Caption := '3rd';
    Width := 80;
  end;
  for i := 4 to 10 do begin
    with lstHistory.Columns.Add do begin
      Caption := IntToStr(i) + 'th';
      Width := 80;
    end;
  end;
  with grdRanking do begin
    RowCount := 1;
    ColCount := 6;
    Cells[0, 0] := 'Player';
    Cells[1, 0] := 'Games';
    Cells[2, 0] := 'Won';
    Cells[3, 0] := '% Won';
    Cells[4, 0] := 'Points';
    Cells[5, 0] := 'P.ts/Game';
    ColWidths[0] := 100;
    ColWidths[1] := 70;
    ColWidths[2] := 70;
    ColWidths[3] := 70;
    ColWidths[4] := 70;
    ColWidths[5] := 70;
  end;
  iSortCol := 0;
end;

procedure TfHistory.FormShow(Sender: TObject);
begin
  Screen.Cursor := crHourGlass;
  iColumnClicked := -1;
  LoadHistoryFile;
  bAscending := true;
  panAnalyze.Visible := false;
  Screen.Cursor := crDefault;
end;

procedure TfHistory.LoadHistoryFile;
var
  fHistory: textfile;
  iMaxRank, iP, iL: integer;
  sRec, sTmp: string;
  dDate: TDate;
begin
  iTotGames := 0;
  // open history file
  if not FileExists(sG_AppPath + 'history.txt') then
    exit;
  AssignFile(fHistory, sG_AppPath + 'history.txt');
  Reset(fHistory);
  // prepare list
  lstHistory.Clear;
  // create object for statistics
  uHRanking := TObjectList.Create;
  // load list
  try
    // read history file
    while not Eof(fHistory) do begin
      Readln(fHistory, sRec);
      inc(iTotGames);
      // date
      sTmp := SplitStr(sRec, ',');
      dDate := EncodeDate(StrToInt(copy(sTmp, 1, 4)),
        StrToInt(copy(sTmp, 5, 2)), StrToInt(copy(sTmp, 7, 2)));
      // max rank
      sTmp := SplitStr(sRec, ',');
      iMaxRank := StrToInt(sTmp);
      // list item
      with lstHistory.Items.Add do begin
        Caption := FormatDateTime('yyyy-mm-dd', dDate);
        SubItems.Add(IntToStr(iMaxRank));
        for iP := 1 to MAXPLAYERS do begin
          if iP <= iMaxRank then begin
            // add player to list item
            sTmp := lowercase(SplitStr(sRec, ','));
            SubItems.Add(sTmp);
            // search player in ranking list
            iL := SearchPlayer(sTmp, uHRanking);
            if iL < 0 then begin
              // not found, add new player
              iL := uHRanking.Count;
              uHRanking.Add(TPStat.Create);
              with uHRanking[iL] as TPStat do begin
                player := sTmp;
                games := 1;
                if iP = 1 then
                  won := 1
                else
                  won := 0;
                points := iMaxRank - iP + 1;
              end;
            end
            else begin
              // found, increment counters
              with uHRanking[iL] as TPStat do begin
                inc(games);
                if iP = 1 then
                  inc(won);
                points := points + iMaxRank - iP + 1;
              end;
            end;
          end else begin
            SubItems.Add('');
          end;
        end;
      end;
    end;
    // load ranking grid
    with grdRanking do begin
      RowCount := uHRanking.Count + 1;
      for iL := 0 to uHRanking.Count - 1 do begin
        with uHRanking[iL] as TPStat do begin
          Cells[0, iL + 1] := player;
          Cells[1, iL + 1] := FormatFloat('#,##0', games);
          Cells[2, iL + 1] := FormatFloat('#,##0', won);
          Cells[4, iL + 1] := FormatFloat('#,##0', points);
          if games > 0 then begin
            Cells[3, iL + 1] := FormatFloat('0.0"%"', (100.0 * won) / games);
            Cells[5, iL + 1] := FormatFloat('0.0', points / games);
          end
          else begin
            Cells[3, iL + 1] := '-';
            Cells[5, iL + 1] := '-';
          end;
        end;
      end;
      if RowCount > 1 then
        FixedRows := 1;
      SortGrid(0, true);
      iSortCol := 0;
    end;
    // load compare combos
    cboPlayer1.Clear;
    cboPlayer2.Clear;
    for iL := 0 to uHRanking.Count - 1 do begin
      cboPlayer1.Items.Add((uHRanking[iL] as TPStat).player);
      cboPlayer2.Items.Add((uHRanking[iL] as TPStat).player);
    end;
  finally
    CloseFile(fHistory);
    uHRanking.Free;
  end;
end;

procedure TfHistory.lstHistoryColumnClick(Sender: TObject; Column: TListColumn);
begin
  if Column.Index = iColumnClicked then begin
    bAscending := not bAscending
  end
  else begin
    bAscending := true;
    iColumnClicked := Column.Index;
  end;
  Screen.Cursor := crHourGlass;
  try (Sender as TListView)
    .AlphaSort;
  finally
    Screen.Cursor := crDefault;
  end;
end;

procedure TfHistory.lstHistoryCompare(Sender: TObject; Item1, Item2: TListItem;
  Data: integer; var Compare: integer);
begin
  case iColumnClicked of
    0:
      Compare := CompareStr(Item1.Caption, Item2.Caption);
  else
    Compare := CompareStr(Item1.SubItems[iColumnClicked - 1],
      Item2.SubItems[iColumnClicked - 1]);
  end;
  if not bAscending then
    Compare := -Compare;
end;

function TfHistory.SearchPlayer(const sKey: string;
  uList: TObjectList): integer;
var
  i: integer;
begin
  for i := 0 to uList.Count - 1 do begin
    if TPStat(uList[i]).player = sKey then begin
      result := i;
      exit;
    end;
  end;
  result := -1;
end;

procedure TfHistory.grdRankingCaptionClick(Sender: TJvStringGrid;
  AColumn, ARow: integer);
begin
  Screen.Cursor := crHourGlass;
  with (Sender as TJvStringGrid) do begin
    iSortCol := AColumn;
    if AColumn = 0 then
      SortGrid(0, true)
    else
      SortGrid(AColumn, false, false, stNumeric, false);
    if RowCount > 0 then
      Row := 1
    else
      Row := 0;
  end;
  Screen.Cursor := crDefault;
end;

procedure TfHistory.grdRankingDrawCell(Sender: TObject; ACol, ARow: integer;
  Rect: TRect; State: TGridDrawState);
begin
  with grdRanking.Canvas do begin
    if ARow = 0 then begin
      Brush.color := clBtnFace;
      Font.color := clBlack;
      Font.Style := [fsBold];
      FillRect(Rect);
    end
    else begin
      if ACol = iSortCol then
        Brush.color := clCream
      else
        Brush.color := clWhite;
      Font.color := clBlack;
      Font.Style := [];
      FillRect(Rect);
    end;
    if ACol = 0 then begin
      TextOut(Rect.Left + 1, Rect.Top + 1, grdRanking.Cells[ACol, ARow]);
    end
    else begin
      TextOut(Rect.Right - TextWidth(grdRanking.Cells[ACol, ARow]) - 3,
        Rect.Top + 1, grdRanking.Cells[ACol, ARow]);
    end;
  end;
end;

procedure TfHistory.cmdAnalyzeClick(Sender: TObject);
var
  i, j, iR1, iR2, iT1, iT2, iTT: integer;
  sP1, sP2: string;
begin
  // check for legal case
  if (cboPlayer1.ItemIndex < 0) or (cboPlayer2.ItemIndex < 0) or
  (cboPlayer1.ItemIndex = cboPlayer2.ItemIndex) then
    exit;
  // analyze
  Screen.Cursor := crHourGlass;
  sP1 := cboPlayer1.Text;
  sP2 := cboPlayer2.Text;
  iT1 := 0;
  iT2 := 0;
  // scan history
  for i := 0 to lstHistory.Items.Count - 1 do begin
    iR1 := 0;
    iR2 := 0;
    // scan game
    with lstHistory.Items[i] do begin
      for j := 1 to SubItems.Count - 1 do begin
        if SubItems[j] = sP1 then
          iR1 := j
        else if SubItems[j] = sP2 then
          iR2 := j;
      end;
    end;
    if (iR1 > 0) and (iR2 > 0) then begin
      if iR1 < iR2 then
        inc(iT1)
      else
        inc(iT2);
    end;
  end;
  // show results
  iTT := iT1 + iT2;
  if iTT > 0 then begin
    prbPlayer1.Position := trunc(100.0 * iT1 / iTT + 0.5);
    prbPlayer2.Position := trunc(100.0 * iT2 / iTT + 0.5);
    lblAnalyze.Caption := 'Results of ' + IntToStr(iTT)
    + ' games including ' + sP1 + ' and ' + sP2;
    lblPlayer1.Caption := sP1 + ' was better ' + IntToStr(iT1)
    + ' times (' + IntToStr(prbPlayer1.Position) + '%)';
    lblPlayer2.Caption := sP2 + ' was better ' + IntToStr(iT2)
    + ' times (' + IntToStr(prbPlayer2.Position) + '%)';
  end
  else begin
    prbPlayer1.Position := 0;
    prbPlayer2.Position := 0;
    lblAnalyze.Caption := 'No games including both ' + sP1 + ' and ' + sP2;
    lblPlayer1.Caption := '';
    lblPlayer2.Caption := '';
  end;
  panAnalyze.Visible := true;
  Screen.Cursor := crDefault;
end;

end.
