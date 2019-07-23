unit TRPError;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, Buttons;

type
  TfTRPError = class(TForm)
    txtMsg: TMemo;
    cmdContinue: TBitBtn;
    cmdDump: TBitBtn;
    cmdHelp: TBitBtn;
    cmdQuit: TBitBtn;
    procedure cmdHelpClick(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  fTRPError: TfTRPError;

implementation

{$R *.dfm}

procedure TfTRPError.cmdHelpClick(Sender: TObject);
begin
  Application.HelpSystem.ShowContextHelp(fTRPError.HelpContext,Application.HelpFile);
end;

end.
