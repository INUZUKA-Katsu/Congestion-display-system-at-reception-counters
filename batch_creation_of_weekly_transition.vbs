Option Explicit

Dim mes,ans

mes="�T���Ƃ̐��ڂ̃y�[�W���ꊇ�������܂��B" & vbCRLF & "�u�h�L�������g\�ߋ����O�v�ɕۑ�����Ă��邷�ׂĂ̓��̃y�[�W���쐬����Ƃ��́uall�v���A" & vbCRLF & "����̓����w�肵�Ă��̓����獡���܂ł̃y�[�W���쐬����Ƃ��͂��̓���yyyymmdd�`���i��:20170808�j�œ��͂��Ă��������B"

ans=inputbox(mes,"�T�ʐ��ڃy�[�W�ꊇ�쐬","all")

WScript.CreateObject("WScript.Shell").Run ".\ruby-dist\ruby.exe .\suii.rb " & ans, 0
