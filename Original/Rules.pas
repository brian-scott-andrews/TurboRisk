unit Rules;

{$MODE Delphi}

interface

uses
  LCLIntf, LCLType, LMessages, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  ComCtrls, StdCtrls, Buttons, ExtCtrls;

type
  TfRules = class(TForm)
    tabRules: TPageControl;
    tbsRules: TTabSheet;
    tbsCards: TTabSheet;
    tbsMove: TTabSheet;
    optAssegnazione: TRadioGroup;
    cmdOK: TBitBtn;
    cmdAnnulla: TBitBtn;
    GroupBox1: TGroupBox;
    Label1: TLabel;
    txtArmIn2: TEdit;
    txtArmIn3: TEdit;
    txtArmIn4: TEdit;
    txtArmIn5: TEdit;
    txtArmIn6: TEdit;
    txtArmIn7: TEdit;
    txtArmIn8: TEdit;
    txtArmIn9: TEdit;
    txtArmIn10: TEdit;
    Label2: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    Label5: TLabel;
    Label6: TLabel;
    Label7: TLabel;
    Label8: TLabel;
    Label9: TLabel;
    optUsoCarte: TRadioGroup;
    panCostante: TGroupBox;
    Label10: TLabel;
    txtSetArt: TEdit;
    txtSetInf: TEdit;
    txtSetCav: TEdit;
    txtSetDif: TEdit;
    Label11: TLabel;
    Label12: TLabel;
    Label13: TLabel;
    panProgressivo: TGroupBox;
    Label14: TLabel;
    txtTrade1: TEdit;
    txtTrade2: TEdit;
    txtTrade3: TEdit;
    txtTrade4: TEdit;
    txtTrade5: TEdit;
    txtTrade6: TEdit;
    txtTrade7: TEdit;
    txtTrade8: TEdit;
    Label15: TLabel;
    Label16: TLabel;
    Label17: TLabel;
    Label18: TLabel;
    Label19: TLabel;
    Label20: TLabel;
    Label21: TLabel;
    Label22: TLabel;
    txtTradeInc: TEdit;
    chkTrasfFinale: TCheckBox;
    txtMaxCardsHeld: TEdit;
    Label23: TLabel;
    chkTradeCaptured: TCheckBox;
    cmdResetRules: TBitBtn;
    procedure cmdOKClick(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure optUsoCarteClick(Sender: TObject);
    procedure txtNumOnlyKeyPress(Sender: TObject; var Key: Char);
    procedure cmdResetRulesClick(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  fRules: TfRules;

implementation

{$R *.lfm}

uses Globals;

procedure TfRules.FormShow(Sender: TObject);
begin
  // Copy global variables into controls
  if RAssignmentType=atRandom then
    optAssegnazione.Itemindex := 1
  else
    optAssegnazione.Itemindex := 0;
  txtArmIn2.Text := IntToStr(RInitialArmies[2]);
  txtArmIn3.Text := IntToStr(RInitialArmies[3]);
  txtArmIn4.Text := IntToStr(RInitialArmies[4]);
  txtArmIn5.Text := IntToStr(RInitialArmies[5]);
  txtArmIn6.Text := IntToStr(RInitialArmies[6]);
  txtArmIn7.Text := IntToStr(RInitialArmies[7]);
  txtArmIn8.Text := IntToStr(RInitialArmies[8]);
  txtArmIn9.Text := IntToStr(RInitialArmies[9]);
  txtArmIn10.Text := IntToStr(RInitialArmies[10]);
  if RCardsValueType=cvConstant then
    optUsoCarte.Itemindex := 0
  else
    optUsocarte.Itemindex := 1;
  optUsoCarteClick(self);
  txtSetArt.Text := IntToStr(RSetValue[csArt]);
  txtSetInf.Text := IntToStr(RSetValue[csInf]);
  txtSetCav.Text := IntToStr(RSetValue[csCav]);
  txtSetDif.Text := IntToStr(RSetValue[csDif]);
  txtTrade1.Text := IntToStr(RTradeValue[1]);
  txtTrade2.Text := IntToStr(RTradeValue[2]);
  txtTrade3.Text := IntToStr(RTradeValue[3]);
  txtTrade4.Text := IntToStr(RTradeValue[4]);
  txtTrade5.Text := IntToStr(RTradeValue[5]);
  txtTrade6.Text := IntToStr(RTradeValue[6]);
  txtTrade7.Text := IntToStr(RTradeValue[7]);
  txtTrade8.Text := IntToStr(RTradeValue[8]);
  txtTradeInc.Text := IntToStr(RValueInc);
  txtMaxCardsHeld.Text := IntToStr(RMaxHeldCards);
  chkTradeCaptured.Checked := RImmediateTrade;
  chkTrasfFinale.Checked := RFinalMove;
end;

procedure TfRules.cmdOKClick(Sender: TObject);

  function IsOk(Field: TWinControl; bOK: boolean; iPage: integer): boolean;
  begin
    if not bOK then begin
      tabRules.ActivePage := tabRules.Pages[iPage];
      Field.SetFocus;
      MessageDlg('Invalid value.',mtError, [mbOk], 0);
    end;
    Result := bOK;
  end;

  function MyStrToInt(s: string): integer;
  begin
    if trim(s)='' then
      result:=0
    else
      result:=StrToInt(s);
  end;

begin
  // Check input controls
  if not IsOk(txtArmIn2,MyStrToInt(txtArmIn2.Text)>=21,0) then exit;
  if not IsOk(txtArmIn3,MyStrToInt(txtArmIn3.Text)>=14,0) then exit;
  if not IsOk(txtArmIn4,MyStrToInt(txtArmIn4.Text)>=11,0) then exit;
  if not IsOk(txtArmIn5,MyStrToInt(txtArmIn5.Text)>=9,0) then exit;
  if not IsOk(txtArmIn6,MyStrToInt(txtArmIn6.Text)>=7,0) then exit;
  if not IsOk(txtArmIn7,MyStrToInt(txtArmIn7.Text)>=6,0) then exit;
  if not IsOk(txtArmIn8,MyStrToInt(txtArmIn8.Text)>=6,0) then exit;
  if not IsOk(txtArmIn9,MyStrToInt(txtArmIn9.Text)>=5,0) then exit;
  if not IsOk(txtArmIn10,MyStrToInt(txtArmIn10.Text)>=5,0) then exit;
  if optUsoCarte.Itemindex = 0 then begin
    if not IsOk(txtSetArt,MyStrToInt(txtSetArt.Text)>=0,1) then exit;
    if not IsOk(txtSetInf,MyStrToInt(txtSetInf.Text)>=0,1) then exit;
    if not IsOk(txtSetCav,MyStrToInt(txtSetCav.Text)>=0,1) then exit;
    if not IsOk(txtSetDif,MyStrToInt(txtSetDif.Text)>=0,1) then exit;
  end else begin
    if not IsOk(txtTrade1,MyStrToInt(txtTrade1.Text)>=0,1) then exit;
    if not IsOk(txtTrade2,MyStrToInt(txtTrade2.Text)>=0,1) then exit;
    if not IsOk(txtTrade3,MyStrToInt(txtTrade3.Text)>=0,1) then exit;
    if not IsOk(txtTrade4,MyStrToInt(txtTrade4.Text)>=0,1) then exit;
    if not IsOk(txtTrade5,MyStrToInt(txtTrade5.Text)>=0,1) then exit;
    if not IsOk(txtTrade6,MyStrToInt(txtTrade6.Text)>=0,1) then exit;
    if not IsOk(txtTrade7,MyStrToInt(txtTrade7.Text)>=0,1) then exit;
    if not IsOk(txtTrade8,MyStrToInt(txtTrade8.Text)>=0,1) then exit;
    if not IsOk(txtTradeInc,MyStrToInt(txtTradeInc.Text)>=0,1) then exit;
  end;
  if not IsOk(txtMaxCardsHeld,MyStrToInt(txtMaxCardsHeld.Text)>=4,1) then exit;

  // Copy controls into global variables
  if optAssegnazione.Itemindex = 1 then begin
    RAssignmentType := atRandom
  end else begin
    RAssignmentType := atTurns;
  end;
  RInitialArmies[2] := MyStrToInt(txtArmIn2.Text);
  RInitialArmies[3] := MyStrToInt(txtArmIn3.Text);
  RInitialArmies[4] := MyStrToInt(txtArmIn4.Text);
  RInitialArmies[5] := MyStrToInt(txtArmIn5.Text);
  RInitialArmies[6] := MyStrToInt(txtArmIn6.Text);
  RInitialArmies[7] := MyStrToInt(txtArmIn7.Text);
  RInitialArmies[8] := MyStrToInt(txtArmIn8.Text);
  RInitialArmies[9] := MyStrToInt(txtArmIn9.Text);
  RInitialArmies[10] := MyStrToInt(txtArmIn10.Text);
  if optUsoCarte.Itemindex = 0 then begin
    RCardsValueType := cvConstant;
  end else begin
    RCardsValueType := cvProgressive;
  end;
  RSetValue[csArt] := MyStrToInt(txtSetArt.Text);
  RSetValue[csInf] := MyStrToInt(txtSetInf.Text);
  RSetValue[csCav] := MyStrToInt(txtSetCav.Text);
  RSetValue[csDif] := MyStrToInt(txtSetDif.Text);
  RTradeValue[1] := MyStrToInt(txtTrade1.Text);
  RTradeValue[2] := MyStrToInt(txtTrade2.Text);
  RTradeValue[3] := MyStrToInt(txtTrade3.Text);
  RTradeValue[4] := MyStrToInt(txtTrade4.Text);
  RTradeValue[5] := MyStrToInt(txtTrade5.Text);
  RTradeValue[6] := MyStrToInt(txtTrade6.Text);
  RTradeValue[7] := MyStrToInt(txtTrade7.Text);
  RTradeValue[8] := MyStrToInt(txtTrade8.Text);
  RValueInc := MyStrToInt(txtTradeInc.Text);
  RMaxHeldCards := MyStrToInt(txtMaxCardsHeld.Text);
  RImmediateTrade := chkTradeCaptured.Checked;
  RFinalMove := chkTrasfFinale.Checked;

  ModalResult := mrOK;

end;

procedure TfRules.optUsoCarteClick(Sender: TObject);
var
  i: integer;
begin
  if optUsocarte.ItemIndex=0 then begin
    with panProgressivo do begin
      Enabled := false;
      for i:=0 to ControlCount-1 do Controls[i].Enabled := false;
    end;
    with panCostante do begin
      Enabled := true;
      for i:=0 to ControlCount-1 do Controls[i].Enabled := true;
    end;
  end else begin
    with panCostante do begin
      Enabled := false;
      for i:=0 to ControlCount-1 do Controls[i].Enabled := false;
    end;
    with panProgressivo do begin
      Enabled := true;
      for i:=0 to ControlCount-1 do Controls[i].Enabled := true;
    end;
  end;
end;


procedure TfRules.txtNumOnlyKeyPress(Sender: TObject; var Key: Char);
begin
  if not (Key in ['0'..'9',#8]) then
    Key:=#0;
end;

procedure TfRules.cmdResetRulesClick(Sender: TObject);
begin
  if MessageDlg('Would you like to reset the rules to their default values?',mtConfirmation, [mbYes,mbNo], 0)<>mrYes then exit;
  optAssegnazione.ItemIndex := 0;
  txtArmIn2.Text := '40';
  txtArmIn3.Text := '35';
  txtArmIn4.Text := '30';
  txtArmIn5.Text := '25';
  txtArmIn6.Text := '20';
  txtArmIn7.Text := '20';
  txtArmIn8.Text := '20';
  txtArmIn9.Text := '20';
  txtArmIn10.Text := '20';
  txtTrade1.Text := '4';
  txtTrade2.Text := '6';
  txtTrade3.Text := '8';
  txtTrade4.Text := '10';
  txtTrade5.Text := '12';
  txtTrade6.Text := '15';
  txtTrade7.Text := '20';
  txtTrade8.Text := '25';
  txtTradeInc.Text := '5';
  optUsoCarte.ItemIndex := 1;
  txtMaxCardsHeld.Text := '5';
  chkTradeCaptured.Checked := true;
  chkTrasfFinale.Checked := true;
end;

end.
