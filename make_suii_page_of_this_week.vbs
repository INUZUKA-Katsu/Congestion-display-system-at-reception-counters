Dim str
Dim objFSO
Dim objFile

Set objFSO = WScript.CreateObject("Scripting.FileSystemObject")
Set objFile = objFSO.OpenTextFile("make_suii_page_of_this_week.rb", 2, True)
objFile.WriteLine("#coding: Windows-31J")
objFile.WriteLine("require './suii'")
objFile.WriteLine("make_suii_for_monitor if Myfile.dir(:suii)")
objFile.WriteLine("if defined? $suii_open and $suii_open==:yes")
objFile.WriteLine("  files=make_html_of_week(Today)")
objFile.WriteLine("  ftp_soshin(files,Myfile.dir(:ftp))")
objFile.WriteLine("end")
objFile.WriteLine("popup '今週の推移のページを作成し、アップロードしました。',64,'アップロード終了',5")
objFile.Close
Set objFile = Nothing
Set objFSO = Nothing

WScript.CreateObject("WScript.Shell").Run ".\ruby-dist\ruby.exe .\make_suii_page_of_this_week.rb" , 0

