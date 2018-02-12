# -*- coding: Shift_JIS -*-

#***********************
#      メール送信
#***********************
def send_mail(title,body,to)
  require 'nkf'
  require 'net/smtp'
  to=[to] if to.class==String
  mail_str  =  "From: #{$from}\n"
  mail_str <<  "To: #{to.join(",")}\n"
  mail_str <<  "Subject: #{NKF.nkf("-SMm0j", title)}\n"
  mail_str <<  "Date: #{Time::now.strftime("%a, %d %b %Y %X %z")}\n"
  mail_str <<  "Mime-Version: 1.0\n"
  mail_str <<  "Content-Type: text/plain; charset=ISO-2022-JP\n"
  mail_str <<  "Content-Transfer-Encoding: 7bit\n"
  mail_str <<  "\n\n"
  mail_str <<  "#{NKF.nkf("-Sj", body).force_encoding("Shift_JIS")}\n"
  begin
    Net::SMTP.start( $smtp, 25 ) do |smtp|
      smtp.send_mail mail_str,$from,*to
    end
  rescue
    print "次のメールは送信できませんでした。\n" << title << "\n" << body
  end
  "send"
end

#**************************
#  開庁日かどうかの判定
#**************************
class Date
   require "./holiday_japan"
   def kaichobi?
     day=self
     def week_num(day)
       (day.strftime("%d").to_i-1)/7+1
     end
     if day.wday == 0
       "日曜日"
     elsif day.wday==6
       case week_num(day)
       when 1  ; "第1土曜日"
       when 3  ; "第3土曜日"
       when 5  ; "第5土曜日"
       else    ; true
       end
     elsif not day.strftime("%m%d").between?("0104","1228")
       "年末年始"
     elsif day.national_holiday? == true
       HolidayJapan.name(day)
     else
       true
     end
   end
end

#****************************
#  開庁時刻と閉庁時刻の取得
#****************************
def kaicho_jikan
  if $today.wday.between?(1,5)
    day=:weekday
  else
    day=:weekend
  end
  t=$kaicho[day].split("～")
  {:kaicho=>t[0],:heicho=>t[1]}
end

#*****************************
#  開庁時間内かどうかの判定
#*****************************
def is_kaicho_jikan?
  if $now.between?(kaicho_jikan[:kaicho],kaicho_jikan[:heicho])
    true
  else
    false
  end
end

#*****************************
#  モニタPCのIPアドレス取得
#*****************************
#YCAN接続端末には固定IPアドレスが与えられておらず不意に変更されてしまう
#ことがある。一方、DOS窓が開くのを回避するためにpingではなくWMIのPingStatus
#を利用することとするがWMIのPingStatusはコンピュータ名の引数では動作しない。
#そこで、その日の初回の実行時にコンピュータ名からIPアドレスを取得して
#ファイルに保存し、2回目以降は初回に保存されたアドレスを使用する仕組みとする。
def get_ip_address
  day=$today.strftime("%y%m%d")
  #各日の初回実行時の処理（pingによってipアドレスを取得しファイル保存するとともに、同アドレスを返す。）
  if File.exist?('./ip_addr.txt')!=true or
    day!=File.mtime("./ip_addr.txt").strftime("%y%m%d")
    if `ping #{$monitor_pc} -4`=~/\[(\d+\.\d+\.\d+\.\d+)\]/
      File.write('./ip_addr.txt',$1)
      return $1
    else
      warning(:server_down)
      return false
    end
  #各日の2回目以降の実行時は保存されたアドレスを返す
  else
    return File.read('./ip_addr.txt')
  end
end

#*********************************************************
#  モニタＰＣの応答確認
#  WMI(Windows Management Instrumentation)のメソッドを使用
#*********************************************************
def ping_respons(address)
  require "win32ole"
  wmi = WIN32OLE.connect('winmgmts://')
  respons_set = wmi.ExecQuery("select * from Win32_PingStatus where Address='"+address+"'")
  respons_set.each do |item|
    return item.StatusCode
  end
end

#**************
#  警告メール
#**************
def warning(syubetu)
  if syubetu==:server_down
    body="モニタPCがYCANに接続されていません。PCが起動していないか、又は何らかの通信障害が生じています。\nすぐにシステム管理者に知らせてください。"
    title="【エラー】モニタPCが見つかりません！"
  elsif syubetu==:setting_error
    title="【エラー】モニタPC死活監視"
    body="設定ファイル(config.txt)にモニタPCのコンピュータ名を登録してください。"
  elsif syubetu==:test1
    title="【てすと】モニタPC死活監視"
    body="設定ファイル(config.txt)のモニタPCコンピュータ名の登録OK"
  elsif syubetu==:test2
    title="【てすと】モニタPC死活監視"
    body="モニタPCへのpingは成功しました。"
  end
  send_mail(title,body,$to)
end
