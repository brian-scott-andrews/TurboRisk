unit Sim;

{$MODE Delphi}

interface

uses
  LCLIntf, LCLType, LMessages, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, ComCtrls, StdCtrls, Globals, ExtCtrls, Buttons{, EdisCustom};

type
  TfSim = class(TForm)
    pgcSim: TPageControl;
    tbsSim: TTabSheet;
    tbsAna: TTabSheet;
    lstAlways: TListBox;
    lstRandom: TListBox;
    Label2: TLabel;
    Label3: TLabel;
    lstNever: TListBox;
    Label6: TLabel;
    Label7: TLabel;
    txtMinPlayers: TEdit;
    txtMaxPlayers: TEdit;
    txtGames: TEdit;
    Label8: TLabel;
    Label9: TLabel;
    panError: TGroupBox;
    chkErrorDump: TCheckBox;
    chkErrorAbort: TCheckBox;
    cmdStart: TBitBtn;
    GroupBox1: TGroupBox;
    chkShowMap: TCheckBox;
    chkShowStats: TCheckBox;
    cboMap: TComboBox;
    Label1: TLabel;
    GroupBox2: TGroupBox;
    txtGameLogFile: TEdisComboDialog;
    Label4: TLabel;
    Label5: TLabel;
    txtCPULogFile: TEdisComboDialog;
    GroupBox3: TGroupBox;
    txtTurnLimit: TEdit;
    Label10: TLabel;
    Label11: TLabel;
    txtTimeLimit: TEdit;
    Label12: TLabel;
    dlgOpenLogFile: TOpenDialog;
    Label13: TLabel;
    Label14: TLabel;
    txtGameLogFile2: TEdisComboDialog;
    txtCPULogFile2: TEdisComboDialog;
    cmdAnalyseGameLog: TBitBtn;
    cmdAnalyseCPULog: TBitBtn;
    procedure FormShow(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure lstTRPDragOver(Sender, Source: TObject; X, Y: Integer;
      State: TDragState; var Accept: Boolean);
    procedure lstTRPDragDrop(Sender, Source: TObject; X, Y: Integer);
    procedure cmdStartClick(Sender: TObject);
    procedure txtGameLogFileCustomDlg(Sender: TObject);
    procedure txtCPULogFileCustomDlg(Sender: TObject);
    procedure cmdAnalyseCPULogClick(Sender: TObject);
    procedure cmdAnalyseGameLogClick(Sender: TObject);
  private
    procedure SimSetup;
    procedure SimCleanup;
    procedure PopulateTRPList;
    procedure PopulateMapList;
    procedure LogCPU;
  public
    { Public declarations }
  end;

var
  fSim: TfSim;

implementation

{$R *.lfm}

uses IniFiles, StrUtils, DateUtils, {StdPas,} SimRun, SimMap, Stats, Territ,
  SimCPULog, SimGameLog;

procedure TfSim.FormShow(Sender: TObject);
begin
  bG_TRSim := true; // main is TRSim
  Setup; // generic TurboRisk setup in globals
  PopulateMapList;
  SimSetup; // TRSim specific setup
  Caption := 'TRSim ' + sG_AppVers;
  Application.HelpFile := sG_AppPath + 'TurboRisk.chm';
  PopulateTRPList;
  pgcSim.ActivePage := tbsSim;
end;

procedure TfSim.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  CanClose := false;
  if GameState = gsStopped then begin
    CanClose := true;
    exit;
  end;
  if bHumanTurn then begin
    GameCleanup;
    CanClose := true;
    exit;
  end
  else begin
    bStopASAP := true;
    bCloseASAP := true;
  end;
end;

procedure TfSim.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  Cleanup;
  SimCleanup;
end;

procedure TfSim.txtGameLogFileCustomDlg(Sender: TObject);
begin
  dlgOpenLogFile.InitialDir := sG_AppPath;
  dlgOpenLogFile.DefaultExt := 'sgl';
  dlgOpenLogFile.FileName := '*.sgl';
  dlgOpenLogFile.Filter := 'TRSim Game Log|sgl';
  if dlgOpenLogFile.Execute then begin (Sender as TEdisComboDialog)
    .Text := ExtractFileName(dlgOpenLogFile.FileName);
  end;
end;

procedure TfSim.txtCPULogFileCustomDlg(Sender: TObject);
begin
  dlgOpenLogFile.InitialDir := sG_AppPath;
  dlgOpenLogFile.DefaultExt := 'scl';
  dlgOpenLogFile.FileName := '*.scl';
  dlgOpenLogFile.Filter := 'TRSim CPU Log|scl';
  if dlgOpenLogFile.Execute then begin (Sender as TEdisComboDialog)
    .Text := ExtractFileName(dlgOpenLogFile.FileName);
  end;
end;

// -----------------
// Setup and cleanup
// -----------------

procedure TfSim.SimSetup;
var
  IniFile: TIniFile;
  i, n: Integer;
begin

  // generic global vars
  sG_AppName := 'TRSim'; // overrides the name set in Globals

  // clear programs lists
  lstAlways.Items.Clear;
  lstRandom.Items.Clear;
  lstNever.Items.Clear;

  // load INI file
  IniFile := TIniFile.Create(sG_AppPath + sG_AppName + '.INI');
  try
    with IniFile do begin
      // Windows setup
      fSim.Top := ReadInteger('Windows', 'SimTop', 0);
      fSim.Left := ReadInteger('Windows', 'SimLeft', 0);
      fSimRun.Top := ReadInteger('Windows', 'SimRunTop', 0);
      fSimRun.Left := ReadInteger('Windows', 'SimRunLeft', 0);
      fSimMap.Top := ReadInteger('Windows', 'SimMapTop', 0);
      fSimMap.Left := ReadInteger('Windows', 'SimMapLeft', 0);
      fStats.Top := ReadInteger('Windows', 'SimStatsTop', 0);
      fStats.Left := ReadInteger('Windows', 'SimSimStatsLeft', 0);
      // Parameters
      txtGames.Text := IntToStr(ReadInteger('Params', 'Games', 0));
      txtMinPlayers.Text := IntToStr(ReadInteger('Params', 'MinPlayers', 2));
      txtMaxPlayers.Text := IntToStr(ReadInteger('Params', 'MaxPlayers', 10));
      chkShowMap.Checked := ReadBool('Params', 'ShowMap', true);
      cboMap.ItemIndex := cboMap.Items.IndexOf(ReadString('Params', 'Map',
          'std_map_small.trm'));
      chkShowStats.Checked := ReadBool('Params', 'ShowStats', true);
      chkErrorDump.Checked := ReadBool('Params', 'ErrorDump', true);
      chkErrorAbort.Checked := ReadBool('Params', 'ErrorAbort', true);
      txtGameLogFile.Text := ReadString('Params', 'GameLog', 'game_log.sgl');
      txtCPULogFile.Text := ReadString('Params', 'CPULog', 'cpu_usage_log.scl');
      txtGameLogFile2.Text := txtGameLogFile.Text;
      txtCPULogFile2.Text := txtCPULogFile.Text;
      txtTurnLimit.Text := IntToStr(ReadInteger('Params', 'TurnLimit', 0));
      txtTimeLimit.Text := IntToStr(ReadInteger('Params', 'TimeLimit', 0));
      // Players
      n := ReadInteger('Players', 'AlwaysCount', 0);
      for i := 1 to n do begin
        lstAlways.Items.Add(ReadString('Players', 'Always' + IntToStr(i), '?'));
      end;
      n := ReadInteger('Players', 'RandomCount', 0);
      for i := 1 to n do begin
        lstRandom.Items.Add(ReadString('Players', 'Random' + IntToStr(i), '?'));
      end;
    end;
  finally
    IniFile.Free;
  end;

end;

procedure TfSim.SimCleanup;
var
  IniFile: TIniFile;
  i: Integer;
begin
  // save setup on INI file
  IniFile := TIniFile.Create(sG_AppPath + sG_AppName + '.INI');
  try
    with IniFile do begin
      // Windows
      WriteInteger('Windows', 'SimTop', fSim.Top);
      WriteInteger('Windows', 'SimLeft', fSim.Left);
      WriteInteger('Windows', 'SimRunTop', fSimRun.Top);
      WriteInteger('Windows', 'SimRunLeft', fSimRun.Left);
      WriteInteger('Windows', 'SimMapTop', fSimMap.Top);
      WriteInteger('Windows', 'SimMapLeft', fSimMap.Left);
      WriteInteger('Windows', 'SimStatsTop', fStats.Top);
      WriteInteger('Windows', 'SimSimStatsLeft', fStats.Left);
      // Parameters
      WriteInteger('Params', 'Games', StrToIntDef(txtGames.Text,0));
      WriteInteger('Params', 'MinPlayers', StrToIntDef(txtMinPlayers.Text,0));
      WriteInteger('Params', 'MaxPlayers', StrToIntDef(txtMaxPlayers.Text,0));
      WriteBool('Params', 'ShowMap', chkShowMap.Checked);
      WriteString('Params', 'Map', cboMap.Text);
      WriteBool('Params', 'ShowStats', chkShowStats.Checked);
      WriteBool('Params', 'ErrorDump', chkErrorDump.Checked);
      WriteBool('Params', 'ErrorAbort', chkErrorAbort.Checked);
      WriteString('Params', 'GameLog', txtGameLogFile.Text);
      WriteString('Params', 'CPULog', txtCPULogFile.Text);
      WriteInteger('Params', 'TurnLimit', StrToIntDef(txtTurnLimit.Text,0));
      WriteInteger('Params', 'TimeLimit', StrToIntDef(txtTimeLimit.Text,0));
      // Players
      WriteInteger('Players', 'AlwaysCount', lstAlways.Count);
      for i := 0 to lstAlways.Count - 1 do begin
        WriteString('Players', 'Always' + IntToStr(i + 1), lstAlways.Items[i]);
      end;
      WriteInteger('Players', 'RandomCount', lstRandom.Count);
      for i := 0 to lstRandom.Count - 1 do begin
        WriteString('Players', 'Random' + IntToStr(i + 1), lstRandom.Items[i]);
      end;
    end;
  finally
    IniFile.Free;
  end;
end;

procedure TfSim.PopulateTRPList;
var
  rFileDesc: TSearchRec;
  sTRP: string;
begin
  // load program list
  if FindFirst(sG_AppPath + 'players\*.trp', faAnyFile, rFileDesc) = 0 then
  begin
    repeat
      // get TRP name from file system
      sTRP := lowercase(rFileDesc.Name);
      // if already in Always or Random list, skip it
      if (lstAlways.Items.IndexOf(sTRP) >= 0) or
      (lstRandom.Items.IndexOf(sTRP) >= 0) then
        continue;
      // else add it to the Never list
      lstNever.Items.Add(sTRP);
    until FindNext(rFileDesc) <> 0;
    FindClose(rFileDesc);
  end;
end;

procedure TfSim.PopulateMapList;
var
  rFileDesc: TSearchRec;
  sMap: string;
begin
  cboMap.Items.Clear;
  // load map list
  if FindFirst(sG_AppPath + 'maps\*.trm', faAnyFile, rFileDesc) = 0 then begin
    repeat
      // get TRP name from file system
      sMap := lowercase(rFileDesc.Name);
      cboMap.Items.Add(sMap);
    until FindNext(rFileDesc) <> 0;
    FindClose(rFileDesc);
  end;
end;

// -------------
// Program lists
// -------------

procedure TfSim.lstTRPDragOver(Sender, Source: TObject; X, Y: Integer;
  State: TDragState; var Accept: Boolean);
begin
  Accept := (Source <> Sender) and
  ((Source = lstAlways) or (Source = lstRandom) or (Source = lstNever));
end;

procedure TfSim.lstTRPDragDrop(Sender, Source: TObject; X, Y: Integer);
var
  i: Integer;
begin
  if (Source <> Sender) and ((Source = lstAlways) or (Source = lstRandom) or
    (Source = lstNever)) then begin
    for i := TListBox(Source).Count - 1 downto 0 do begin
      if TListBox(Source).Selected[i] then begin
        TListBox(Sender).Items.Add(TListBox(Source).Items[i]);
        TListBox(Source).Items.Delete(i);
      end;
    end;
  end;
end;

// ----------
// Simulation
// ----------

procedure TfSim.cmdStartClick(Sender: TObject);
var
  i, iP: Integer;
begin
  // prepare global variables
  iSimGames := StrToIntDef(txtGames.Text, 0);
  iSimMinPl := StrToIntDef(txtMinPlayers.Text, 0);
  iSimMaxPl := StrToIntDef(txtMaxPlayers.Text, 0);
  iSimTimeLimit := StrToIntDef(txtTimeLimit.Text, 0);
  iSimTurnLimit := StrToIntDef(txtTurnLimit.Text, 0);
  sSimGameLogFile := txtGameLogFile.Text;
  sSimCPULogFile := txtCPULogFile.Text;
  // validity check
  if iSimGames <= 0 then begin
    MsgErr('Invalid number of games.');
    txtGames.SetFocus;
    exit;
  end;
  if (iSimMinPl < 2) or (iSimMaxPl > 10) or (iSimMaxPl < iSimMinPl) then begin
    MsgErr('Invalid number of players. Min=2, max=10');
    txtMinPlayers.SetFocus;
    exit;
  end;
  if lstAlways.Count > iSimMinPl then begin
    MsgErr(
      'The number of TRPs in the "always" list is greater then the minimum number of players per game.');
    txtMinPlayers.SetFocus;
    exit;
  end;
  if lstAlways.Count + lstRandom.Count < iSimMaxPl then begin
    MsgErr(
      'The total number of TRPs in the "always" and "random" lists is not large enough to reach the maximum number of players per game.');
    txtMaxPlayers.SetFocus;
    exit;
  end;
  // prepare players
  lstRandom.Sorted := false;
  for iP := 1 to MAXPLAYERS do begin
    arPlayer[iP].Computer := true;
    arPlayer[iP].KeepLog := false;
  end;
  // show map if required
  if chkShowMap.Checked then begin
    sMapFile := cboMap.Text;
    LoadMap;
    fSimMap.Show;
  end;
  // show stats if required
  if chkShowStats.Checked then
    fStats.Show;
  // disables main simulation window
  fSim.Enabled := false;
  // show run window
  fSimRun.cmdStop.Enabled := true;
  fSimRun.cmdAbortGame.Enabled := true;
  fSimRun.BorderIcons := [];
  fSimRun.txtSimLog.Clear;
  fSimRun.SimLog('*** Simulation starts ***');
  if not fSimRun.Visible then
    fSimRun.Show;
  // start simulation
  Screen.Cursor := crHourGlass;
  try
    // init vars
    iSimCurr := 0;
    iSimCompl := 0;
    bSimAbort := false;
    dtSimStartTime := Now;
    fSimRun.prbGames.Max := iSimGames;
    fSimRun.prbGames.Position := 0;
    // main simulation loop
    repeat
      inc(iSimCurr);
      fSimRun.UpdateSimStats;
      fSimRun.SimLog('Game #' + IntToStr(iSimCurr) + ' started');
      // reset players
      for iP := 1 to MAXPLAYERS do
        arPlayer[iP].Active := false;
      // random number of players
      iSimPlayers := iSimMinPl + random(iSimMaxPl - iSimMinPl + 1);
      // take players from the "always" list first
      iP := 0;
      for i := 0 to lstAlways.Count - 1 do begin
        if iP < iSimPlayers then begin
          inc(iP);
          arPlayer[iP].Active := true;
          arPlayer[iP].PrgFile := lstAlways.Items[i];
          arPlayer[iP].Name := ChangeFileExt(lstAlways.Items[i], '');
        end;
      end;
      // then take players from the "random" list, if any
      if lstRandom.Count > 0 then begin
        for i := 1 to 100 do begin // "shuffle" random list
          lstRandom.Items.Exchange(random(lstRandom.Count),
            random(lstRandom.Count));
        end;
        for i := 0 to lstRandom.Count - 1 do begin
          if iP < iSimPlayers then begin
            inc(iP);
            arPlayer[iP].Active := true;
            arPlayer[iP].PrgFile := lstRandom.Items[i];
            arPlayer[iP].Name := ChangeFileExt(lstRandom.Items[i], '');
          end;
        end;
      end;
      // new game
      uSimStatus := ssRunning;
      dtSimGameTime := Now;
      NewGameSetup;
      Supervisor;
      iSimGameTime := SecondsBetween(Now, dtSimGameTime);
      // update log
      case uSimStatus of
        ssComplete:
          fSimRun.SimLog('Game #' + IntToStr(iSimCurr)
            + ' completed in ' + FormatDateTime('hh:nn:ss',
              Now - dtSimGameTime) + ', ' + IntToStr(iTurnCounter)
            + ' turns, winner is ' + arPlayer[iSimWinner].Name);
        ssError:
          fSimRun.SimLog('Game #' + IntToStr(iSimCurr)
            + ' aborted for TRP error');
        ssTurnLimit:
          fSimRun.SimLog('Game #' + IntToStr(iSimCurr) +
            ' aborted, turn limit reached');
        ssTimeLimit:
          fSimRun.SimLog('Game #' + IntToStr(iSimCurr) +
            ' aborted, time limit reached');
        ssAbort:
          fSimRun.SimLog('Game #' + IntToStr(iSimCurr) + ' aborted by user');
      end;
      // log game data
      UpdateHistoryFile;
      // log CPU data
      LogCPU;
      // update stats
      if not bSimAbort then
        inc(iSimCompl);
    until (iSimCompl = iSimGames) or bSimAbort;
  finally
    // last update of stats
    fSimRun.UpdateSimStats;
    if bSimAbort then
      fSimRun.SimLog('*** Simulation aborted by user ***')
    else
      fSimRun.SimLog('*** Simulation ends ***');
    // enable main form again
    fSim.Enabled := true;
    // close/disable controls
    fSimRun.cmdStop.Enabled := false;
    fSimRun.cmdAbortGame.Enabled := false;
    fSimRun.BorderIcons := [biSystemMenu];
    fSimMap.Close;
    fStats.Close;
    Screen.Cursor := crDefault;
    lstRandom.Sorted := true;
  end;
end;

procedure TfSim.LogCPU;
var
  LogFile: TIniFile;
  iP, iCalls, iTime, iPhases: Integer;
  uRoutine: TRoutine;
  sRoutine: string;
begin
  // open log file
  LogFile := TIniFile.Create(sG_AppPath + sSimCPULogFile);
  // update log file
  try
    with LogFile do begin
      for iP := 1 to iSimPlayers do begin
        for uRoutine := rtAssignment to rtFortification do begin
          sRoutine := IntToStr(ord(uRoutine));
          iPhases := ReadInteger(arPlayer[iP].Name, 'Phases' + sRoutine, 0);
          iCalls := ReadInteger(arPlayer[iP].Name, 'Calls' + sRoutine, 0);
          iTime := ReadInteger(arPlayer[iP].Name, 'Time' + sRoutine, 0);
          iPhases := iPhases + arPlayer[iP].aCPU[uRoutine].iPhases;
          iCalls := iCalls + arPlayer[iP].aCPU[uRoutine].iCalls;
          iTime := iTime + arPlayer[iP].aCPU[uRoutine]
          .iTime * 1000 div iPerformanceFrequency;
          WriteInteger(arPlayer[iP].Name, 'Phases' + sRoutine, iPhases);
          WriteInteger(arPlayer[iP].Name, 'Calls' + sRoutine, iCalls);
          WriteInteger(arPlayer[iP].Name, 'Time' + sRoutine, iTime);
        end;
      end;
    end;
  finally
    LogFile.Free;
  end;
end;

// --------
// Analysis
// --------

procedure TfSim.cmdAnalyseGameLogClick(Sender: TObject);
begin
  fSimGameLog := TfSimGameLog.Create(self);
  fSimGameLog.sLogFileName := txtGameLogFile2.Text;
  fSimGameLog.Show;
end;

procedure TfSim.cmdAnalyseCPULogClick(Sender: TObject);
begin
  fSimCPULog := TfSimCPULog.Create(self);
  fSimCPULog.sLogFileName := txtCPULogFile2.Text;
  fSimCPULog.Show;
end;

end.
