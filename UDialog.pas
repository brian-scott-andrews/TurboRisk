unit UDialog;

{$MODE Delphi}

interface

uses
  LCLIntf, LCLType, LMessages, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls;

type
  TfUDialog = class(TForm)
    lblMsg: TLabel;
    cmdB1: TButton;
    cmdB2: TButton;
    cmdB3: TButton;
    cmdB4: TButton;
    cmdB5: TButton;
    function SplitStr(var theString: string; delimiter: string): string;
    procedure cmdBClick(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure FormKeyPress(Sender: TObject; var Key: Char);
  private
    { Private declarations }
  public
    sMsg, // message to display
    sButtons: string; // buttons to display
    iDlgResult: integer; // number of button pressed, 0 if form closed with X button
  end;

var
  fUDialog: TfUDialog;

implementation

{$R *.lfm}

{uses StdPas;}

function TfuDialog.SplitStr(var theString: string; delimiter: string): string;
var
  i: integer;
begin
  Result:= '';
  if theString <> '' then
  begin
    i:= Pos(delimiter, theString);
    if i > 0 then
    begin
       Result:= Copy(theString, 1, i-1);
       theString:= Copy(theString, i+Length(delimiter), maxLongInt);
    end
    else
    begin
       Result:= theString;
       theString:= '';
    end;
  end;
end;



procedure TfUDialog.FormShow(Sender: TObject);
var
  sBtn: string;
begin
  lblMsg.Caption := sMsg;
  sBtn := SplitStr(sButtons,';');
  cmdB1.Visible := sBtn>'';
  cmdB1.Caption := sBtn;
  sBtn := SplitStr(sButtons,';');
  cmdB2.Visible := sBtn>'';
  cmdB2.Caption := sBtn;
  sBtn := SplitStr(sButtons,';');
  cmdB3.Visible := sBtn>'';
  cmdB3.Caption := sBtn;
  sBtn := SplitStr(sButtons,';');
  cmdB4.Visible := sBtn>'';
  cmdB4.Caption := sBtn;
  sBtn := SplitStr(sButtons,';');
  cmdB5.Visible := sBtn>'';
  cmdB5.Caption := sBtn;
  iDlgResult := 0;
end;

procedure TfUDialog.FormKeyPress(Sender: TObject; var Key: Char);
begin
  if Key=#27 then begin
    iDlgResult := 0;
    Close;
  end;
end;

procedure TfUDialog.cmdBClick(Sender: TObject);
begin
  iDlgResult := (Sender as Tcontrol).Tag;
  Close;
end;

end.
