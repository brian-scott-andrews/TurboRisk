unit VultureTests;
{$MODE Delphi}
interface
procedure RunVultureTests;
implementation
uses Classes, SysUtils, Variants, Globals, Territ;

procedure RunVultureTests;
var Context: TTRCompContext;
  Params: array of Variant;
  Lines: TStringList;
  Script,Name,Value,Diagnostics: string;
  OldTrade: array[1..8] of Integer;
  OldTrades,I: Integer;

  procedure Reset;
  var T,P: Integer; Card: TCard;
  begin
    Context.CurrentPlayer:=1; Context.Conquest:=False;
    Context.CardTradeByCombination:=False; Context.Message:='';
    for P:=1 to MAXPLAYERS do begin
      Context.PlayerActive[P]:=P<=3; Context.PlayerName[P]:=IntToStr(P);
      Context.PlayerProgram[P]:='simple.trp'; Context.PlayerNewArmies[P]:=0;
      for Card:=Low(TCard) to High(TCard) do Context.PlayerCards[P,Card]:=0;
    end;
    for T:=1 to MAXBUFFER do Context.Buffers[T]:=0;
    for T:=1 to MAXTERRITORIES do begin
      Context.TerritoryOwner[T]:=3; Context.TerritoryArmies[T]:=100;
    end;
    Context.TerritoryOwner[39]:=1; Context.TerritoryArmies[39]:=20;
  end;

  procedure Run(const Routine: string; Count,A,B,C: Integer);
  var I: Integer;
    Actual: string;
  begin
    SetLength(Params,Count);
    for I:=0 to Count-1 do Params[I]:=0;
    if Routine='Occupation' then begin Params[0]:=39; Params[1]:=40 end;
    if not RunTRPRoutine(Name,Script,Routine,Context,Params,Value,Diagnostics) then
      raise Exception.Create('Vulture '+Routine+': '+Diagnostics);
    Actual:='';
    for I:=0 to Count-1 do begin
      if I>0 then Actual:=Actual+',';
      Actual:=Actual+VarToStr(Params[I]);
    end;
    if (Integer(Params[0])<>A) or
       ((Count>1) and (Integer(Params[1])<>B)) or
       ((Count>2) and (Integer(Params[2])<>C)) then
      raise Exception.CreateFmt('Vulture %s expected %d,%d,%d; got %s',
        [Routine,A,B,C,Actual]);
  end;
begin
  SetupTerritories;
  Name:='players'+PathDelim+'vulture.trp';
  Lines:=TStringList.Create;
  try Lines.LoadFromFile(Name); Script:=Lines.Text finally Lines.Free end;
  if not ValidateTRPSource(Name,Script,Diagnostics) then
    raise Exception.Create('Vulture compilation: '+Diagnostics);
  Reset;
  Context.TerritoryOwner[40]:=0;
  Run('Assignment',1,40,0,0);
  Reset;
  Run('Placement',1,39,0,0);
  Run('Attack',2,0,0,0);
  Context.TerritoryArmies[40]:=2;
  Run('Attack',2,39,40,0);
  Context.TerritoryArmies[39]:=6;
  Run('Attack',2,0,0,0);
  Context.TerritoryArmies[40]:=1;
  Run('Attack',2,39,40,0);
  Context.Conquest:=True;
  Run('Attack',2,0,0,0);
  Run('Occupation',3,39,40,5);
  for I:=1 to 8 do OldTrade[I]:=RTradeValue[I];
  OldTrades:=arPlayer[1].NScambi;
  try
    for I:=1 to 8 do RTradeValue[I]:=30;
    arPlayer[1].NScambi:=0;
    Reset;
    Context.TerritoryOwner[40]:=2; Context.TerritoryArmies[40]:=3;
    Context.PlayerCards[2,Low(TCard)]:=4;
    Context.PlayerCards[1,Low(TCard)]:=1;
    Context.Conquest:=True;
    Run('Attack',2,39,40,0); // Elimination remains eligible after taking a card.
    Context.TerritoryArmies[39]:=12;
    Run('Attack',2,0,0,0); // Cannot borrow the victim's future trade.
    Context.PlayerNewArmies[1]:=1000;
    Run('Attack',2,0,0,0);
    Context.TerritoryArmies[39]:=20;
    Context.PlayerCards[1,Low(TCard)]:=0;
    Run('Attack',2,0,0,0); // Four captured cards alone do not guarantee a set.
    Context.PlayerCards[1,Low(TCard)]:=1;
    Context.CardTradeByCombination:=True;
    Run('Attack',2,0,0,0);
    Context.CardTradeByCombination:=False;
    Context.TerritoryOwner[41]:=2; Context.TerritoryArmies[41]:=2;
    Run('Attack',2,39,40,0);
    Context.TerritoryOwner[40]:=1; Context.TerritoryArmies[40]:=15;
    Context.TerritoryArmies[39]:=1;
    Run('Attack',2,40,41,0); // Replan from the advanced stack.
    Context.TerritoryOwner[41]:=1;
    Run('Attack',2,0,0,0);
  finally
    for I:=1 to 8 do RTradeValue[I]:=OldTrade[I];
    arPlayer[1].NScambi:=OldTrades;
  end;
  Reset;
  Context.TerritoryOwner[40]:=1; Context.TerritoryOwner[41]:=1;
  Context.TerritoryOwner[42]:=1;
  Context.TerritoryArmies[40]:=1; Context.TerritoryArmies[42]:=1;
  Context.TerritoryArmies[41]:=25;
  Run('Fortification',3,41,40,24);
  Context.TerritoryArmies[40]:=100;
  Run('Fortification',3,40,39,99);
  Writeln('PASS: Vulture weak-target filter, card stop, affordable full elimination, progressive rewards, replanning and consolidation.');
end;
end.
