unit Main;

{$MODE Delphi}

interface

uses
  LCLIntf, LCLType, LMessages, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  Menus, ExtCtrls, StdCtrls, ComCtrls, {JvComponentBase, JvPropertyStore,
  JvProgramVersionCheck, IdAntiFreezeBase, IdAntiFreeze, IdBaseComponent,
  IdComponent, IdTCPConnection, IdTCPClient, IdFTP,} ImgList, ToolWin;

type
  TfMain = class(TForm)
    panMap: TPanel;
    imgMap: TImage;
    mnuMain: TMainMenu;
    mnuFil: TMenuItem;
    mnuFilSep1: TMenuItem;
    mnuFilExit: TMenuItem;
    mnuFilNew: TMenuItem;
    mnuFilEnd: TMenuItem;
    mnuOpt: TMenuItem;
    mnuOptRules: TMenuItem;
    mnuVie: TMenuItem;
    mnuVieStats: TMenuItem;
    panStatus: TStatusBar;
    mnuVieLog: TMenuItem;
    mnuHel: TMenuItem;
    mnuHelReadme: TMenuItem;
    mnuHelAbout: TMenuItem;
    mnuOptMap: TMenuItem;
    mnuVieHist: TMenuItem;
    N1: TMenuItem;
    N2: TMenuItem;
    N3: TMenuItem;
    mnuHelCheckUpdates: TMenuItem;
    {IdAntiFreeze: TIdAntiFreeze;      }
    mnuHelHomepage: TMenuItem;
    mnuFilSave: TMenuItem;
    mnuFilRestore: TMenuItem;
    N4: TMenuItem;
    dlgOpen: TOpenDialog;
    dlgSave: TSaveDialog;
    tlbToolBar: TToolBar;
    cmdNewGame: TToolButton;
    imlButtons: TImageList;
    cmdEndGame: TToolButton;
    cmdSaveGame: TToolButton;
    cmdRestoreGame: TToolButton;
    cmdStatistics: TToolButton;
    cmdEndTurn: TToolButton;
    imlDisButtons: TImageList;
    Panel1: TPanel;
    Label1: TLabel;
    panTurn: TPanel;
    mnuOptPref: TMenuItem;
    cmdExit: TToolButton;
    cmdLog: TToolButton;
    cmdHistory: TToolButton;
    cmdRules: TToolButton;
    cmdMap: TToolButton;
    cmdPreferences: TToolButton;
//    cmdHelp: TToolButton;
    cmdHomePage: TToolButton;
    cmdUpdate: TToolButton;
    cmdAbout: TToolButton;
    mnuHelGroup: TMenuItem;
    N5: TMenuItem;
    procedure mnuFilExitClick(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure imgMapMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure mnuFilNewClick(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure mnuFilEndClick(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure mnuVieStatsClick(Sender: TObject);
    procedure mnuOptRulesClick(Sender: TObject);
    procedure mnuOptPlayersClick(Sender: TObject);
    procedure mnuVieLogClick(Sender: TObject);
{    procedure mnuHelReadmeClick(Sender: TObject);   }
    procedure mnuHelAboutClick(Sender: TObject);
    procedure mnuOptMapClick(Sender: TObject);
    procedure mnuVieHistClick(Sender: TObject);
{    procedure mnuHelCheckUpdatesClick(Sender: TObject);  }
    procedure mnuHelHomepageClick(Sender: TObject);
    procedure mnuFilSaveClick(Sender: TObject);
    procedure mnuFilRestoreClick(Sender: TObject);
    procedure cmdEndTurnClick(Sender: TObject);
    procedure imgMapMouseMove(Sender: TObject; Shift: TShiftState;
      X, Y: Integer);
    procedure mnuOptPrefClick(Sender: TObject);
    procedure mnuHelGroupClick(Sender: TObject);
  private
  public
    { Public declarations }
  end;

var
  fMain: TfMain;

implementation

{$R *.lfm}

uses Globals, Territ, NewGame, Stats, Human, Rules, Players, Log,
  Readme,
  About, ExpSubr, Map, History, Pref, SplashScreen;

procedure TfMain.FormShow(Sender: TObject);
begin
  bG_TRSim := false;
  Setup;
  Caption := 'TurboRisk ' + sG_AppVers;
  Application.HelpFile := sG_AppPath + 'TurboRisk.chm';
  // remove splash screen
  fSplashScreen.Hide;
  fSplashScreen.Free;
end;

procedure TfMain.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
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

procedure TfMain.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  Cleanup;
end;

procedure TfMain.mnuFilNewClick(Sender: TObject);
begin
  if GameState <> gsStopped then
    exit;
  if fNewGame.ShowModal = mrOK then begin
    Screen.Cursor := crHourGlass;
    panStatus.Panels[2].Text := 'Preparing new game, please wait...';
    Application.ProcessMessages;
    NewGameSetup;
    panStatus.Panels[2].Text := '';
    Screen.Cursor := crDefault;
    if GameState <> gsStopped then
      Supervisor
    else
      GameCleanup;
  end;
end;

procedure TfMain.mnuFilEndClick(Sender: TObject);
begin
  if GameState = gsStopped then
    exit;
  if bPrefConfirmAbort and (MessageDlg(
      'Are you sure you want to quit this game?', mtConfirmation,
      [mbYes, mbNo], 0) <> mrYes) then
    exit;
  if bHumanTurn then begin
    GameCleanup;
    exit;
  end
  else begin
    bStopASAP := true;
  end;
end;

procedure TfMain.mnuFilSaveClick(Sender: TObject);
begin
  if not bHumanTurn then
    exit;
  dlgSave.InitialDir := sG_AppPath;
  dlgSave.FileName := 'my_game.trg';
  if dlgSave.Execute then begin
    SaveGame(dlgSave.FileName, '');
    panStatus.Panels[2].Text := 'Game saved.';
  end;
end;

procedure TfMain.mnuFilRestoreClick(Sender: TObject);
begin
  dlgOpen.InitialDir := sG_AppPath;
  if dlgOpen.Execute then begin
    Screen.Cursor := crHourGlass;
    panStatus.Panels[2].Text := 'Restoring game, please wait...';
    Application.ProcessMessages;
    GameCleanup;
    RestoreGame(dlgOpen.FileName);
    Screen.Cursor := crDefault;
    panStatus.Panels[2].Text := '';
    if GameState = gsStopped then begin
      GameCleanup;
      exit;
    end;
    MostraIstruzioni;
    UpdateGridPos;
    // save and restore enabled (though meaningless)
    mnuFilSave.Enabled := true;
    cmdSaveGame.Enabled := true;
    mnuFilRestore.Enabled := true;
    cmdRestoreGame.Enabled := true;
  end;
end;

procedure TfMain.mnuFilExitClick(Sender: TObject);
begin
  Close;
end;

procedure TfMain.mnuVieStatsClick(Sender: TObject);
begin
  if fStats.Visible then begin
    fStats.Close;
  end
  else begin
    fStats.Show;
  end;
end;

procedure TfMain.mnuVieHistClick(Sender: TObject);
begin
  fHistory.ShowModal;
end;

procedure TfMain.mnuVieLogClick(Sender: TObject);
begin
  if fLog.Visible then begin
    fLog.Close;
  end
  else begin
    fLog.Show;
  end;
end;

procedure TfMain.mnuOptPlayersClick(Sender: TObject);
begin
  fPlayers.ShowModal;
end;

procedure TfMain.mnuOptPrefClick(Sender: TObject);
begin
  fPref.ShowModal;
end;

procedure TfMain.mnuOptRulesClick(Sender: TObject);
begin
  fRules.ShowModal;
end;

procedure TfMain.mnuOptMapClick(Sender: TObject);
begin
  fMap.ShowModal;
end;

{
procedure TfMain.mnuHelReadmeClick(Sender: TObject);
begin
  // Application.HelpSystem.ShowTableOfContents; // doesn'twork!
  Application.HelpSystem.ShowContextHelp(100, sG_AppPath + 'TurboRisk.chm');
end;
}

procedure TfMain.mnuHelAboutClick(Sender: TObject);
begin
  fAbout.ShowModal;
end;


procedure TfMain.mnuHelGroupClick(Sender: TObject);
begin
  OpenURL(pChar(
      'http://groups.google.com/group/turborisk')); { *Converted from ShellExecute* }
end;

procedure TfMain.mnuHelHomepageClick(Sender: TObject);
begin
  OpenURL(pChar(
      'http://www.marioferrari.org/freeware/turborisk/turborisk.html')); { *Converted from ShellExecute* }
end;

procedure TfMain.imgMapMouseMove(Sender: TObject; Shift: TShiftState;
  X, Y: Integer);
var
  iT: Integer;
begin
  if GameState = gsStopped then
    exit;
  // search territory hoovered by mouse
  iT := TrovaTerritorio(X, Y);
  // if changed...
  if iT <> GetHooverTerritory then begin
    // set new hoovered territory
    SetHooverTerritory(iT);
  end;
end;

procedure TfMain.imgMapMouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  iT: Integer;
  iColl: Integer;
begin
  if not bHumanTurn then
    exit;
  iT := TrovaTerritorio(X, Y);
  cmdEndTurn.Enabled := false; // disable "end turn" button
  // Puntamento su territorio
  if iT > 0 then begin
    case GameState of
      gsAssigning: begin
          if arTerritory[iT].Owner = 0 then begin
            AssegnaTerritorio(iT, iTurn);
            inc(arTerritory[iT].Army);
            dec(arPlayer[iTurn].NewArmy);
            DisplayTerritory(iT);
            if arPlayer[iTurn].KeepLog then
              ScriviLog(arTerritory[iT].Name + ' assigned.');
            // fine turno
            Supervisor;
            exit;
          end;
        end;
      gsDistributing: begin
          if (arTerritory[iT].Owner = iTurn) and (arPlayer[iTurn].NewArmy > 0)
            then begin
            CollocaArmata(iT, iTurn, 1);
            // fine turno
            Supervisor;
            exit;
          end;
        end;
      gsPlaying: begin
          case HumanPhase of
            hpPlacement: begin
                if (arTerritory[iT].Owner = iTurn) and
                  (arPlayer[iTurn].NewArmy > 0) then begin
                  iColl := 1;
                  if ssShift in Shift then
                    inc(iColl);
                  if ssAlt in Shift then
                    inc(iColl);
                  if ssCtrl in Shift then
                    inc(iColl);
                  case iColl of
                    4:
                      iColl := 25;
                    3:
                      iColl := 10;
                    2:
                      iColl := 5;
                  end;
                  CollocaArmata(iT, iTurn, iColl);
                  mnuFilSave.Enabled := false; // game save allowed only at the beginning of a turn
                  cmdSaveGame.Enabled := false;
                  if arPlayer[iTurn].NewArmy = 0 then begin
                    HumanPhase := hpAttack;
                    cmdEndTurn.Enabled := true; // enable "end turn" button
                  end;
                  MostraIstruzioni;
                end;
              end;
            hpAttack: begin
                cmdEndTurn.Enabled := true; // enable "end turn" button
                if GetFromTerritory = 0 then begin
                  if (arTerritory[iT].Owner = iTurn) and
                    (arTerritory[iT].Army >= 2) then begin
                    SetFromTerritory(iT);
                    MostraIstruzioni;
                  end;
                end
                else begin
                  if Confinante(GetFromTerritory, iT) then begin
                    if arTerritory[iT].Owner <> iTurn then begin
                      SetToTerritory(iT);
                      fMain.panStatus.Panels[2].Text := 'Attack in progress...';
                      UomoAttacca(GetFromTerritory, iT);
                      if iNPlayers < 2 then begin
                        // last opponent eliminated, the game ends
                        Supervisor;
                        exit;
                      end;
                    end
                    else if (arTerritory[iT].Owner = iTurn)
                      and not arPlayer[iTurn].FlMove then begin
                      SetToTerritory(iT);
                      fMain.panStatus.Panels[2].Text :=
                        'Troops move in progress...';
                      UomoSposta(GetFromTerritory, iT, true);
                      if arPlayer[iTurn].FlMove and RFinalMove then begin
                        // turn ends
                        SetFromTerritory(0);
                        SetToTerritory(0);
                        Supervisor;
                      end;
                      exit;
                    end;
                  end;
                  SetFromTerritory(0);
                  SetToTerritory(0);
                  MostraIstruzioni;
                end;
              end;
          end;
        end;
    end;
  end
  else begin
    SetFromTerritory(0);
    SetToTerritory(0);
    MostraIstruzioni;
    if bHumanTurn and (GameState = gsPlaying) and (HumanPhase > hpPlacement)
      then begin
      cmdEndTurn.Enabled := true; // enable "end turn" button
    end;
  end;
end;

procedure TfMain.FormKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if Key = VK_ESCAPE then
    Application.Minimize
  else if Key = VK_SPACE then begin
    if bHumanTurn and (GameState = gsPlaying) and (HumanPhase > hpPlacement)
      then begin
      SetFromTerritory(0);
      SetToTerritory(0);
      Supervisor;
      exit;
    end;
  end;
end;

procedure TfMain.cmdEndTurnClick(Sender: TObject);
begin
  if bHumanTurn and (GameState = gsPlaying) and (HumanPhase > hpPlacement) then
    begin
    SetFromTerritory(0);
    SetToTerritory(0);
    Supervisor;
  end;
end;

end.
