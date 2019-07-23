unit NewGame;

{$MODE Delphi}

interface

uses
  LCLIntf, LCLType, LMessages, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  StdCtrls, Buttons, ExtCtrls, ImgList;

type
  TfNewGame = class(TForm)
    panPlayer1: TPanel;
    chkName1: TCheckBox;
    imlPlayers: TImageList;
    imgType1: TImage;
    cmdChange1: TSpeedButton;
    panColor1: TPanel;
    panPlayer2: TPanel;
    imgType2: TImage;
    cmdChange2: TSpeedButton;
    chkName2: TCheckBox;
    panColor2: TPanel;
    Panel1: TPanel;
    imgType3: TImage;
    cmdChange3: TSpeedButton;
    chkName3: TCheckBox;
    panColor3: TPanel;
    Panel3: TPanel;
    imgType4: TImage;
    cmdChange4: TSpeedButton;
    chkName4: TCheckBox;
    panColor4: TPanel;
    Panel5: TPanel;
    imgType5: TImage;
    cmdChange5: TSpeedButton;
    chkName5: TCheckBox;
    panColor5: TPanel;
    Panel7: TPanel;
    imgType6: TImage;
    cmdChange6: TSpeedButton;
    chkName6: TCheckBox;
    panColor6: TPanel;
    Panel9: TPanel;
    imgType7: TImage;
    cmdChange7: TSpeedButton;
    chkName7: TCheckBox;
    panColor7: TPanel;
    Panel11: TPanel;
    imgType8: TImage;
    cmdChange8: TSpeedButton;
    chkName8: TCheckBox;
    panColor8: TPanel;
    Panel13: TPanel;
    imgType9: TImage;
    cmdChange9: TSpeedButton;
    chkName9: TCheckBox;
    panColor9: TPanel;
    Panel15: TPanel;
    imgType10: TImage;
    cmdChange10: TSpeedButton;
    chkName10: TCheckBox;
    panColor10: TPanel;
    cmdOK: TBitBtn;
    BitBtn1: TBitBtn;
    Label1: TLabel;
    GroupBox1: TGroupBox;
    Label2: TLabel;
    cboSetup: TComboBox;
    cmdSaveSetup: TBitBtn;
    cmdDeleteSetup: TBitBtn;
    procedure FormShow(Sender: TObject);
    procedure cmdOKClick(Sender: TObject);
    procedure cmdChangeClick(Sender: TObject);
    procedure cboSetupSelect(Sender: TObject);
    procedure cmdSaveSetupClick(Sender: TObject);
    procedure BitBtn1Click(Sender: TObject);
    procedure cmdDeleteSetupClick(Sender: TObject);
  private
    procedure ActivePlayers;
  public
    { Public declarations }
  end;

var
  fNewGame: TfNewGame;

implementation

{$R *.lfm}

uses Globals, Players, Stats;

procedure TfNewGame.FormShow(Sender: TObject);
var
  i: integer;
begin
  chkName1.Caption := arPlayer[1].Name;
  chkName1.Checked := arPlayer[1].Active;
  imgType1.Picture.Bitmap := nil;
  if arPlayer[1].Computer then
    imlPlayers.GetBitmap(1, imgType1.Picture.Bitmap)
  else
    imlPlayers.GetBitmap(0, imgType1.Picture.Bitmap);
  panColor1.Color := arPlayer[1].Color;

  chkName2.Caption := arPlayer[2].Name;
  chkName2.Checked := arPlayer[2].Active;
  imgType2.Picture.Bitmap := nil;
  if arPlayer[2].Computer then
    imlPlayers.GetBitmap(1, imgType2.Picture.Bitmap)
  else
    imlPlayers.GetBitmap(0, imgType2.Picture.Bitmap);
  panColor2.Color := arPlayer[2].Color;

  chkName3.Caption := arPlayer[3].Name;
  chkName3.Checked := arPlayer[3].Active;
  imgType3.Picture.Bitmap := nil;
  if arPlayer[3].Computer then
    imlPlayers.GetBitmap(1, imgType3.Picture.Bitmap)
  else
    imlPlayers.GetBitmap(0, imgType3.Picture.Bitmap);
  panColor3.Color := arPlayer[3].Color;

  chkName4.Caption := arPlayer[4].Name;
  chkName4.Checked := arPlayer[4].Active;
  imgType4.Picture.Bitmap := nil;
  if arPlayer[4].Computer then
    imlPlayers.GetBitmap(1, imgType4.Picture.Bitmap)
  else
    imlPlayers.GetBitmap(0, imgType4.Picture.Bitmap);
  panColor4.Color := arPlayer[4].Color;

  chkName5.Caption := arPlayer[5].Name;
  chkName5.Checked := arPlayer[5].Active;
  imgType5.Picture.Bitmap := nil;
  if arPlayer[5].Computer then
    imlPlayers.GetBitmap(1, imgType5.Picture.Bitmap)
  else
    imlPlayers.GetBitmap(0, imgType5.Picture.Bitmap);
  panColor5.Color := arPlayer[5].Color;

  chkName6.Caption := arPlayer[6].Name;
  chkName6.Checked := arPlayer[6].Active;
  imgType6.Picture.Bitmap := nil;
  if arPlayer[6].Computer then
    imlPlayers.GetBitmap(1, imgType6.Picture.Bitmap)
  else
    imlPlayers.GetBitmap(0, imgType6.Picture.Bitmap);
  panColor6.Color := arPlayer[6].Color;

  chkName7.Caption := arPlayer[7].Name;
  chkName7.Checked := arPlayer[7].Active;
  imgType7.Picture.Bitmap := nil;
  if arPlayer[7].Computer then
    imlPlayers.GetBitmap(1, imgType7.Picture.Bitmap)
  else
    imlPlayers.GetBitmap(0, imgType7.Picture.Bitmap);
  panColor7.Color := arPlayer[7].Color;

  chkName8.Caption := arPlayer[8].Name;
  chkName8.Checked := arPlayer[8].Active;
  imgType8.Picture.Bitmap := nil;
  if arPlayer[8].Computer then
    imlPlayers.GetBitmap(1, imgType8.Picture.Bitmap)
  else
    imlPlayers.GetBitmap(0, imgType8.Picture.Bitmap);
  panColor8.Color := arPlayer[8].Color;

  chkName9.Caption := arPlayer[9].Name;
  chkName9.Checked := arPlayer[9].Active;
  imgType9.Picture.Bitmap := nil;
  if arPlayer[9].Computer then
    imlPlayers.GetBitmap(1, imgType9.Picture.Bitmap)
  else
    imlPlayers.GetBitmap(0, imgType9.Picture.Bitmap);
  panColor9.Color := arPlayer[9].Color;

  chkName10.Caption := arPlayer[10].Name;
  chkName10.Checked := arPlayer[10].Active;
  imgType10.Picture.Bitmap := nil;
  if arPlayer[10].Computer then
    imlPlayers.GetBitmap(1, imgType10.Picture.Bitmap)
  else
    imlPlayers.GetBitmap(0, imgType10.Picture.Bitmap);
  panColor10.Color := arPlayer[10].Color;

  // load quick setup combo
  cboSetup.Items.Clear;
  for i := 1 to iPlSetCount do begin
    cboSetup.Items.Add(arPlayersSet[i].Name);
  end;
  if iPlSet = 0 then
    cboSetup.Text := ''
  else
    cboSetup.ItemIndex := iPlSet - 1;
end;

procedure TfNewGame.cboSetupSelect(Sender: TObject);
var
  i, iP: integer;
begin
  i := cboSetup.ItemIndex + 1;
  if i > iPlSetCount then
    exit;
  for iP := 1 to MAXPLAYERS do begin
    if (iP = 1) and not arPlayer[iP].Computer then
      continue;
    arPlayer[iP].Name := arPlayersSet[i].arPlSet[iP].Name;
    arPlayer[iP].Computer := arPlayersSet[i].arPlSet[iP].Computer;
    arPlayer[iP].PrgFile := arPlayersSet[i].arPlSet[iP].PrgFile;
    arPlayer[iP].Color := arPlayersSet[i].arPlSet[iP].Color;
    arPlayer[iP].Active := arPlayersSet[i].arPlSet[iP].Active;
    arPlayer[iP].CardsHandling := arPlayersSet[i].arPlSet[iP].CardsHandling;
  end;
  iPlSet := i;
  FormShow(Sender);
end;

procedure TfNewGame.ActivePlayers;
begin
  arPlayer[1].Active := chkName1.Checked;
  arPlayer[2].Active := chkName2.Checked;
  arPlayer[3].Active := chkName3.Checked;
  arPlayer[4].Active := chkName4.Checked;
  arPlayer[5].Active := chkName5.Checked;
  arPlayer[6].Active := chkName6.Checked;
  arPlayer[7].Active := chkName7.Checked;
  arPlayer[8].Active := chkName8.Checked;
  arPlayer[9].Active := chkName9.Checked;
  arPlayer[10].Active := chkName10.Checked;
end;

procedure TfNewGame.cmdChangeClick(Sender: TObject);
var
  i: integer;
begin
  ActivePlayers;
  i := (Sender as TSpeedButton).Tag;
  with fPlayers do begin
    cboColor.Selected := arPlayer[i].Color;
    if arPlayer[i].Computer then begin
      optTipo.ItemIndex := 1;
      txtName.Text := arPlayer[i].PrgFile;
    end
    else begin
      optTipo.ItemIndex := 0;
      txtName.Text := arPlayer[i].Name;
    end;
    cboPrgFile.Text := arPlayer[i].PrgFile;
    optCarte.ItemIndex := ord(arPlayer[i].CardsHandling);
    chkLog.Checked := arPlayer[i].KeepLog;
  end;
  // show fPlayers form
  if fPlayers.ShowModal = mrOK then begin
    with fPlayers do begin
      // put player's parameters into array
      arPlayer[i].Computer := optTipo.ItemIndex = 1;
      arPlayer[i].CardsHandling := TCardsHandling(optCarte.ItemIndex);
      arPlayer[i].Color := cboColor.Selected;
      arPlayer[i].KeepLog := chkLog.Checked;
      if arPlayer[i].Computer then begin
        arPlayer[i].PrgFile := cboPrgFile.Text;
        arPlayer[i].Name := lowercase(ChangeFileExt(cboPrgFile.Text, ''));
      end
      else begin
        arPlayer[i].Name := txtName.Text;
      end;
    end;
    // update stats form with new names and colors
    UpdateStats;
    // players set has been modified
    if iPlSet <= STDPLSETS then
      iPlSet := 0;
    // copy parameters in controls
    FormShow(Sender);
  end;
end;

procedure TfNewGame.cmdOKClick(Sender: TObject);
var
  iG, iAttivi: integer;
begin
  ActivePlayers;
  iAttivi := 0;
  for iG := 1 to MAXPLAYERS do begin
    with arPlayer[iG] do begin
      if Active then begin
        inc(iAttivi);
        if Computer then begin
          if not FileExists(sG_AppPath + 'players\' + PrgFile) then begin
            MessageDlg(Name + ':' + sG_AppPath + 'players\' + PrgFile +
                ' not found.', mtError, [mbOK], 0);
            ModalResult := mrNone;
          end;
        end;
      end;
    end;
  end;

  if iAttivi < 2 then begin
    ModalResult := mrNone;
    MessageDlg('At least two players required.', mtError, [mbOK], 0);
  end;

end;

procedure TfNewGame.cmdSaveSetupClick(Sender: TObject);
var
  sName: string;
  i, iPS, iP: integer;
begin
  ActivePlayers;
  sName := trim(cboSetup.Text);
  if sName = '' then begin
    MessageDlg('You must specify a name.', mtError, [mbOK], 0);
    exit;
  end;
  iPS := 0;
  for i := 1 to MAXPLSETS do begin
    if CompareText(sName, arPlayersSet[i].Name) = 0 then begin
      iPS := i;
      break;
    end;
  end;
  // check for errors and ask for confirmation
  if iPS > 0 then begin
    if iPS <= STDPLSETS then begin
      MessageDlg('"' + sName + '" is a standard setup and cannot be modified.',
        mtError, [mbOK], 0);
      exit;
    end;
    if MessageDlg('A setup with name "' + sName + '" already exists. Confirm?',
      mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
      exit;
  end
  else begin
    if iPlSetCount >= MAXPLSETS then begin
      MessageDlg('You have reached the maximun number of custom setups.',
        mtError, [mbOK], 0);
      exit;
    end;
    if MessageDlg('Save current setup with name "' + sName + '". Confirm?',
      mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
      exit;
  end;
  // save setup
  if iPS = 0 then begin
    inc(iPlSetCount);
    iPS := iPlSetCount;
  end;
  arPlayersSet[iPS].Name := sName;
  for iP := 1 to MAXPLAYERS do begin
    arPlayersSet[iPS].arPlSet[iP].Name := arPlayer[iP].Name;
    arPlayersSet[iPS].arPlSet[iP].Computer := arPlayer[iP].Computer;
    arPlayersSet[iPS].arPlSet[iP].PrgFile := arPlayer[iP].PrgFile;
    arPlayersSet[iPS].arPlSet[iP].Color := arPlayer[iP].Color;
    arPlayersSet[iPS].arPlSet[iP].Active := arPlayer[iP].Active;
    arPlayersSet[iPS].arPlSet[iP].CardsHandling := arPlayer[iP].CardsHandling;
  end;
  iPlSet := iPS;
  FormShow(Sender);
end;

procedure TfNewGame.cmdDeleteSetupClick(Sender: TObject);
var
  sName: string;
  i, iPS: integer;
begin
  ActivePlayers;
  sName := trim(cboSetup.Text);
  if sName = '' then begin
    MessageDlg('You must select an existing setup.', mtError, [mbOK], 0);
    exit;
  end;
  iPS := 0;
  for i := 1 to MAXPLSETS do begin
    if CompareText(sName, arPlayersSet[i].Name) = 0 then begin
      iPS := i;
      break;
    end;
  end;
  // check for errors and ask for confirmation
  if iPS = 0 then begin
    MessageDlg('You must select an existing setup.', mtError, [mbOK], 0);
    exit;
  end;
  if iPS <= STDPLSETS then begin
    MessageDlg('"' + sName + '" is a standard setup and cannot be deleted.',
      mtError, [mbOK], 0);
    exit;
  end;
  if MessageDlg('Delete setup with name "' + sName + '". Confirm?',
    mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
    exit;
  // delete setup
  for i := iPS to iPlSetCount - 1 do begin
    arPlayersSet[iPS]:=arPlayersSet[iPS+1];
  end;
  dec(iPlSetCount);
  iPlSet := 0;
  FormShow(Sender);
end;

procedure TfNewGame.BitBtn1Click(Sender: TObject);
begin
  ActivePlayers;
end;

end.
