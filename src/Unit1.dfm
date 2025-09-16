object Form1: TForm1
  Left = 0
  Top = 0
  BorderIcons = [biSystemMenu]
  Caption = #1053#1072#1089#1090#1088#1086#1081#1082#1080
  ClientHeight = 362
  ClientWidth = 394
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OnShow = FormShow
  TextHeight = 13
  object pcSettings: TPageControl
    Left = 0
    Top = 0
    Width = 394
    Height = 321
    ActivePage = tsSettings
    Align = alClient
    TabOrder = 0
    ExplicitHeight = 251
    object tsSettings: TTabSheet
      Caption = #1053#1072#1089#1090#1088#1086#1081#1082#1080
      object lbCCaptionChanel: TLabel
        Left = 24
        Top = 104
        Width = 212
        Height = 13
        Caption = #1050#1072#1085#1072#1083' '#1074' '#1082#1086#1090#1086#1088#1086#1084' '#1073#1091#1076#1077#1090' '#1088#1072#1073#1086#1090#1072#1090#1100' '#1087#1083#1072#1075#1080#1085':'
      end
      object dePachVLC: TLabeledEdit
        Left = 24
        Top = 32
        Width = 329
        Height = 21
        EditLabel.Width = 66
        EditLabel.Height = 13
        EditLabel.Caption = #1055#1091#1090#1100' '#1076#1086' VLC:'
        TabOrder = 0
        Text = ''
      end
      object cbIPTVchan: TComboBox
        Left = 24
        Top = 123
        Width = 329
        Height = 21
        TabOrder = 1
      end
      object edURLM3U: TLabeledEdit
        Left = 24
        Top = 168
        Width = 329
        Height = 21
        EditLabel.Width = 104
        EditLabel.Height = 13
        EditLabel.Caption = #1055#1091#1090#1100' '#1076#1086' '#1092#1072#1081#1083#1072' M3U:'
        TabOrder = 2
        Text = ''
      end
      object edURLJTV: TLabeledEdit
        Left = 24
        Top = 216
        Width = 329
        Height = 21
        EditLabel.Width = 162
        EditLabel.Height = 13
        EditLabel.Caption = #1055#1091#1090#1100' '#1076#1086' '#1092#1072#1081#1083#1072' '#1090#1077#1083#1077#1087#1088#1086#1075#1088#1072#1084#1084#1099':'
        TabOrder = 3
        Text = ''
      end
      object lePachStyle: TLabeledEdit
        Left = 24
        Top = 77
        Width = 329
        Height = 21
        EditLabel.Width = 133
        EditLabel.Height = 13
        EditLabel.Caption = #1055#1091#1090#1100' '#1076#1086' '#1092#1072#1081#1083#1086#1074' '#1096#1072#1073#1083#1086#1085#1072':'
        TabOrder = 4
        Text = ''
      end
    end
    object tsAbout: TTabSheet
      Caption = #1054' '#1087#1083#1072#1075#1080#1085#1077
      ImageIndex = 1
    end
    object tsLog: TTabSheet
      Caption = 'Log'
      ImageIndex = 2
      object Memo1: TMemo
        Left = 0
        Top = 0
        Width = 386
        Height = 293
        Align = alClient
        TabOrder = 0
      end
    end
  end
  object pnButton: TPanel
    Left = 0
    Top = 321
    Width = 394
    Height = 41
    Align = alBottom
    TabOrder = 1
    ExplicitTop = 251
    object btSave: TButton
      Left = 128
      Top = 8
      Width = 129
      Height = 25
      Caption = #1055#1088#1080#1084#1077#1085#1080#1090#1100
      TabOrder = 0
      OnClick = btSaveClick
    end
  end
end
