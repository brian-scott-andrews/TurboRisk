object fTRPError: TfTRPError
  Left = 393
  Top = 181
  HelpContext = 600
  BorderStyle = bsDialog
  Caption = 'TRP Error'
  ClientHeight = 231
  ClientWidth = 352
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  OldCreateOrder = False
  Position = poMainFormCenter
  PixelsPerInch = 96
  TextHeight = 13
  object txtMsg: TMemo
    Left = 5
    Top = 5
    Width = 341
    Height = 171
    ReadOnly = True
    TabOrder = 0
  end
  object cmdContinue: TBitBtn
    Left = 5
    Top = 190
    Width = 86
    Height = 31
    Caption = '&Continue'
    Default = True
    DoubleBuffered = True
    Glyph.Data = {
      DE010000424DDE01000000000000760000002800000024000000120000000100
      0400000000006801000000000000000000001000000000000000000000000000
      80000080000000808000800000008000800080800000C0C0C000808080000000
      FF0000FF000000FFFF00FF000000FF00FF00FFFF0000FFFFFF00333333444444
      33333333333F8888883F33330000324334222222443333388F3833333388F333
      000032244222222222433338F8833FFFFF338F3300003222222AAAAA22243338
      F333F88888F338F30000322222A33333A2224338F33F8333338F338F00003222
      223333333A224338F33833333338F38F00003222222333333A444338FFFF8F33
      3338888300003AAAAAAA33333333333888888833333333330000333333333333
      333333333333333333FFFFFF000033333333333344444433FFFF333333888888
      00003A444333333A22222438888F333338F3333800003A2243333333A2222438
      F38F333333833338000033A224333334422224338338FFFFF8833338000033A2
      22444442222224338F3388888333FF380000333A2222222222AA243338FF3333
      33FF88F800003333AA222222AA33A3333388FFFFFF8833830000333333AAAAAA
      3333333333338888883333330000333333333333333333333333333333333333
      0000}
    ModalResult = 5
    NumGlyphs = 2
    ParentDoubleBuffered = False
    TabOrder = 1
  end
  object cmdDump: TBitBtn
    Left = 100
    Top = 190
    Width = 86
    Height = 31
    Caption = '&Dump memory'
    DoubleBuffered = True
    ModalResult = 6
    NumGlyphs = 2
    ParentDoubleBuffered = False
    TabOrder = 2
  end
  object cmdHelp: TBitBtn
    Left = 290
    Top = 190
    Width = 56
    Height = 31
    DoubleBuffered = True
    Kind = bkHelp
    ParentDoubleBuffered = False
    TabOrder = 3
    OnClick = cmdHelpClick
  end
  object cmdQuit: TBitBtn
    Left = 195
    Top = 190
    Width = 86
    Height = 31
    Caption = '&Quit TurboRisk'
    DoubleBuffered = True
    ModalResult = 3
    NumGlyphs = 2
    ParentDoubleBuffered = False
    TabOrder = 4
  end
end