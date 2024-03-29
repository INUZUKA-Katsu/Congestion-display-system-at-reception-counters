# -*- coding: Windows-31J -*-
#--------------------------------------------------------------------------------#
#   保土ケ谷区保険年金課 窓口混雑状況表示システム Ver.3.5 (2019.9.7)            #
#                                                                                #
#                        mado_FTP.rb の繰り返し実行編                            #
#                                                                                #
#         ○常駐してmado_FTP.rbを繰り返し実行する。                              #
#         ○常駐中に重複して起動しようとすると即時終了する。                     #
#                                                                                #
#                        作成    犬塚  克 ( ka00-inuzuka@city.yokohama.jp )      #
#                        著作権  横浜市                                          #
#--------------------------------------------------------------------------------#

#****作業ディレクトリの設定****
Dir.chdir(__dir__)

#***** 二重起動防止 *****
require "./process_count"
rb_file = File.basename(__FILE__)
if process_count(rb_file) > 1
  p "This program process exist."
  puts "終了"
  exit
else
  p "Start resident"
end

#*** mado_FTP.rbを繰り返し実行 ****
require "./Objectinitialize.rb"
interval_second=10
loop do
  load "./mado_FTP.rb"
  Time.loop_count
  sleep interval_second
end
