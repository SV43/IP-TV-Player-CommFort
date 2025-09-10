object Form2: TForm2
  Left = 0
  Top = 0
  BorderIcons = []
  Caption = #1055#1088#1086#1074#1077#1088#1082#1072' '#1086#1073#1085#1086#1074#1083#1077#1085#1080#1081
  ClientHeight = 128
  ClientWidth = 525
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  Visible = True
  PixelsPerInch = 96
  TextHeight = 13
  object sLabel1: TsLabel
    Left = 48
    Top = 24
    Width = 417
    Height = 18
    Caption = #1054#1073#1085#1086#1074#1083#1077#1085#1080#1077
    ParentFont = False
    Font.Charset = RUSSIAN_CHARSET
    Font.Color = clWindowText
    Font.Height = -16
    Font.Name = 'Arial'
    Font.Style = [fsBold, fsItalic]
  end
  object sProgressBar1: TsProgressBar
    Left = 48
    Top = 64
    Width = 425
    Height = 33
    TabOrder = 0
    SkinData.SkinSection = 'GAUGE'
  end
  object IdHTTP1: TIdHTTP
    OnWork = IdHTTP1Work
    OnWorkBegin = IdHTTP1WorkBegin
    OnWorkEnd = IdHTTP1WorkEnd
    AllowCookies = True
    ProxyParams.BasicAuthentication = False
    ProxyParams.ProxyPort = 0
    Request.ContentLength = -1
    Request.ContentRangeEnd = -1
    Request.ContentRangeStart = -1
    Request.ContentRangeInstanceLength = -1
    Request.Accept = 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'
    Request.BasicAuthentication = False
    Request.UserAgent = 'Mozilla/3.0 (compatible; Indy Library)'
    Request.Ranges.Units = 'bytes'
    Request.Ranges = <>
    HTTPOptions = [hoForceEncodeParams]
    Left = 320
    Top = 8
  end
  object Timer1: TTimer
    Interval = 10000
    OnTimer = Timer1Timer
    Left = 400
    Top = 8
  end
end
