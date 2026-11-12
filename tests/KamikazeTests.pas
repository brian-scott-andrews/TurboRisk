unit KamikazeTests;
{$MODE Delphi}
interface
procedure RunKamikazeTests;
implementation
uses Classes, SysUtils, Variants, Globals, Territ;

procedure RunKamikazeTests;
var Context: TTRCompContext;
  Params: array of Variant;
  Lines: TStringList;
  Script, Name, Value, Diagnostics: string;
  T: Integer;

  procedure Reset;
  var T,P: Integer;
    Card: TCard;
  begin
    Context.CurrentPlayer:=1; Context.Conquest:=False;
    Context.CardTradeByCombination:=False; Context.Message:='';
    for P:=1 to MAXPLAYERS do begin
      Context.PlayerActive[P]:=P<=2; Context.PlayerName[P]:=IntToStr(P);
      Context.PlayerProgram[P]:='simple.trp'; Context.PlayerNewArmies[P]:=0;
      for Card:=Low(TCard) to High(TCard) do Context.PlayerCards[P,Card]:=0;
    end;
    for T:=1 to MAXBUFFER do Context.Buffers[T]:=0;
    for T:=1 to MAXTERRITORIES do begin
      Context.TerritoryOwner[T]:=2; Context.TerritoryArmies[T]:=20;
    end;
    Context.TerritoryOwner[1]:=1; Context.TerritoryArmies[1]:=10;
  end;

  procedure Run(const Routine: string; Count: Integer; A,B,C: Integer);
  var I: Integer;
  begin
    SetLength(Params,Count);
    for I:=0 to Count-1 do Params[I]:=0;
    if Routine='Occupation' then begin Params[0]:=1; Params[1]:=2 end;
    if not RunTRPRoutine(Name,Script,Routine,Context,Params,Value,Diagnostics) then
      raise Exception.Create('Kamikaze '+Routine+': '+Diagnostics);
    if (Integer(Params[0])<>A) or
       ((Count>1) and (Integer(Params[1])<>B)) or
       ((Count>2) and (Integer(Params[2])<>C)) then
      raise Exception.Create('Kamikaze unexpected '+Routine+' decision');
  end;

begin
  SetupTerritories;
  Name:='players'+PathDelim+'kamikaze.trp';
  Lines:=TStringList.Create;
  try Lines.LoadFromFile(Name); Script:=Lines.Text finally Lines.Free end;
  if not ValidateTRPSource(Name,Script,Diagnostics) then
    raise Exception.Create('Kamikaze compilation: '+Diagnostics);
  Reset;
  Context.TerritoryOwner[5]:=0;
  Run('Assignment',1,5,0,0);
  Reset;
  Context.TerritoryOwner[10]:=1; Context.TerritoryArmies[10]:=50;
  Run('Placement',1,10,0,0);
  Context.TerritoryArmies[2]:=1;
  Run('Attack',2,1,2,0);
  Context.TerritoryArmies[1]:=2;
  Run('Attack',2,1,2,0);
  Context.TerritoryArmies[1]:=1;
  Run('Attack',2,0,0,0);
  Reset;
  Context.TerritoryArmies[1]:=4;
  Run('Attack',2,1,2,0); // No odds safeguard: four armies may attack twenty.
  Context.Conquest:=True;
  Run('Attack',2,0,0,0);
  Context.TerritoryOwner[2]:=1;
  Run('Occupation',3,1,2,3);
  Reset;
  Context.TerritoryArmies[1]:=3;
  Run('Attack',2,0,0,0);
  Reset;
  for T:=1 to MAXTERRITORIES do Context.TerritoryOwner[T]:=1;
  Context.TerritoryArmies[10]:=50;
  Run('Placement',1,10,0,0);
  Run('Attack',2,0,0,0);
  Run('Fortification',3,0,0,0);
  Reset;
  Context.TerritoryOwner[2]:=1; Context.TerritoryOwner[4]:=1;
  Context.TerritoryOwner[37]:=1;
  Run('Fortification',3,1,2,9);
  Writeln('PASS: Kamikaze callbacks, placement, risky attack commitment, one conquest, occupation and consolidation.');
end;
end.
