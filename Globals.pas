unit Globals;

{$MODE Delphi}

interface

uses LCLIntf, LCLType, LMessages, Graphics, Classes, uPSRuntime, uPSPreProcessor;

const
  VERSION = '2.0.5'; // TurboRisk
  VERSION_TRSIM = '1.0'; // TRSim
  MAXTERRITORIES = 42; // Number of countries in the map
  MAXBORDERS = 6; // Max number of borders per Territory
  MAXORIGINS = 20; // Max number of floodfill points per Territory (for coloring)
  MAXPLAYERS = 10; // Max number of players
  MAXPLSETS = 50; // Max number of players sets
  STDPLSETS = 5; // Number of standard players sets
  // MAXLOGLINES = 100;    // Max number of log lines
  MAXBUFFER = 500; // Number of buffers for the computer players

  aiDefTradeVal: array [1 .. 8] of byte = (4, 6, 8, 10, 12, 15, 20, 25);
  aiDefIniArmy: array [2 .. MAXPLAYERS] of byte = (40, 35, 30, 25, 20, 20, 20,
    20, 20);
  atDefColor: array [1 .. MAXPLAYERS] of TColor = (clBlue, clRed, clGreen,
    clYellow, clAqua, clFuchsia, clLime, clCream, clMaroon, clPurple);

type
  TGameState = (gsStopped, gsAssigning, gsDistributing, gsPlaying);
  THumanPhase = (hpPlacement, hpAttack);
  TCard = (caInf, caArt, caCav, caJok);
  TCardsSet = (csInf, csArt, csCav, csDif);
  TCardsHandling = (chManual, chSmart, chAuto);
  TContId = (coNA, coSA, coEU, coAF, coAS, coAU);
  TSimStatus = (ssRunning, ssComplete, ssError, ssTurnLimit, ssTimeLimit,
    ssAbort);

  TTerritory = record // Information about a territory
    // Dynamic, they change during the game
    Owner: integer; // Player who owns the territory
    Army: integer; // Number of occupying armies
    // Static, specific of each territory
    Name: string; // Name
    NBord: integer; // Number of borders
    Bord: array [1 .. MAXBORDERS] of integer;
    // Pointers to the border territories
    Contin: TContId; // Continent which the territory belongs to
    // Semi-dynamic, depending on the actual map
    Color: TColor; // Color in the base map
    Coord: TPoint; // Coordinates for the label showing the armies
    NOrig: integer; // Number of floodfill areas for coloring
    Orig: array [1 .. MAXORIGINS] of TPoint; // Coordinates of floodfill areas
  end;

  TContInfo = record // Information about a continent
    // Dynamic, they change during the game
    Owner: integer; // Owner of the continent (if any)
    // Static, specific of each continent
    Name: string; // Name
    Bonus: integer; // Bonus armies for the owner
  end;

  TCPUusage = record // Information about CPU usage by TRPs (for TRSim)
    iTime: int64; // length of calls (in high resolution timer ticks)
    iPhases, // number of phases (e.g. attack, occupation...)
    iCalls: integer; // number of calls
  end;

  TRoutine = (rtAssignment, rtPlacement, rtAttack, rtOccupation,
    rtFortification);

  TPlayer = record // Information about a player
    // Parameters selected by the player
    Name: string; // Name
    Active: boolean; // Flag, true when the player is (still) active
    Color: TColor; // Color to represent the player
    Computer: boolean; // Flag, true if player is a TRP
    CardsHandling: TCardsHandling; // Card handling option
    KeepLog: boolean; // Flag, true if the player keeps the log
    PrgFile: string; // Source file name for computer players (TRP)
    Code: ansistring; // Tokenized script for computer players (compiled TRP)
    // Status variables
    Army: integer; // Total armies (not updated in real-time)
    NewArmy: integer; // Armies to be placed
    Territ: integer; // Number of owned territories
    Cards: array [TCard] of integer; // Count of the owned cards (number of cards per kind)
    NScambi: integer; // N° scambi carte effettuati
    FlConq: boolean; // Flag, true if the player conquered at least one territory during the turn
    FlMove: boolean; // Flag, true if the player performed at leaste one troops move during the turn
    LastTurn, // last turn played by the player
    Rank: integer; // Rank at the end of the game
    // Runtime variables
    Buffer: array [1 .. MAXBUFFER] of double; // Buffer reserved to the TRPs for their 'static' values
    USnapShotEnabled, // flag to enable USnapShot
    ULogEnabled, // flag to enable ULog
    UMessageEnabled, // flag to enable UMessage
    UDialogEnabled: boolean; // flag to enable UDialog
    // TRSim statistics
    aCPU: array [TRoutine] of TCPUusage;
  end;

  TPlayersSet = record // Information about a set of players
    Name: string; // Name
    arPlSet: array [0 .. MAXPLAYERS] of record Name: string; // Name
    Active: boolean; // Flag, true when the player is (still) active
    Color: TColor; // Color to represent the player
    Computer: boolean; // Flag, true if player is a TRP
    CardsHandling: TCardsHandling; // Card handling option
    KeepLog: boolean; // Flag, true if the player keeps the log
    PrgFile: string; // Source file name for computer players (TRP)
  end;

end;

var

  // Generic global variabils
  bG_TRSim: boolean; // true if the main program is TRSim
  sG_AppName, // application name
  sG_AppVers, // version
  sG_AppPath: string; // exe file name
  sG_LastNews: TDate; // last read news
  iPerformanceFrequency: int64; // frequency of the high-resolution performance counter

  // Global variables about the state of the game
  GameState: TGameState; // phase of the game
  iTurnCounter, // counts turn progression
  iTurn: integer; // current player
  iFirstTurn: integer; // player who play first and starts the game
  iNPlayers: integer; // number of players in the game
  iToAssign: integer; // number of territories non yet assigned
  bHumanTurn: boolean; // flag, true if current turn is for a human player
  HumanPhase: THumanPhase; // human player's phase of the turn
  bEliminatedPlayer: boolean; // flag, true if opponent got eliminated during the last attack
  bStopASAP: boolean; // the user required to stop the game
  bCloseASAP: boolean; // the user required to close TurboRisk
  iRank: integer; // rank to assign to the player

  // Global variables about the map
  BaseMap: TBitmap; // Hidden base map for territory recognition
  arTerritory: array [1 .. MAXTERRITORIES] of TTerritory; // Territories
  arContinent: array [TContId] of TContInfo; // Continents
  sMapFile, // File name of the map (.trm)
  sMapDesc, // Map description
  sMapFontName: string; // Map font name
  iMapFontSize: integer; // Map font size
  tMapTextFG, tMapTextBG: TColor; // text foreground and background colors

  // Global variables about players and sets of players
  arPlayer: array [0 .. MAXPLAYERS] of TPlayer; // Players
  arPlayersSet: array [0 .. MAXPLSETS] of TPlayersSet; // Players
  aiTurnList: array [0 .. MAXPLAYERS] of integer; // Turn sequence
  iPlSet, // curent players set
  iPlSetCount: integer; // total players sets

  // Global variables about the rules
  RAssignmentType: (atRandom, atTurns); // Type of territory assignment
  RInitialArmies: array [2 .. MAXPLAYERS] of integer;
  // Number of initial armies to place
  RCardsValueType: (cvConstant, cvProgressive); // Card trade value scheme
  RSetValue: array [TCardsSet] of integer; // Value of the cards sets for the constant value scheme
  RTradeValue: array [1 .. 8] of integer; // Value of the cards sets for the progressive value scheme
  RValueInc: integer; // Value increment for the progressive value scheme after 8th trade
  RMaxHeldCards: integer; // Max number of cards a player can hold without trading
  RFinalMove: boolean; // Flag, true if troops move is allowed only at the end of a turn
  RImmediateTrade: boolean; // Flag, true if immediate trade of captured cards is allowed

  // Global variable about stats
  bStOpTer, // flag, if true the stats show territories
  bStOpArm, // flag, if true the stats show armies
  bStOpCon, // flag, if true the stats show continents
  bStOpCar, // flag, if true the stats show cards count
  bStOpCTIV: boolean; // flag, if true the stats show cards turn in value

  // The script executer
  ScriptExec: TPSExec;

  // Interface preferences
  sPrefTlbButtons: string; // toolbar buttons
  bPrefConfirmAbort, // flag, true if user is required confirmation before aborting a game in progress
  bPrefShowToolbar, // flag, true if user wants the toolbar enabled
  bPrefCheckUpdate, // flag, true if user wants to check for updates at startup
  bPrefExpertAttack, // flag, true if user wants the Expert Attack window
  bPrefMapHoover, // flag, true if user wants territory to change color when hooverd
  bPrefMapSelected: boolean; // flag, true if user wants territory to change color when selected
  iPrefMapHoover, // % of color intensity decrease/increase when hoovering
  iPrefMapSelected: integer; // % of color intensity decrease/increase when selecting

  // TRSim simulation environment
  iSimCurr, // current simulation game
  iSimCompl, // number of finished games
  iSimGames, // number of games to simulate
  iSimWinner, // number of the winner
  iSimGameTime, // duration of last game, in seconds
  iSimTimeLimit, // max number of seconds per game
  iSimTurnLimit, // max number of turns per game
  iSimPlayers, // number of players in current game
  iSimMinPl, // minimum players per game
  iSimMaxPl: integer; // maximum players per game
  uSimStatus: TSimStatus; // termination type
  bSimAbort: boolean; // flag, true to abort simulation
  dtSimGameTime, // game start time
  dtSimStartTime: TDateTime; // simulation start time
  sSimGameLogFile, // name of the game log file
  sSimCPULogFile: string; // name of the CPU log file

  // Application Setup
procedure Setup;

// Application Cleanup
procedure Cleanup;

// Menu setup according to the state of the game
procedure MenuSetup;

// New game setup
procedure NewGameSetup;

// Game cleanup
procedure GameCleanup;

// Initial random assignment
procedure RandomAssignment;

// Assign new armies
procedure AssignNewArmies(bCardsOnly: boolean);

// Perform an attack
function PerformAttack(iTA, iTD: integer): boolean;

// Supervisor for the game turns and phases
procedure Supervisor;

// Update history file
procedure UpdateHistoryFile;

// Restore game from file
procedure RestoreGame(sFileName: string);

// Save game to file
procedure SaveGame(sFileName, sErrorMsg: string);

// Find best contrast text color
function BestTextColor(tBkgColor: TColor): TColor;

// Make a color lighter or darker
function ChangeColor(Color: TColor; Percent: shortint): TColor;

// functions to set and get curront from, to and hoovered territories
function GetFromTerritory: integer;
function GetToTerritory: integer;
function GetHooverTerritory: integer;
procedure SetFromTerritory(iT: integer);
procedure SetToTerritory(iT: integer);
procedure SetHooverTerritory(iT: integer);

implementation

uses Forms, SysUtils, IniFiles, Dialogs, Math, DateUtils,
  uPSCompiler,
  Main, Territ, Computer, Stats, Human, Cards, Log, ExpSubr, History, SimRun;

var
  bAssignmentFound, // flags to check if the script
  bPlacementFound, // contains all the required procedures
  bAttackFound, bOccupationFound, bFortificationFound: boolean;
  // private vars about territories, changed and queried through proper functions
  HooverTerrit, // territory hoovered with the mouse pointer
  ToTerrit, // territory choosen by curent player to attack or to move to
  FromTerrit: integer; // territory choosen by curent player to attack or to move from

function ScriptOnUses(Sender: TPSPascalCompiler;
  const Name: ansistring): boolean;
{ the OnUses callback function is called for each "uses" in the script.
  It's always called with the parameter 'SYSTEM' at the top of the script.
  For example: uses ii1, ii2;
  This will call this function 3 times. First with 'SYSTEM' then 'II1' and then 'II2'.
}
begin
  if Name = 'SYSTEM' then begin
    // register external functions
    Sender.AddDelphiFunction('function TName(T: integer): string');
    Sender.AddDelphiFunction('function TOwner(T: integer): integer');
    Sender.AddDelphiFunction('function TName(T: integer): string');
    Sender.AddDelphiFunction('function TOwner(T: integer): integer');
    Sender.AddDelphiFunction('function TArmies(T: integer): integer');
    Sender.AddDelphiFunction('function TContinent(T: integer): integer');
    Sender.AddDelphiFunction('function TBordersCount(T: integer): integer');
    Sender.AddDelphiFunction('function TBorder(T,B: integer): integer');
    Sender.AddDelphiFunction('function TIsBordering(T1,T2: integer): boolean');
    Sender.AddDelphiFunction('function TIsFront(T: integer): boolean');
    Sender.AddDelphiFunction('function TIsMine(T: integer): boolean');
    Sender.AddDelphiFunction('function TIsEntry(T: integer): boolean');
    Sender.AddDelphiFunction('function TFrontsCount(T: integer): integer');
    Sender.AddDelphiFunction('function TFront(T,F: integer): integer');
    Sender.AddDelphiFunction(
      'function TStrongestFront(T: integer; var ET,EA: integer): boolean');
    Sender.AddDelphiFunction(
      'function TWeakestFront(T: integer; var ET,EA: integer): boolean');
    Sender.AddDelphiFunction('function TPressure(T: integer): integer');
    Sender.AddDelphiFunction('function TDistance(ST, DT: integer): integer;');
    Sender.AddDelphiFunction(
      'function TShortestPath(ST, DT: integer; var TT, PL: integer): boolean;');
    Sender.AddDelphiFunction(
      'function TWeakestPath(ST, DT: integer; var TT, PL, EA: integer): boolean;');
    Sender.AddDelphiFunction('function TPathToFront(T: integer): integer;');
    Sender.AddDelphiFunction('function PMe: integer');
    Sender.AddDelphiFunction('function PName(P: integer): string');
    Sender.AddDelphiFunction('function PProgram(P: integer): string');
    Sender.AddDelphiFunction('function PActive(P: integer): boolean');
    Sender.AddDelphiFunction('function PAlive(P: integer): boolean');
    Sender.AddDelphiFunction('function PHuman(P: integer): boolean');
    Sender.AddDelphiFunction('function PArmiesCount(P: integer): integer');
    Sender.AddDelphiFunction('function PNewArmies(P: integer): integer');
    Sender.AddDelphiFunction('function PTerritoriesCount(P: integer): integer');
    Sender.AddDelphiFunction('function PCardCount(P: integer): integer');
    Sender.AddDelphiFunction('function PCardTurnInValue(P: integer): integer');
    Sender.AddDelphiFunction('function COwner(C: integer): integer');
    Sender.AddDelphiFunction('function CBonus(C: integer): integer');
    Sender.AddDelphiFunction('function CTerritoriesCount(C: integer): integer');
    Sender.AddDelphiFunction('function CTerritory(C,T: integer): integer');
    Sender.AddDelphiFunction('function CBordersCount(C: integer): integer');
    Sender.AddDelphiFunction('function CBorder(C,B: integer): integer');
    Sender.AddDelphiFunction('function CEntriesCount(C: integer): integer');
    Sender.AddDelphiFunction('function CEntry(C,B: integer): integer');
    Sender.AddDelphiFunction(
      'function CAnalysis(C: integer; var PT,PA,ET,EA: integer): boolean');
    Sender.AddDelphiFunction(
      'function CLeader(C: integer; var P,T,A: integer): boolean');
    Sender.AddDelphiFunction('function SConquest: boolean');
    Sender.AddDelphiFunction('function SPlayersCount: integer');
    Sender.AddDelphiFunction('function SAlivePlayersCount: integer');
    Sender.AddDelphiFunction('function SCardsBasedOnCombo: boolean');
    Sender.AddDelphiFunction('procedure UMessage(M: string)');
    Sender.AddDelphiFunction('procedure ULog(M: string)');
    Sender.AddDelphiFunction('procedure UBufferSet(B: integer; V: double)');
    Sender.AddDelphiFunction('function UBufferGet(B: integer): double');
    Sender.AddDelphiFunction('function URandom(R: integer): double');
    Sender.AddDelphiFunction('procedure UTakeSnapshot(M: string)');
    Sender.AddDelphiFunction('function UDialog(M,B: string): integer');
    Sender.AddDelphiFunction('procedure UAbortGame');
    Sender.AddDelphiFunction('procedure ULogOff');
    Sender.AddDelphiFunction('procedure ULogOn');
    Sender.AddDelphiFunction('procedure UMessageOff');
    Sender.AddDelphiFunction('procedure UMessageOn');
    Sender.AddDelphiFunction('procedure UDialogOff');
    Sender.AddDelphiFunction('procedure UDialogOn');
    Sender.AddDelphiFunction('procedure USnapShotOff');
    Sender.AddDelphiFunction('procedure USnapShotOn');
    Result := True;
  end
  else
    Result := False;
end;

function ScriptOnExportCheck(Sender: TPSPascalCompiler;
  Proc: TPSInternalProcedure; const ProcDecl: ansistring): boolean;
{
  The OnExportCheck callback function is called for each function in the script
  (Also for the main proc, with '!MAIN' as a Proc^.Name). ProcDecl contains the
  result type and parameter types of a function using this format:
  ProcDecl: ResultType + ' ' + Parameter1 + ' ' + Parameter2 + ' '+Parameter3 + .....
  Parameter: ParameterType+TypeName
  ParameterType is @ for a normal parameter and ! for a var parameter.
  A result type of 0 means no result.
}
var
  sExpectedPar: string;
begin
  sExpectedPar := '';
  if (Proc.Name = 'ASSIGNMENT') then begin
    bAssignmentFound := True;
    sExpectedPar := '0 !LONGINT';
  end
  else if (Proc.Name = 'PLACEMENT') then begin
    bPlacementFound := True;
    sExpectedPar := '0 !LONGINT';
  end
  else if (Proc.Name = 'ATTACK') then begin
    bAttackFound := True;
    sExpectedPar := '0 !LONGINT !LONGINT';
  end
  else if (Proc.Name = 'OCCUPATION') then begin
    bOccupationFound := True;
    sExpectedPar := '0 @LONGINT @LONGINT !LONGINT';
  end
  else if (Proc.Name = 'FORTIFICATION') then begin
    bFortificationFound := True;
    sExpectedPar := '0 !LONGINT !LONGINT !LONGINT';
  end;
  // check if procedure declaration matched expected declaration
  if sExpectedPar <> '' then begin
    if ProcDecl <> sExpectedPar then begin
      Sender.MakeError('', ecCustomError,
        'Type mismatch in declaration of procedure ' + Proc.Name);
      Result := False;
      Exit;
    end;
    // Proc.aExport := etExportDecl; // Export the proc; This is needed because IFPS doesn't store the name of a function by default
    Result := True;
  end
  else begin
    Result := True;
  end;
end;

procedure DefaultPlayersSets;
var
  i, iP, iPLCount: integer;
  procedure AddPlayer(i: integer; sPrg: string);
  begin
    with arPlayersSet[i] do begin
      inc(iPLCount);
      arPlSet[iPLCount].PrgFile := sPrg;
      arPlSet[iPLCount].Name := ChangeFileExt(sPrg, '');
      arPlSet[iPLCount].Active := True;
      arPlSet[iPLCount].Computer := True;
    end;
  end;

begin
  iPlSetCount := STDPLSETS;
  for i := 1 to STDPLSETS do
    with arPlayersSet[i] do begin
      for iP := 1 to MAXPLAYERS do begin
        arPlSet[iP].Name := '';
        arPlSet[iP].Computer := False;
        arPlSet[iP].Active := False;
        arPlSet[iP].CardsHandling := chSmart;
        arPlSet[iP].Color := atDefColor[iP];
      end;
      iPLCount := 1;
      arPlSet[1].Name := 'human';
      arPlSet[1].Active := True;
      case i of
        1: begin
            Name := '* Very easy *';
            AddPlayer(i, 'napoleon.trp');
            AddPlayer(i, 'rambo.trp');
            AddPlayer(i, 'simple.trp');
          end;
        2: begin
            Name := '* Easy *';
            AddPlayer(i, 'alexander.trp');
            AddPlayer(i, 'borg.trp');
            AddPlayer(i, 'napoleon.trp ');
            AddPlayer(i, 'rambo.trp');
            AddPlayer(i, 'struggler.trp ');
          end;
        3: begin
            Name := '* Medium *';
            AddPlayer(i, 'digger.trp');
            AddPlayer(i, 'era$or-bot.trp');
            AddPlayer(i, 'raptorbot.trp');
            AddPlayer(i, 'shy.trp');
            AddPlayer(i, 'struggler.trp');
          end;
        4: begin
            Name := '* Hard *';
            AddPlayer(i, 'australian+.trp');
            AddPlayer(i, 'digger.trp');
            AddPlayer(i, 'era$or-bot.trp');
            AddPlayer(i, 'raptorbot.trp');
            AddPlayer(i, 'shy2.trp');
            AddPlayer(i, 'wyrm.trp');
            AddPlayer(i, 'zotob.trp');
          end;
        5: begin
            Name := '* Very hard *';
            AddPlayer(i, 'australian09.trp');
            AddPlayer(i, 'descartes09.trp');
            AddPlayer(i, 'frank+.trp');
            AddPlayer(i, 'raptorbot.trp');
            AddPlayer(i, 'shy.trp');
            AddPlayer(i, 'vexer.trp');
            AddPlayer(i, 'wyrm.trp');
            AddPlayer(i, 'struggler+.trp');
          end;
      end;
    end;
end;

// Application Setup
procedure Setup;
var
  IniFile: TIniFile;
  i, iP: integer;
  sTmp: string;
begin

  Randomize;

  // get the frequency of the high-resolution performance counter
  iPerformanceFrequency:=1;//SysUtils.GetTickCount64();
//  QueryPerformanceFrequency(iPerformanceFrequency);
  if iPerformanceFrequency = 0 then
    iPerformanceFrequency := 1;

  // generic global vars
  sG_AppName := 'TurboRisk';
  if bG_TRSim then
    sG_AppVers := VERSION_TRSIM
  else
    sG_AppVers := VERSION;
  sG_AppPath := ExtractFilePath(Application.ExeName);
  bCloseASAP := False;

  // Default players sets
  DefaultPlayersSets;

  // load INI file
  IniFile := TIniFile.Create(sG_AppPath + sG_AppName + '.INI');
  try
    with IniFile do begin
      // News
      sTmp := ReadString('News', 'LastRead', FormatDateTime('yyyymmdd',Today));
      sG_LastNews := EncodeDate(StrToInt(copy(sTmp, 1, 4)),
        StrToInt(copy(sTmp, 5, 2)), StrToInt(copy(sTmp, 7, 2)));
      // Windows setup
      fMain.Top := ReadInteger('Windows', 'MainTop', 0);
      fMain.Left := ReadInteger('Windows', 'MainLeft', 0);
      fStats.Top := ReadInteger('Windows', 'StatsTop', 0);
      fStats.Left := ReadInteger('Windows', 'StatsLeft', 0);
      bStOpTer := ReadBool('Windows', 'StatsTer', True);
      bStOpArm := ReadBool('Windows', 'StatsArm', True);
      bStOpCon := ReadBool('Windows', 'StatsCon', True);
      bStOpCar := ReadBool('Windows', 'StatsCar', True);
      bStOpCTIV := ReadBool('Windows', 'StatsCTIV', True);
      if bG_TRSim then
        fStats.Visible := False
      else
        fStats.Visible := ReadBool('Windows', 'StatsVisible', False);
      fLog.Top := ReadInteger('Windows', 'LogTop', 0);
      fLog.Left := ReadInteger('Windows', 'LogLeft', 0);
      fLog.Width := ReadInteger('Windows', 'LogWidth', 100);
      fLog.Height := ReadInteger('Windows', 'LogHeight', 100);
      fLog.Visible := ReadBool('Windows', 'LogVisible', False);
      fHistory.Top := ReadInteger('Windows', 'HistoryTop', 0);
      fHistory.Left := ReadInteger('Windows', 'HistoryLeft', 0);
      fHistory.Width := ReadInteger('Windows', 'HistoryWidth', 500);
      fHistory.Height := ReadInteger('Windows', 'HistoryHeight', 400);
      // Preferences
      bPrefShowToolbar := ReadBool('Pref', 'ShowToolbar', True);
      fMain.tlbToolBar.Visible := bPrefShowToolbar;
      sPrefTlbButtons := ReadString('Pref', 'Toolbar', '011111000000000');
      for i := 0 to fMain.tlbToolBar.ButtonCount - 3 do begin
        fMain.tlbToolBar.Buttons[i].Visible := (sPrefTlbButtons[i + 1] <> '0');
      end;
      bPrefExpertAttack := ReadBool('Pref', 'ExpertAttack', False);
      bPrefMapHoover := ReadBool('Pref', 'MapHooverOn', True);
      bPrefMapSelected := ReadBool('Pref', 'MapSelectedOn', True);
      iPrefMapHoover := ReadInteger('Pref', 'MapHooverP', -20);
      iPrefMapSelected := ReadInteger('Pref', 'MapSelectedP', -20);
      bPrefConfirmAbort := ReadBool('Pref', 'ConfirmAbort', True);
      bPrefCheckUpdate := ReadBool('Pref', 'CheckUpdate', False);
      // Map
      sMapFile := ReadString('Map', 'File', 'std_map_small.trm');
      // Rules
      case ReadInteger('Rules', 'Assignment', 0) of
        0:
          RAssignmentType := atRandom;
        1:
          RAssignmentType := atTurns;
      end;
      for iP := 2 to MAXPLAYERS do begin
        RInitialArmies[iP] := ReadInteger('Rules', 'InitArmies' + IntToStr(iP),
          aiDefIniArmy[iP]);
      end;
      case ReadInteger('Rules', 'CardUsage', 1) of
        0:
          RCardsValueType := cvConstant;
        1:
          RCardsValueType := cvProgressive;
      end;
      RSetValue[csArt] := ReadInteger('Rules', 'ArtSetValue', 4);
      RSetValue[csInf] := ReadInteger('Rules', 'InfSetValue', 6);
      RSetValue[csCav] := ReadInteger('Rules', 'CavSetValue', 8);
      RSetValue[csDif] := ReadInteger('Rules', 'DifSetValue', 10);
      for i := 1 to 8 do begin
        RTradeValue[i] := ReadInteger('Rules', 'TradeValue' + IntToStr(i),
          aiDefTradeVal[i]);
      end;
      RValueInc := ReadInteger('Rules', 'TradeValueInc', 5);
      RMaxHeldCards := ReadInteger('Rules', 'MaxHeldCards', 5);
      RImmediateTrade := ReadBool('Rules', 'TradeCapturedCards', True);
      RFinalMove := ReadBool('Rules', 'AllowAttackAfterMove', True);
      // Players
      for iP := 1 to MAXPLAYERS do begin
        with arPlayer[iP] do begin
          Name := ReadString('Player' + IntToStr(iP), 'Name',
            'Player' + IntToStr(iP));
          Active := ReadBool('Player' + IntToStr(iP), 'Active', True);
          Color := ReadInteger('Player' + IntToStr(iP), 'Color',
            atDefColor[iP]);
          Computer := ReadBool('Player' + IntToStr(iP), 'Computer', True);
          KeepLog := ReadBool('Player' + IntToStr(iP), 'Log', False);
          CardsHandling := TCardsHandling(ReadInteger('Player' + IntToStr(iP),
              'AutoCards', 1));
          PrgFile := ReadString('Player' + IntToStr(iP), 'PrgFile', '');
          if PrgFile = '' then
            PrgFile := 'simple.trp';
        end;
      end;
      // Players sets
      iPlSetCount := ReadInteger('PlSets', 'Count', STDPLSETS);
      iPlSet := ReadInteger('PlSets', 'Set', 0);
      for i := STDPLSETS + 1 to iPlSetCount do begin
        arPlayersSet[i].Name := ReadString('PlSet' + IntToStr(i), 'Name',
          'PlSet' + IntToStr(i));
        for iP := 1 to MAXPLAYERS do begin
          with arPlayersSet[i].arPlSet[iP] do begin
            Name := ReadString('PlSet' + IntToStr(i), 'Name' + IntToStr(iP),
              '');
            Active := ReadBool('PlSet' + IntToStr(i), 'Active' + IntToStr(iP),
              True);
            Color := ReadInteger('PlSet' + IntToStr(i), 'Color' + IntToStr(iP),
              atDefColor[iP]);
            Computer := ReadBool('PlSet' + IntToStr(i),
              'Computer' + IntToStr(iP), True);
            KeepLog := ReadBool('PlSet' + IntToStr(i), 'Log' + IntToStr(iP),
              False);
            CardsHandling := TCardsHandling(ReadInteger('PlSet' + IntToStr(i),
                'AutoCards' + IntToStr(iP), 1));
            PrgFile := ReadString('PlSet' + IntToStr(i),
              'PrgFile' + IntToStr(iP), '');
            if PrgFile = '' then
              PrgFile := 'simple.trp';
          end;
        end;
      end;
    end;
  finally
    IniFile.Free;
  end;

  // 'nil' player, which is the default for non-assigned territories
  with arPlayer[0] do begin
    Name := 'Nil';
    Active := False;
    Color := clSilver;
  end;

  // Setup territories
  SetupTerritories;

  // Creat base map used to find territory from mouse position
  BaseMap := TBitmap.Create;

  // Load map from file
  LoadMap;

  // Initial state of the game (just as a game had just been completed)
  GameCleanup;

end;

// Application Cleanup
procedure Cleanup;
var
  IniFile: TIniFile;
  i, iP: integer;
begin

  if not bG_TRSim then begin // TRSim does not save main TurboRisk ini file

    // save setup on INI file
    IniFile := TIniFile.Create(sG_AppPath + sG_AppName + '.INI');
    try
      with IniFile do begin
        // News
        WriteString('News', 'LastRead',
          FormatDateTime('yyyymmdd', sG_LastNews));
        // Windows
        WriteInteger('Windows', 'MainTop', fMain.Top);
        WriteInteger('Windows', 'MainLeft', fMain.Left);
        WriteInteger('Windows', 'StatsTop', fStats.Top);
        WriteInteger('Windows', 'StatsLeft', fStats.Left);
        WriteBool('Windows', 'StatsVisible', fStats.Visible);
        WriteBool('Windows', 'StatsTer', bStOpTer);
        WriteBool('Windows', 'StatsArm', bStOpArm);
        WriteBool('Windows', 'StatsCon', bStOpCon);
        WriteBool('Windows', 'StatsCar', bStOpCar);
        WriteBool('Windows', 'StatsCTIV', bStOpCTIV);
        WriteInteger('Windows', 'LogTop', fLog.Top);
        WriteInteger('Windows', 'LogLeft', fLog.Left);
        WriteInteger('Windows', 'LogWidth', fLog.Width);
        WriteInteger('Windows', 'LogHeight', fLog.Height);
        WriteBool('Windows', 'LogVisible', fLog.Visible);
        WriteInteger('Windows', 'HistoryTop', fHistory.Top);
        WriteInteger('Windows', 'HistoryLeft', fHistory.Left);
        WriteInteger('Windows', 'HistoryWidth', fHistory.Width);
        WriteInteger('Windows', 'HistoryHeight', fHistory.Height);
        // Preferences
        WriteBool('Pref', 'ShowToolbar', bPrefShowToolbar);
        WriteString('Pref', 'Toolbar', sPrefTlbButtons);
        WriteBool('Pref', 'ExpertAttack', bPrefExpertAttack);
        WriteBool('Pref', 'MapHooverOn', bPrefMapHoover);
        WriteBool('Pref', 'MapSelectedOn', bPrefMapSelected);
        WriteInteger('Pref', 'MapHooverP', iPrefMapHoover);
        WriteInteger('Pref', 'MapSelectedP', iPrefMapSelected);
        WriteBool('Pref', 'ConfirmAbort', bPrefConfirmAbort);
        WriteBool('Pref', 'CheckUpdate', bPrefCheckUpdate);
        // Map
        WriteString('Map', 'File', sMapFile);
        // Rules
        WriteInteger('Rules', 'Assignment', ord(RAssignmentType));
        for iP := 2 to MAXPLAYERS do begin
          WriteInteger('Rules', 'InitArmies' + IntToStr(iP),
            RInitialArmies[iP]);
        end;
        WriteInteger('Rules', 'CardUsage', ord(RCardsValueType));
        WriteInteger('Rules', 'ArtSetValue', RSetValue[csArt]);
        WriteInteger('Rules', 'InfSetValue', RSetValue[csInf]);
        WriteInteger('Rules', 'CavSetValue', RSetValue[csCav]);
        WriteInteger('Rules', 'DifSetValue', RSetValue[csDif]);
        for i := 1 to 8 do begin
          WriteInteger('Rules', 'TradeValue' + IntToStr(i), RTradeValue[i]);
        end;
        WriteInteger('Rules', 'TradeValueInc', RValueInc);
        WriteInteger('Rules', 'MaxHeldCards', RMaxHeldCards);
        WriteBool('Rules', 'TradeCapturedCards', RImmediateTrade);
        WriteBool('Rules', 'AllowAttackAfterMove', RFinalMove);
        // Players
        for iP := 1 to MAXPLAYERS do begin
          with arPlayer[iP] do begin
            WriteString('Player' + IntToStr(iP), 'Name', Name);
            WriteBool('Player' + IntToStr(iP), 'Active', Active);
            WriteInteger('Player' + IntToStr(iP), 'Color', Color);
            WriteBool('Player' + IntToStr(iP), 'Computer', Computer);
            WriteBool('Player' + IntToStr(iP), 'Log', KeepLog);
            WriteInteger('Player' + IntToStr(iP), 'AutoCards',
              ord(CardsHandling));
            WriteString('Player' + IntToStr(iP), 'PrgFile', PrgFile);
          end;
        end;
        // Players sets
        WriteInteger('PlSets', 'Count', iPlSetCount);
        WriteInteger('PlSets', 'Set', iPlSet);
        for i := STDPLSETS + 1 to iPlSetCount do begin
          WriteString('PlSet' + IntToStr(i), 'Name', arPlayersSet[i].Name);
          for iP := 1 to MAXPLAYERS do begin
            with arPlayersSet[i].arPlSet[iP] do begin
              WriteString('PlSet' + IntToStr(i), 'Name' + IntToStr(iP), Name);
              WriteBool('PlSet' + IntToStr(i), 'Active' + IntToStr(iP), Active);
              WriteInteger('PlSet' + IntToStr(i), 'Color' + IntToStr(iP),
                Color);
              WriteBool('PlSet' + IntToStr(i), 'Computer' + IntToStr(iP),
                Computer);
              WriteBool('PlSet' + IntToStr(i), 'Log' + IntToStr(iP), KeepLog);
              WriteInteger('PlSet' + IntToStr(i), 'AutoCards' + IntToStr(iP),
                ord(CardsHandling));
              WriteString('PlSet' + IntToStr(i), 'PrgFile' + IntToStr(iP),
                PrgFile);
            end;
          end;
        end;
      end;
    finally
      IniFile.Free;
    end;
  end;
  BaseMap.Free;

end;

// Menu setup according to the state of the game
procedure MenuSetup;
begin
  with fMain do
    case GameState of
      gsStopped: begin
          mnuFilNew.Enabled := True;
          mnuFilEnd.Enabled := False;
          mnuFilSave.Enabled := False;
          mnuFilRestore.Enabled := True;
          mnuOptRules.Enabled := True;
          mnuOptPref.Enabled := True;
          cmdNewGame.Enabled := True;
          cmdEndGame.Enabled := False;
          cmdSaveGame.Enabled := False;
          cmdRestoreGame.Enabled := True;
          cmdEndTurn.Enabled := False;
          cmdRules.Enabled := True;
          cmdPreferences.Enabled := True;
        end;
      gsAssigning, gsPlaying: begin
          mnuFilNew.Enabled := False;
          mnuFilEnd.Enabled := True;
          mnuFilSave.Enabled := False;
          mnuFilRestore.Enabled := False;
          mnuOptRules.Enabled := False;
          mnuOptPref.Enabled := False;
          cmdNewGame.Enabled := False;
          cmdEndGame.Enabled := True;
          cmdSaveGame.Enabled := False;
          cmdRestoreGame.Enabled := False;
          cmdEndTurn.Enabled := False;
          cmdRules.Enabled := False;
          cmdPreferences.Enabled := False;
        end;
    end;
end;

// Create and prepare an instance of the script executer
procedure ScriptSetup;
begin

  // Create an instance of the script executer
  ScriptExec := TPSExec.Create;

  // Register the external functions to the executer
  // RegisterStandardLibrary_R(ScriptExec); // Register the standard library
  ScriptExec.RegisterDelphiFunction(@TName, 'TNAME', cdRegister);
  ScriptExec.RegisterDelphiFunction(@TOwner, 'TOWNER', cdRegister);
  ScriptExec.RegisterDelphiFunction(@TArmies, 'TARMIES', cdRegister);
  ScriptExec.RegisterDelphiFunction(@TContinent, 'TCONTINENT', cdRegister);
  ScriptExec.RegisterDelphiFunction(@TBordersCount, 'TBORDERSCOUNT',
    cdRegister);
  ScriptExec.RegisterDelphiFunction(@TBorder, 'TBORDER', cdRegister);
  ScriptExec.RegisterDelphiFunction(@TIsBordering, 'TISBORDERING', cdRegister);
  ScriptExec.RegisterDelphiFunction(@TIsFront, 'TISFRONT', cdRegister);
  ScriptExec.RegisterDelphiFunction(@TIsMine, 'TISMINE', cdRegister);
  ScriptExec.RegisterDelphiFunction(@TIsEntry, 'TISENTRY', cdRegister);
  ScriptExec.RegisterDelphiFunction(@TFrontsCount, 'TFRONTSCOUNT', cdRegister);
  ScriptExec.RegisterDelphiFunction(@TFront, 'TFRONT', cdRegister);
  ScriptExec.RegisterDelphiFunction(@TStrongestFront, 'TSTRONGESTFRONT',
    cdRegister);
  ScriptExec.RegisterDelphiFunction(@TWeakestFront, 'TWEAKESTFRONT',
    cdRegister);
  ScriptExec.RegisterDelphiFunction(@TPressure, 'TPRESSURE', cdRegister);
  ScriptExec.RegisterDelphiFunction(@TDistance, 'TDISTANCE', cdRegister);
  ScriptExec.RegisterDelphiFunction(@TShortestPath, 'TSHORTESTPATH',
    cdRegister);
  ScriptExec.RegisterDelphiFunction(@TWeakestPath, 'TWEAKESTPATH', cdRegister);
  ScriptExec.RegisterDelphiFunction(@TPathToFront, 'TPATHTOFRONT', cdRegister);
  ScriptExec.RegisterDelphiFunction(@PMe, 'PME', cdRegister);
  ScriptExec.RegisterDelphiFunction(@PName, 'PNAME', cdRegister);
  ScriptExec.RegisterDelphiFunction(@PProgram, 'PPROGRAM', cdRegister);
  ScriptExec.RegisterDelphiFunction(@PActive, 'PACTIVE', cdRegister);
  ScriptExec.RegisterDelphiFunction(@PAlive, 'PALIVE', cdRegister);
  ScriptExec.RegisterDelphiFunction(@PHuman, 'PHUMAN', cdRegister);
  ScriptExec.RegisterDelphiFunction(@PArmiesCount, 'PARMIESCOUNT', cdRegister);
  ScriptExec.RegisterDelphiFunction(@PNewArmies, 'PNEWARMIES', cdRegister);
  ScriptExec.RegisterDelphiFunction(@PTerritoriesCount, 'PTERRITORIESCOUNT',
    cdRegister);
  ScriptExec.RegisterDelphiFunction(@PCardCount, 'PCARDCOUNT', cdRegister);
  ScriptExec.RegisterDelphiFunction(@PCardTurnInValue, 'PCARDTURNINVALUE',
    cdRegister);
  ScriptExec.RegisterDelphiFunction(@COwner, 'COWNER', cdRegister);
  ScriptExec.RegisterDelphiFunction(@CBonus, 'CBONUS', cdRegister);
  ScriptExec.RegisterDelphiFunction(@CTerritoriesCount, 'CTERRITORIESCOUNT',
    cdRegister);
  ScriptExec.RegisterDelphiFunction(@CTerritory, 'CTERRITORY', cdRegister);
  ScriptExec.RegisterDelphiFunction(@CBordersCount, 'CBORDERSCOUNT',
    cdRegister);
  ScriptExec.RegisterDelphiFunction(@CBorder, 'CBORDER', cdRegister);
  ScriptExec.RegisterDelphiFunction(@CEntriesCount, 'CENTRIESCOUNT',
    cdRegister);
  ScriptExec.RegisterDelphiFunction(@CEntry, 'CENTRY', cdRegister);
  ScriptExec.RegisterDelphiFunction(@CAnalysis, 'CANALYSIS', cdRegister);
  ScriptExec.RegisterDelphiFunction(@CLeader, 'CLEADER', cdRegister);
  ScriptExec.RegisterDelphiFunction(@SConquest, 'SCONQUEST', cdRegister);
  ScriptExec.RegisterDelphiFunction(@SPlayersCount, 'SPLAYERSCOUNT',
    cdRegister);
  ScriptExec.RegisterDelphiFunction(@SAlivePlayersCount, 'SALIVEPLAYERSCOUNT',
    cdRegister);
  ScriptExec.RegisterDelphiFunction(@SCardsBasedOnCombo, 'SCARDSBASEDONCOMBO',
    cdRegister);
  ScriptExec.RegisterDelphiFunction(@UMessage, 'UMESSAGE', cdRegister);
  ScriptExec.RegisterDelphiFunction(@ULog, 'ULOG', cdRegister);
  ScriptExec.RegisterDelphiFunction(@UBufferSet, 'UBUFFERSET', cdRegister);
  ScriptExec.RegisterDelphiFunction(@UBufferGet, 'UBUFFERGET', cdRegister);
  ScriptExec.RegisterDelphiFunction(@URandom, 'URANDOM', cdRegister);
  ScriptExec.RegisterDelphiFunction(@UTakeSnapshot, 'UTAKESNAPSHOT',
    cdRegister);
  ScriptExec.RegisterDelphiFunction(@UDialogO, 'UDIALOGO', cdRegister);
  ScriptExec.RegisterDelphiFunction(@UAbortGame, 'UABORTGAME', cdRegister);
  ScriptExec.RegisterDelphiFunction(@ULogOff, 'ULOGOFF', cdRegister);
  ScriptExec.RegisterDelphiFunction(@ULogOn, 'ULOGON', cdRegister);
  ScriptExec.RegisterDelphiFunction(@UMessageOff, 'UMESSAGEOFF', cdRegister);
  ScriptExec.RegisterDelphiFunction(@UMessageOn, 'UMESSAGEON', cdRegister);
  ScriptExec.RegisterDelphiFunction(@UDialogOff, 'UDIALOGOFF', cdRegister);
  ScriptExec.RegisterDelphiFunction(@UDialogOn, 'UDIALOGON', cdRegister);
  ScriptExec.RegisterDelphiFunction(@USnapShotOff, 'USNAPSHOTOFF', cdRegister);
  ScriptExec.RegisterDelphiFunction(@USnapShotOn, 'USNAPSHOTON', cdRegister);
end;

// Free the script executer
procedure ScriptCleanup;
begin
  if ScriptExec <> nil then begin
    ScriptExec.Free;
    ScriptExec := nil;
  end;
end;

function CompileTRP(Compiler: TPSPascalCompiler;
  sName, sSource: string): boolean;
var
  sCompErr: string;
  iErr: integer;
  sPPout: ansistring;
begin
  Result := False;
  sCompErr := 'Program: ' + sName + #13#10;
  // invoke PS compiler
  if Compiler.Compile(sSource) then begin
    // compilation succeeded
    if not bAssignmentFound then
      sCompErr := sCompErr + 'ASSIGNMENT procedure not found'
    else if not bPlacementFound then
      sCompErr := sCompErr + 'PLACEMENT procedure not found'
    else if not bAttackFound then
      sCompErr := sCompErr + 'ATTACK procedure not found'
    else if not bOccupationFound then
      sCompErr := sCompErr + 'OCCUPATION procedure not found'
    else if not bFortificationFound then
      sCompErr := sCompErr + 'FORTIFICATION procedure not found'
    else
      Result := True;
  end
  else begin
    // compilation aborted: show errors
    for iErr := 0 to Compiler.MsgCount - 1 do begin
      sCompErr := sCompErr + Compiler.Msg[iErr].MessageToString + #13#10;
    end;
  end;
  // show error messages
  if not Result then begin
    MessageDlg(sCompErr, mtError, [mbOk], 0);
  end;
end;

// New game setup
procedure NewGameSetup;
var
  iCount, iT, iP, iB, // generic
  iTL, iTL1, iTL2, iTL3: integer; // turn list generation
  tCont: TContId;
  bSwap: boolean;
  PrgTemp: TstringList;
  Compiler: TPSPascalCompiler; // TPSPascalCompiler is the compiler part of the scriptengine. This will
  // translate a Pascal script into a compiled for the executer understands.
  Preproc: TPSPreProcessor;
  bCompErrors: boolean; // true if at least one compilation failed
  sPPout: ansistring;

begin

  ScriptSetup; // create the script executer; will be destroyed in GameCleanup
  PrgTemp := TstringList.Create;
  // create input buffer for source code
  Compiler := TPSPascalCompiler.Create;
  Preproc := TPSPreProcessor.Create;
  // create an instance of the compiler.
  Compiler.OnUses := ScriptOnUses; // assign the OnUses event.
  Compiler.OnExportCheck := ScriptOnExportCheck;
  bCompErrors := False;
  // reset global flag for compilation errors
  bStopASAP := False; // reset flag for required stopping

  try
    // Reset log
    fLog.txtLog.Lines.Clear;
    // Reset rank
    iRank := 0;
    // Reset territories
    HooverTerrit := 0;
    FromTerrit := 0;
    ToTerrit := 0;
    for iT := 1 to MAXTERRITORIES do begin
      with arTerritory[iT] do begin
        Army := 0;
        Owner := 0;
      end;
      DisplayTerritory(iT);
    end;
    // Reset continents
    for tCont := coNA to coAU do begin
      arContinent[tCont].Owner := 0;
    end;
    // Count initial players
    iCount := 0;
    for iP := 1 to MAXPLAYERS do
      if arPlayer[iP].Active then
        inc(iCount);
    // Reset players
    for iP := 1 to MAXPLAYERS do begin
      with arPlayer[iP] do begin
        // Reset buffers
        for iB := 1 to MAXBUFFER do
          Buffer[iB] := 0.0;
        // Reset runtime flags
        USnapShotEnabled := False;
        ULogEnabled := False;
        UMessageEnabled := False;
        UDialogEnabled := False;
        // Set active players
        if Active then begin
          NewArmy := RInitialArmies[iCount];
          Territ := 0;
          Cards[caInf] := 0;
          Cards[caArt] := 0;
          Cards[caCav] := 0;
          Cards[caJok] := 0;
          NScambi := 0;
          Rank := 0;
          if Computer then begin
            // Load TRPs
            if FileExists(sG_AppPath + 'players/' + PrgFile) then
              PrgTemp.LoadFromFile(sG_AppPath + 'players/' + PrgFile)
            else begin
              MessageDlg
              (sG_AppPath + 'players/' +
                PrgFile + ': File not found.', mtError, [mbOk], 0);
              PrgTemp.Clear;
              bCompErrors := True;
              continue;
            end;
            // Compile TRPs
            bAssignmentFound := False;
            bPlacementFound := False;
            bAttackFound := False;
            bOccupationFound := False;
            bFortificationFound := False;
            Preproc.MainFileName := sG_AppPath + 'players/' + PrgFile;
            Preproc.MainFile := PrgTemp.Text;
            Preproc.PreProcess(Preproc.MainFileName, sPPout);
            if CompileTRP(Compiler, PrgFile, sPPout) then begin
              Compiler.GetOutput(Code);
            end
            else begin
              bCompErrors := True;
            end;
            // Exec main TRP code
            if not ScriptExec.LoadData(Code) then begin
              MessageDlg('Player: ' + Name + #13#10 +
                'Error: script loading failed', mtError, [mbOk], 0);
              bCompErrors := True;
              continue;
            end;
            iTurn := iP;
            ScriptExec.RunScript;
          end;
        end;
      end;
    end;
    // State of the game
    if bCompErrors then begin
      GameState := gsStopped;
    end
    else begin
      // Current phase is Assignment
      GameState := gsAssigning;
      // Choose first player at random
      repeat
        iFirstTurn := Random(MAXPLAYERS) + 1;
      until arPlayer[iFirstTurn].Active;
      iTurn := iFirstTurn;
      iTurnCounter := 1;
      bHumanTurn := False;
      // Create turn list
      for iTL := 0 to MAXPLAYERS do
        aiTurnList[iTL] := iTL;
      aiTurnList[iFirstTurn] := 1; // first player in turn is
      aiTurnList[1] := iFirstTurn; // always in position 1
      // Randomize turn list
      for iTL := 1 to 100 do begin // perform random swaps
        iTL1 := Random(MAXPLAYERS - 1) + 2; // range is 2..MAXPLAYERS
        iTL2 := Random(MAXPLAYERS - 1) + 2;
        iTL3 := aiTurnList[iTL1];
        aiTurnList[iTL1] := aiTurnList[iTL2];
        aiTurnList[iTL2] := iTL3;
      end;
      // Move inactive players at the end of the list (bubble sort)
      repeat
        bSwap := False;
        for iTL := 1 to MAXPLAYERS - 1 do begin
          if not arPlayer[aiTurnList[iTL]].Active and arPlayer
          [aiTurnList[iTL + 1]].Active then begin
            iTL3 := aiTurnList[iTL];
            aiTurnList[iTL] := aiTurnList[iTL + 1];
            aiTurnList[iTL + 1] := iTL3;
            bSwap := True;
          end;
        end;
      until not bSwap;
      // All territories have to be assigned
      iToAssign := MAXTERRITORIES;
      // Count the number of active players
      iNPlayers := 0;
      for iP := 1 to MAXPLAYERS do
        if arPlayer[iP].Active then
          inc(iNPlayers);
      // Help context
      fMain.HelpContext := 110; // context is "play game"
    end;
    // Dynamic menus
    MenuSetup;
    // Update the stat window
    UpdateStats;
  finally
    PrgTemp.Free;
    Preproc.Free;
    Compiler.Free;
  end;
end;

// Game cleanup
procedure GameCleanup;
begin
  with fMain do begin
    HelpContext := 100;
    // context is "overview"
    imgMap.Picture.Assign(BaseMap);
    panStatus.Panels[0].Text := '';
    panStatus.Panels[1].Text := '';
    panStatus.Panels[2].Text := '';
    panTurn.Caption := '';
    panTurn.Color := clBtnFace;
  end;
  GameState := gsStopped;
  MenuSetup;
  UpdateStats;
  ScriptCleanup;
  if bCloseASAP then
    fMain.Close;
end;

// Initial random assignment
procedure RandomAssignment;
var
  iT: integer;
begin
  iT := Random(MAXTERRITORIES) + 1;
  while arTerritory[iT].Owner <> 0 do
    iT := iT mod MAXTERRITORIES + 1;
  AssegnaTerritorio(iT, iTurn);
  inc(arTerritory[iT].Army);
  dec(arPlayer[iTurn].NewArmy);
  DisplayTerritory(iT);
  // Log
  if arPlayer[iTurn].KeepLog then
    ScriviLog(arTerritory[iT].Name + ' randomly assigned.');
end;

// Pass turn to next player
procedure PassTurn;
var
  iTL: integer;
begin
  // locate curren player in turn list
  for iTL := 1 to MAXPLAYERS do
    if iTurn = aiTurnList[iTL] then
      break;
  // next player in turn list
  iTL := iTL mod MAXPLAYERS + 1;
  iTurn := aiTurnList[iTL];
  // increment global turn counter, if turn came back to first player
  if iTurn = iFirstTurn then
    inc(iTurnCounter);
  // if TRSim, update stats and check time and turn limits
  if bG_TRSim then begin
    fSimRun.UpdateSimStats;
    if (iSimTurnLimit > 0) and (iTurnCounter > iSimTurnLimit) then begin
      uSimStatus := ssTurnLimit;
      bStopASAP := True;
    end
    else if (iSimTimeLimit > 0) and (SecondsBetween(Now,
        dtSimGameTime) > iSimTimeLimit) then begin
      uSimStatus := ssTimeLimit;
      bStopASAP := True;
    end;
  end;
end;

// Assign new armies
procedure AssignNewArmies(bCardsOnly: boolean);
var
  tCont: TContId;
  iInf, iCav, iArt, iJok: integer;
  iArmy, iArmyTer, iArmyCon, iArmyCar: integer;
begin
  iArmyTer := 0;
  iArmyCon := 0;
  iArmyCar := 0;
  with arPlayer[iTurn] do begin
    // Log
    if KeepLog then
      ScriviLog('Cards in hand: ' + IntToStr(Cards[caInf]) + '×Inf ' + IntToStr
        (Cards[caCav]) + '×Cav ' + IntToStr(Cards[caArt]) + '×Art ' + IntToStr
        (Cards[caJok]) + '×Jok');
    if not bCardsOnly then begin
      // armies from count of territories
      iArmyTer := Territ div 3;
      if iArmyTer < 3 then
        iArmyTer := 3;
      inc(NewArmy, iArmyTer);
      // armaies from continents
      iArmyCon := 0;
      for tCont := coNA to coAU do
        if arContinent[tCont].Owner = iTurn then begin
          inc(iArmyCon, arContinent[tCont].Bonus)
        end;
      inc(NewArmy, iArmyCon);
    end;
    // armies from owned cards
    if Computer or (CardsHandling = chAuto) then begin
      repeat
        CercaCombinazioneMigliore(iInf, iCav, iArt, iJok);
        iArmy := TestCombinazione(iInf, iCav, iArt, iJok);
        if iArmy > 0 then begin
          inc(iArmyCar, iArmy);
          inc(NewArmy, iArmy);
          dec(Cards[caInf], iInf);
          dec(Cards[caCav], iCav);
          dec(Cards[caArt], iArt);
          dec(Cards[caJok], iJok);
          inc(NScambi);
        end;
      until iArmy <= 0;
    end
    else if CardsHandling = chSmart then begin
      if CercaCombinazioneMigliore(iInf, iCav, iArt, iJok) then begin
        iArmyCar := NewArmy;
        UpdateStats;
        fCards.ShowModal;
        iArmyCar := NewArmy - iArmyCar;
      end;
    end
    else begin
      iArmyCar := NewArmy;
      UpdateStats;
      fCards.ShowModal;
      iArmyCar := NewArmy - iArmyCar;
    end;
    // Log
    if KeepLog and (NewArmy > 0) then
      ScriviLog(IntToStr(NewArmy) + ' new armies (Terr:' + IntToStr(iArmyTer)
        + ' Cont:' + IntToStr(iArmyCon) + ' Cards:' + IntToStr(iArmyCar)
        + ')');
  end;
  UpdateStats;
end;

// Perform an attack
function PerformAttack(iTA, iTD: integer): boolean;
type
  TDice = array [1 .. 3] of integer;
var
  iNDiceA, iNDiceD: integer;
  // number of dice (attacker, defender)
  aiDiceA, aiDiceD: TDice; // dice (attacker, defender)
  iMinDice: integer; // min number of dice used (least between attacker & defender)
  iLostA, iLostD: integer; // lost armies (attacker, defender)
  sMsg: string; // messagge about the result
  iOpp: integer; // opponent
  iArmA, iArmD: integer; // initial armies in the territories (attacker, defender)
  i: integer;

  procedure ThrowDice(iNDice: integer;

    var aiDice: TDice);
  var
    i, iTmp: integer;
    fSwap: boolean;
  begin
    // generate random numbers
    for i := 1 to iNDice do
      aiDice[i] := Random(6) + 1;
    // sort ny descending values (bubble sort)
    repeat
      fSwap := False;
      for i := 1 to iNDice - 1 do begin
        if aiDice[i] < aiDice[i + 1] then begin
          iTmp := aiDice[i];
          aiDice[i] := aiDice[i + 1];
          aiDice[i + 1] := iTmp;
          fSwap := True;
        end;
      end;
    until not fSwap;
  end;

begin
  // Opponent is still alive
  bEliminatedPlayer := False;
  // Attacker
  iArmA := arTerritory[iTA].Army;
  iNDiceA := arTerritory[iTA].Army - 1;
  if iNDiceA > 3 then
    iNDiceA := 3;
  ThrowDice(iNDiceA, aiDiceA);
  // Defender
  iArmD := arTerritory[iTD].Army;
  iNDiceD := arTerritory[iTD].Army;
  if iNDiceD > 2 then
    iNDiceD := 2;
  ThrowDice(iNDiceD, aiDiceD);
  // Fighting (comparing dice and counting lost armies)
  if iNDiceA < iNDiceD then
    iMinDice := iNDiceA
  else
    iMinDice := iNDiceD;
  iLostA := 0;
  iLostD := 0;
  for i := 1 to iMinDice do begin
    if aiDiceA[i] > aiDiceD[i] then
      inc(iLostD)
    else
      inc(iLostA);
  end;
  // Messagge
  sMsg := 'A:[';
  for i := 1 to iNDiceA do begin
    if i > 1 then
      sMsg := sMsg + '-';
    sMsg := sMsg + IntToStr(aiDiceA[i]);
  end;
  sMsg := sMsg + '] D:[';
  for i := 1 to iNDiceD do begin
    if i > 1 then
      sMsg := sMsg + '-';
    sMsg := sMsg + IntToStr(aiDiceD[i]);
  end;
  if iLostA = 2 then
    sMsg := sMsg + ']. Attacker loses 2 armies.'
  else if iLostD = 2 then
    sMsg := sMsg + ']. Defender loses 2 armies.'
  else if (iLostA = 1) and (iLostD = 1) then
    sMsg := sMsg + ']. Both sides lose 1 army.'
  else if iLostA = 1 then
    sMsg := sMsg + ']. Attacker loses 1 army.'
  else if iLostD = 1 then
    sMsg := sMsg + ']. Defender loses 1 army.';
  // Update territoris
  iOpp := 0;
  dec(arTerritory[iTA].Army, iLostA);
  dec(arTerritory[iTD].Army, iLostD);
  if arTerritory[iTD].Army = 0 then begin // conquered territory
    // messagge
    sMsg := sMsg + ' ' + arTerritory[iTD].Name + ' conquered.';
    // assign territory and perform default troops move
    iOpp := arTerritory[iTD].Owner;
    AssegnaTerritorio(iTD, iTurn);
    if iNDiceA >= arTerritory[iTA].Army then
      dec(iNDiceA);
    dec(arTerritory[iTA].Army, iNDiceA);
    inc(arTerritory[iTD].Army, iNDiceA);
    arPlayer[iTurn].FlConq := True;
    // check is opponent has been eliminated
    if arPlayer[iOpp].Territ = 0 then begin
      bEliminatedPlayer := True;
      // rank
      inc(iRank);
      arPlayer[iOpp].Rank := iRank;
      // messagge
      sMsg := sMsg + ' ' + arPlayer[iOpp].Name + ' destroyed.';
      // capture opponent's cards
      inc(arPlayer[iTurn].Cards[caInf], arPlayer[iOpp].Cards[caInf]);
      inc(arPlayer[iTurn].Cards[caCav], arPlayer[iOpp].Cards[caCav]);
      inc(arPlayer[iTurn].Cards[caArt], arPlayer[iOpp].Cards[caArt]);
      inc(arPlayer[iTurn].Cards[caJok], arPlayer[iOpp].Cards[caJok]);
      arPlayer[iOpp].Cards[caInf] := 0;
      arPlayer[iOpp].Cards[caCav] := 0;
      arPlayer[iOpp].Cards[caArt] := 0;
      arPlayer[iOpp].Cards[caJok] := 0;
      // decrease number of active players
      dec(iNPlayers);
      // stop human turn if game won
      if bHumanTurn and (iNPlayers < 2) then
        bHumanTurn := False;
    end;
    Result := True;
  end
  else begin
    Result := False;
  end;
  // log
  if arPlayer[iTurn].KeepLog then
    ScriviLog('Attack ' + arTerritory[iTD].Name + '(' + IntToStr(iArmD)
      + ') from ' + arTerritory[iTA].Name + '(' + IntToStr(iArmA)
      + '), ' + sMsg);
  // eliminated opponent's log
  if bEliminatedPlayer and (arPlayer[iOpp].KeepLog) then
    ScriviLog('(' + arPlayer[iOpp].Name + ' destroyed by ' + arPlayer[iTurn]
      .Name + ')');
  // update windows
  DisplayTerritory(iTA);
  DisplayTerritory(iTD);
  fMain.panStatus.Panels[2].Text := sMsg;
  UpdateStats;
end;

// Supervisor for the game turns and phases
procedure Supervisor;
var
  iP, iToDistribute: integer;
begin

  // Check if game has been required to stop
  if bStopASAP then begin
    GameCleanup;
    Exit;
  end;

  // Save and restore allowed only at beginning of a turn
  fMain.mnuFilSave.Enabled := False;
  fMain.mnuFilRestore.Enabled := False;
  fMain.cmdSaveGame.Enabled := False;
  fMain.cmdRestoreGame.Enabled := False;

  // End Turn button allowed only during HumanTurn and Attack
  fMain.cmdEndTurn.Enabled := False;

  // Handle the case where I enter here after having waited for a Human Player to move
  if bHumanTurn then begin
    bHumanTurn := False;
    // Assign a card if necessary
    if (GameState = gsPlaying) and (arPlayer[iTurn].FlConq) then begin
      PescaCarta;
    end;
    // Pass the turn to the next player
    PassTurn;
    fMain.panStatus.Panels[2].Text := '';
  end;

  // Initial assignment of territories
  // ---------------------------------

  while GameState = gsAssigning do begin
    // Check if game has been required to stop
    if bStopASAP then begin
      GameCleanup;
      Exit;
    end;
    // Assign
    if iToAssign > 0 then begin
      if arPlayer[iTurn].Active then begin
        // Log
        // if arPlayer[iTurn].KeepLog then ScriviLog(arPlayer[iTurn].Name+'''s turn');
        // Show turn
        fMain.panStatus.Panels[0].Text := 'Turn ' + IntToStr(iTurnCounter);
        fMain.panStatus.Panels[1].Text := arPlayer[iTurn].Name;
        fMain.panTurn.Color := arPlayer[iTurn].Color;
        fMain.panTurn.Font.Color := BestTextColor(arPlayer[iTurn].Color);
        fMain.panTurn.Caption := arPlayer[iTurn].Name;
        if RAssignmentType = atRandom then begin
          // Random assignment
          RandomAssignment;
          PassTurn;
        end
        else begin
          // Manual assignment in turn
          if arPlayer[iTurn].Computer then begin
            // Computer player
            EseguiTurnoComputer;
            PassTurn;
          end
          else begin
            // Show messages and update pointer to stats
            MostraIstruzioni;
            UpdateGridPos;
            // Human player: wait for a move
            bHumanTurn := True;
            Exit;
          end;
        end;
      end
      else begin
        PassTurn;
      end;
    end
    else begin
      // Change game state from Assignment to Distribution
      GameState := gsDistributing;
    end;
  end;

  // Distribution of additional armies on the newly assigned territories
  // -------------------------------------------------------------------
  while GameState = gsDistributing do begin
    // Check if game has been required to stop
    if bStopASAP then begin
      GameCleanup;
      Exit;
    end;
    // Count armies to be distributed
    iToDistribute := 0;
    for iP := 1 to MAXPLAYERS do
      if arPlayer[iP].Active then
        inc(iToDistribute, arPlayer[iP].NewArmy);
    // Distribute
    if iToDistribute > 0 then begin
      if arPlayer[iTurn].Active and (arPlayer[iTurn].NewArmy > 0) then begin
        // Log
        // if arPlayer[iTurn].KeepLog then ScriviLog(0,arPlayer[iTurn].Name+'''s turn');
        // Show turn
        fMain.panStatus.Panels[0].Text := 'Turn ' + IntToStr(iTurnCounter);
        fMain.panStatus.Panels[1].Text := arPlayer[iTurn].Name;
        fMain.panTurn.Color := arPlayer[iTurn].Color;
        fMain.panTurn.Font.Color := BestTextColor(arPlayer[iTurn].Color);
        fMain.panTurn.Caption := arPlayer[iTurn].Name;
        // Execute distribution
        if arPlayer[iTurn].Computer then begin
          // Computer player
          EseguiTurnoComputer;
          PassTurn;
        end
        else begin
          // Show messages and update pointer to stats
          MostraIstruzioni;
          UpdateGridPos;
          // Human player: wait for a move
          bHumanTurn := True;
          Exit;
        end;
      end
      else begin
        PassTurn;
      end;
    end
    else begin
      GameState := gsPlaying;
    end;
  end;

  // Game phases
  // -----------

  while GameState = gsPlaying do begin
    // Check if game has been required to stop
    if bStopASAP then begin
      GameCleanup;
      Exit;
    end;
    // Check if game has been won
    if iNPlayers < 2 then begin
      if not bG_TRSim then begin // TurboRisk
        MessageDlg(arPlayer[arTerritory[1].Owner].Name +
          ' has conquered the world!', mtCustom, [mbOk], 0);
      end
      else begin // TRSim
        iSimWinner := arTerritory[1].Owner;
        uSimStatus := ssComplete;
      end;
      GameState := gsStopped;
      // Log
      if arPlayer[iTurn].KeepLog then
        ScriviLog('World conquered');
      // History
      inc(iRank);
      arPlayer[arTerritory[1].Owner].Rank := iRank;
      if not bG_TRSim then begin // TurboRisk
        UpdateHistoryFile; // TRSim updates history in its main simulation loop
      end;
      // Reset game
      GameCleanup;
      Exit;
    end;
    // Prepare and execute a move
    if arPlayer[iTurn].Active and (arPlayer[iTurn].Territ > 0) then begin
      // Log
      { if arPlayer[iTurn].KeepLog then ScriviLog(0,arPlayer[iTurn].Name+'''s turn'); }
      // Show turn
      fMain.panStatus.Panels[0].Text := 'Turn ' + IntToStr(iTurnCounter);
      fMain.panStatus.Panels[1].Text := arPlayer[iTurn].Name;
      fMain.panTurn.Color := arPlayer[iTurn].Color;
      fMain.panTurn.Font.Color := BestTextColor(arPlayer[iTurn].Color);
      fMain.panTurn.Caption := arPlayer[iTurn].Name;
      // Initialize turn
      arPlayer[iTurn].FlConq := False;
      arPlayer[iTurn].FlMove := False;
      // Assign new armies
      AssignNewArmies(False);
      // Execute a move
      if arPlayer[iTurn].Computer then begin
        // Computer player
        EseguiTurnoComputer;
        // Pick a new card if at least one territory has been conquered
        if arPlayer[iTurn].FlConq then begin
          PescaCarta;
        end;
        PassTurn;
      end
      else begin
        // Initialize human turn
        if arPlayer[iTurn].NewArmy > 0 then begin
          HumanPhase := hpPlacement;
        end
        else begin
          HumanPhase := hpAttack;
          fMain.cmdEndTurn.Enabled := True; // allow "end turn" button
        end;
        FromTerrit := 0;
        ToTerrit := 0;
        // Allow save and restore only at beginning of a turn
        fMain.mnuFilSave.Enabled := True;
        fMain.mnuFilRestore.Enabled := True;
        fMain.cmdSaveGame.Enabled := True;
        fMain.cmdRestoreGame.Enabled := True;
        // Show messages and update pointer to stats
        MostraIstruzioni;
        UpdateGridPos;
        // Human player: wait for a move
        bHumanTurn := True;
        Exit;
      end;
    end
    else begin
      PassTurn;
    end;
  end;
end;

procedure UpdateHistoryFile;
var
  fHistory: textfile;
  iP, iCurP, iCurRank, iMaxRank: integer;
  bFound: boolean;
  sHFName, sList: string;
begin
  // assign history file
  if bG_TRSim then
    sHFName := sG_AppPath + sSimGameLogFile
  else
    sHFName := sG_AppPath + 'history.txt';
  AssignFile(fHistory, sHFName);
  // open history file for append or rewrite
  if FileExists(sHFName) then
    Append(fHistory)
  else
    Rewrite(fHistory);
  // write on history file
  try
    // calculate highest rank
    iMaxRank := 0;
    for iP := 1 to MAXPLAYERS do begin
      if arPlayer[iP].Active then begin
        inc(iMaxRank);
      end;
    end;
    // if TurboRisk, or TRSim completed game, create player list by rank
    if not bG_TRSim or (uSimStatus = ssComplete) then begin
      iCurRank := iMaxRank;
      sList := '';
      repeat
        bFound := False;
        for iP := 1 to MAXPLAYERS do begin
          if (arPlayer[iP].Active) and (arPlayer[iP].Rank = iCurRank) then begin
            iCurP := iP;
            bFound := True;
            break;
          end;
        end;
        if bFound then begin
          sList := sList + ',' + arPlayer[iCurP].Name;
          if bG_TRSim then begin // TRSim
            sList := sList + ',' + IntToStr(arPlayer[iCurP].LastTurn);
            sList := sList + ',' + IntToStr(arPlayer[iCurP].Army);
            sList := sList + ',' + IntToStr(arPlayer[iCurP].Territ);
          end;
        end;
        dec(iCurRank);
      until not bFound;
    end
    // otherwise, just list the players
    else begin
      for iP := 1 to MAXPLAYERS do begin
        if (arPlayer[iP].Active) then begin
          sList := sList + ',' + arPlayer[iP].Name;
          if bG_TRSim then begin // TRSim
            sList := sList + ',' + IntToStr(arPlayer[iP].LastTurn);
            sList := sList + ',' + IntToStr(arPlayer[iP].Army);
            sList := sList + ',' + IntToStr(arPlayer[iP].Territ);
          end;
        end;
      end;
    end;
    // append record to file
    if bG_TRSim then begin // TRSim
      Writeln(fHistory, FormatDateTime('yyyymmdd,hhnnss', Now) + ',' + IntToStr
        (ord(uSimStatus)) + ',' + IntToStr(iSimGameTime) + ',' + IntToStr
        (iTurnCounter) + ',' + IntToStr(iMaxRank) + sList);
    end
    else begin // TurboRisk
      Writeln(fHistory, FormatDateTime('yyyymmdd', Today) + ',' + IntToStr
        (iMaxRank) + sList);
    end;
  finally
    CloseFile(fHistory);
  end;
end;

procedure SaveGame(sFileName, sErrorMsg: string);
var
  IniFile: TIniFile;
  i, iP, iB, iT, iG: integer;
  sSec: string;
begin

  // save current game on INI-like file
  IniFile := TIniFile.Create(sFileName);
  try
    with IniFile do begin
      // Status of the game
      WriteInteger('Status', 'TurnCounter', iTurnCounter);
      WriteInteger('Status', 'Turn', iTurn);
      WriteInteger('Status', 'FirstTurn', iFirstTurn);
      WriteInteger('Status', 'Rank', iRank);
      WriteString('Status', 'ErrorMsg', sErrorMsg);
      for iG := 1 to MAXPLAYERS do
        WriteInteger('Status', 'TurnList' + IntToStr(iG), aiTurnList[iG]);
      // Rules
      WriteInteger('Rules', 'Assignment', ord(RAssignmentType));
      for iP := 2 to MAXPLAYERS do begin
        WriteInteger('Rules', 'InitArmies' + IntToStr(iP), RInitialArmies[iP]);
      end;
      WriteInteger('Rules', 'CardUsage', ord(RCardsValueType));
      WriteInteger('Rules', 'ArtSetValue', RSetValue[csArt]);
      WriteInteger('Rules', 'InfSetValue', RSetValue[csInf]);
      WriteInteger('Rules', 'CavSetValue', RSetValue[csCav]);
      WriteInteger('Rules', 'DifSetValue', RSetValue[csDif]);
      for i := 1 to 8 do begin
        WriteInteger('Rules', 'TradeValue' + IntToStr(i), RTradeValue[i]);
      end;
      WriteInteger('Rules', 'TradeValueInc', RValueInc);
      WriteInteger('Rules', 'MaxHeldCards', RMaxHeldCards);
      WriteBool('Rules', 'TradeCapturedCards', RImmediateTrade);
      WriteBool('Rules', 'AllowAttackAfterMove', RFinalMove);
      // Players
      for iP := 1 to MAXPLAYERS do begin
        with arPlayer[iP] do begin
          sSec := 'Player' + IntToStr(iP);
          WriteString(sSec, 'Name', Name);
          WriteBool(sSec, 'Active', Active);
          WriteInteger(sSec, 'Color', Color);
          WriteBool(sSec, 'Computer', Computer);
          WriteBool(sSec, 'Log', KeepLog);
          WriteInteger(sSec, 'AutoCards', ord(CardsHandling));
          WriteString(sSec, 'PrgFile', PrgFile);
          WriteInteger(sSec, 'NewArmy', NewArmy);
          WriteInteger(sSec, 'CardTrades', NScambi);
          if (RCardsValueType = cvProgressive) then begin
            if NScambi < 8 then
              WriteInteger(sSec, 'CTIV', RTradeValue[NScambi + 1])
            else
              WriteInteger(sSec, 'CTIV',
                RTradeValue[8] + (NScambi - 7) * RValueInc);
          end
          else begin
            WriteInteger(sSec, 'CTIV', 0);
          end;
          WriteString(sSec, 'Cards',
            IntToStr(Cards[caInf]) + IntToStr(Cards[caArt]) + IntToStr
            (Cards[caCav]) + IntToStr(Cards[caJok]));
          WriteInteger(sSec, 'Rank', Rank);
          WriteBool(sSec, 'USnapShot', USnapShotEnabled);
          WriteBool(sSec, 'ULog', ULogEnabled);
          WriteBool(sSec, 'UMessage', UMessageEnabled);
          WriteBool(sSec, 'UDialog', UDialogEnabled);
          for iB := 1 to MAXBUFFER do begin
            if Buffer[iB] <> 0.0 then begin
              WriteString(sSec, 'Buffer' + IntToStr(iB),
                FloatToStr(Buffer[iB]));
            end;
          end;
        end;
      end;
      // Territories
      for iT := 1 to MAXTERRITORIES do begin
        WriteInteger('Territory', 'Owner' + IntToStr(iT),
          arTerritory[iT].Owner);
        WriteInteger('Territory', 'Army' + IntToStr(iT), arTerritory[iT].Army);
      end;
    end;
  finally
    IniFile.Free;
  end;
end;

procedure RestoreGame(sFileName: string);
var
  IniFile: TIniFile;
  i, iP, iB, iT, iG: integer;
  iC: TContId;
  sSec, sTmp: string;
  PrgTemp: TstringList;
  Compiler: TPSPascalCompiler; // TPSPascalCompiler is the compiler part of the scriptengine. This will
  // translate a Pascal script into a compiled for the executer understands.
  Preproc: TPSPreProcessor;
  bCompErrors: boolean; // true if at least one compilation failed

begin
  // restore game from INI-like file
  IniFile := TIniFile.Create(sFileName);
  try
    with IniFile do begin
      // Status of the game
      iTurnCounter := ReadInteger('Status', 'TurnCounter', 1);
      iTurn := ReadInteger('Status', 'Turn', 1);
      iFirstTurn := ReadInteger('Status', 'FirstTurn', 1);
      iRank := ReadInteger('Status', 'Rank', iRank);
      { sErrorMsg := ReadString('Status','ErrorMsg',''); }
      for iG := 1 to MAXPLAYERS do
        aiTurnList[iG] := ReadInteger('Status', 'TurnList' + IntToStr(iG), iG);
      // Rules
      case ReadInteger('Rules', 'Assignment', 0) of
        0:
          RAssignmentType := atRandom;
        1:
          RAssignmentType := atTurns;
      end;
      for iP := 2 to MAXPLAYERS do begin
        RInitialArmies[iP] := ReadInteger('Rules', 'InitArmies' + IntToStr(iP),
          30);
      end;
      case ReadInteger('Rules', 'CardUsage', 0) of
        0:
          RCardsValueType := cvConstant;
        1:
          RCardsValueType := cvProgressive;
      end;
      RSetValue[csArt] := ReadInteger('Rules', 'ArtSetValue', 4);
      RSetValue[csInf] := ReadInteger('Rules', 'InfSetValue', 6);
      RSetValue[csCav] := ReadInteger('Rules', 'CavSetValue', 8);
      RSetValue[csDif] := ReadInteger('Rules', 'DifSetValue', 10);
      for i := 1 to 8 do begin
        RTradeValue[i] := ReadInteger('Rules', 'TradeValue' + IntToStr(i),
          i + 3);
      end;
      RValueInc := ReadInteger('Rules', 'TradeValueInc', 1);
      RMaxHeldCards := ReadInteger('Rules', 'MaxHeldCards', 4);
      RImmediateTrade := ReadBool('Rules', 'TradeCapturedCards', True);
      RFinalMove := ReadBool('Rules', 'AllowAttackAfterMove', True);
      // Players
      for iP := 1 to MAXPLAYERS do begin
        with arPlayer[iP] do begin
          sSec := 'Player' + IntToStr(iP);
          Name := ReadString(sSec, 'Name', sSec);
          Active := ReadBool(sSec, 'Active', True);
          Color := ReadInteger(sSec, 'Color', clBlue);
          Computer := ReadBool(sSec, 'Computer', False);
          KeepLog := ReadBool(sSec, 'Log', False);
          CardsHandling := TCardsHandling(ReadInteger(sSec, 'AutoCards', 1));
          PrgFile := ReadString(sSec, 'PrgFile', '');
          NewArmy := ReadInteger(sSec, 'NewArmy', 0);
          NScambi := ReadInteger(sSec, 'CardTrades', 0);
          sTmp := ReadString(sSec, 'Cards', '0000');
          Cards[caInf] := StrToIntDef(sTmp[1], 0);
          Cards[caArt] := StrToIntDef(sTmp[2], 0);
          Cards[caCav] := StrToIntDef(sTmp[3], 0);
          Cards[caJok] := StrToIntDef(sTmp[4], 0);
          Rank := ReadInteger(sSec, 'Rank', 0);
          USnapShotEnabled := ReadBool(sSec, 'USnapShot', False);
          ULogEnabled := ReadBool(sSec, 'ULog', False);
          UMessageEnabled := ReadBool(sSec, 'UMessage', False);
          UDialogEnabled := ReadBool(sSec, 'UDialog', False);
          for iB := 1 to MAXBUFFER do begin
            sTmp := ReadString(sSec, 'Buffer' + IntToStr(iB), '0');
            Buffer[iB] := StrToFloatDef(sTmp, 0.0);
          end;
        end;
      end;
      // Territories
      for iT := 1 to MAXTERRITORIES do begin
        arTerritory[iT].Owner := ReadInteger('Territory',
          'Owner' + IntToStr(iT), 0);
        arTerritory[iT].Army := ReadInteger('Territory', 'Army' + IntToStr(iT),
          0);
      end;
    end;
  finally
    IniFile.Free;
  end;

  // prepare game

  ScriptSetup; // create the script executer; will be destroyed in GameCleanup
  PrgTemp := TstringList.Create;
  // create input buffer for source code
  Compiler := TPSPascalCompiler.Create;
  Preproc := TPSPreProcessor.Create;
  // create an instance of the compiler.
  Compiler.OnUses := ScriptOnUses; // assign the OnUses event.
  Compiler.OnExportCheck := ScriptOnExportCheck;
  bCompErrors := False;
  // reset global flag for compilation errors
  bStopASAP := False; // reset flag for required stopping

  try
    // Reset log
    fLog.txtLog.Lines.Clear;
    // Reset players
    for iP := 1 to MAXPLAYERS do begin
      with arPlayer[iP] do begin
        if Active then begin
          Army := 0;
          Territ := 0;
          FlConq := False;
          FlMove := False;
          if Computer then begin
            // Load TRPs
            if FileExists(sG_AppPath + 'players/' + PrgFile) then
              PrgTemp.LoadFromFile(sG_AppPath + 'players/' + PrgFile)
            else begin
              MessageDlg
              (sG_AppPath + 'players/' +
                PrgFile + ': File not found.', mtError, [mbOk], 0);
              PrgTemp.Clear;
              bCompErrors := True;
              continue;
            end;
            // Compile TRPs
            bAssignmentFound := False;
            bPlacementFound := False;
            bAttackFound := False;
            bOccupationFound := False;
            bFortificationFound := False;
            if CompileTRP(Compiler, PrgFile, PrgTemp.Text) then begin
              Compiler.GetOutput(Code);
            end
            else begin
              bCompErrors := True;
            end;
          end;
        end;
      end;
    end;
    // State of the game
    if bCompErrors then begin
      GameState := gsStopped;
      Exit;
    end;
    // bHumanTurn always true because save allowed only during human turn
    bHumanTurn := True;
    // Help context
    fMain.HelpContext := 110; // context is "play game"
    // reset continents' owners
    for iC := coNA to coAU do begin
      arContinent[iC].Owner := -1;
    end;
    // scan territories
    GameState := gsPlaying;
    for iT := 1 to MAXTERRITORIES do begin
      iP := arTerritory[iT].Owner;
      iC := arTerritory[iT].Contin;
      if iP > 0 then begin
        // count territories and armies
        inc(arPlayer[iP].Territ);
        inc(arPlayer[iP].Army, arTerritory[iT].Army);
        // assign continents
        if arContinent[iC].Owner = -1 then begin
          arContinent[iC].Owner := iP;
          // temp assigned to first owner found
        end
        else if arContinent[iC].Owner <> iP then begin
          arContinent[iC].Owner := 0; // different owners -> cont is unassigned
        end;
      end
      else begin
        arContinent[iC].Owner := 0;
        // terr unassigned -> cont unassigned
        GameState := gsAssigning; // terr unassigned -> game state is Assigning
      end;
      DisplayTerritory(iT);
    end;
    // Count the number of active players
    iNPlayers := 0;
    for iP := 1 to MAXPLAYERS do
      if PAlive(iP) then
        inc(iNPlayers);
    // Phase of the game
    if GameState = gsPlaying then
      HumanPhase := hpPlacement;
    // Dynamic menus
    MenuSetup;
    // Update the stat window
    UpdateStats;
    // Show turn
    fMain.panStatus.Panels[0].Text := 'Turn ' + IntToStr(iTurnCounter);
    fMain.panStatus.Panels[1].Text := arPlayer[iTurn].Name;
    fMain.panTurn.Color := arPlayer[iTurn].Color;
    fMain.panTurn.Font.Color := BestTextColor(arPlayer[iTurn].Color);
    fMain.panTurn.Caption := arPlayer[iTurn].Name;
  finally
    PrgTemp.Free;
    Preproc.Free;
    Compiler.Free;
  end;
end;

// Find best contrast text color
function BestTextColor(tBkgColor: TColor): TColor;
var
  iR, iG, iB: integer;
  dDist: double;
begin
  iB := (tBkgColor and $FF0000) shr 16;
  iG := (tBkgColor and $FF00) shr 8;
  iR := tBkgColor and $FF;
  dDist := sqrt(iB * iB + iG * iG + iR * iR); // compute "distance" from black
  if dDist < 260.0 then
    Result := clWhite
  else
    Result := clBlack;
end;

function ChangeColor(Color: TColor; Percent: shortint): TColor;
var
  r, g, b: byte;
begin
  Color := ColorToRGB(Color);
  r := GetRValue(Color);
  g := GetGValue(Color);
  b := GetBValue(Color);
  if Percent >= 0 then begin
    r := r + muldiv(255 - r, Percent, 100); // Percent% closer to white
    g := g + muldiv(255 - g, Percent, 100);
    b := b + muldiv(255 - b, Percent, 100);
  end
  else begin
    r := r - muldiv(r, -Percent, 100); // Percent% closer to black
    g := g - muldiv(g, -Percent, 100);
    b := b - muldiv(b, -Percent, 100);
  end;
  Result := RGB(r, g, b);
end;

// functions to set and get curront from, to and hoovered territories
function GetFromTerritory: integer;
begin
  Result := FromTerrit;
end;

function GetToTerritory: integer;
begin
  Result := ToTerrit;
end;

function GetHooverTerritory: integer;
begin
  Result := HooverTerrit;
end;

procedure SetFromTerritory(iT: integer);
var
  iPrev: integer;
begin
  iPrev := FromTerrit;
  FromTerrit := iT;
  if iPrev > 0 then
    DisplayTerritory(iPrev);
  if iT > 0 then
    DisplayTerritory(iT);
end;

procedure SetToTerritory(iT: integer);
var
  iPrev: integer;
begin
  iPrev := ToTerrit;
  ToTerrit := iT;
  if iPrev > 0 then
    DisplayTerritory(iPrev);
  if iT > 0 then
    DisplayTerritory(iT);
end;

procedure SetHooverTerritory(iT: integer);
var
  iPrev: integer;
begin
  iPrev := HooverTerrit;
  HooverTerrit := iT;
  if iPrev > 0 then
    DisplayTerritory(iPrev);
  if iT > 0 then
    DisplayTerritory(iT);
end;

end.
