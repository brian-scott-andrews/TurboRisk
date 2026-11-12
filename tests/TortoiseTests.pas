unit TortoiseTests;
{$MODE Delphi}
interface
procedure RunTortoiseTests;
implementation
uses Classes, SysUtils, Variants, Globals, Territ;

procedure RunTortoiseTests;
var Context: TTRCompContext;
  Params: array of Variant;
  Lines: TStringList;
  Script,Mock,Name,Value,Diagnostics: string;
  T: Integer;

  procedure Reset;
  var I,P: Integer; Card: TCard;
  begin
    Context.CurrentPlayer:=1; Context.Conquest:=False;
    Context.CardTradeByCombination:=False; Context.Message:='';
    for P:=1 to MAXPLAYERS do begin
      Context.PlayerActive[P]:=P<=2; Context.PlayerName[P]:=IntToStr(P);
      Context.PlayerProgram[P]:='simple.trp'; Context.PlayerNewArmies[P]:=0;
      for Card:=Low(TCard) to High(TCard) do Context.PlayerCards[P,Card]:=0;
    end;
    for I:=1 to MAXBUFFER do Context.Buffers[I]:=0;
    for I:=1 to MAXTERRITORIES do begin
      Context.TerritoryOwner[I]:=2; Context.TerritoryArmies[I]:=1;
    end;
    for I:=39 to 42 do begin
      Context.TerritoryOwner[I]:=1; Context.TerritoryArmies[I]:=5;
    end;
    Context.Buffers[490]:=1; Context.Buffers[491]:=1;
  end;

  procedure Run(const Routine: string; Count,A,B,C: Integer);
  var I: Integer;
  begin
    SetLength(Params,Count);
    for I:=0 to Count-1 do Params[I]:=0;
    if Routine='Occupation' then begin Params[0]:=39; Params[1]:=31 end;
    if not RunTRPRoutine(Name,Mock,Routine,Context,Params,Value,Diagnostics) then
      raise Exception.Create('Tortoise '+Routine+': '+Diagnostics);
    if (Routine='Fortification') and (Integer(Params[0])>0) then begin
      if (Integer(Params[0])>MAXTERRITORIES) or
         (Integer(Params[1])<1) or (Integer(Params[1])>MAXTERRITORIES) then
        raise Exception.Create('Tortoise fortification territory out of range');
      if (Context.TerritoryOwner[Integer(Params[0])]<>Context.CurrentPlayer) or
         (Context.TerritoryOwner[Integer(Params[1])]<>Context.CurrentPlayer) or
         not Confinante(Integer(Params[0]),Integer(Params[1])) or
         (Integer(Params[2])<1) or
         (Integer(Params[2])>=Context.TerritoryArmies[Integer(Params[0])]) then
        raise Exception.Create('Tortoise returned an illegal fortification');
    end;
    if (Integer(Params[0])<>A) or
       ((Count>1) and (Integer(Params[1])<>B)) or
       ((Count>2) and (Integer(Params[2])<>C)) then
      raise Exception.CreateFmt('Tortoise %s expected %d,%d,%d; got %s',
        [Routine,A,B,C,VarToStr(Params[0])]);
  end;
begin
  SetupTerritories;
  Name:='players'+PathDelim+'tortoise.trp';
  Lines:=TStringList.Create;
  try Lines.LoadFromFile(Name); Script:=Lines.Text finally Lines.Free end;
  if not ValidateTRPSource(Name,Script,Diagnostics) then
    raise Exception.Create('Tortoise compilation: '+Diagnostics);
  Mock:=StringReplace(Script,'HCount','TestCount',[rfReplaceAll]);
  Mock:=StringReplace(Mock,'HGet','TestGet',[rfReplaceAll]);
  Mock:='function TestCount: integer; begin Result:=trunc(UBufferGet(490)); end;'+
    LineEnding+'function TestGet(I,F: integer): integer; begin Result:=0;'+
    ' if F=AF_KIND then Result:=AK_TURN_START;'+
    ' if F=AF_PLAYER then Result:=trunc(UBufferGet(491)); end;'+LineEnding+Mock;
  Reset;
  Run('Placement',1,39,0,0);
  Run('Placement',1,39,0,0);
  if Context.Buffers[2]<>1 then raise Exception.Create('Counted per-army callbacks as turns');
  Context.Buffers[490]:=12;
  Context.TerritoryArmies[39]:=100;
  Run('Attack',2,0,0,0);
  Context.TerritoryOwner[40]:=2;
  Run('Attack',2,39,40,0);
  Context.TerritoryOwner[40]:=1;
  Context.Buffers[490]:=13;
  Context.TerritoryArmies[39]:=30;
  Run('Attack',2,0,0,0);
  Context.TerritoryArmies[39]:=31;
  Run('Attack',2,39,31,0);
  Context.Conquest:=True; Context.TerritoryOwner[31]:=1;
  Run('Occupation',3,39,31,29);
  if Context.Buffers[3]<>31 then raise Exception.Create('Wall did not migrate');
  Run('Attack',2,0,0,0);
  Reset;
  Run('Placement',1,39,0,0);
  Context.Buffers[490]:=13;
  Context.TerritoryArmies[39]:=100;
  Context.TerritoryOwner[1]:=1; Context.TerritoryArmies[1]:=1;
  Run('Placement',1,1,0,0);
  Reset;
  Run('Placement',1,39,0,0);
  Context.TerritoryArmies[41]:=25;
  Run('Fortification',3,41,40,24);
  Context.TerritoryArmies[41]:=1;
  Context.TerritoryArmies[40]:=25;
  Run('Fortification',3,40,39,24);
  Context.Buffers[490]:=13;
  Run('Fortification',3,40,39,24);
  Reset;
  Run('Placement',1,39,0,0);
  Context.TerritoryOwner[39]:=2;
  Run('Placement',1,40,0,0);
  Reset;
  Context.Buffers[491]:=2; Context.Buffers[490]:=20;
  Run('Placement',1,39,0,0);
  if Context.Buffers[2]<>0 then raise Exception.Create('Counted opponent turns');
  for T:=1 to MAXTERRITORIES do Context.TerritoryOwner[T]:=1;
  Run('Attack',2,0,0,0);
  Run('Fortification',3,0,0,0);
  Writeln('PASS: Tortoise twelve personal turns, wall ownership, breach recovery, pressure balancing, threshold, migration and owned-path consolidation.');
end;
end.
