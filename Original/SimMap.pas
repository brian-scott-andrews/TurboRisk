unit SimMap;

{$MODE Delphi}

interface

uses
  LCLIntf, LCLType, LMessages, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  Menus, ExtCtrls, StdCtrls, ComCtrls, {JvComponentBase, JvPropertyStore,
  JvProgramVersionCheck, IdAntiFreezeBase, IdAntiFreeze, IdBaseComponent,
  IdComponent, IdTCPConnection, IdTCPClient, IdFTP,} ImgList, ToolWin;

type
  TfSimMap = class(TForm)
    panMap: TPanel;
    imgMap: TImage;
    procedure FormShow(Sender: TObject);
  private
  public
    { Public declarations }
  end;

var
  fSimMap: TfSimMap;

implementation

{$R *.lfm}

uses Globals;

procedure TfSimMap.FormShow(Sender: TObject);
begin
//
end;

end.
