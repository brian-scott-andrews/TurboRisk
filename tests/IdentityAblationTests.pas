unit IdentityAblationTests;
{$MODE Delphi}
interface
procedure RunIdentityAblationTests;
implementation
uses Classes, SysUtils, Variants, Globals;
procedure RunIdentityAblationTests;
const Bots: array[0..9] of string =
  ('borg','Walker2','Walker3','digger','defender','hunter','pitbull','slave','frank','frank+');
var Source: TStringList; Bot,Text,Diagnostics,Value: string;
  Context: TTRCompContext; Params: array of Variant; P: Integer;
begin
  Source:=TStringList.Create;
  try
    for Bot in Bots do begin
      Source.LoadFromFile('players'+PathDelim+Bot+'.trp');
      Text:=StringReplace(Source.Text,'PProgram(', 'StudyProgram(', [rfReplaceAll,rfIgnoreCase]);
      Text:='function StudyProgram(P: integer): string;'+LineEnding+
        'begin Result:=PProgram(P); if (P<>PMe) and (Result=PProgram(PMe)) then '+
        'Result:=''__study_other_copy__''; end;'+LineEnding+Text;
      if not ValidateTRPSource(Bot,Text,Diagnostics) then
        raise Exception.Create('Ablation '+Bot+': '+Diagnostics);
      Context.CurrentPlayer:=1;
      Context.PlayerProgram[1]:=Bot+'.trp';
      Context.PlayerProgram[2]:=Bot+'.trp';
      Context.PlayerProgram[3]:='vexer.trp';
      SetLength(Params,1);
      // Call the helper directly; no bot state or random decisions are involved.
      for P:=1 to 3 do begin
        Params[0]:=P;
        if not RunTRPRoutine(Bot,Text,'StudyProgram',Context,Params,Value,Diagnostics) then
          raise Exception.Create('Ablation identity probe: '+Diagnostics);
        if ((P=1) and (Value<>LowerCase(Bot)+'.trp')) or
          ((P=2) and (Value<>'__study_other_copy__')) or
          ((P=3) and (Value<>'vexer.trp')) then
          raise Exception.Create('Ablation changed self/outsider identity');
      end;
    end;
    WriteLn('PASS: ten identity-ablation variants compile; only other copies are masked.');
  finally Source.Free; end;
end;
end.
