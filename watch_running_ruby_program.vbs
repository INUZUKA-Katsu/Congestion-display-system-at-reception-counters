Option Explicit

Dim path,objWshShell

Set objWshShell = WScript.CreateObject("WScript.Shell")

path = Replace(WScript.ScriptFullName,WScript.ScriptName,"")

objWshShell.CurrentDirectory = path

WScript.CreateObject("WScript.Shell").Run ".\ruby-dist\ruby.exe .\watch_running_ruby_program.rb", 0