program TurboRisk;

{$MODE Delphi}

uses
  Forms, Interfaces,
  {HTMLHElpViewerMario,}
  SimMap in 'SimMap.pas' {fSimMap},
  Globals in 'Globals.pas',
  Territ in 'Territ.pas',
  NewGame in 'NewGame.pas' {fNewGame},
  Computer in 'Computer.pas',
  Stats in 'Stats.pas' {fStats},
  Human in 'Human.pas',
  Rules in 'Rules.pas' {fRules},
  Cards in 'Cards.pas' {fCards},
  Attack in 'Attack.pas' {fAttack},
  Move in 'Move.pas' {fMove},
  Players in 'Players.pas' {fPlayers},
  Log in 'Log.pas' {fLog},
  About in 'About.pas' {fAbout},
  ExpSubr in 'ExpSubr.pas',
  Map in 'Map.pas' {fMap},
  History in 'History.pas' {fHistory},
  Programs in 'Programs.pas' {fPrograms},
  TRPError in 'TRPError.pas' {fTRPError},
  Pref in 'Pref.pas' {fPref},
  SplashScreen in 'SplashScreen.pas' {fSplashScreen},
  UDialog in 'UDialog.pas' {fUDialog},
  Main in 'Main.pas' {fMain};

{.$R *.RES}

begin
  fSplashScreen := TfSplashScreen.Create(Application) ;
  fSplashScreen.Show;
  Application.Initialize;
  fSplashScreen.Update;
  Application.CreateForm(TfMain, fMain);
  Application.CreateForm(TfSimMap, fSimMap);
  Application.CreateForm(TfNewGame, fNewGame);
  Application.CreateForm(TfStats, fStats);
  Application.CreateForm(TfRules, fRules);
  Application.CreateForm(TfCards, fCards);
  Application.CreateForm(TfAttack, fAttack);
  Application.CreateForm(TfMove, fMove);
  Application.CreateForm(TfPlayers, fPlayers);
  Application.CreateForm(TfLog, fLog);
  Application.CreateForm(TfAbout, fAbout);
  Application.CreateForm(TfMap, fMap);
  Application.CreateForm(TfHistory, fHistory);
  Application.CreateForm(TfPrograms, fPrograms);
  Application.CreateForm(TfTRPError, fTRPError);
  Application.CreateForm(TfPref, fPref);
  Application.CreateForm(TfUDialog, fUDialog);
  Application.Run;
end.
