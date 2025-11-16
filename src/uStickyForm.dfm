object frmStickyForm: TfrmStickyForm
  Left = 457
  Top = 248
  BorderIcons = []
  BorderStyle = bsNone
  Caption = 'IPTV-Plugin Final'
  ClientHeight = 483
  ClientWidth = 979
  Color = clWhite
  DoubleBuffered = True
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  OnCloseQuery = FormCloseQuery
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  OnShow = FormShow
  TextHeight = 13
  object Splitter: TSplitter
    Left = 605
    Top = 0
    Height = 430
    Align = alRight
    ExplicitLeft = 905
    ExplicitTop = -5
    ExplicitHeight = 455
  end
  object Panel_Button: TPanel
    Left = 0
    Top = 430
    Width = 979
    Height = 53
    Align = alBottom
    ParentBackground = False
    PopupMenu = pmMenu
    TabOrder = 0
    object sbBack: TSpeedButton
      AlignWithMargins = True
      Left = 4
      Top = 4
      Width = 45
      Height = 45
      Align = alLeft
      ImageIndex = 4
      HotImageIndex = 0
      Flat = True
      OnClick = sbBackClick
    end
    object sbPlay: TSpeedButton
      AlignWithMargins = True
      Left = 55
      Top = 4
      Width = 45
      Height = 45
      Align = alLeft
      Flat = True
      OnClick = sbPlayClick
      ExplicitTop = 5
    end
    object sbNext: TSpeedButton
      AlignWithMargins = True
      Left = 106
      Top = 4
      Width = 45
      Height = 45
      Align = alLeft
      Flat = True
      OnClick = sbNextClick
    end
    object sbFullScreen: TSpeedButton
      AlignWithMargins = True
      Left = 930
      Top = 4
      Width = 45
      Height = 45
      Align = alRight
      Flat = True
      OnClick = sbFullScreenClick
      ExplicitTop = 5
    end
    object sbOpen: TSpeedButton
      AlignWithMargins = True
      Left = 157
      Top = 4
      Width = 45
      Height = 45
      Align = alLeft
      Flat = True
      OnClick = sbOpenClick
    end
    object sbVolume: TSpeedButton
      AlignWithMargins = True
      Left = 879
      Top = 4
      Width = 45
      Height = 45
      Align = alRight
      Flat = True
      OnClick = sbVolumeClick
      ExplicitLeft = 1010
    end
    object tvVolume: TImageTrackBar
      Left = 676
      Top = 1
      Width = 200
      Height = 51
      Align = alRight
      Position = 100
      OnChange = ImageTrackBar1Change
    end
  end
  object Panel_VLC_Player: TPanel
    Left = 0
    Top = 0
    Width = 605
    Height = 430
    Align = alClient
    Color = clBlack
    Font.Charset = RUSSIAN_CHARSET
    Font.Color = clWhite
    Font.Height = -19
    Font.Name = 'Arial'
    Font.Style = [fsBold]
    ParentBackground = False
    ParentFont = False
    TabOrder = 1
    object FVlc: TVlcPlayer
      Left = 1
      Top = 1
      Width = 603
      Height = 428
      LibPath = 'libvlc.dll'
      UserAgent = 
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KH' +
        'TML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
      HttpHeaders.Strings = (
        'Accept=*/*'
        'Accept-Language=en-US,en;q=0.9'
        'Accept-Encoding=gzip, deflate, br')
      InfoText.FontSize = 10
      InfoText.Y = 408
      OnVideoDblClick = FVlcVideoDblClick
      Align = alClient
      BevelOuter = bvNone
      Color = clBlack
      ParentBackground = False
      PopupMenu = pmMenu
      TabOrder = 0
      OnDblClick = FVlcDblClick
    end
  end
  object Panel_Channels: TPanel
    Left = 608
    Top = 0
    Width = 371
    Height = 430
    Align = alRight
    TabOrder = 2
    object lbChannels: TListBox
      Left = 1
      Top = 1
      Width = 369
      Height = 428
      Style = lbOwnerDrawVariable
      Align = alClient
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -11
      Font.Name = 'MS Sans Serif'
      Font.Style = [fsBold]
      ItemHeight = 80
      ParentFont = False
      PopupMenu = pmMenu
      TabOrder = 0
      OnDblClick = lbChannelsDblClick
      OnDrawItem = lbChannelsDrawItem
    end
  end
  object pmMenu: TPopupMenu
    Left = 248
    Top = 256
    object C1: TMenuItem
      AutoCheck = True
      Caption = #1057#1087#1080#1089#1086#1082' '#1082#1072#1085#1072#1083#1086#1074
      Checked = True
      OnClick = C1Click
    end
    object N1: TMenuItem
      Caption = #1053#1072#1089#1090#1088#1086#1081#1082#1080
      OnClick = N1Click
    end
  end
  object PlayerStatus: TTimer
    Enabled = False
    Interval = 100
    OnTimer = PlayerStatusTimer
    Left = 520
    Top = 280
  end
  object TimeEpgStatus: TTimer
    Interval = 15000
    OnTimer = TimeEpgStatusTimer
    Left = 433
    Top = 193
  end
end
