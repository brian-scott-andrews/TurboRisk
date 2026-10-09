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
    chkStatSignificantSample: TCheckBox;
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
    Label4: TLabel;
    Label5: TLabel;
    txtGameLogFile: TEdit;
    txtGameLogFilebtn: TButton;
    txtCPULogFile: TEdit;
    txtCPULogFilebtn: TButton;
    GroupBox3: TGroupBox;
    txtTurnLimit: TEdit;
    Label10: TLabel;
    Label11: TLabel;
    txtTimeLimit: TEdit;
    Label12: TLabel;
    dlgOpenLogFile: TOpenDialog;
    Label13: TLabel;
    Label14: TLabel;
    txtGameLogFile2: TEdit;
    txtGameLogFile2btn: TButton;
    txtCPULogFile2: TEdit;
    txtCPULogFile2btn: TButton;
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
    fPlayerSchedule: TStringList;
    fCliErrorOccurred: Boolean;
    fCliStatSignificantSample: Boolean;
    procedure SimSetup;
    procedure SimCleanup;
    procedure PopulateTRPList;
    procedure PopulateMapList;
    procedure LogCPU;
  public
    { Public declarations }
    function RunCLI: Integer;
  end;

var
  fSim: TfSim;
  bSimVerbose: Boolean;

implementation

{$R *.lfm}

uses IniFiles, StrUtils, DateUtils, {StdPas,} SimRun, SimMap, Stats, Territ,
  SimCPULog, SimGameLog, ExpSubr;

procedure TfSim.FormShow(Sender: TObject);
begin
  bG_TRSim := true; // main is TRSim
  Setup; // generic TurboRisk setup in globals
  PopulateMapList;
  SimSetup; // TRSim specific setup
  Caption := 'TRSim ' + sG_AppVers;
  Application.HelpFile := sG_AppPath + 'Doc' + PathDelim + 'TurboRisk.chm';
  PopulateTRPList;
  pgcSim.ActivePage := tbsSim;
end;

function TfSim.RunCLI: Integer;
var
  iArg, iValue, iGame, iPlayer, iMinPlayers, iMaxPlayers: Integer;
  sArg, sScheduleFile, sMapName, sGameLogFile, sCPULogFile: string;
  sLine, sPlayer, sNormalizedLine: string;
  Schedule, NormalizedSchedule, GamePlayers, UniquePlayers: TStringList;
  bErrorDump: Boolean;
  bSeedSpecified: Boolean;
  bStatSignificantSample: Boolean;
  iSeed: Integer;

  function NextArgument(const sOption: string): string;
  begin
    Inc(iArg);
    if iArg > ParamCount then
      raise Exception.Create('Missing value for ' + sOption);
    Result := ParamStr(iArg);
  end;

  function ReadNonNegativeInteger(const sOption: string): Integer;
  begin
    if not TryStrToInt(NextArgument(sOption), Result) or (Result < 0) then
      raise Exception.Create('Invalid non-negative integer for ' + sOption);
  end;

  procedure PrintUsage;
  begin
    WriteLn('TRSimCLI --schedule <file> [options]');
    WriteLn('Run scheduled TRP games without showing the simulator GUI.');
    WriteLn('Each non-empty, non-comment schedule line is one comma-separated roster.');
    WriteLn('Player names may include or omit .trp; each roster needs 2-10 distinct files.');
    WriteLn('Blank lines and lines beginning with # are ignored.');
    WriteLn('Paths for schedules and logs are relative to the current directory.');
    WriteLn('Map files are loaded from the maps directory beside TRSimCLI.');
    WriteLn('Example: TRSimCLI --schedule pairings.csv --map std_map_small.trm --turn-limit 20');
    WriteLn('Options:');
    WriteLn('  --schedule <file>      Required roster schedule (one game per line)');
    WriteLn('  --map <file.trm>       Map in maps (default: std_map_small.trm)');
    WriteLn('  --game-log <file>      Game log (default: TRSimCLI.sgl)');
    WriteLn('  --cpu-log <file>       CPU usage log (default: TRSimCLI.scl)');
    WriteLn('  --turn-limit <number>  Maximum turns per game (0: unlimited)');
    WriteLn('  --time-limit <seconds> Maximum seconds per game (0: unlimited)');
    WriteLn('  --seed <number>        Random-number-generator seed');
    WriteLn('  --statistically-significant-sample');
    WriteLn('                         Repeat schedule up to 10x until each TRP''s');
    WriteLn('                         95% Wilson win-rate interval is within +/- 5 points');
    WriteLn('  --verbose              Log TRP decisions and action outcomes');
    WriteLn('  --error-dump           Write a game dump when a TRP errors');
    WriteLn('  --help, -h             Show this help');
    WriteLn('Exit codes: 0 success; 1 one or more TRP errors; 2 input or setup error.');
    WriteLn('Turn- and time-limited games are logged separately from TRP errors.');
    WriteLn('Concurrent runs must use different game-log and CPU-log paths.');
  end;

begin
  Result := 2;
  bErrorDump := False;
  bSimVerbose := False;
  sScheduleFile := '';
  sMapName := 'std_map_small.trm';
  sGameLogFile := '';
  sCPULogFile := '';
  bSeedSpecified := False;
  bStatSignificantSample := False;
  iSeed := 0;
  iSimTurnLimit := 0;
  iSimTimeLimit := 0;
  iArg := 1;

  try
    while iArg <= ParamCount do begin
      sArg := LowerCase(ParamStr(iArg));
      if (sArg = '--help') or (sArg = '-h') then begin
        PrintUsage;
        Exit(0);
      end
      else if sArg = '--schedule' then
        sScheduleFile := NextArgument(sArg)
      else if sArg = '--map' then
        sMapName := NextArgument(sArg)
      else if sArg = '--game-log' then
        sGameLogFile := NextArgument(sArg)
      else if sArg = '--cpu-log' then
        sCPULogFile := NextArgument(sArg)
      else if sArg = '--turn-limit' then
        iSimTurnLimit := ReadNonNegativeInteger(sArg)
      else if sArg = '--time-limit' then
        iSimTimeLimit := ReadNonNegativeInteger(sArg)
      else if sArg = '--seed' then
        begin
          iSeed := ReadNonNegativeInteger(sArg);
          bSeedSpecified := True;
        end
      else if sArg = '--error-dump' then
        bErrorDump := True
      else if sArg = '--statistically-significant-sample' then
        bStatSignificantSample := True
      else if sArg = '--verbose' then
        bSimVerbose := True
      else
        raise Exception.Create('Unknown option: ' + ParamStr(iArg));
      Inc(iArg);
    end;
    if sScheduleFile = '' then
      raise Exception.Create('A --schedule file is required');

    sMapName := ExtractFileName(sMapName);
    if (sMapName = '') or not SameText(ExtractFileExt(sMapName), '.trm') or
       not FileExists(IncludeTrailingPathDelimiter(
         ExtractFilePath(Application.ExeName)) + 'maps' + PathDelim + sMapName) then
      raise Exception.Create('Map file not found under maps: ' + sMapName);
    sMapFile := sMapName;
    bTRSimCLI := True;
    FormShow(Self);
    if bSeedSpecified then
      SetURandomSeed(iSeed);

    iValue := cboMap.Items.IndexOf(LowerCase(sMapName));
    if iValue < 0 then
      raise Exception.Create('Map is not available in TRSim: ' + sMapName);
    cboMap.ItemIndex := iValue;
    if not SameText(sMapFile, sMapName) then begin
      sMapFile := sMapName;
      LoadMap;
    end;

    sScheduleFile := ExpandFileName(sScheduleFile);
    if not FileExists(sScheduleFile) then
      raise Exception.Create('Schedule file not found: ' + sScheduleFile);

    Schedule := TStringList.Create;
    NormalizedSchedule := TStringList.Create;
    GamePlayers := TStringList.Create;
    UniquePlayers := TStringList.Create;
    try
      Schedule.LoadFromFile(sScheduleFile);
      iMinPlayers := MAXPLAYERS + 1;
      iMaxPlayers := 0;
      for iGame := 0 to Schedule.Count - 1 do begin
        sLine := Trim(Schedule[iGame]);
        if sLine = '' then
          continue;
        if sLine[1] = #$FEFF then
          Delete(sLine, 1, 1);
        sLine := Trim(sLine);
        if (sLine = '') or (sLine[1] = '#') then
          continue;
        GamePlayers.Clear;
        GamePlayers.StrictDelimiter := True;
        GamePlayers.Delimiter := ',';
        GamePlayers.DelimitedText := sLine;
        if (GamePlayers.Count < 2) or (GamePlayers.Count > MAXPLAYERS) then
          raise Exception.CreateFmt('Schedule line %d has an invalid player count', [iGame + 1]);
        sNormalizedLine := '';
        for iPlayer := 0 to GamePlayers.Count - 1 do begin
          sPlayer := Trim(GamePlayers[iPlayer]);
          if ExtractFileExt(sPlayer) = '' then
            sPlayer := sPlayer + '.trp';
          if not SameText(ExtractFileExt(sPlayer), '.trp') or
             (ExtractFileName(sPlayer) <> sPlayer) then
            raise Exception.CreateFmt('Invalid player filename on schedule line %d: %s',
              [iGame + 1, sPlayer]);
          if not FileExists(sG_AppPath + 'players' + PathDelim + sPlayer) then
            raise Exception.CreateFmt('Player file not found on schedule line %d: %s',
              [iGame + 1, sPlayer]);
          for iValue := 0 to iPlayer - 1 do
            if SameText(sPlayer, GamePlayers[iValue]) then
              raise Exception.CreateFmt('Duplicate player on schedule line %d: %s',
                [iGame + 1, sPlayer]);
          GamePlayers[iPlayer] := sPlayer;
          if sNormalizedLine <> '' then
            sNormalizedLine := sNormalizedLine + ',';
          sNormalizedLine := sNormalizedLine + sPlayer;
          if UniquePlayers.IndexOf(LowerCase(sPlayer)) < 0 then
            UniquePlayers.Add(LowerCase(sPlayer));
        end;
        NormalizedSchedule.Add(sNormalizedLine);
        if GamePlayers.Count < iMinPlayers then
          iMinPlayers := GamePlayers.Count;
        if GamePlayers.Count > iMaxPlayers then
          iMaxPlayers := GamePlayers.Count;
      end;
      if NormalizedSchedule.Count = 0 then
        raise Exception.Create('Schedule contains no game rosters');
      fPlayerSchedule := NormalizedSchedule;
      NormalizedSchedule := nil;
      lstAlways.Items.Clear;
      lstRandom.Items.Assign(UniquePlayers);
      lstNever.Items.Clear;
    finally
      Schedule.Free;
      NormalizedSchedule.Free;
      GamePlayers.Free;
      UniquePlayers.Free;
    end;

    txtGames.Text := IntToStr(fPlayerSchedule.Count);
    txtMinPlayers.Text := IntToStr(iMinPlayers);
    txtMaxPlayers.Text := IntToStr(iMaxPlayers);
    txtTurnLimit.Text := IntToStr(iSimTurnLimit);
    txtTimeLimit.Text := IntToStr(iSimTimeLimit);
    chkShowMap.Checked := False;
    chkShowStats.Checked := False;
    chkErrorAbort.Checked := True;
    chkErrorDump.Checked := bErrorDump;
    fCliStatSignificantSample := bStatSignificantSample;
    if sGameLogFile = '' then
      sGameLogFile := ExpandFileName('TRSimCLI.sgl')
    else
      sGameLogFile := ExpandFileName(sGameLogFile);
    if sCPULogFile = '' then
      sCPULogFile := ExpandFileName('TRSimCLI.scl')
    else
      sCPULogFile := ExpandFileName(sCPULogFile);
    if not DirectoryExists(ExtractFileDir(sGameLogFile)) then
      raise Exception.Create('Game log directory does not exist: ' +
        ExtractFileDir(sGameLogFile));
    if not DirectoryExists(ExtractFileDir(sCPULogFile)) then
      raise Exception.Create('CPU log directory does not exist: ' +
        ExtractFileDir(sCPULogFile));
    txtGameLogFile.Text := sGameLogFile;
    txtCPULogFile.Text := sCPULogFile;
    fCliErrorOccurred := False;
    WriteLn(Format('TRSimCLI: validated %d games, %d unique TRPs (%d-%d per game)',
      [fPlayerSchedule.Count, lstRandom.Count, iMinPlayers, iMaxPlayers]));
    cmdStartClick(nil);
    if fCliErrorOccurred then
      Result := 1
    else
      Result := 0;
  except
    on E: Exception do begin
      WriteLn(ErrOutput, 'TRSimCLI: ' + E.Message);
      PrintUsage;
      Result := 2;
    end;
  end;
  FreeAndNil(fPlayerSchedule);
  bSimVerbose := False;
  fCliStatSignificantSample := False;
  bTRSimCLI := False;
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
  dlgOpenLogFile.DefaultExt := '.sgl';
  dlgOpenLogFile.FileName := '*.sgl';
  dlgOpenLogFile.Filter := 'TRSim Game Log (*.sgl)|*.sgl';
  if dlgOpenLogFile.Execute then begin
    if Sender is TEdit then begin
      TEdit(Sender).Text := ExtractFileName(dlgOpenLogFile.FileName);
    end;
    if Sender is TButton then begin
      if TButton(Sender).Tag =1 then begin
        txtGameLogFile.Text := ExtractFileName(dlgOpenLogFile.FileName);
      end
      else begin
        txtGameLogFile2.Text := ExtractFileName(dlgOpenLogFile.FileName);
      end;
    end;
  end;
end;

procedure TfSim.txtCPULogFileCustomDlg(Sender: TObject);
begin
  dlgOpenLogFile.InitialDir := sG_AppPath;
  dlgOpenLogFile.DefaultExt := '.scl';
  dlgOpenLogFile.FileName := '*.scl';
  dlgOpenLogFile.Filter := 'TRSim CPU Log (*.scl)|*.scl';
  if dlgOpenLogFile.Execute then begin
    if Sender is TEdit then begin
      TEdit(Sender).Text := ExtractFileName(dlgOpenLogFile.FileName);
    end;
    if Sender is TButton then begin
      if TButton(Sender).Tag =1 then begin
        txtCPULogFile.Text := ExtractFileName(dlgOpenLogFile.FileName);
      end
      else begin
        txtCPULogFile2.Text := ExtractFileName(dlgOpenLogFile.FileName);
      end;
    end;
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
      cboMap.ItemIndex := cboMap.Items.IndexOf(ReadString('Params', 'Map', 'std_map_small.trm'));
      chkShowStats.Checked := ReadBool('Params', 'ShowStats', true);
      chkStatSignificantSample.Checked :=
        ReadBool('Params', 'StatSignificantSample', False);
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
      WriteBool('Params', 'StatSignificantSample',
        chkStatSignificantSample.Checked);
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
  if FindFirst(sG_AppPath + 'players' + PathDelim + '*.trp', faAnyFile, rFileDesc) = 0 then
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
  if FindFirst(sG_AppPath + 'maps'+ PathDelim + '*.trm', faAnyFile, rFileDesc) = 0 then begin
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
  iRequestedGames, iMaxSampleGames, iStatIndex: Integer;
  bUseStatSignificantSample, bStatSignificantReached: Boolean;
  SamplePlayers: TStringList;
  SampleAppearances, SampleWins: array of Integer;
  GameRoster: TStringList;

  function SamplePlayerIndex(const sPlayerName: string): Integer;
  begin
    Result := SamplePlayers.IndexOf(sPlayerName);
    if Result < 0 then begin
      Result := SamplePlayers.Add(sPlayerName);
      SetLength(SampleAppearances, SamplePlayers.Count);
      SetLength(SampleWins, SamplePlayers.Count);
    end;
  end;

  function HasStatisticallySignificantSample: Boolean;
  var
    j: Integer;
    dZ, dZSquared, dRate, dWilsonDenominator, dWilsonHalfWidth: Double;
  begin
    Result := SamplePlayers.Count > 0;
    dZ := 1.96;
    dZSquared := dZ * dZ;
    for j := 0 to SamplePlayers.Count - 1 do begin
      if SampleAppearances[j] = 0 then begin
        Result := False;
        Exit;
      end;
      dRate := SampleWins[j] / SampleAppearances[j];
      dWilsonDenominator := 1 + dZSquared / SampleAppearances[j];
      dWilsonHalfWidth := (dZ / dWilsonDenominator) *
        Sqrt(dRate * (1 - dRate) / SampleAppearances[j] +
        dZSquared / (4.0 * SampleAppearances[j] * SampleAppearances[j]));
      if dWilsonHalfWidth > 0.05 then begin
        Result := False;
        Exit;
      end;
    end;
  end;

begin
  // prepare global variables
  iSimGames := StrToIntDef(txtGames.Text, 0);
  iRequestedGames := iSimGames;
  iMaxSampleGames := iSimGames;
  iSimMinPl := StrToIntDef(txtMinPlayers.Text, 0);
  iSimMaxPl := StrToIntDef(txtMaxPlayers.Text, 0);
  iSimTimeLimit := StrToIntDef(txtTimeLimit.Text, 0);
  iSimTurnLimit := StrToIntDef(txtTurnLimit.Text, 0);
  sSimGameLogFile := txtGameLogFile.Text;
  sSimCPULogFile := txtCPULogFile.Text;
  // validity check
  if iSimGames <= 0 then begin
    if bTRSimCLI then
      raise Exception.Create('Invalid number of games.');
    ShowMessage('Invalid number of games.');
    txtGames.SetFocus;
    exit;
  end;
  if (iSimMinPl < 2) or (iSimMaxPl > 10) or (iSimMaxPl < iSimMinPl) then begin
    if bTRSimCLI then
      raise Exception.Create('Invalid number of players. Min=2, max=10');
    ShowMessage('Invalid number of players. Min=2, max=10');
    txtMinPlayers.SetFocus;
    exit;
  end;
  if lstAlways.Count > iSimMinPl then begin
    if bTRSimCLI then
      raise Exception.Create(
        'The number of TRPs in the "always" list is greater than the minimum number of players per game.');
    ShowMessage(
      'The number of TRPs in the "always" list is greater then the minimum number of players per game.');
    txtMinPlayers.SetFocus;
    exit;
  end;
  if lstAlways.Count + lstRandom.Count < iSimMaxPl then begin
    if bTRSimCLI then
      raise Exception.Create(
        'The total number of TRPs in the "always" and "random" lists is not large enough to reach the maximum number of players per game.');
    ShowMessage(
      'The total number of TRPs in the "always" and "random" lists is not large enough to reach the maximum number of players per game.');
    txtMaxPlayers.SetFocus;
    exit;
  end;
  bUseStatSignificantSample :=
    (bTRSimCLI and fCliStatSignificantSample) or
    (not bTRSimCLI and chkStatSignificantSample.Checked);
  bStatSignificantReached := False;
  SamplePlayers := nil;
  SampleAppearances := nil;
  SampleWins := nil;
  if bUseStatSignificantSample then begin
    if iRequestedGames > High(Integer) div 10 then
      iMaxSampleGames := High(Integer)
    else
      iMaxSampleGames := iRequestedGames * 10;
    iSimGames := iMaxSampleGames;
    SamplePlayers := TStringList.Create;
    for i := 0 to lstAlways.Count - 1 do
      SamplePlayerIndex(ChangeFileExt(lstAlways.Items[i], ''));
    for i := 0 to lstRandom.Count - 1 do
      SamplePlayerIndex(ChangeFileExt(lstRandom.Items[i], ''));
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
  if bUseStatSignificantSample then
    fSimRun.SimLog('Statistical sample mode: minimum ' +
      IntToStr(iRequestedGames) + ' games, maximum ' +
      IntToStr(iMaxSampleGames) + ' games');
  if not bTRSimCLI and not fSimRun.Visible then
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
      if fPlayerSchedule = nil then begin
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
      end
      else begin
        GameRoster := TStringList.Create;
        try
          GameRoster.StrictDelimiter := True;
          GameRoster.Delimiter := ',';
          GameRoster.DelimitedText :=
            fPlayerSchedule[(iSimCurr - 1) mod fPlayerSchedule.Count];
          iSimPlayers := GameRoster.Count;
          if (iSimPlayers < iSimMinPl) or (iSimPlayers > iSimMaxPl) or
             (iSimPlayers > MAXPLAYERS) then
            raise Exception.CreateFmt('Invalid scheduled roster for game %d',
              [iSimCurr]);
          for iP := 1 to iSimPlayers do begin
            arPlayer[iP].Active := true;
            arPlayer[iP].PrgFile := GameRoster[iP - 1];
            arPlayer[iP].Name := ChangeFileExt(GameRoster[iP - 1], '');
          end;
        finally
          GameRoster.Free;
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
          begin
            fCliErrorOccurred := True;
            fSimRun.SimLog('Game #' + IntToStr(iSimCurr)
              + ' aborted for TRP error');
          end;
        ssTurnLimit:
          fSimRun.SimLog('Game #' + IntToStr(iSimCurr) +
            ' aborted, turn limit reached');
        ssTimeLimit:
          fSimRun.SimLog('Game #' + IntToStr(iSimCurr) +
            ' aborted, time limit reached');
        ssAbort:
          fSimRun.SimLog('Game #' + IntToStr(iSimCurr) + ' aborted by user');
      end;
      if bUseStatSignificantSample and (uSimStatus = ssComplete) then begin
        for iP := 1 to iSimPlayers do
          if arPlayer[iP].Active then begin
            iStatIndex := SamplePlayerIndex(arPlayer[iP].Name);
            Inc(SampleAppearances[iStatIndex]);
            if iP = iSimWinner then
              Inc(SampleWins[iStatIndex]);
          end;
      end;
      // log game data
      UpdateHistoryFile;
      // log CPU data
      LogCPU;
      // update stats
      if not bSimAbort then
        inc(iSimCompl);
      if bUseStatSignificantSample and
         (iSimCurr >= iRequestedGames) and
         HasStatisticallySignificantSample then begin
        bStatSignificantReached := True;
        fSimRun.SimLog('Statistically significant sample reached after ' +
          IntToStr(iSimCurr) + ' games (95% Wilson confidence interval within ' +
          '+/- 5 percentage points for every included player)');
      end;
    until (iSimCompl = iSimGames) or bSimAbort or
      (bUseStatSignificantSample and
       (bStatSignificantReached or (iSimCurr >= iMaxSampleGames)));
  finally
    // last update of stats
    fSimRun.UpdateSimStats;
    if bSimAbort then
      fSimRun.SimLog('*** Simulation aborted by user ***')
    else if bUseStatSignificantSample and not bStatSignificantReached then begin
      fSimRun.SimLog('Statistically significant sample not reached within the ' +
        IntToStr(iMaxSampleGames) + '-game limit');
      fSimRun.SimLog('*** Simulation ends ***');
    end
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
    if SamplePlayers <> nil then
      SamplePlayers.Free;
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
  LogFile := TIniFile.Create(ResolveSimPath(sSimCPULogFile));
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
