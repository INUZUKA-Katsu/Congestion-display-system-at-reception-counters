# -*- coding: Shift_JIS -*-
#--------------------------------------------------------------------------------#
#   保土ケ谷区保険年金課 窓口混雑状況表示システム Ver.2.8 (2014.8.15)            #
#                                                                                #
#                             二重起動防止メソッド編                             #
#                                                                                #
#                        作成    犬塚  克 ( ka00-inuzuka@city.yokohama.jp )      #
#                        著作権  横浜市                                          #
#--------------------------------------------------------------------------------#

#***** 二重起動防止等のためのメソッド *****
require "win32ole"
def process_count(exe_file)
  pids=Array.new
  wmi = WIN32OLE.connect('winmgmts://')
  process_set = wmi.ExecQuery("select * from Win32_Process where CommandLine like '%#{exe_file}%'")
  process_set.each do |item|
    pids << item.ProcessID
  end
  pids.size 
end
def process_exist?(exe_file)
  c=process_count(exe_file)
  if c==0
    false
  else
    true
  end
end
