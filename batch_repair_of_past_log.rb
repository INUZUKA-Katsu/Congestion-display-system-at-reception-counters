# -*- coding: Windows-31J -*-
#--------------------------------------------------------------------------------#
#   保土ケ谷区保険年金課 窓口混雑状況表示システム Ver.352 (2017.9.9)             #
#                                                                                #
#          過去ログファイルの修復編                                              #
#                                                                                #
#                        作成    犬塚  克 ( ka00-inuzuka@city.yokohama.jp )      #
#                        著作権  横浜市                                          #
#--------------------------------------------------------------------------------#

Encoding.default_external="Windows-31J"

#***** 設定ファイル、ログファイル等から各種オブジェクトを作成（初期化）する。 *****
require "./ObjectInitialize.rb"
require "./Suii.rb"

#****作業ディレクトリの設定****
Dir.chdir(__dir__)

if ARGV[0] and ARGV[0]=~/^\d{8}$/
  Day     = ARGV[0]
  KakoLog.new(Day..Today,:simple).repair
end
