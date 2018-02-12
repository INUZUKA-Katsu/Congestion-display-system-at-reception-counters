# -*- coding: Windows-31J -*-
#--------------------------------------------------------------------------------#
#   保土ケ谷区保険年金課 窓口混雑状況表示システム Ver.2.8 (2014.8.15)            #
#                                                                                #
#              モニター用ＰＣログイン監視編                                      #
#                64bit版Windowsと32bit版rubyの組合せでは                         #
#                ログインの判定ができないことが分かっています。                  #
#                                                                                #
#                        作成    犬塚  克 ( ka00-inuzuka@city.yokohama.jp )      #
#                        著作権  横浜市                                          #
#--------------------------------------------------------------------------------#


Encoding.default_external="Windows-31J"

#****作業ディレクトリの設定****
Dir.chdir(__dir__)

#****設定ファイルの読込み****
load './config.txt'
load './config_for_development.txt' if [2,3,4,5].include?($test_mode) and $development_mode==true

#****ライブラリの読込み****
require "./Raicholist.rb"

#****開庁時間のセットアップ****
Today   =Time.now.strftime("%Y%m%d")
YobiNum =Time.now.wday
$ku=KaichoJikan.setup(Today)

#****VcallMonitorオブジェクトセットアップ****
$vcall=VcallMonitor.new

#***** ログイン時モジュール *****
module WatchLogin
  def self.send_mail_by_situation(result)
    case result
    when :switch_on
      title="モニタＰＣ起動(未ログイン)"
      body    = "モニタＰＣ起動しました(まだログインはしていません)。"
    when :login
      title="モニタＰＣログイン"
      body ="ログイン時刻：#{$vcall.login_time}"
    when :login_error
      title="【警告】モニタＰＣにログインしていません。"
      body ="すぐにモニタPCにログインし、モニタシステムを立ち上げてください。"
    end
    send_mail(title,body)
  end
  def self.write_log(result)
    case result
    when :switch_on
      syubetu = :success
      body    = "モニタＰＣ起動しました(まだログインしてません)。"
    when :login
      syubetu = :success
      body    = "モニタＰＣにログインしました。(#{Time.now.to_hhmm})"
    when :login_error
      syubetu = :error
      body    = "モニタＰＣにログインしていません。(#{Time.now.to_hhmm})"
    end
    VcallMonitor.write_event_log(event: syubetu, text: body)
  end
end

#********************  ログイン監視  ***********************
unless $vcall.login?
  WatchLogin.send_mail_by_situation(:switch_on)
  WatchLogin.write_log(:switch_on)
  until $vcall.login?
    #開庁時刻の10分前になってもログインしていないとき、
    #５秒ごとに再確認し、1分ごとに警告メールを発信する。
    now=Time.now
    p now
    if now.to_hhmm >= $ku.kaicho - 10.minute and now.sec < 5
      WatchLogin.send_mail_by_situation(:login_error)
      WatchLogin.write_log(:login_error)
      
    end
    sleep 5
  end
end
WatchLogin.send_mail_by_situation(:login)
WatchLogin.write_log(:login)

