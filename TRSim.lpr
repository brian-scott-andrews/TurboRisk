program TRSim;

{$MODE Delphi}

uses
  Forms, Interfaces,
  {HTMLHelpViewerMario,}
  Sim in 'Sim.pas' {fSim},
  Globals in 'Globals.pas',
  Attack in 'Attack.pas' {fAttack},
  Cards in 'Cards.pas' {fCards},
  Computer in 'Computer.pas',
  ExpSubr in 'ExpSubr.pas',
  History in 'History.pas' {fHistory},
  Human in 'Human.pas',
  Log in 'Log.pas' {fLog},
  SimMap in 'SimMap.pas' {fSimMap},
  Move in 'Move.pas' {fMove},
  NewGame in 'NewGame.pas' {fNewGame},
  Players in 'Players.pas' {fPlayers},
  Programs in 'Programs.pas' {fPrograms},
  Stats in 'Stats.pas' {fStats},
  Territ in 'Territ.pas',
  TRPError in 'TRPError.pas' {fTRPError},
  UDialog in 'UDialog.pas' {fUDialog},
  SimRun in 'SimRun.pas' {fSimRun},
  Main in 'Main.pas' {fMain},
  SimCPULog in 'SimCPULog.pas' {fSimCPULog},
  SimGameLog in 'SimGameLog.pas' {fSimGameLog};

{.$R *.res}

begin
  Application.Initialize;
//  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TfSim, fSim);
  Application.CreateForm(TfAttack, fAttack);
  Application.CreateForm(TfCards, fCards);
  Application.CreateForm(TfHistory, fHistory);
  Application.CreateForm(TfLog, fLog);
  Application.CreateForm(TfSimMap, fSimMap);
  Application.CreateForm(TfMove, fMove);
  Application.CreateForm(TfNewGame, fNewGame);
  Application.CreateForm(TfPlayers, fPlayers);
  Application.CreateForm(TfPrograms, fPrograms);
  Application.CreateForm(TfStats, fStats);
  Application.CreateForm(TfTRPError, fTRPError);
  Application.CreateForm(TfUDialog, fUDialog);
  Application.CreateForm(TfSimRun, fSimRun);
  Application.CreateForm(TfMain, fMain);
  Application.Run;
end.
