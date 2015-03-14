unit About;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  StdCtrls, ExtCtrls;

type
  TfAbout = class(TForm)
    Label2: TLabel;
    Label4: TLabel;
    Label5: TLabel;
    lblVersion: TLabel;
    Label6: TLabel;
    Image1: TImage;
    txtCredits: TMemo;
    procedure FormShow(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  fAbout: TfAbout;

implementation

{$R *.DFM}

uses Globals;

procedure TfAbout.FormShow(Sender: TObject);
begin
  lblVersion.Caption := 'Version ' + sG_AppVers;
  with txtCredits.Lines do begin
    Clear;
    Add(
      'Many thanks to Steve Stancliff for his WinRisk program, which I liked ' + 'and used so much, and which  inspired TurboRisk.');
    Add('');
    Add('I want to thank all the many people who gave a contribution ' +
        'to make TurboRisk a better program.');
    Add('');
    Add('A very special thanks to the following people for their invaluable help:');
    Add('');
    Add('Paul R. Brown');
    Add('Julio Couce');
    Add('Anthony Covey-Crump');
    Add('Bobo Frogg');
    Add('Alexander Gogava');
    Add('Heitor Mansel');
    Add('Martin Nehrdich');
    Add('Eric Platel');
    Add('Timothy Purkess');
    Add('Rafal Smotrzyk');
    Add('Chrystian Wurmser');
    Add('');
    Add('Nathan Scarbrough deserves a special mention, because of his enormous'
        + ' contribution to the development and testing of version 2.');
    Add('');
    Add('Thanks to RemObjects for their free Pascal Script interpreter.');
  end;
end;

end.
