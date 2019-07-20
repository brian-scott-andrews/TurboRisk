unit Pref;

{$MODE Delphi}

interface

uses
  LCLIntf, LCLType, LMessages, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, ComCtrls, StdCtrls, Buttons, ExtCtrls, CheckLst;

type
  TfPref = class(TForm)
    tabPref: TPageControl;
    tbsToolbar: TTabSheet;
    cmdOK: TBitBtn;
    cmdAnnulla: TBitBtn;
    cmdResetRules: TBitBtn;
    tbsMap: TTabSheet;
    chkMapHoover: TCheckBox;
    chkMapSelected: TCheckBox;
    panMapHoover: TPanel;
    trbMapHoover: TTrackBar;
    Label1: TLabel;
    txtMapHoover: TEdit;
    Label2: TLabel;
    panMapSelected: TPanel;
    Label3: TLabel;
    Label4: TLabel;
    trbMapSelected: TTrackBar;
    txtMapSelected: TEdit;
    lstTlbButtons: TListView;
    tbsGame: TTabSheet;
    chkGameConfirmAbort: TCheckBox;
    chkTlbShowToolbar: TCheckBox;
    tbsUpdate: TTabSheet;
    chkUpdateCheck: TCheckBox;
    chkExpertAttack: TCheckBox;
    procedure FormShow(Sender: TObject);
    procedure trbMapHooverChange(Sender: TObject);
    procedure chkMapHooverClick(Sender: TObject);
    procedure trbMapSelectedChange(Sender: TObject);
    procedure cmdOKClick(Sender: TObject);
    procedure cmdResetRulesClick(Sender: TObject);
    procedure chkMapSelectedClick(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  fPref: TfPref;

implementation

{$R *.lfm}

uses Globals, Main, Territ;

procedure TfPref.FormShow(Sender: TObject);
var
  i: integer;
begin
  // toolbar
  chkTlbShowToolbar.Checked := bPrefShowToolbar;
  lstTlbButtons.Clear;
  for i := 0 to fMain.tlbToolBar.ButtonCount - 3 do begin
    with lstTlbButtons.Items.Add do begin
      Caption := fMain.tlbToolBar.Buttons[i].Caption;
      ImageIndex := i;
      Checked := fMain.tlbToolBar.Buttons[i].Visible;
    end;
  end;
  // map
  chkMapHoover.Checked := bPrefMapHoover;
  panMapHoover.Visible := bPrefMapHoover;
  chkMapSelected.Checked := bPrefMapSelected;
  panMapSelected.Visible := bPrefMapSelected;
  txtMapHoover.Text := IntToStr(iPrefMapHoover);
  txtMapSelected.Text := IntToStr(iPrefMapSelected);
  trbMapHoover.Position := iPrefMapHoover div 5;
  trbMapSelected.Position := iPrefMapSelected div 5;
  // game
  chkGameConfirmAbort.Checked := bPrefConfirmAbort;
  chkExpertAttack.Checked := bPrefExpertAttack;
  // update
  chkUpdateCheck.Checked := bPrefCheckUpdate;
end;

procedure TfPref.chkMapHooverClick(Sender: TObject);
begin
  panMapHoover.Visible := chkMapHoover.Checked;
end;

procedure TfPref.trbMapHooverChange(Sender: TObject);
begin
  txtMapHoover.Text := IntToStr(trbMapHoover.Position * 5);
end;

procedure TfPref.chkMapSelectedClick(Sender: TObject);
begin
  panMapSelected.Visible := chkMapSelected.Checked;
end;

procedure TfPref.trbMapSelectedChange(Sender: TObject);
begin
  txtMapSelected.Text := IntToStr(trbMapSelected.Position * 5);
end;

procedure TfPref.cmdOKClick(Sender: TObject);
var
  i: integer;
begin
  // toolbar
  bPrefShowToolbar := chkTlbShowToolbar.Checked;
  fMain.tlbToolBar.Visible := bPrefShowToolbar;
  sPrefTlbButtons := '';
  for i := 0 to fMain.tlbToolBar.ButtonCount - 3 do begin
    with lstTlbButtons.Items[i] do begin
      if Checked then begin
        fMain.tlbToolBar.Buttons[i].Visible := true;
        sPrefTlbButtons := sPrefTlbButtons + '1';
      end
      else begin
        fMain.tlbToolBar.Buttons[i].Visible := false;
        sPrefTlbButtons := sPrefTlbButtons + '0';
      end;
    end;
  end;
  // map
  bPrefMapHoover := chkMapHoover.Checked;
  bPrefMapSelected := chkMapSelected.Checked;
  iPrefMapHoover := StrToIntDef(txtMapHoover.Text, 0);
  iPrefMapSelected := StrToIntDef(txtMapSelected.Text, 0);
  ModalResult := mrOK;
  // game
  bPrefConfirmAbort := chkGameConfirmAbort.Checked;
  bPrefExpertAttack := chkExpertAttack.Checked;
  // update
  bPrefCheckUpdate := chkUpdateCheck.Checked;
  // resize main window according to map and toolbar
  ResizeMainWindow;
end;

procedure TfPref.cmdResetRulesClick(Sender: TObject);
var
  i: integer;
begin
  if MessageDlg(
    'Would you like to reset the preferences to their default values?',
    mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
    exit;
  // toolbar
  chkTlbShowToolbar.Checked := true;
  for i := 0 to fMain.tlbToolBar.ButtonCount - 3 do begin
    with lstTlbButtons.Items[i] do begin
      Checked := (i >= 1) and (i <= 5);
    end;
  end;
  // map
  chkMapHoover.Checked := true;
  chkMapSelected.Checked := true;
  txtMapHoover.Text := IntToStr(-20);
  txtMapSelected.Text := IntToStr(-20);
  trbMapHoover.Position := -20 div 5;
  trbMapSelected.Position := -20 div 5;
  // game
  chkGameConfirmAbort.Checked := true;
  chkExpertAttack.Checked := false;
  // update
  chkUpdateCheck.Checked := false;
end;

end.
