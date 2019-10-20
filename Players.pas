unit Players;

{$MODE Delphi}

interface

uses
  LCLIntf, LCLType, LMessages, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs, ColorBox,
  StdCtrls, Buttons, ExtCtrls{, EdisCustom};

type
  TfPlayers = class(TForm)
    txtName: TEdit;
    optTipo: TRadioGroup;
    lblName: TLabel;
    Label3: TLabel;
    cmdOK: TBitBtn;
    optCarte: TRadioGroup;
    chkLog: TCheckBox;
    cboPrgFile: TEdit;
    cboPrgFileSelect: TButton;
    cboColor: TColorBox;
    BitBtn1: TBitBtn;
    procedure FormShow(Sender: TObject);
    procedure optTipoClick(Sender: TObject);
    procedure cboPrgFileCustomDlg(Sender: TObject);
    procedure cboColorChange(Sender: TObject);
    procedure cmdOKClick(Sender: TObject);
    procedure cmdCancel(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  fPlayers: TfPlayers;

implementation

{$R *.lfm}

uses Globals, Stats, Programs;

procedure TfPlayers.FormShow(Sender: TObject);
begin
  optTipoClick(Sender);
end;

procedure TfPlayers.cboColorChange(Sender: TObject);
begin
  if cboColor.Selected = clBlack then
    cboColor.Selected := clGray;
  if cboColor.Selected = clWhite then
    cboColor.Selected := clCream;
end;

procedure TfPlayers.optTipoClick(Sender: TObject);
begin
  case optTipo.ItemIndex of
    0: begin
        cboPrgFile.Visible := false;
        cboPrgFileSelect.Visible := false;
        txtName.Visible := true;
        lblName.Caption := 'Name';
        optCarte.Enabled := true;
      end;
    1: begin
        cboPrgFile.Visible := true;
        cboPrgFileSelect.Visible := true;
        txtName.Visible := false;
        lblName.Caption := 'Program';
        optCarte.Enabled := false;
      end;
  end;
end;

procedure TfPlayers.cboPrgFileCustomDlg(Sender: TObject);
begin
  if fPrograms.ShowModal = mrOK then begin
  end;
end;

procedure TfPlayers.cmdOKClick(Sender: TObject);
begin
  if (optTipo.ItemIndex = 1) and (trim(cboPrgFile.Text) = '') then begin
    MessageDlg('Specify a program.', mtError, [mbOK], 0);
    cboPrgFile.SetFocus;
    ModalResult := mrNone;
  end;
  ModalResult := mrOK;
end;

procedure TfPlayers.cmdCancel(Sender:TObject);
begin
  ModalResult := mrCancel;
end;

end.
