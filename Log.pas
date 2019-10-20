unit Log;

{$MODE Delphi}

interface

uses
  LCLIntf, LCLType, LMessages, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  StdCtrls;

type
  TfLog = class(TForm)
    txtLog: TMemo;
    procedure FormShow(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
  private
    { Private declarations }
  public
  end;

var
  fLog: TfLog;

procedure ScriviLog(sMsg: string);

implementation

{$R *.lfm}

uses Globals, Main;

procedure TfLog.FormShow(Sender: TObject);
begin
  fMain.mnuVieLog.Checked := true;
  fMain.cmdLog.Down := true;
end;

procedure TfLog.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  fMain.mnuVieLog.Checked := false;
  fMain.cmdLog.Down := false;
end;

procedure ScriviLog(sMsg: string);
begin
  with fLog.txtLog do begin
    // if Lines.Count>=MAXLOGLINES then Lines.Delete(0);
    Lines.Add(IntToStr(iTurnCounter) + ' ' + arPlayer[iTurn]
        .Name + ' - ' + sMsg);
  end;
end;

end.
