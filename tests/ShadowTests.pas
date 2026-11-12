unit ShadowTests;
{$MODE Delphi}
interface
procedure RunShadowTests;
procedure RunShadow2Tests;
implementation
uses Classes, SysUtils, Variants, Globals, Territ, ActionHistory;

procedure ResetContext(var Context: TTRCompContext);
var T,P: Integer;
  Card: TCard;
begin
  Context.CurrentPlayer:=1;
  Context.Conquest:=False;
  Context.CardTradeByCombination:=False;
  Context.Message:='';
  for P:=1 to MAXPLAYERS do begin
    Context.PlayerActive[P]:=P<=3;
    Context.PlayerName[P]:=IntToStr(P);
    Context.PlayerProgram[P]:='simple.trp';
    Context.PlayerNewArmies[P]:=0;
    for Card:=Low(TCard) to High(TCard) do Context.PlayerCards[P,Card]:=0;
  end;
  Context.PlayerProgram[1]:='shadow.trp';
  Context.PlayerProgram[2]:='vexer.trp';
  for T:=1 to MAXBUFFER do Context.Buffers[T]:=0;
  for T:=1 to MAXTERRITORIES do begin
    Context.TerritoryOwner[T]:=3;
    Context.TerritoryArmies[T]:=1;
  end;
  Context.TerritoryOwner[1]:=1;
  Context.TerritoryArmies[1]:=20;
  Context.TerritoryOwner[2]:=2;
end;

function LoadSource(const Name: string): string;
var Lines: TStringList;
  Diagnostics: string;
begin
  Lines:=TStringList.Create;
  try
    Lines.LoadFromFile(Name);
    Result:=Lines.Text;
    if not ValidateTRPSource(Name,Result,Diagnostics) then
      raise Exception.Create(Name+': '+Diagnostics);
  finally Lines.Free; end;
end;

procedure CompareRoutines(const Name,Script,Reference: string;
  const Saved: TTRCompContext; FirstRoutine,LastRoutine: Integer);
var Context,Expected: TTRCompContext;
  Params,ExpectedParams: array of Variant;
  R,J,Count: Integer;
  Routine,Value,Diagnostics: string;
begin
  for R:=FirstRoutine to LastRoutine do begin
    case R of
      0: begin Routine:='Assignment'; Count:=1 end;
      1: begin Routine:='Placement'; Count:=1 end;
      2: begin Routine:='Attack'; Count:=2 end;
      3: begin Routine:='Occupation'; Count:=3 end;
      4: begin Routine:='Fortification'; Count:=3 end;
    end;
    Context:=Saved;
    SetLength(Params,Count);
    for J:=0 to Count-1 do Params[J]:=0;
    if R=3 then begin Params[0]:=4; Params[1]:=5 end;
    if not RunTRPRoutine(Name,Reference,Routine,Context,Params,Value,Diagnostics) then
      raise Exception.Create('Reference '+Routine+': '+Diagnostics);
    Expected:=Context;
    ExpectedParams:=Copy(Params,0,Length(Params));
    Context:=Saved;
    for J:=0 to Count-1 do Params[J]:=0;
    if R=3 then begin Params[0]:=4; Params[1]:=5 end;
    if not RunTRPRoutine(Name,Script,Routine,Context,Params,Value,Diagnostics) then
      raise Exception.Create(Name+' '+Routine+': '+Diagnostics);
    for J:=0 to Count-1 do
      if Params[J]<>ExpectedParams[J] then
        raise Exception.CreateFmt('%s %s parameter %d differs', [Name,Routine,J]);
    for J:=1 to MAXBUFFER do
      if Context.Buffers[J]<>Expected.Buffers[J] then
        raise Exception.CreateFmt('%s %s buffer %d differs', [Name,Routine,J]);
  end;
end;

procedure RunShadowTests;
var Context: TTRCompContext;
  Params: array of Variant;
  Name,Script,Mock,Reference,Value,Diagnostics: string;
  T,P,Board: Integer;

  procedure Run(const Routine,Text: string);
  begin
    if not RunTRPRoutine(Name,Text,Routine,Context,Params,Value,Diagnostics) then
      raise Exception.Create('Original Shadow '+Routine+': '+Diagnostics);
  end;

  procedure Attack(From,Destination: Integer);
  begin
    SetLength(Params,2); Params[0]:=0; Params[1]:=0;
    Run('Attack',Script);
    if (Integer(Params[0])<>From) or (Integer(Params[1])<>Destination) then
      raise Exception.CreateFmt('Original Shadow expected %d -> %d, got %d -> %d',
        [From,Destination,Integer(Params[0]),Integer(Params[1])]);
  end;

begin
  SetupTerritories;
  Name:='players'+PathDelim+'shadow.trp';
  Script:=LoadSource(Name);
  ResetContext(Context);
  Context.TerritoryArmies[4]:=1000; Context.TerritoryArmies[37]:=1000;
  Attack(1,2);
  Context.Conquest:=True;
  Attack(0,0);
  Context.Buffers[102]:=1;
  Attack(1,2);
  Context.TerritoryArmies[1]:=9;
  Attack(0,0);
  Context.TerritoryArmies[1]:=30;
  Context.TerritoryOwner[42]:=2;
  Attack(0,0);
  ResetContext(Context);
  Context.Conquest:=True;
  Context.PlayerProgram[2]:='not-vexer.trp';
  Context.Buffers[102]:=1;
  Attack(0,0);
  Context.PlayerProgram[2]:='VeXeR.TrP';
  Attack(1,2);
  ResetContext(Context);
  Context.TerritoryArmies[2]:=3;
  Context.TerritoryArmies[37]:=1000;
  Attack(1,4);
  Mock:=StringReplace(Script,'HCount','TestCount',[rfReplaceAll]);
  Mock:=StringReplace(Mock,'HGet','TestGet',[rfReplaceAll]);
  Mock:='function TestCount: integer; begin Result:=trunc(UBufferGet(480)); end;'+
    LineEnding+'function TestGet(I,F: integer): integer; begin Result:=0;'+
    ' if F=AF_KIND then Result:=trunc(UBufferGet(482));'+
    ' if F=AF_PLAYER then Result:=trunc(UBufferGet(481)); end;'+LineEnding+Mock;
  ResetContext(Context);
  Context.Buffers[480]:=1; Context.Buffers[481]:=2;
  Context.Buffers[482]:=AK_ELIMINATION;
  SetLength(Params,1); Params[0]:=0;
  Run('Placement',Mock);
  if (Context.Buffers[102]<>1) or (Context.Buffers[500]<>1) then
    raise Exception.Create('Original Shadow did not latch Vexer kill');
  Run('Placement',Mock);
  if Context.Buffers[500]<>1 then
    raise Exception.Create('Original Shadow history cursor changed');
  ResetContext(Context);
  Context.Buffers[480]:=1; Context.Buffers[481]:=3;
  Context.Buffers[482]:=AK_ELIMINATION;
  Run('Placement',Mock);
  if Context.Buffers[102]<>0 then
    raise Exception.Create('Original Shadow credited outsider kill');
  ResetContext(Context);
  Context.TerritoryOwner[2]:=1; Context.TerritoryOwner[3]:=2;
  SetLength(Params,3); Params[0]:=0; Params[1]:=0; Params[2]:=0;
  Run('Fortification',Script);
  if (Integer(Params[0])<>1) or (Integer(Params[1])<>2) or
    (Integer(Params[2])<>19) then
    raise Exception.Create('Original Shadow did not follow Vexer');
  Reference:=LoadSource('players'+PathDelim+'doomstack.trp');
  for Board:=0 to 47 do begin
    ResetContext(Context);
    Context.PlayerActive[3]:=False;
    Context.Conquest:=Board mod 2=1;
    Context.CardTradeByCombination:=Board mod 4>=2;
    Context.PlayerNewArmies[1]:=Board mod 12;
    for T:=1 to MAXTERRITORIES do begin
      Context.TerritoryOwner[T]:=1+Ord((T*7+Board) mod 5<2);
      Context.TerritoryArmies[T]:=1+(T*13+Board*17) mod 40;
      if (Board mod 6=0) and (T>39) then Context.TerritoryOwner[T]:=0;
    end;
    Context.Buffers[1]:=2; Context.Buffers[2]:=4;
    CompareRoutines(Name,Script,Reference,Context,0,4);
  end;
  Reference:=LoadSource('players'+PathDelim+'actuary.trp');
  for Board:=0 to 31 do begin
    ResetContext(Context);
    Context.Conquest:=Board mod 2=1;
    Context.CardTradeByCombination:=Board mod 4>=2;
    Context.PlayerNewArmies[1]:=Board mod 12;
    Context.PlayerProgram[4]:='VeXeR.TrP';
    for P:=4 to MAXPLAYERS do Context.PlayerActive[P]:=P<=4+Board mod 7;
    for T:=1 to MAXTERRITORIES do begin
      Context.TerritoryOwner[T]:=1;
      if (T*7+Board) mod 5<2 then Context.TerritoryOwner[T]:=3;
      Context.TerritoryArmies[T]:=1+(T*13+Board*17) mod 40;
    end;
    CompareRoutines(Name,Script,Reference,Context,1,4);
  end;
  ResetContext(Context);
  SetLength(Params,0);
  Run('AfterVexer',Script);
  if Value<>'False' then raise Exception.Create('Original Shadow switched early');
  Context.PlayerProgram[4]:='vexer.trp'; Context.PlayerActive[4]:=True;
  Context.TerritoryOwner[2]:=4;
  Run('AfterVexer',Script);
  if Value<>'False' then raise Exception.Create('Original Shadow ignored live Vexer');
  Context.TerritoryOwner[2]:=3;
  Run('AfterVexer',Script);
  if Value<>'True' then raise Exception.Create('Original Shadow did not hand off');
  WriteLn('PASS: original Shadow trigger, route budget, identity, movement,',
    ' 240 Doomstack duel and 128 Actuary post-Vexer routine comparisons.');
end;

procedure RunShadow2Tests;
var Context: TTRCompContext;
  Params: array of Variant;
  Name,Script,Reference,Value,Diagnostics: string;
  T,P,Board,Mode,I: Integer;
  SavedTradeValues: array [1..8] of Integer;
  SavedTrades: array [1..MAXPLAYERS] of Integer;
  Probability: Double;

  procedure Run(const Routine: string);
  begin
    if not RunTRPRoutine(Name,Script,Routine,Context,Params,Value,Diagnostics) then
      raise Exception.Create('New Shadow2 '+Routine+': '+Diagnostics);
  end;

  procedure TargetScore(EV,Probability,Expected: Double; Target: Integer);
  begin
    SetLength(Params,3); Params[0]:=EV; Params[1]:=Probability; Params[2]:=Target;
    Run('TargetValue');
    if Abs(StrToFloat(Value)-Expected)>0.000001 then
      raise Exception.Create('Shadow2 preference exceeded its profitability/odds gate');
  end;

  procedure Kill(Target: Integer);
  begin
    SetLength(Params,4);
    Params[0]:=0; Params[1]:=0; Params[2]:=0; Params[3]:=0;
    Run('BestKill');
    if (StrToFloat(Value)<=0) or (Integer(Params[3])<>Target) or
      (Integer(Params[1])<>1) or (Integer(Params[2])<>2) then
      raise Exception.Create('Shadow2 did not plan profitable elimination before trigger');
    SetLength(Params,2); Params[0]:=0; Params[1]:=0;
    Run('Attack');
    if (Integer(Params[0])<>1) or (Integer(Params[1])<>2) then
      raise Exception.Create('Shadow2 did not execute profitable elimination before trigger');
  end;

  procedure Payback(Mine,Captured: Integer; Expected: Double);
  begin
    ResetContext(Context);
    Context.PlayerCards[1,caInf]:=Mine;
    Context.PlayerCards[2,caInf]:=Captured;
    SetLength(Params,1); Params[0]:=2;
    Run('KillValue');
    if Abs(StrToFloat(Value)-Expected)>0.000001 then
      raise Exception.CreateFmt('Shadow2 payback for %d + %d cards: %s, expected %.2f',
        [Mine,Captured,Value,Expected]);
  end;

  procedure Route(Start,Target,Extra,First,Garrisons: Integer; Loss: Double;
    Expected: Boolean);
  begin
    SetLength(Params,7);
    Params[0]:=Start; Params[1]:=Target; Params[2]:=Extra;
    Params[3]:=0; Params[4]:=0.0; Params[5]:=0.0; Params[6]:=0;
    Run('PlanKill');
    if (Value='True')<>Expected then
      raise Exception.Create('Shadow2 full-route feasibility mismatch');
    if Expected then begin
      if (Integer(Params[3])<>First) or (Integer(Params[6])<>Garrisons) or
        (Abs(Double(Params[5])-Loss)>0.000001) then
        raise Exception.Create('Shadow2 route omitted or double-counted enemies/garrisons');
      if (Double(Params[4])<=0.0) or (Double(Params[4])>1.0) then
        raise Exception.Create('Shadow2 route probability out of range');
    end;
  end;

  procedure NoKill;
  var J: Integer;
  begin
    SetLength(Params,4);
    for J:=0 to 3 do Params[J]:=0;
    Run('BestKill');
    if (StrToFloat(Value)<>0.0) or (Integer(Params[1])<>0) or
      (Integer(Params[2])<>0) or (Integer(Params[3])<>0) then
      raise Exception.Create('Shadow2 accepted an unprofitable or unfunded kill');
  end;

begin
  SetupTerritories;
  Name:='players'+PathDelim+'shadow2.trp';
  Script:=LoadSource(Name);
  Reference:=LoadSource('players'+PathDelim+'actuary.trp');
  for I:=1 to 8 do begin
    SavedTradeValues[I]:=RTradeValue[I];
    RTradeValue[I]:=10+(I-1)*5;
  end;
  for P:=1 to MAXPLAYERS do begin
    SavedTrades[P]:=arPlayer[P].NScambi;
    arPlayer[P].NScambi:=0;
  end;
  try
  Payback(0,0,0);
  Payback(0,3,0);
  Payback(0,4,0);
  Payback(0,5,10);
  Payback(2,3,10);
  Payback(0,8,20);
  Payback(3,2,0);
  Payback(3,5,10);
  arPlayer[2].NScambi:=7;
  Payback(2,3,10);
  arPlayer[1].NScambi:=1;
  Payback(2,3,15);
  arPlayer[1].NScambi:=0;
  Payback(2,3,10);
  SetLength(Params,5);
  Params[0]:=2; Params[1]:=0.75; Params[2]:=4.0;
  Params[3]:=20; Params[4]:=1;
  Run('KillScore');
  if Abs(StrToFloat(Value)+1.25)>0.000001 then
    raise Exception.Create('Shadow2 did not charge full attrition/failure/garrison costs');
  Params[1]:=1.0; Params[2]:=10.0; Params[4]:=0;
  Run('KillScore');
  if Abs(StrToFloat(Value))>0.000001 then
    raise Exception.Create('Shadow2 break-even kill retained arbitrary bonuses');

  ResetContext(Context);
  for T:=1 to MAXTERRITORIES do Context.TerritoryOwner[T]:=1;
  Context.TerritoryOwner[2]:=2; Context.TerritoryOwner[3]:=2;
  Context.TerritoryOwner[42]:=3;
  Route(1,2,0,2,1,1.1,True);
  Context.TerritoryOwner[2]:=1; Context.TerritoryArmies[1]:=1;
  Context.TerritoryArmies[2]:=18;
  Route(2,2,0,3,0,0.55,True);
  Context.TerritoryArmies[2]:=4;
  Route(2,2,0,0,0,0,False);
  Route(2,2,3,3,0,0.55,True);
  Context.PlayerCards[1,caInf]:=2; Context.PlayerCards[2,caInf]:=3;
  NoKill;
  Context.PlayerCards[2,caInf]:=30;
  NoKill;
  Context.PlayerCards[2,caInf]:=3; Context.PlayerNewArmies[1]:=3;
  SetLength(Params,4);
  Params[0]:=3; Params[1]:=0; Params[2]:=0; Params[3]:=0;
  Run('BestKill');
  if (StrToFloat(Value)<=0.0) or (Integer(Params[1])<>2) then
    raise Exception.Create('Shadow2 ignored actual pending reinforcements');
  SetLength(Params,1); Params[0]:=0;
  Run('Placement');
  if Integer(Params[0])<>2 then
    raise Exception.Create('Shadow2 did not prepare the affordable kill stack');

  ResetContext(Context);
  for T:=1 to MAXTERRITORIES do Context.TerritoryOwner[T]:=1;
  Context.TerritoryOwner[4]:=3; Context.TerritoryArmies[4]:=8;
  Context.TerritoryOwner[5]:=2; Context.TerritoryOwner[42]:=3;
  Context.TerritoryArmies[1]:=40;
  Context.PlayerCards[1,caInf]:=2; Context.PlayerCards[2,caInf]:=3;
  Route(1,2,0,4,1,7.43,True);
  SetLength(Params,4); for I:=0 to 3 do Params[I]:=0;
  Run('BestKill');
  if (StrToFloat(Value)<=0.0) or (Integer(Params[2])<>4) then
    raise Exception.Create('Shadow2 rejected a profitable route through another opponent');
  Context.TerritoryArmies[4]:=20;
  Route(1,2,0,4,1,17.75,True);
  NoKill;

  ResetContext(Context);
  for T:=1 to MAXTERRITORIES do Context.TerritoryOwner[T]:=1;
  Context.TerritoryOwner[3]:=2; Context.TerritoryOwner[42]:=3;
  Route(1,2,0,0,0,0,False);
  Context.TerritoryOwner[2]:=3;
  Context.TerritoryOwner[37]:=2; Context.TerritoryArmies[37]:=100;
  Context.TerritoryArmies[1]:=1000;
  Route(1,2,0,0,0,0,False);

  ResetContext(Context);
  Context.TerritoryArmies[1]:=40; Context.TerritoryArmies[2]:=5;
  Context.TerritoryArmies[4]:=1000; Context.TerritoryArmies[37]:=1000;
  Context.Conquest:=True; Context.PlayerCards[2,caInf]:=3;
  SetLength(Params,2); Params[0]:=0; Params[1]:=0;
  Run('Attack');
  if (Integer(Params[0])<>0) or (Integer(Params[1])<>0) then
    raise Exception.Create('Shadow2 ordinary attack retained the old elimination bonus');
  Context.PlayerCards[1,caInf]:=2;
  Kill(2);
  Context.PlayerProgram[2]:='simple.trp';
  Kill(2);
  Context.TerritoryArmies[1]:=4;
  NoKill;
  SetLength(Params,2); Params[0]:=0; Params[1]:=0;
  Run('Attack');
  if (Integer(Params[0])<>0) or (Integer(Params[1])<>0) then
    raise Exception.Create('Shadow2 spent captured-card rewards before completing the kill');

  ResetContext(Context);
  Context.TerritoryArmies[1]:=24; Context.TerritoryArmies[2]:=20;
  Context.PlayerCards[1,caInf]:=2; Context.PlayerCards[2,caInf]:=3;
  RTradeValue[1]:=1000;
  Route(1,2,0,2,0,17.2,True);
  Probability:=Double(Params[4]);
  if Probability>=0.6 then
    raise Exception.Create('Shadow2 odds-gate fixture unexpectedly exceeds 60%');
  SetLength(Params,5);
  Params[0]:=2; Params[1]:=Probability; Params[2]:=17.2;
  Params[3]:=23; Params[4]:=0;
  Run('KillScore');
  if StrToFloat(Value)<=0.0 then
    raise Exception.Create('Shadow2 odds-gate fixture is not economically profitable');
  NoKill;
  RTradeValue[1]:=10;

  ResetContext(Context);
  Context.Conquest:=True;
  for T:=1 to MAXTERRITORIES do Context.TerritoryArmies[T]:=1000;
  Context.TerritoryArmies[1]:=20; Context.TerritoryArmies[2]:=1;
  Context.TerritoryOwner[10]:=1; Context.TerritoryArmies[10]:=40;
  Context.TerritoryOwner[20]:=1; Context.TerritoryArmies[20]:=50;
  Context.TerritoryOwner[30]:=1; Context.TerritoryArmies[30]:=60;
  Context.PlayerCards[1,caInf]:=2; Context.PlayerCards[2,caInf]:=3;
  NoKill;
  SetLength(Params,2); Params[0]:=0; Params[1]:=0;
  Run('Attack');
  if (Integer(Params[0])<>1) or (Integer(Params[1])<>2) then
    raise Exception.Create('Shadow2 missed a profitable single-territory kill outside its top three fronts');

  ResetContext(Context);
  Context.PlayerActive[3]:=False;
  for T:=1 to MAXTERRITORIES do Context.TerritoryOwner[T]:=1;
  Context.TerritoryOwner[2]:=2; Context.TerritoryArmies[1]:=3;
  SetLength(Params,1); Params[0]:=2;
  Run('KillValue');
  if StrToFloat(Value)<>1000.0 then
    raise Exception.Create('Shadow2 required card payback to win the game');
  Kill(2);
  Context.TerritoryArmies[1]:=5000; Context.TerritoryArmies[2]:=2000;
  Kill(2);

  ResetContext(Context);
  TargetScore(10,0.75,10.5,2);
  TargetScore(10,0.749,10,2);
  TargetScore(-2,1,-2,2);
  TargetScore(0,1,0,2);
  TargetScore(10,1,10,3);
  TargetScore(10,1,10,0);
  Context.PlayerProgram[2]:='not-vexer.trp';
  TargetScore(10,1,10,2);
  Context.PlayerProgram[2]:='VeXeR.TrP';
  TargetScore(10,1,10.5,2);
  for P:=2 to 3 do begin
    ResetContext(Context);
    for T:=1 to MAXTERRITORIES do Context.TerritoryOwner[T]:=3;
    Context.TerritoryOwner[1]:=1; Context.TerritoryOwner[2]:=P;
    if P=3 then Context.TerritoryOwner[10]:=2;
    Context.TerritoryArmies[1]:=40;
    Context.PlayerCards[1,caInf]:=2;
    Context.PlayerCards[P,caInf]:=3;
    if P=3 then begin
      for T:=1 to MAXTERRITORIES do
        if (Context.TerritoryOwner[T]=3) and (T<>2) then Context.TerritoryOwner[T]:=2;
    end;
    Kill(P);
  end;
  ResetContext(Context);
  Context.TerritoryOwner[2]:=3;
  Context.TerritoryOwner[10]:=1; Context.TerritoryArmies[10]:=20;
  Context.TerritoryOwner[11]:=2;
  SetLength(Params,1); Params[0]:=0;
  Run('StagingTerritory');
  if StrToInt(Value)<>10 then raise Exception.Create('Shadow2 staging ignored proximity');
  Context.TerritoryArmies[1]:=30;
  Run('StagingTerritory');
  if StrToInt(Value)<>1 then raise Exception.Create('Shadow2 sacrificed strong stack for proximity');
  Context.TerritoryArmies[1]:=20;
  SetLength(Params,0);
  Run('StrongestFront');
  if StrToInt(Value)<>10 then raise Exception.Create('Shadow2 strongest-front tie ignored proximity');
  Context.TerritoryOwner[11]:=3; Context.TerritoryOwner[2]:=2;
  Run('StrongestFront');
  if StrToInt(Value)<>1 then raise Exception.Create('Shadow2 reused stale Vexer distance');
  for Mode:=0 to 2 do
    for Board:=0 to 23 do begin
      ResetContext(Context);
      Context.Conquest:=Board mod 2=1;
      Context.CardTradeByCombination:=Board mod 4>=2;
      Context.PlayerNewArmies[1]:=Board mod 12;
      if Mode=0 then Context.PlayerProgram[2]:='simple.trp';
      if Mode=1 then begin
        Context.PlayerActive[3]:=False;
        Context.PlayerProgram[2]:='simple.trp';
      end;
      for T:=1 to MAXTERRITORIES do begin
        Context.TerritoryOwner[T]:=1+(T*7+Board) mod 3;
        if Mode=1 then Context.TerritoryOwner[T]:=1+(T*7+Board) mod 2;
        if (Mode=2) and (Context.TerritoryOwner[T]=2) then
          Context.TerritoryOwner[T]:=3;
        Context.TerritoryArmies[T]:=1+(T*13+Board*17) mod 40;
      end;
      CompareRoutines(Name,Script,Reference,Context,0,4);
    end;
  WriteLn('PASS: Shadow2 progressive marginal card payback, full-route attrition,',
    ' failure/garrison costs, reserves, replanning, final-opponent wins, bounded',
    ' Vexer preference and 360 Actuary comparisons without eligible eliminations.');
  finally
    for I:=1 to 8 do RTradeValue[I]:=SavedTradeValues[I];
    for P:=1 to MAXPLAYERS do arPlayer[P].NScambi:=SavedTrades[P];
  end;
end;
end.
