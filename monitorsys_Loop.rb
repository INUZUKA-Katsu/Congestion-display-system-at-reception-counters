# -*- coding: Shift_JIS -*-
#--------------------------------------------------------------------------------#
#   保土ケ谷区保険年金課 窓口混雑状況表示システム Ver.3.2 (2015.2.20)            #
#                                                                                #
#              モニターシステム接続監視＆自動再接続編                            #
#                                                                                #
#                        作成    犬塚  克 ( ka00-inuzuka@city.yokohama.jp )      #
#                        著作権  横浜市                                          #
#--------------------------------------------------------------------------------#

Encoding.default_external="Shift_JIS"

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

#****設定ファイルの読込み****
load './config.txt'
load './config_for_development.txt' if [2,3,4,5].include?($test_mode) and $development_mode==true

#****テストモード４のときはここで終了****
if $test_mode==4
  fname=File.basename(__FILE__).force_encoding("Shift_JIS")
  puts "テストモード４なので「#{fname}」は実行しません。"
  exit
end

#****ライブラリの読込み****
require "./Raicholist.rb"

#****開庁時間のセットアップ****
Today   =Time.now.strftime("%Y%m%d")
YobiNum =Time.now.wday
$ku=KaichoJikan.setup(Today)

#****閉庁時間後であるときはここで終了****
if $ku.heicho < Time.now.to_hhmm
  puts "#{Time.now.to_hhmm} 閉庁時刻を過ぎているため終了します。"
  exit
end

#****VcallMonitorオブジェクトセットアップ****
$vcall=VcallMonitor.new

#モニタシステム起動用モジュール
module StartMonitor
  def self.send_mail_by_situation(result)
  #メールメッセージ
    case result
    when :start
      title = "モニタシステム起動（準備完了）"
      body  = "モニタシステムの運用モニタ画面を開きました。準備完了です。"
    when :start_error
      title = "【警告】モニタシステム起動失敗"
      body  = "モニタシステムの運用モニタ画面を表示することができませんでした。"
      body << "手動操作によって運用モニタ画面を表示させてください。"
    end
    send_mail(title,body)
  end
  def self.write_log(result)
  #イベントログに記録
    case result
    when :start
      syubetu = :success
      body    = "【モニタシステム】モニタシステムの運用モニタ画面を開きました。準備完了です。"
    when :start_error
      syubetu = :error
      body    = "【モニタシステム】モニタシステムの運用モニタ画面を開くことができませんでした。このままではホームページに今日の混雑状況を掲載することができません。"
    end
    VcallMonitor.write_event_log(event: syubetu, text: body)
  end
end

#接続監視&自動再接続用モジュール
module AutCon
  def self.send_mail_by_situation(result)
  #メールメッセージ
    case result
    when :first_info
      title = "【警告！】モニタシステムが発券機から切断されました！"
      body  = "発券機の電源が入っていることを確認してからモニタシステムを再起動する必要があります。"
      body << "窓口混雑状況表示システムは、発券機の応答が確認できしだい、モニタシステムを再起動して"
      body << "発券機との再接続を試みます。"
    when :reconnect_error
      title = "【警告！】モニタシステムと発券機を再接続することができません。"
      body = "モニタシステムが発券機から切断されたため自動再接続を試みましたが接続できませんでした。"
      body += "このままではホームページの更新ができないので、すぐに状況を確認して対処してください。"
    when :connect
      title = "【報告】モニタシステムと発券機の再接続成功"
      body = "モニタシステムを再起動し、発券機と再接続しました。"
    when :start_error # 2015.2.20 1st stage で起動できないまま 2nd stage に進んだ場合
      title = "【警告】モニタシステム起動失敗"
      body  = "モニタシステムの運用モニタ画面を表示することができませんでした。"
      body << "手動操作によって運用モニタ画面を表示させてください。"
    end
    send_mail(title,body)
  end
  def self.write_log(result)
  #イベントログに記録
    case result
    when :first_info
      syubetu = :error
      body    = "【モニタシステム】　発券機から切断されました。"
    when :reconnect_error
      syubetu = :error
      body    = "【モニタシステム】　発券機に接続できませんでした。"
    when :ping_error
      syubetu = :error
      body    = "【モニタシステム】　発券機からpingの応答がありません。"
    when :connect
      syubetu = :success
      body    = "【モニタシステム】　ボイスコールモニタシステムを起動し,発券機と再接続しました。"
    end    
    VcallMonitor.write_event_log(event: syubetu, text: body)
  end
end

#例外発生時の終了処理モジュール
module AtRaise
  def self.send_mail_by_situation
  #メールメッセージ
    title = "【モニタシステム】常時監視プログラム終了"
    body  = "モニタシステム常時監視プログラムが終了しました。"
    send_mail(title,body)
  end
  def self.write_log
  #イベントログに記録
    syubetu = :error
    body    = "【モニタシステム】常時監視プログラムが終了しました。"
    VcallMonitor.write_event_log(event: syubetu, text: body)
  end
end
#例外による終了時の処理
END{
  unless $ku.heicho < Time.now.to_hhmm
    AtRaise.send_mail_by_situation
    AtRaise.write_log
  end
}

#********************  モニタシステム起動  ***********************
p "1st stage"
5.times do |i|
  break if $vcall.data_communication_with_hakkenki == "通信中"
  $vcall.stop if $vcall.process_id  #2重起動を避ける
  case $vcall.start
  when :success
    sleep 2
    $vcall.app_activate
    if $vcall.data_communication_with_hakkenki == "通信中"
      StartMonitor.send_mail_by_situation(:start)
      StartMonitor.write_log(:start)
      break
    else
      sleep 5
      next if i<4
      StartMonitor.send_mail_by_situation(:start_error)
      StartMonitor.write_log(:start_error)
      #モニタシステム不起動のまま 2nd stage に進む。
    end
    sleep 1
  when :vcall_path_not_exist
  #設定が間違っていたとき
    popup "モニタシステム起動・常時監視プログラムを終了します。"
    exit
  end
end


#********************  発券機との常時接続監視・自動再接続  ***********************
p "2nd stage"
loop do
  sleep 30
  p Time.now
  next  if $ku.kaicho > Time.now.to_hhmm                           # 開庁時間前は何もせず待機
  break if $ku.heicho < Time.now.to_hhmm                           # 閉庁時間後は終了
  case $vcall.data_communication_with_hakkenki                     # 発券機との通信状況を確認する。
  when "通信中"
    p "通信中"
    next
  when "通信切断"
    sleep 3
    next unless $vcall.data_communication_with_hakkenki=="通信切断" # 念のため3秒待って再確認。
    if $vcall.monitor_started
      mes = :first_info
    else
      mes = :start_error
    end
    AutCon.send_mail_by_situation(mes)                              # やはりダメなら最初の報告メールを送信。
    AutCon.write_log(mes)
    $vcall.restart_vcall_monitor                                    # モニタシステムを再起動
    if $vcall.data_communication_with_hakkenki=="通信中"            # 復旧したか確認
      AutCon.send_mail_by_situation(:connect)
      AutCon.write_log(:connect)
    else
      AutCon.send_mail_by_situation(:reconnect_error)
      AutCon.write_log(:reconnect_error)
    end
  when "回線途絶"                                                  # ping応答もないとき
    sleep 3
    next unless $vcall.data_communication_with_hakkenki=="回線途絶" # 念のため3秒待って再確認。
    AutCon.send_mail_by_situation(:ping_error)
    AutCon.write_log(:ping_error)
  end
end
