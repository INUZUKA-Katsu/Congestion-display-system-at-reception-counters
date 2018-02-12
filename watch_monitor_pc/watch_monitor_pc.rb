# -*- coding: Shift_JIS -*-

#*********************************************************************
#*************              ******************************************
#*************   初期設定   ******************************************
#*************              ******************************************
#*********************************************************************

#モニタPCのコンピュータ名
$monitor_pc="YH-99-99999999"

#警告メールの送信元・送信先、メールサーバの指定
$from = "xx-hokennenkin@city.yokohama.jp"
$to   = ["xx-hokennenkin@city.yokohama.jp","xxxxxxxx@docomo.ne.jp"]
$smtp = "smtp.office.ycan"

#開庁時間
$kaicho=Hash.new
$kaicho[:weekday] = "08:45～17:00"   #平日の開庁時間
$kaicho[:weekend] = "09:00～12:00"   #土日の開庁時間

#************* ↑初期設定ここまで ***********************************

Dir.chdir(__dir__)
require "./tools"
require "date"

$today = Date.today
$now   = Time.now.strftime("%H:%M")
#test_mode=true #テストのときは行頭の#を削除する。

#***** テスト(開庁日・時間判定) *********************
if defined?(test_mode) and test_mode==true
  $today = Date.parse("2014/6/13")
  $now   = "08:46"
  def ping_respons(address)
    1
  end
end
#****************************************************

unless defined? $monitor_pc
  warning(:setting_error)
  exit
end

if $today.kaichobi? != true
  puts $today.kaichobi?
  exit
end

if is_kaicho_jikan? == false
  puts "開庁時間ではありません"
  exit
end

address=get_ip_address
if ping_respons(address)==0
  puts "正常です"
else
  puts "モニタＰＣからレスポンスがありません!"
  warning(:server_down)
end
