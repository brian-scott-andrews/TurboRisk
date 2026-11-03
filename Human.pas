unit Human;

{$MODE Delphi}

interface

// Show instructions to the human player
procedure MostraIstruzioni;

// Human attack
procedure UomoAttacca(iTf, iTt: integer);

// Human troop movement
procedure UomoSposta(iTf, iTt: integer; bMove: boolean);

implementation

uses SysUtils, Controls,
     Globals, Main, Attack, Move, ActionHistory;

// Show instructions to the human player
procedure MostraIstruzioni;
var
  sMsg: string;
begin
  sMsg := '';
  if GameState=gsAssigning then begin
    sMsg := 'Please claim a territory.';
  end else if (GameState=gsDistributing) then begin
    if arPlayer[iTurn].NewArmy>1 then begin
      sMsg := 'You have '+IntToStr(arPlayer[iTurn].NewArmy)+
              ' armies left to place. Please place an army.';
    end else begin
      sMsg := 'You have 1 army left to place. Please place it.';
    end;
  end else if ((GameState=gsPlaying) and (HumanPhase=hpPlacement)) then begin
    if arPlayer[iTurn].NewArmy>1 then begin
      sMsg := 'You have '+IntToStr(arPlayer[iTurn].NewArmy)+
              ' armies left to place  (click=1, +shift=5, +ctrl+shift=10, +alt+ctrl+shift=25)';
    end else begin
      sMsg := 'You have 1 army left to place. ';
    end;
  end else begin
    if GetFromTerritory=0 then begin
      sMsg := 'Please choose a territory to attack or move from (click)'+
              ' or pass (spacebar)';
    end else begin
      sMsg := 'From '+arTerritory[GetFromTerritory].Name+
                '. Please choose a territory to attack or move to.'
    end;
  end;
  fMain.panStatus.Panels[2].Text := sMsg;
end;

// Human attack
procedure UomoAttacca(iTf, iTt: integer);
begin
  fAttack.iTf := iTf;
  fAttack.iTt := iTt;
  // Handle the attack
  if fAttack.ShowModal=mrOK then begin
    // Check whether all opponents have been eliminated
    if bEliminatedPlayer and (iNPlayers<2) then exit;
    // Move troops into the conquered territory
    if arTerritory[iTf].Army>1 then
      UomoSposta(iTf, iTt, false);
    // Check whether captured cards should be traded
    if bEliminatedPlayer then begin
      if RImmediateTrade then AssignNewArmies(true);
      if arPlayer[iTurn].NewArmy>0 then HumanPhase := hpPlacement;
    end;
  end;
end;

// Human troop movement
procedure UomoSposta(iTf, iTt: integer; bMove: boolean);
var
  FromBefore, ToBefore, Kind: Integer;
  Completed: Boolean;
begin
  FromBefore := arTerritory[iTf].Army;
  ToBefore := arTerritory[iTt].Army;
  fMove.iTf := iTf;
  fMove.iTt := iTt;
  Completed := fMove.ShowModal=mrOK;
  if Completed then begin
    if bMove then Kind := AK_FORTIFICATION else Kind := AK_OCCUPATION;
    RecordGameAction(Kind, iTurn, 0, iTf, iTt,
      arTerritory[iTt].Army - ToBefore, FromBefore, ToBefore);
    if bMove then arPlayer[iTurn].FlMove := true;
  end;
  if not (Completed and bMove) then begin
    SetFromTerritory(0);
    SetToTerritory(0);
    MostraIstruzioni;
  end;
end;

end.
