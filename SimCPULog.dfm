object fSimCPULog: TfSimCPULog
  Left = 0
  Top = 0
  Caption = 'CPU usage log'
  ClientHeight = 472
  ClientWidth = 533
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  Position = poScreenCenter
  OnClose = FormClose
  OnDestroy = FormDestroy
  OnShow = FormShow
  PixelsPerInch = 96
  TextHeight = 13
  object Panel1: TPanel
    Left = 0
    Top = 365
    Width = 533
    Height = 107
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 0
    ExplicitWidth = 548
    object lstDetail: TListView
      Left = 0
      Top = 0
      Width = 533
      Height = 107
      Align = alClient
      Columns = <
        item
          Caption = 'Player'
          Width = 110
        end
        item
          Alignment = taCenter
          Caption = 'Assignment'
          Width = 80
        end
        item
          Alignment = taCenter
          Caption = 'Placement'
          Width = 80
        end
        item
          Alignment = taCenter
          Caption = 'Attack'
          Width = 80
        end
        item
          Alignment = taCenter
          Caption = 'Occupation'
          Width = 80
        end
        item
          Alignment = taCenter
          Caption = 'Fortification'
          Width = 80
        end>
      GridLines = True
      ReadOnly = True
      TabOrder = 0
      ViewStyle = vsReport
      ExplicitWidth = 548
    end
  end
  object lstSummary: TListView
    Left = 0
    Top = 0
    Width = 533
    Height = 365
    Align = alClient
    Columns = <
      item
        Caption = 'Player'
        Width = 110
      end
      item
        Alignment = taCenter
        Caption = 'Assignment'
        Width = 80
      end
      item
        Alignment = taCenter
        Caption = 'Placement'
        Width = 80
      end
      item
        Alignment = taCenter
        Caption = 'Attack'
        Width = 80
      end
      item
        Alignment = taCenter
        Caption = 'Occupation'
        Width = 80
      end
      item
        Alignment = taCenter
        Caption = 'Fortification'
        Width = 80
      end>
    GridLines = True
    ReadOnly = True
    RowSelect = True
    TabOrder = 1
    ViewStyle = vsReport
    OnSelectItem = lstSummarySelectItem
    ExplicitWidth = 497
  end
end
