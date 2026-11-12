unit CounterweightTests;
{$MODE Delphi}
interface
procedure RunCounterweightTests;
implementation
uses Classes, SysUtils, Variants, Globals, Territ;

procedure RunCounterweightTests;
var Context: TTRCompContext; Params: array of Variant;
  Lines: TStringList; Script,Name,Value,Diagnostics: string;
  A,D,T,Source,Target: Integer;

  procedure Reset;
  var I,P: Integer; Card: TCard;
  begin
    Context.CurrentPlayer:=1; Context.Conquest:=False;
    Context.CardTradeByCombination:=False; Context.Message:='';
    for P:=1 to MAXPLAYERS do begin
      Context.PlayerActive[P]:=P<=2; Context.PlayerName[P]:=IntToStr(P);
      Context.PlayerProgram[P]:='vexer.trp'; Context.PlayerNewArmies[P]:=0;
      for Card:=Low(TCard) to High(TCard) do Context.PlayerCards[P,Card]:=0;
    end;
    for I:=1 to MAXBUFFER do Context.Buffers[I]:=0;
    for I:=1 to MAXTERRITORIES do begin
      Context.TerritoryOwner[I]:=2; Context.TerritoryArmies[I]:=100;
    end;
    Context.TerritoryOwner[39]:=1; Context.TerritoryArmies[39]:=20;
  end;

  procedure Run(const Routine: string);
  begin
    if not RunTRPRoutine(Name,Script,Routine,Context,Params,Value,Diagnostics) then
      raise Exception.Create('Counterweight '+Routine+': '+Diagnostics);
  end;

  procedure Attack;
  begin
    SetLength(Params,2); Params[0]:=0; Params[1]:=0; Run('Attack');
    Source:=Integer(Params[0]); Target:=Integer(Params[1]);
    if (Source<>0) or (Target<>0) then
      if (Source<1) or (Source>42) or (Target<1) or (Target>42) or
         (Context.TerritoryOwner[Source]<>1) or (Context.TerritoryOwner[Target]=1) or
         not Confinante(Source,Target) or (Context.TerritoryArmies[Source]<2) then
        raise Exception.Create('Counterweight returned illegal attack');
  end;
begin
  SetupTerritories;
  Name:='players'+PathDelim+'counterweight.trp';
  Lines:=TStringList.Create;
  try Lines.LoadFromFile(Name); Script:=Lines.Text finally Lines.Free end;
  Script:=StringReplace(Script,'begin'+LineEnding+'  Ready:=False;'+LineEnding+'end.',
    'function TestOdds(A,D: integer): double; begin PrepareOdds; Result:=Odds(A,D); end;'+
    LineEnding+'begin Ready:=False; end.',[]);
  if not ValidateTRPSource(Name,Script,Diagnostics) then
    raise Exception.Create('Counterweight compilation: '+Diagnostics);
  Reset;
  SetLength(Params,2); Params[0]:=1; Params[1]:=1; Run('TestOdds');
  if Abs(StrToFloat(Value)-5.0/12.0)>0.000001 then
    raise Exception.Create('Counterweight 1v1 odds incorrect');
  Params[0]:=3; Params[1]:=1; Run('TestOdds');
  if Abs(StrToFloat(Value)-0.916374)>0.00001 then
    raise Exception.Create('Counterweight 3v1 battle odds incorrect');
  Reset; Attack;
  if Source<>0 then raise Exception.Create('Counterweight attacks hopeless battle');
  Context.TerritoryArmies[40]:=1; Attack;
  if (Source<>39) or (Target<>40) then raise Exception.Create('Counterweight missed cheap campaign');
  Context.Conquest:=True; Attack;
  if Source=0 then raise Exception.Create('Counterweight stopped solely because card earned');
  Context.TerritoryOwner[40]:=1; Context.TerritoryArmies[40]:=18;
  Context.TerritoryArmies[39]:=1; Context.TerritoryArmies[41]:=1;
  Attack;
  if Source<>40 then raise Exception.Create('Counterweight did not advance campaign');
  Context.TerritoryOwner[42]:=1;
  SetLength(Params,3); Params[0]:=40; Params[1]:=41; Params[2]:=0;
  Run('Occupation');
  if (Integer(Params[2])<0) or (Integer(Params[2])>17) then
    raise Exception.Create('Counterweight occupation out of bounds');
  Reset; Context.TerritoryOwner[40]:=0;
  SetLength(Params,1); Params[0]:=0; Run('Assignment');
  if Integer(Params[0])<>40 then raise Exception.Create('Counterweight assignment incorrect');
  Reset; Context.PlayerNewArmies[1]:=3;
  SetLength(Params,1); Params[0]:=0; Run('Placement');
  if Integer(Params[0])<>39 then raise Exception.Create('Counterweight placement incorrect');
  for T:=39 to 42 do Context.TerritoryOwner[T]:=1;
  Context.TerritoryArmies[41]:=25; Context.TerritoryArmies[40]:=1;
  Context.TerritoryArmies[42]:=1;
  SetLength(Params,3); Params[0]:=0; Params[1]:=0; Params[2]:=0;
  Run('Fortification');
  if (Integer(Params[0])<>41) or (Integer(Params[1])<>40) or (Integer(Params[2])<>24) then
    raise Exception.Create('Counterweight consolidation incorrect');
  for A:=1 to 4 do for D:=1 to 4 do begin
    Reset; Context.TerritoryArmies[39]:=A; Context.TerritoryArmies[40]:=D;
    Attack;
  end;
  Writeln('PASS: Counterweight exact dice odds, campaign continuity, legal callbacks, occupation and consolidation.');
end;
end.
