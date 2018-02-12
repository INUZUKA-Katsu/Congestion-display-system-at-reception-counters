Option Explicit

Dim strDate,mes,ans

strDate = Replace(DateAdd("d",-1,Left(Now(),10)), "/", "")

mes="指定した日のエクセルファイルを生成します。" & vbCRLF & "エクセルファイルを生成したい日をyyyymmdd形式（例:20170808）で入力してください。"

ans=inputbox(mes,"エクセルファイル生成",strDate)

if not isempty(ans) then
	WScript.CreateObject("WScript.Shell").Run ".\ruby-dist\ruby.exe .\make_Excel.rb " & ans, 0
end if
