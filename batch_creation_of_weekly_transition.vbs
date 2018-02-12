Option Explicit

Dim mes,ans

mes="週ごとの推移のページを一括生成します。" & vbCRLF & "「ドキュメント\過去ログ」に保存されているすべての日のページを作成するときは「all」を、" & vbCRLF & "特定の日を指定してその日から今日までのページを作成するときはその日をyyyymmdd形式（例:20170808）で入力してください。"

ans=inputbox(mes,"週別推移ページ一括作成","all")

WScript.CreateObject("WScript.Shell").Run ".\ruby-dist\ruby.exe .\suii.rb " & ans, 0
