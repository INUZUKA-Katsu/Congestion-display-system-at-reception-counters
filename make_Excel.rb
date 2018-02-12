# -*- coding: Windows-31J -*-
#--------------------------------------------------------------------------------#
#   保土ケ谷区保険年金課 窓口混雑状況表示システム Ver.352 (2017.9.8)             #
#                                                                                #
#          エクセルファイルマニュアル作成編                                      #
#                                                                                #
#                        作成    犬塚  克 ( ka00-inuzuka@city.yokohama.jp )      #
#                        著作権  横浜市                                          #
#--------------------------------------------------------------------------------#

Encoding.default_external="Windows-31J"

#***** 設定ファイル、ログファイル等から各種オブジェクトを作成（初期化）する。 *****
require "./ObjectInitialize.rb"

#****作業ディレクトリの設定****
Dir.chdir(__dir__)

if ARGV[0] and ARGV[0]=~/^\d{8}$/
  Today     = ARGV[0]
  TimeNow = "23:59"
  log_file=Myfile.dir(:kako_log)+"/"+Today+".log"

  if File.exist?(log_file) and Myfile.dir(:excel)
    $logs=RaichoList.setup(log_file,$mado_array,Today)
    make_xlsx($logs)
    popup Myfile.dir(:suii) + " に保存しました。"
  else
    popup "エラー!\n\""+Today+"\"のログファイルが見つかりません."
  end
elsif ARGV[0]
  popup "日付の指定が間違っていると思われます.yyyymmdd形式の数字8桁で日付を指定してください."
else
  popup "yyyymmdd形式の数字8桁で日付を指定してください."
end

