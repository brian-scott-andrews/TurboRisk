program TRMap;

{$MODE Delphi}

uses
  Interfaces, Forms,
  TRMapForm in 'TRMapForm.pas' {fTRMap};

begin
  Application.Initialize;
  Application.CreateForm(TfTRMap, fTRMap);
  Application.Run;
end.
