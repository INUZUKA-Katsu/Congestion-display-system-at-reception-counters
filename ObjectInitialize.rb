# -*- coding: Windows-31J -*-
#--------------------------------------------------------------------------------#
#   保土ケ谷区保険年金課 窓口混雑状況表示システム Ver.353 (2018.3.21)            #
#                                                                                #
#                      <<オブジェクトの生成（初期化）>>                          #
#                                                                                #
#                        作成    犬塚  克 ( ka00-inuzuka@city.yokohama.jp )      #
#                        著作権  横浜市                                          #
#--------------------------------------------------------------------------------#

#*****設定ファイル(confファイルで変数を設定)*****
load "./config.txt"


#*****運用モード****
#テストモードの指定がないときは運用モードとする。
$test_mode=0 until defined? $test_mode


#*****テスト環境用の設定ファイル*****
#     本番環境の共有フォルダが存在しない環境で動作テストするとき、
#     及び発券機に接続していないPCで動作テストするとき使用 
load "./config_for_development.txt" if [2,3,4,5].include?($test_mode) and $development_mode==true


#*****ライブラリの読み込み*****
require "./Raicholist"


#*****設定ファイルの読込み確認ファイル「設定値一覧.txt」を保存（2017.11.5, 2018.3.21 Raicholist.rbを読み込んだ後に移置）*****
ConfigSet.make_table_of_setted_value if [1,2,3,4,5,6].include?($test_mode)


#***** 設定ファイルを元にMadoSysFileクラスオブジェクトを設定(2014.3.31) *****
Myfile=MadoSysFile.setup


#***** 設定ファイルの指定フォルダが存在しないときはフォルダを作成 *****
ConfigSet.setup_dir if test_mode?


#***** 現在日の設定 *****
Today   =Time.now.strftime("%Y%m%d")
YobiNum =Time.now.wday
#p TimeNow


#****窓口番号の配列*****
if $mado_bango.class==String
  $mado_array = $mado_bango.split(",")
  #旧バージョンとの互換性保持(2016.3.8)
else
  $mado_array = $mado_bango
end


#****窓口ごとの番号の割り当てを券番号（KenBango）クラスの変数に格納******
#使い方例：$bango["8"].mini => 301
#          $bango["8"].max  => 600
#          $bango["8"].wariates_su => 300
unless $bango
  ConfigSet.mado_bango_check if test_mode?
  $bango=Hash.new
  $mado_array.each do |mado|
    $bango[mado]=KenBango.parse($ken_bango[mado])
  end
end


#***** 設定ファイルのデータをもとに開庁時刻、閉庁時刻を開庁時間（KaichoJikan）クラスの変数に格納 *****
#使い方例：$ku.kaicho => "08:45"
#          $ku.heicho => "17:00"
$ku=KaichoJikan.setup(Today) unless $ku


#***** 窓口混雑状況メッセージを目安待ち時間（MeyasuMachijikan）クラスの変数に格納 *****
$message=MeyasuMachijikan.parse($jam_message) if defined? $jam_message

#***** 窓口状況による警告(注意喚起)の条件をAlertJokenクラスの変数に格納 2015/10/10*****
AJ=AlertJoken.new($keikoku_joken) if defined? $keikoku_joken


#***** 設定チェック(テストモード６のときのみ) *****
if test_mode?(6)
  exit if ConfigSet.check_all_test_mode6 == false or test_mode?(6)
end

#***** テスト用ログデータのチェック *****
if test_mode?(2,3,4,5)
  ConfigSet.log_file_check
end

#以下はプログラムの動作確認用（テストモード５のとき実行）
#※※※※※※※※※※※※※※※※※※※※※※※※※※※※※※※※※
#***** 来庁者リストオブジェクトの確認（コンソール画面に表示）*****
#※※※※※※※※※※※※※※※※※※※※※※※※※※※※※※※※※
if $test_mode == 5
  #***** 現在時刻の設定 *****
  TimeNow =Time.now.strftime("%H:%M") if String.const_defined?(:TimeNow)==false or Object.class_eval{remove_const :TimeNow}
  #***** ログデータをもとに来庁者リスト(RaichoList)クラスのオブジェクトを作成 *****
  $log=RaichoList.setup(Myfile.file[:log],$mado_array)
  $mado_array.each do |mado|
    p $log[mado][-1] #各窓の最終来庁者オブジェクト
  end
  $mado_array.each do |mado|
    $log[mado].display
  end
  puts "\n来庁者数(来庁者オブジェクトの数) => " << RaichoList.sya_su.to_s
  puts "１時間以内に更新されたか?        => " << RaichoList.update?.to_s
  puts "窓口全体の状況                   => " << RaichoList.state_whole
  puts "窓口全体の待ち人数               => " << RaichoList.machi_su.nin

  puts ""
  alert("来庁者数")
  $mado_array.each do |mado|
    alert(mado+"番窓口:"+$log[mado].sya_su.to_s)
  end
  alert("合   計:" + RaichoList.sya_su.to_s)
  
  puts ""
  alert("平均待ち時間")
  $mado_array.each do |mado|
    alert mado+"番窓口: "+$log[mado].average_machi_hun.to_s+"分"
  end
  
  puts ""
  alert("時間ごとの来庁者数")
  $mado_array.each do |mado|
    (8..17).each do |ji|
      if ji.to_hhmm < TimeNow
        alert "#{mado}番 #{ji.to_s}時台: #{$log[mado].jikan_betsu_sya_su(ji).to_s}人"
      end
    end
  end
end

def 動作テスト
  p RaichoList.last_update_time
  p RaichoList.update?
  p RaichoList.logfile_update_within 50.minute
  p $log["7"].maiji_sya_su($ku)
  RaichoList.events.display
  p RaichoList.events.select{|ev| ev.kubun_code==0}
  RaichoList.part_events("9",:hakken).each{|l| p l}
  RaichoList.part_events("9",:yobidashi).each{|l| p l}
  p $log["9"].current(:yobidashi,TimeNow).id
  RaichoList.part_events.each{|l| p l}

  puts "終了"
end
動作テスト if 1==0

#***** AlertJokenクラスの動作チェック(開発用) *****
def alert_jokenテスト
  p AJ["7"]
  p AJ["7"].by("メール").table.to_a
  p AJ["7"].by("モニター").joken_set_another("next_machi_jikan")
  p AJ["7"].by("モニター").compare("next_machi_jikan").joken_set
end
alert_jokenテスト if 1==0


