Option Explicit

Dim strDate,mes,ans

strDate = Replace(DateAdd("d",-1,Left(Now(),10)), "/", "")

mes="�w�肵�����̃G�N�Z���t�@�C���𐶐����܂��B" & vbCRLF & "�G�N�Z���t�@�C���𐶐�����������yyyymmdd�`���i��:20170808�j�œ��͂��Ă��������B"

ans=inputbox(mes,"�G�N�Z���t�@�C������",strDate)

if not isempty(ans) then
	WScript.CreateObject("WScript.Shell").Run ".\ruby-dist\ruby.exe .\make_Excel.rb " & ans, 0
end if
