program TRCompApp;

{$MODE Delphi}

uses
  Forms, Interfaces,
  TRCompForm in 'TRCompForm.pas' {fTRComp},
  Globals in 'Globals.pas';

begin
  Application.Initialize;
  Application.CreateForm(TfTRComp, fTRComp);
  Application.Run;
end.
