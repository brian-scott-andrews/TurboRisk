unit SimGameLog;

{$MODE Delphi}

interface

uses
  LCLIntf, LCLType, LMessages, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, Globals, ComCtrls, ExtCtrls, StdCtrls, Buttons, Grids{, JvExGrids,
  JvStringGrid};

type

  TPlayerStats = record
    Name: string; // name
    Army, // total armies when game ended
    Territ, // number of owned territories when game ended
    LastTurn, // last turn played by the player
    Points, // points in the game
    Rank: integer; // rank at the end of the game
  end;

  TGameStats = record
    GameEnd: TSimStatus; // termination type
    GameDate: TDateTime; // date+time the simulation ended
    GameTime, // duration of the game in seconds
    GameTurns, // duration of the game in turns
    NumPl: integer; // number of players
    aPStats: array [0 .. MAXPLAYERS] of TPlayerStats; // players' stats
  end;

  TPlayerSummary = record
    Name: string; // name
    Games, // number of games played
    Better, // number of games the player was better than the reference player
    Worse, // number of games the player was worse than the reference player
    Won, // number of games won
    Rank, // sum of the ranks
    RefRank, // sum of the ranks of the reference player
    TurnsPlayed, // sum of turns of played games
    TurnsToWin, // sum of turns of won games
    Armies, // sum of armies at the end of won games
    Points: integer; // sum of the points
  end;

  TfSimGameLog = class(TForm)
    pgcLog: TPageControl;
    tbsGames: TTabSheet;
    lstGames: TListView;
    Panel1: TPanel;
    lstPlayers: TListView;
    tbsRanking: TTabSheet;
    grdRanking: TJvStringGrid;
    tbsAnalysis: TTabSheet;
    cboPlayer: TComboBox;
    Label1: TLabel;
    grdAnalysis: TJvStringGrid;
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure FormDestroy(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure lstGamesSelectItem(Sender: TObject; Item: TListItem;
      Selected: Boolean);
    procedure FormCreate(Sender: TObject);
    procedure grdRankingCaptionClick(Sender: TJvStringGrid;
      AColumn, ARow: integer);
    procedure grdRankingDrawCell(Sender: TObject; ACol, ARow: integer;
      Rect: TRect; State: TGridDrawState);
    procedure grdAnalysisCaptionClick(Sender: TJvStringGrid;
      AColumn, ARow: integer);
    procedure grdAnalysisDrawCell(Sender: TObject; ACol, ARow: integer;
      Rect: TRect; State: TGridDrawState);
    procedure cboPlayerSelect(Sender: TObject);
  private
    aGameStats: array of TGameStats;
    aPlaySum: array of TPlayerSummary;
    iSortCol, // ranking grid sort column
    iSortCol2, // analysis grid sort column
    iPlayCount, // number of players in aPlaySum
    iTotGames: integer; // number of games in the log file
    procedure LoadLogFile;
    procedure PopulateGamesList;
    procedure PopulateAnalysisGrid(const sPlayer: string);
    procedure PopulateRankingGrid;
    function DecodeGameEnd(uEnd: TSimStatus): string;
    procedure SummarizePlayers(const sPlayer: string);
  public
    sLogFileName: string;
  end;

var
  fSimGameLog: TfSimGameLog;

implementation

{$R *.lfm}

{uses StdPas;}

procedure TfSimGameLog.FormCreate(Sender: TObject);
begin
  with grdRanking do begin
    RowCount := 1;
    ColCount := 10;
    Cells[0, 0] := 'Player';
    Cells[1, 0] := 'Games';
    Cells[2, 0] := 'Won';
    Cells[3, 0] := '% Won';
    Cells[4, 0] := 'Points';
    Cells[5, 0] := 'Pts/Game';
    Cells[6, 0] := 'Avg Rank';
    Cells[7, 0] := 'Turns/Game';
    Cells[8, 0] := 'Turns to win';
    Cells[9, 0] := 'Final armies';

    ColWidths[0] := 70;
    ColWidths[1] := 50;
    ColWidths[2] := 50;
    ColWidths[3] := 50;
    ColWidths[4] := 50;
    ColWidths[5] := 70;
    ColWidths[6] := 70;
    ColWidths[7] := 80;
    ColWidths[8] := 80;
    ColWidths[9] := 80;
  end;
  iSortCol := 0;
  with grdAnalysis do begin
    RowCount := 1;
    ColCount := 7;
    Cells[0, 0] := 'Competitor';
    Cells[1, 0] := 'Games';
    Cells[2, 0] := 'Better';
    Cells[3, 0] := 'Worse';
    Cells[4, 0] := '% Better';
    Cells[5, 0] := '% Worse';
    Cells[6, 0] := 'Rank diff.';
    ColWidths[0] := 70;
    ColWidths[1] := 50;
    ColWidths[2] := 50;
    ColWidths[3] := 50;
    ColWidths[4] := 70;
    ColWidths[5] := 70;
    ColWidths[6] := 70;
  end;
  iSortCol2 := 0;
end;

procedure TfSimGameLog.FormShow(Sender: TObject);
begin
  Caption := 'Game log analysis: ' + sLogFileName;
  LoadLogFile;
  PopulateGamesList;
  PopulateRankingGrid;
  pgcLog.ActivePage := tbsGames;
end;

procedure TfSimGameLog.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  Action := caFree;
end;

procedure TfSimGameLog.FormDestroy(Sender: TObject);
begin
  fSimGameLog := nil;
end;

procedure TfSimGameLog.grdAnalysisCaptionClick(Sender: TJvStringGrid;
  AColumn, ARow: integer);
begin
  Screen.Cursor := crHourGlass;
  with (Sender as TJvStringGrid) do begin
    iSortCol2 := AColumn;
    case AColumn of
      0:
        SortGrid(0, true);
      6:
        SortGrid(AColumn, true, false, stNumeric, false);
    else
      SortGrid(AColumn, false, false, stNumeric, false);
    end;
    if RowCount > 0 then
      Row := 1
    else
      Row := 0;
  end;
  Screen.Cursor := crDefault;
end;

procedure TfSimGameLog.grdAnalysisDrawCell(Sender: TObject;
  ACol, ARow: integer; Rect: TRect; State: TGridDrawState);
begin
  with grdAnalysis.Canvas do begin
    if ARow = 0 then begin
      Brush.color := clBtnFace;
      Font.color := clBlack;
      Font.Style := [fsBold];
      FillRect(Rect);
    end
    else begin
      if ACol = iSortCol2 then
        Brush.color := clCream
      else
        Brush.color := clWhite;
      Font.color := clBlack;
      Font.Style := [];
      FillRect(Rect);
    end;
    if ACol = 0 then begin
      TextOut(Rect.Left + 1, Rect.Top + 1, grdAnalysis.Cells[ACol, ARow]);
    end
    else begin
      TextOut(Rect.Right - TextWidth(grdAnalysis.Cells[ACol, ARow]) - 3,
        Rect.Top + 1, grdAnalysis.Cells[ACol, ARow]);
    end;
  end;
end;

procedure TfSimGameLog.grdRankingCaptionClick(Sender: TJvStringGrid;
  AColumn, ARow: integer);
begin
  Screen.Cursor := crHourGlass;
  with (Sender as TJvStringGrid) do begin
    iSortCol := AColumn;
    case AColumn of
      0:
        SortGrid(0, true);
      6:
        SortGrid(AColumn, true, false, stNumeric, false);
    else
      SortGrid(AColumn, false, false, stNumeric, false);
    end;
    if RowCount > 0 then
      Row := 1
    else
      Row := 0;
  end;
  Screen.Cursor := crDefault;
end;

procedure TfSimGameLog.grdRankingDrawCell(Sender: TObject; ACol, ARow: integer;
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

procedure TfSimGameLog.lstGamesSelectItem(Sender: TObject; Item: TListItem;
  Selected: Boolean);
var
  iP: integer;
begin
  lstPlayers.Clear;
  if lstGames.ItemIndex < 0 then begin
    exit;
  end;
  // populate player's list
  with aGameStats[lstGames.ItemIndex] do begin
    for iP := 1 to NumPl do begin
      with lstPlayers.Items.Add do begin
        if GameEnd = ssComplete then
          Caption := IntToStr(aPStats[iP].Rank)
        else
          Caption := '-';
        SubItems.Add(aPStats[iP].Name);
        SubItems.Add(IntToStr(aPStats[iP].LastTurn));
        SubItems.Add(IntToStr(aPStats[iP].Army));
        SubItems.Add(IntToStr(aPStats[iP].Territ));
      end;
    end;
  end;
end;

procedure TfSimGameLog.cboPlayerSelect(Sender: TObject);
begin
  PopulateAnalysisGrid(cboPlayer.Text);
end;

procedure TfSimGameLog.LoadLogFile;
const
  ARRAY_INCR = 100;
var
  fHistory: textfile;
  iG, iP: integer;
  sRec, sTmp: string;
begin
  iTotGames := 0;
  // open history file
  if not FileExists(sG_AppPath + sLogFileName) then begin
    MsgErr('Log file "' + sLogFileName + '" not found.');
    exit;
  end;
  AssignFile(fHistory, sG_AppPath + sLogFileName);
  Reset(fHistory);
  // prepare array
  SetLength(aGameStats, ARRAY_INCR);
  // load list
  try
    // read history file into array
    while not Eof(fHistory) do begin
      Readln(fHistory, sRec);
      inc(iTotGames);
      if iTotGames > length(aGameStats) then begin
        SetLength(aGameStats, length(aGameStats) + ARRAY_INCR);
      end;
      iG := iTotGames - 1;
      with aGameStats[iG] do begin
        // date
        sTmp := SplitStr(sRec, ',');
        GameDate := EncodeDate(StrToInt(copy(sTmp, 1, 4)),
          StrToInt(copy(sTmp, 5, 2)), StrToInt(copy(sTmp, 7, 2)));
        // time
        sTmp := SplitStr(sRec, ',');
        GameDate := GameDate + EncodeTime(StrToInt(copy(sTmp, 1, 2)),
          StrToInt(copy(sTmp, 3, 2)), StrToInt(copy(sTmp, 5, 2)), 0);
        // termination type
        sTmp := SplitStr(sRec, ',');
        GameEnd := TSimStatus(StrToInt(sTmp));
        // time
        sTmp := SplitStr(sRec, ',');
        GameTime := StrToInt(sTmp);
        // turns
        sTmp := SplitStr(sRec, ',');
        GameTurns := StrToInt(sTmp);
        // number of players
        sTmp := SplitStr(sRec, ',');
        NumPl := StrToInt(sTmp);
        // list item
        for iP := 1 to NumPl do begin
          // player's name
          sTmp := lowercase(SplitStr(sRec, ','));
          aPStats[iP].Name := sTmp;
          // player's last turn
          sTmp := SplitStr(sRec, ',');
          aPStats[iP].LastTurn := StrToInt(sTmp);
          // player's army
          sTmp := SplitStr(sRec, ',');
          aPStats[iP].Army := StrToInt(sTmp);
          // player's territories
          sTmp := SplitStr(sRec, ',');
          aPStats[iP].Territ := StrToInt(sTmp);
          // rank & points
          if GameEnd = ssComplete then begin
            aPStats[iP].Rank := iP;
            aPStats[iP].Points := NumPl + 1 - iP;
          end
          else begin
            aPStats[iP].Rank := 0;
            aPStats[iP].Points := 0;
          end;
        end;
      end;
    end;
  finally
    CloseFile(fHistory);
  end;
end;

procedure TfSimGameLog.PopulateGamesList;
var
  i: integer;
begin
  lstGames.Clear;
  for i := 0 to iTotGames - 1 do begin
    with lstGames.Items.Add do begin
      Caption := IntToStr(i + 1);
      SubItems.Add(FormatDateTime('c', aGameStats[i].GameDate));
      SubItems.Add(DecodeGameEnd(aGameStats[i].GameEnd));
      SubItems.Add(IntToStr(aGameStats[i].GameTime));
      SubItems.Add(IntToStr(aGameStats[i].GameTurns));
      if aGameStats[i].GameEnd = ssComplete then begin
        SubItems.Add(aGameStats[i].aPStats[1].Name);
      end
    end;
  end;
end;

procedure TfSimGameLog.PopulateRankingGrid;
var
  iL: integer;
begin
  // summarize players
  SummarizePlayers('');
  // load ranking grid
  with grdRanking do begin
    RowCount := iPlayCount + 1;
    for iL := 0 to iPlayCount - 1 do begin
      with aPlaySum[iL] do begin
        Cells[0, iL + 1] := Name;
        Cells[1, iL + 1] := FormatFloat('#,##0', Games);
        Cells[2, iL + 1] := FormatFloat('#,##0', Won);
        Cells[4, iL + 1] := FormatFloat('#,##0', Points);
        if Games > 0 then begin
          Cells[3, iL + 1] := FormatFloat('0.0"%"', (100.0 * Won) / Games);
          Cells[5, iL + 1] := FormatFloat('0.0', Points / Games);
          Cells[6, iL + 1] := FormatFloat('0.0', Rank / Games);
          Cells[7, iL + 1] := FormatFloat('0', TurnsPlayed / Games);
        end
        else begin
          Cells[3, iL + 1] := '-';
          Cells[5, iL + 1] := '-';
          Cells[6, iL + 1] := '-';
          Cells[7, iL + 1] := '-';
        end;
        if Won > 0 then begin
          Cells[8, iL + 1] := FormatFloat('0', TurnsToWin / Won);
          Cells[9, iL + 1] := FormatFloat('0', Armies / Won);
        end
        else begin
          Cells[8, iL + 1] := '-';
          Cells[9, iL + 1] := '-';
        end;
      end;
    end;
    if RowCount > 1 then
      FixedRows := 1;
    SortGrid(0, true);
    iSortCol := 0;
  end;
  // populate player's combo
  with cboPlayer do begin
    Clear;
    for iL := 0 to iPlayCount - 1 do begin
      Items.Add(aPlaySum[iL].Name);
    end;
  end;
end;

procedure TfSimGameLog.PopulateAnalysisGrid(const sPlayer: string);
var
  iL, iP: integer;
begin
  // summarize players
  SummarizePlayers(sPlayer);
  // load grid
  with grdAnalysis do begin
    RowCount := iPlayCount;
    iL := 0;
    for iP := 0 to iPlayCount - 1 do begin
      with aPlaySum[iP] do begin
        if SameText(sPlayer, Name) then
          continue; // skip analysed player
        inc(iL);
        Cells[0, iL] := Name;
        Cells[1, iL] := FormatFloat('#,##0', Games);
        Cells[2, iL] := FormatFloat('#,##0', Better);
        Cells[3, iL] := FormatFloat('#,##0', Worse);
        if Games > 0 then begin
          Cells[4, iL] := FormatFloat('0.0"%"', (100.0 * Better) / Games);
          Cells[5, iL] := FormatFloat('0.0"%"', (100.0 * Worse) / Games);
          Cells[6, iL] := FormatFloat('0.0', (Rank - RefRank) / Games);
        end
        else begin
          Cells[4, iL] := '-';
          Cells[5, iL] := '-';
          Cells[6, iL] := '-';
        end;
      end;
    end;
    if RowCount > 1 then
      FixedRows := 1;
    SortGrid(0, true);
    iSortCol2 := 0;
  end;
end;

procedure TfSimGameLog.SummarizePlayers(const sPlayer: string);
var
  iG, iP, iPS, iRefRank: integer;
  bFound: Boolean;
begin
  SetLength(aPlaySum, 100);
  iPlayCount := 0;
  for iG := 0 to iTotGames - 1 do begin
    // skip uncompleted games
    if aGameStats[iG].GameEnd <> ssComplete then
      continue;
    // if a player is specified, skip games that do not contain that player
    if sPlayer > '' then begin
      bFound := false;
      for iP := 1 to aGameStats[iG].NumPl do begin
        if SameText(sPlayer, aGameStats[iG].aPStats[iP].Name) then begin
          bFound := true;
          iRefRank := aGameStats[iG].aPStats[iP].Rank;
          break;
        end;
      end;
      if not bFound then
        continue;
    end;
    // account players' stats
    for iP := 1 to aGameStats[iG].NumPl do begin
      // search player in summary array
      bFound := false;
      for iPS := 0 to iPlayCount - 1 do begin
        if SameText(aGameStats[iG].aPStats[iP].Name, aPlaySum[iPS].Name) then
        begin
          bFound := true;
          break;
        end;
      end;
      // if not found, add it to the array
      if not bFound then begin
        inc(iPlayCount);
        if iPlayCount > length(aPlaySum) then
          SetLength(aPlaySum, length(aPlaySum) + 100);
        iPS := iPlayCount - 1;
        aPlaySum[iPS].Name := aGameStats[iG].aPStats[iP].Name;
        aPlaySum[iPS].Games := 0;
        aPlaySum[iPS].Better := 0;
        aPlaySum[iPS].Worse := 0;
        aPlaySum[iPS].Won := 0;
        aPlaySum[iPS].Rank := 0;
        aPlaySum[iPS].RefRank := 0;
        aPlaySum[iPS].Points := 0;
        aPlaySum[iPS].TurnsPlayed := 0;
        aPlaySum[iPS].TurnsToWin := 0;
        aPlaySum[iPS].Armies := 0;
      end;
      // update stats
      inc(aPlaySum[iPS].Games);
      aPlaySum[iPS].TurnsPlayed := aPlaySum[iPS].TurnsPlayed + aGameStats[iG]
      .aPStats[iP].LastTurn;
      if aGameStats[iG].aPStats[iP].Rank = 1 then begin
        inc(aPlaySum[iPS].Won);
        aPlaySum[iPS].TurnsToWin := aPlaySum[iPS].TurnsToWin + aGameStats[iG]
        .aPStats[iP].LastTurn;
        aPlaySum[iPS].Armies := aPlaySum[iPS].Armies + aGameStats[iG]
        .aPStats[iP].Army;
      end;
      aPlaySum[iPS].Rank := aPlaySum[iPS].Rank + aGameStats[iG].aPStats[iP]
      .Rank;
      aPlaySum[iPS].Points := aPlaySum[iPS].Points + aGameStats[iG]
      .NumPl + 1 - aGameStats[iG].aPStats[iP].Rank;
      if sPlayer > '' then begin
        aPlaySum[iPS].RefRank := aPlaySum[iPS].RefRank + iRefRank;
        if aGameStats[iG].aPStats[iP].Rank < iRefRank then
          inc(aPlaySum[iPS].Better);
        if aGameStats[iG].aPStats[iP].Rank > iRefRank then
          inc(aPlaySum[iPS].Worse);
      end;
    end;
  end;
end;

function TfSimGameLog.DecodeGameEnd(uEnd: TSimStatus): string;
begin
  case uEnd of
    ssComplete:
      result := 'completed';
    ssError:
      result := 'TRP error';
    ssTurnLimit:
      result := 'turn limit';
    ssTimeLimit:
      result := 'time limit';
    ssAbort:
      result := 'aborted';
  end;
end;

end.
