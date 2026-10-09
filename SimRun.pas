unit SimRun;

{$MODE Delphi}

interface

uses
  LCLIntf, LCLType, LMessages, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ExtCtrls, ComCtrls, Buttons;

type
  TfSimRun = class(TForm)
    prbGames: TProgressBar;
    panGameNbr: TPanel;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    cmdStop: TBitBtn;
    Label4: TLabel;
    panSimTime: TPanel;
    txtSimLog: TMemo;
    panTurn: TPanel;
    panGameTime: TPanel;
    Label5: TLabel;
    cmdAbortGame: TBitBtn;
    procedure cmdStopClick(Sender: TObject);
    procedure cmdAbortGameClick(Sender: TObject);
  private
    { Private declarations }
  public
    procedure UpdateSimStats;
    procedure SimLog(const sMsg: string);
  end;

var
  fSimRun: TfSimRun;

implementation

{$R *.lfm}

uses DateUtils, Globals;

procedure TfSimRun.cmdAbortGameClick(Sender: TObject);
begin
  uSimStatus := ssAbort; // game status = aborted
  bStopASAP := true; // abort current game
end;

procedure TfSimRun.cmdStopClick(Sender: TObject);
begin
  uSimStatus := ssAbort; // game status = aborted
  bSimAbort := true; // abort simulation
  bStopASAP := true; // abort current game
end;

procedure TfSimRun.SimLog(const sMsg: string);
var
  sLogEntry: string;
begin
  sLogEntry := FormatDateTime('hh:nn:ss', Now) + ' ' + sMsg;
  if bTRSimCLI then
    WriteLn(sLogEntry)
  else
    txtSimLog.Lines.Add(sLogEntry);
end;

procedure TfSimRun.UpdateSimStats;
begin
  panGameNbr.Caption := IntToStr(iSimCurr) + ' / ' + IntToStr(iSimGames);
  prbGames.Position := iSimCompl;
  panTurn.Caption := IntToStr(iTurnCounter);
  panGameTime.Caption := FormatDateTime('hh:nn:ss',Now-dtSimGameTime);
  panSimTime.Caption := FormatDateTime('hh:nn:ss',Now-dtSimStartTime);
  if not bTRSimCLI then
    Application.ProcessMessages;
end;

end.
