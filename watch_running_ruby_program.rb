# -*- coding: Windows-31J -*-
#---------------------------------------------------------------------------------#
#   保土ケ谷区保険年金課 窓口混雑状況表示システム Ver.3.6 (2020.5.25)             #
#                                                                                 #
#                            常駐プログラム定期監視編                             #
#                                                                                 #
#  ○「mado_Loop.rb」が実行中か確認し、実行中でなければ起動する。                 #
#  ○「monitorsys_Loop.rb」が実行中か調べ、実行中でなければ起動する。             #
#  ○ タスクスケジューラに登録して一定間隔で実行する。                            #
#                                                                                 #
#                        作成    犬塚  克 ( ka00-inuzuka@city.yokohama.jp )       #
#                        著作権  横浜市                                           #
#---------------------------------------------------------------------------------#

Dir.chdir(__dir__)

require "./process_count"

#***** rubyプログラム非同期実行用メソッド *****

def ruby_path
  require 'rbconfig'
  ruby_path = RbConfig.ruby
  if File.exist? ruby_path
    ruby_path
  else
    ruby_path.sub("/bin","")
  end
end

def run(ruby_file)
  str="#{ruby_path} #{ruby_file}"
  wsh = WIN32OLE.new('WScript.Shell')
  wsh.Run(str,0,false)
end


#***** 常駐プログラムを起動（実行中でないとき） *****
rb=Array.new
rb[0] = "monitorsys_Loop.rb"
rb[1] = "mado_Loop.rb"
rb.each do |rb_file|
  unless process_exist? rb_file
    run(rb_file)
    puts "#{rb_file} を実行しました。"
  else
    puts "#{rb_file} は実行中でした。"
  end
end
