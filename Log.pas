unit Log;

{$MODE Delphi}

interface

uses
  LCLIntf, LCLType, LMessages, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  StdCtrls;

type
  TfLog = class(TForm)
    txtLog: TMemo;
    cmdActionLog: TButton;
    procedure cmdActionLogClick(Sender: TObject);
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

uses Globals, Main, ActionHistory;

procedure TfLog.cmdActionLogClick(Sender: TObject);
var
  SaveDialog: TSaveDialog;
begin
  if ActionLogFileName <> '' then begin
    StopActionLog;
    cmdActionLog.Caption := 'Log actions...';
    Exit;
  end;
  SaveDialog := TSaveDialog.Create(Self);
  try
    SaveDialog.Title := 'Log public game actions (appends to existing action logs)';
    SaveDialog.DefaultExt := 'jsonl';
    SaveDialog.Filter := 'TurboRisk action log (*.jsonl)|*.jsonl';
    SaveDialog.Options := [ofPathMustExist, ofEnableSizing];
    if SaveDialog.Execute then begin
      try
        StartActionLog(SaveDialog.FileName);
        cmdActionLog.Caption := 'Stop action log';
      except
        on E: Exception do
          MessageDlg('Cannot start action log: ' + E.Message, mtError, [mbOK], 0);
      end;
    end;
  finally
    SaveDialog.Free;
  end;
end;

procedure TfLog.FormShow(Sender: TObject);
begin
  if ActionLogFileName = '' then cmdActionLog.Caption := 'Log actions...'
  else cmdActionLog.Caption := 'Stop action log';
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
