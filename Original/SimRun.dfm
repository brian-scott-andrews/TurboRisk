object fSimRun: TfSimRun
  Left = 0
  Top = 0
  BorderIcons = []
  BorderStyle = bsDialog
  Caption = 'Simulation progress'
  ClientHeight = 442
  ClientWidth = 534
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  PixelsPerInch = 96
  TextHeight = 13
  object Label1: TLabel
    Left = 8
    Top = 13
    Width = 38
    Height = 13
    Caption = 'Game #'
  end
  object Label2: TLabel
    Left = 8
    Top = 73
    Width = 50
    Height = 13
    Caption = 'Game time'
  end
  object Label3: TLabel
    Left = 8
    Top = 43
    Width = 60
    Height = 13
    Caption = 'Current turn'
  end
  object Label4: TLabel
    Left = 8
    Top = 103
    Width = 71
    Height = 13
    Caption = 'Simulation time'
  end
  object Label5: TLabel
    Left = 8
    Top = 138
    Width = 65
    Height = 13
    Caption = 'Simulation log'
  end
  object prbGames: TProgressBar
    Left = 162
    Top = 8
    Width = 364
    Height = 24
    TabOrder = 0
  end
  object panGameNbr: TPanel
    Left = 96
    Top = 8
    Width = 55
    Height = 24
    BevelOuter = bvLowered
    Caption = '0'
    TabOrder = 1
  end
  object cmdStop: TBitBtn
    Left = 396
    Top = 68
    Width = 130
    Height = 54
    Caption = 'Stop simulation'
    DoubleBuffered = True
    ParentDoubleBuffered = False
    TabOrder = 2
    OnClick = cmdStopClick
  end
  object panSimTime: TPanel
    Left = 96
    Top = 98
    Width = 55
    Height = 24
    BevelOuter = bvLowered
    Caption = '0'
    TabOrder = 3
  end
  object txtSimLog: TMemo
    Left = 8
    Top = 157
    Width = 518
    Height = 274
    TabStop = False
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -11
    Font.Name = 'Courier New'
    Font.Style = []
    Lines.Strings = (
      'txtSimLog')
    ParentFont = False
    ReadOnly = True
    ScrollBars = ssVertical
    TabOrder = 4
  end
  object panTurn: TPanel
    Left = 96
    Top = 38
    Width = 55
    Height = 24
    BevelOuter = bvLowered
    Caption = '0'
    TabOrder = 5
  end
  object panGameTime: TPanel
    Left = 96
    Top = 68
    Width = 55
    Height = 24
    BevelOuter = bvLowered
    Caption = '0'
    TabOrder = 6
  end
  object cmdAbortGame: TBitBtn
    Left = 260
    Top = 68
    Width = 130
    Height = 54
    Caption = 'Abort current game'
    DoubleBuffered = True
    ParentDoubleBuffered = False
    TabOrder = 7
    OnClick = cmdAbortGameClick
  end
end
