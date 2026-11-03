unit ActionEngineTests;

{$MODE Delphi}

interface

procedure RunActionEngineTests;

implementation

uses Classes, SysUtils, Forms, Graphics, ActionHistory, Globals,
  Main, Sim, Stats, Log, SimRun, Attack, Move, Human, Territ, Cards;

type
  TMoveDriver = class
    Cancel: Boolean;
    procedure ClickMove(Data: PtrInt);
  end;

procedure TMoveDriver.ClickMove(Data: PtrInt);
begin
  if Cancel then fMove.cmdCancelClick(nil)
  else begin
    Dec(fMove.iProv, 2);
    Inc(fMove.iDest, 2);
    fMove.cmdOkClick(nil);
  end;
end;

procedure Check(Condition: Boolean; const MessageText: string);
begin
  if not Condition then raise Exception.Create(MessageText);
end;

procedure RunActionEngineTests;
var
  Driver: TMoveDriver;
  SavedName: string;
  I, Before, SavedCount, FromArmy: Integer;
begin
  fSim := TfSim.Create(nil);
  fMain := TfMain.Create(nil);
  fStats := TfStats.Create(nil);
  fLog := TfLog.Create(nil);
  fSimRun := TfSimRun.Create(nil);
  fAttack := TfAttack.Create(nil);
  fMove := TfMove.Create(nil);
  fCards := TfCards.Create(nil);
  Driver := TMoveDriver.Create;
  SavedName := GetTempFileName(GetTempDir(False), 'tra');
  BaseMap := TBitmap.Create;
  bG_TRSim := True;
  try
    SetupTerritories;
    for I := 1 to MAXTERRITORIES do begin
      arTerritory[I].Owner := 0;
      arTerritory[I].Army := 0;
    end;
    for I := 1 to MAXPLAYERS do begin
      arPlayer[I].Active := I <= 2;
      arPlayer[I].Computer := False;
      arPlayer[I].KeepLog := False;
      arPlayer[I].Territ := 0;
      arPlayer[I].NewArmy := 40;
      aiTurnList[I] := I;
    end;
    iTurn := 1;
    iFirstTurn := 1;
    iTurnCounter := 50;
    iNPlayers := 2;
    GameState := gsPlaying;
    BeginActionHistory('{}');
    ClaimTerritory(1, 1);
    ClaimTerritory(2, 1);
    ClaimTerritory(3, 2);
    Check((ActionCount = 3) and (ActionValue(3, AF_PLAYER) = 2) and
      (ActionValue(3, AF_TO_AFTER) = 1), 'Shared assignment hook failed');
    CollocaArmata(1, 1, 10);
    Check((ActionValue(4, AF_KIND) = AK_PLACEMENT) and
      (ActionValue(4, AF_TO_BEFORE) = 1) and
      (ActionValue(4, AF_TO_AFTER) = 11), 'Shared placement hook failed');
    arPlayer[1].NewArmy := 2;
    CollocaArmata(1, 1, 20);
    Check(ActionValue(5, AF_ARMIES) = 2, 'Placement recorded requested rather than actual armies');
    TransferArmies(1, 2, 2, AK_FORTIFICATION);
    Check((ActionValue(6, AF_FROM_BEFORE) = 13) and
      (ActionValue(6, AF_FROM_AFTER) = 11), 'Shared troop movement hook failed');
    Before := ActionCount;
    Application.QueueAsyncCall(Driver.ClickMove, 0);
    UomoSposta(1, 2, True);
    Check((ActionCount = Before + 1) and
      (ActionValue(ActionCount, AF_KIND) = AK_FORTIFICATION) and
      (ActionValue(ActionCount, AF_ARMIES) = 2), 'Human fortification was not recorded');
    arPlayer[1].FlMove := False;
    Application.QueueAsyncCall(Driver.ClickMove, 0);
    UomoSposta(1, 2, False);
    Check(ActionValue(ActionCount, AF_KIND) = AK_OCCUPATION,
      'Human occupation was not recorded');
    Before := ActionCount;
    FromArmy := arTerritory[1].Army;
    Driver.Cancel := True;
    Application.QueueAsyncCall(Driver.ClickMove, 0);
    UomoSposta(1, 2, True);
    Check((ActionCount = Before) and (arTerritory[1].Army = FromArmy),
      'Cancelled human move changed history or board');
    arPlayer[1].NewArmy := 100;
    CollocaArmata(1, 1, 100);
    RandSeed := 123;
    fAttack.iTf := 1;
    fAttack.iTt := 3;
    fAttack.chkAutoMoveAll.Checked := True;
    while (arTerritory[3].Owner = 2) and (arTerritory[1].Army > 1) do
      fAttack.cmdAttackClick(nil);
    Check(arTerritory[3].Owner = 1, 'Deterministic capture setup failed');
    Check((ActionValue(ActionCount, AF_KIND) = AK_OCCUPATION) and
      (arTerritory[1].Army = 1), 'Human automatic occupation was not recorded');
    Check(ActionValue(ActionCount - 1, AF_KIND) = AK_ELIMINATION,
      'Elimination event was not recorded after combat');
    Check(ActionValue(ActionCount - 2, AF_OPPONENT) = 2,
      'Combat lost the original defender identity');
    RCardsValueType := cvConstant;
    RSetValue[csInf] := 4;
    arPlayer[1].Cards[caInf] := 3;
    arPlayer[1].CardsHandling := chManual;
    fCards.FormShow(nil);
    fCards.cmdTradeClick(nil);
    Check((ActionValue(ActionCount, AF_KIND) = AK_CARD_TRADE) and
      (ActionValue(ActionCount, AF_ARMIES) = 4), 'Human card trade was not recorded');
    SavedCount := ActionCount;
    arPlayer[1].Buffer[500] := SavedCount;
    SaveGame(SavedName, '');
    BeginActionHistory('{}');
    RestoreGame(SavedName);
    Check((ActionCount = SavedCount) and (arPlayer[1].Buffer[500] = SavedCount),
      'Saving/loading a game separated history from the TRP cursor');
    GameCleanup;
    Check(ActionValue(ActionCount, AF_KIND) = AK_GAME_END, 'Missing game-end event');
    Before := ActionCount;
    GameCleanup;
    Check(ActionCount = Before, 'Repeated cleanup duplicated the game-end event');
    WriteLn('PASS: engine claims/placements, human move/cancel/auto-occupation/trade, combat, and game save/load.');
  finally
    Driver.Free;
    DeleteFile(SavedName);
    fCards.Free;
    fMove.Free;
    fAttack.Free;
    fSimRun.Free;
    fLog.Free;
    fStats.Free;
    fMain.Free;
    fSim.Free;
    BaseMap.Free;
    BaseMap := nil;
    bG_TRSim := False;
  end;
end;

end.
