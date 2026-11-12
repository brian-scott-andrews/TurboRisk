unit Walker3Tests;
{$MODE Delphi}
interface
procedure RunWalker3Tests;
implementation
uses Classes, SysUtils, Variants, Globals, Territ;

procedure RunWalker3Tests;
var
  Source: TStringList;
  Context: TTRCompContext;
  Params: array of Variant;
  Name, Diagnostics, Value: string;
  I,P,FT,TT: integer;
  Card: TCard;
begin
  SetupTerritories;
  Name:='players'+PathDelim+'Walker3.trp';
  Source:=TStringList.Create;
  try
    Source.LoadFromFile(Name);
    if not ValidateTRPSource(Name,Source.Text,Diagnostics) then
      raise Exception.Create(Diagnostics);
    Context.CurrentPlayer:=1;
    Context.Conquest:=False;
    Context.CardTradeByCombination:=False;
    Context.Message:='';
    for I:=1 to MAXTERRITORIES do begin
      Context.TerritoryOwner[I]:=3; Context.TerritoryArmies[I]:=100;
    end;
    for P:=1 to MAXPLAYERS do begin
      Context.PlayerActive[P]:=P<=3;
      Context.PlayerName[P]:='Player '+IntToStr(P);
      Context.PlayerProgram[P]:='simple.trp';
      Context.PlayerNewArmies[P]:=0;
      for Card:=Low(TCard) to High(TCard) do Context.PlayerCards[P,Card]:=0;
    end;
    for I:=1 to MAXBUFFER do Context.Buffers[I]:=0;
    Context.PlayerProgram[1]:='Walker3.trp';
    Context.PlayerProgram[2]:='Walker3.trp';
    Context.TerritoryOwner[1]:=1; Context.TerritoryArmies[1]:=10;
    Context.TerritoryOwner[2]:=2; Context.TerritoryArmies[2]:=1;
    SetLength(Params,2); Params[0]:=0; Params[1]:=0;
    if not RunTRPRoutine(Name,Source.Text,'Attack',Context,Params,Value,Diagnostics) then
      raise Exception.Create(Diagnostics);
    if Integer(Params[0])<>0 then
      raise Exception.Create('Walker3 attacked its ally while outsiders survived');
    Context.PlayerProgram[2]:='Walker2.trp';
    Params[0]:=0; Params[1]:=0;
    if not RunTRPRoutine(Name,Source.Text,'Attack',Context,Params,Value,Diagnostics) then
      raise Exception.Create(Diagnostics);
    FT:=Params[0]; TT:=Params[1];
    if (FT<>1) or (TT<>2) then
      raise Exception.Create('Walker3 incorrectly allied with Walker2');
    Context.TerritoryArmies[1]:=3;
    Context.TerritoryArmies[2]:=1;
    Params[0]:=0; Params[1]:=0;
    if not RunTRPRoutine(Name,Source.Text,'Attack',Context,Params,Value,Diagnostics) then
      raise Exception.Create(Diagnostics);
    if Integer(Params[0])<>0 then
      raise Exception.Create('Walker3 ignored its available-army threshold');
    WriteLn('PASS: Walker3 compiles, protects identical allies, treats Walker2 as outsider, and enforces attack threshold.');
  finally Source.Free; end;
end;
end.
