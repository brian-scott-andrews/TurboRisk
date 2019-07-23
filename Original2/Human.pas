unit Human;

interface

// Mostra istruzioni per giocatore umano
procedure MostraIstruzioni;

// Attacco umano
procedure UomoAttacca(iTf, iTt: integer);

// Trasferimento umano
procedure UomoSposta(iTf, iTt: integer; bMove: boolean);

implementation

uses SysUtils, Controls,
     Globals, Main, Attack, Move;

// Mostra istruzioni per giocatore umano
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

// Attacco umano
procedure UomoAttacca(iTf, iTt: integer);
begin
  fAttack.iTf := iTf;
  fAttack.iTt := iTt;
  // Gestione attacco
  if fAttack.ShowModal=mrOK then begin
    // test eliminati tutti gli avversari
    if bEliminatedPlayer and (iNPlayers<2) then exit;
    // territorio conquistato, spostamento conseguente
    if arTerritory[iTf].Army>1 then
      UomoSposta(iTf, iTt, false);
    // test scambio carte catturate  
    if bEliminatedPlayer then begin
      if RImmediateTrade then AssignNewArmies(true);
      if arPlayer[iTurn].NewArmy>0 then HumanPhase := hpPlacement;
    end;
  end;
end;

// Trasferimento umano
procedure UomoSposta(iTf, iTt: integer; bMove: boolean);
begin
  fMove.iTf := iTf;
  fMove.iTt := iTt;
  if (fMove.ShowModal=mrOK) and bMove then begin
    arPlayer[iTurn].FlMove := true;
  end else begin
    SetFromTerritory(0);
    SetToTerritory(0);
    MostraIstruzioni;
  end;
end;

end.
