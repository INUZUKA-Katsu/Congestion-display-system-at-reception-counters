# -*- coding: Windows-31J -*-
#--------------------------------------------------------------------------------#
#   保土ケ谷区保険年金課 窓口混雑状況表示システム Ver.3.43 (2017.6.24)                  #
#                                                                                #
#        <<オブジェクト定義、ユーティリティメソッド及びオプション機能>>                    #
#                                                                                #
#                        作成    犬塚  克 ( ka00-inuzuka@city.yokohama.jp )        #
#                        著作権  横浜市                                            #
#--------------------------------------------------------------------------------#

Encoding.default_external="Windows-31J"

require 'fileutils'
require 'net/ftp'
require 'timeout'
require 'win32ole'
require 'time'
require 'logger'
require 'nkf'
require 'net/smtp'
require 'date'
require 'csv'
require './holiday_japan'


#*** マイドキュメントフォルダ ***
wsh = WIN32OLE.new('WScript.Shell')
MYDOC=wsh.SpecialFolders('MyDocuments').encode("Windows-31J")
DESKTOP=wsh.SpecialFolders('Desktop').encode("Windows-31J")
wsh=nil


#*** アラートを表示し、ログに出力する ***
def alert(str)
  print str
  print "\n"
end


#**** ポップアップ ***
#     システム運用中はポップアップを使用しないこと。メッセージに気付かない間システムがストップしてしまう。
#     icon_and_button:  16=>stop,32=>?,48=>!,64=>i
#                       0=>OK,  1=>OK・キャンセル,  3=>はい・いいえ・キャンセル, 4=>はい・いいえ
#     戻り値: 1=>OK, 2=>キャンセル, 6=>はい, 7=>いいえ

def popup(str,icon_and_button=64,title="メッセージ",delay_time=0)
  wsh = WIN32OLE.new('WScript.Shell')
  wsh.Popup(str,delay_time,title,icon_and_button)
end


#*** インプットボックスを表示し、入力値を取得 ***
def get_input(prompt='', title='')
  cmd="InputBox(\"#{prompt}\",\"#{title}\")"
  sc = WIN32OLE.new("ScriptControl")
  sc.language = "VBScript"
  sa = sc.eval(cmd)
  sa
end


#*** フォルダのチェック ***
def dir_check(dir)
  return false if dir==nil
  return false unless defined? dir
  return false unless File.exist? dir
  true
end


class ConfigSet
  #*** ディレクトリチェック（なければ作成する） ***
  def self.setup_dir()
    return @@dir if defined? @@dir
    @@dir=true
    Myfile.dir.each do |key,dir|
      next if dir==nil or key==:ftp
      if make_dir(dir)==:error
        @@dir=false
      end
    end
    Myfile.file.each do |key,file|
      dir=File.dirname(file)
      if dir != "." and make_dir(dir)==:error
        @@dir=false
      end
    end
    @@dir
  end
  def self.make_dir(dir)
    begin
      FileUtils.mkdir_p dir #存在しないときは作る
      :success
    rescue
      if test_mode?(1,3,4,5)
        popup("フォルダ #{dir} を作成することができませんでした。設定ファイルの内容を確認してください。",48,"ディレクトリエラー",30)
      else
        send_mail("【エラー】窓口混雑状況表示システム","フォルダ #{dir} は存在しません。設定ファイルの内容を確認してください。")
      end
      :error
    end
  end
  #config.txt の窓口番号関連変数の整合性チェック（初期設定で間違いやすい）2014.4.4 付加
  def self.mado_bango_check
    return unless test_mode? #テストモードのときのみ実行
    return @@bango if defined? @@bango
    @@bango=true
    if $mado_bango.class==String then
      mado_array=$mado_bango.split(",").sort
      # 旧バージョンとの互換性を保持(2016.3.8)
    else
      mado_array=$mado_bango.sort
    end
    ans=[]
    unless $ken_bango.keys.sort==mado_array
        ans << "「発券番号の割り当て($len_bango)」"
    end
    unless $gyomu.values.sort==mado_array
      ans << "「業務コードと窓口番号の対応($gyomu)」"
    end
    unless AlertJoken.new($keikoku_joken).keys-mado_array==[]
      ans << "「警告条件($keikoku_joken)」"
    end
    if defined? $jam_message
      mado=[]
      $jam_message.each_line do |line|
        next if line =~ /窓口.*待ち人数.*メッセージ/
        mado << $& if line =~ /[^\s]+/
      end
      ans << "$jam_message"         unless mado.uniq.sort==mado_array
    end
    unless ans==[]
      popup "設定ファイルの\n" + ans.join("、") + "\nの窓口番号に不整合があります。\n" +
            "環境設定シート(又はconfig.txt)を開いて修正してください。"
      return false
    end
    @@bango
  end
  #FTPサーバアクセスチェック
  def self.ftp_check
    begin
      ftp = Net::FTP.new
      ftp.connect($ftp_server)
      ftp.login($account,pass())
      ftp.close
      true
    rescue
      false
    end
  end
  #メール送信チェック
  def self.mail_check
    title = "メール送信テスト"
    body  = "窓口混雑状況表示システムからのメール送信テストです。"
    send_mail(title,body) #成功すると:send、心配するとfalseが返る
  end
  #config.txtにテストモード６があるか（最新仕様のconfig.txtか）
  def self.has_test_mode6?
    config=File.read("./config.txt")
    if config.match("テストモード６")
      true
    else
      false
    end
  end
  #テストモード６の場合のオール設定チェック
  def self.check_all_test_mode6
    mes = "窓口番号設定の整合性、指定フォルダの有無、FTPサーバへのアクセス、メール送信環境をチェックします。\n"
    mes << "この確認には相当の時間がかかる場合があります。しばらくお待ちください。"
    popup mes,64,"お待ちください",10

    dir_err  = "フォルダの指定を見直す必要があります。"
    bango_err= "窓口番号に関連する指定に不整合があります。"
    ftp_err  = "FTPサーバに接続できませんでした。FTPサーバのURL、アカウント、パスワードを見直してください。"
    mail_err = "メールサーバに接続できませんでした。SMTPサーバのURL、アカウントを見直してください。"

    res=Hash.new
    res[:dir]  =dir_err   unless setup_dir           #ディレクトリチェック
    res[:bango]=bango_err unless mado_bango_check    #窓口番号チェック
    res[:ftp]  =ftp_err   unless ftp_check           #FTPサーバチェック
    res[:mail] =mail_err  unless mail_check          #メール送信チェック
    if res.size==0
      popup "チェック項目はすべて問題ありませんでした。"
      true
    else
      str=""
      res.each do |key,mess|
        str << mess << "\n"
      end
      popup str
      false
    end
  end
  #ログファイル・ログデータの整合性チェック(テストモード2,3,4,5のとき使用)
  def self.log_file_check
    file =File.expand_path(Myfile.file(:log))
    fname=File.basename(file)
    dir  =File.dirname(file)
    kako_log = "#{Myfile.dir(:kako_log)}/#{Today}.log"
    unless File.exist? file
      popup "ログファイル「#{fname}」が、指定されたフォルダ「#{dir}」にありません。",48,"エラー"
      exit
    end
    log_events=LogEvents.setup(file,Today,:prior_check)
    if log_events.size==0
      if File.exist? kako_log
        FileUtils.cp(kako_log, Myfile.file(:log))
        log_events=LogEvents.setup(file,Today,:prior_check)
      else
        popup "テスト用のログファイル「#{file}」には、テスト用日付 #{$datetime.match(/\d{4}\/\d\d?\/\d\d?/)} のデータがありません。\n" <<
              "テスト用のログファイルが空でないとすれば、config.txt の $datetime をテスト用データに合わせて修正する必要があると思われます。" ,48,"エラー"
        exit
      end
    end
    range=Hash.new
    wariate=nil
    $mado_array.each do |mado|
      mini=log_events.min_bango(mado)
      max =log_events.max_bango(mado)
      range[mado]=[mini,max]
      if mini #データ皆無:mini=nilのときを除く
        wariate=:error unless $bango[mado].range.include? mini
        wariate=:error unless $bango[mado].range.include? max
      end
    end
    if wariate==:error
      mes =  "config.txt の券番号の割り当てと矛盾する券番号がログファイルにあります。\n"
      mes << "配布されたテスト用のログファイルのためだと思われます。\n"
      mes << "一時的に券番号の割り当てを変更してこのままテストを続行しますか？\n"
      mes << "(50秒間経過したときもこのまま続行します。)"
      ans=popup(mes,51,"エラー",50)
      if ans==6
        $mado_array.each do |mado|
          $bango[mado].mini=range[mado][0]
          $bango[mado].max =range[mado][1]
        end
      else
        popup "動作テストを終了します。\n config.txt の券番号の割り当てを点検してください。"
        exit
      end
    end
  end
end


#***** エラーポップアップ＋エラーログ(最新200行を保持。カレントフォルダに作成) *****
END{
  def lotation(file,max_lines=1000) #2017.6.24 記録を200行から1000行に変更
    gyo_su = 0
    f=File.read(file)
    f.each_line do
      gyo_su+=1
    end
    if gyo_su>max_lines
      i=1
      File.open(file,"w") do |f_new|
        f.each_line do |line|
          f_new.print line if i>=gyo_su-max_lines
          i+=1
        end
      end
    end
  end
  logger = Logger.new('error.log')
  logger.level = Logger::ERROR
  if $!
    backtrace=$!.backtrace.map{|s| s.force_encoding("Windows-31J")}.join("\n  ")
    message=$!.message.force_encoding("Windows-31J")
    error_mes="#{$!.class}:#{message}\n  #{backtrace}\n"
    popup(error_mes,16,"エラーのため終了します。",50) unless message=="exit"
    logger.error(error_mes)
  end
  lotation('error.log')
}


#***** メール *****
def send_mail(title,body)
  if test_mode?
    if test_mode?(6) or $smtp_usable==nil or ($smtp_usable and $smtp_usable==true)
      to=$to_on_trial #テスト用アドレスに送信
    else
      #テストモード6以外のとき、又はメール送信環境がないことを$smtp_usable=falseで明示したときはコンソールに表示
      puts "(以下はテストモードで$smtp_usable=nil or falseのときの代替表示)"
      puts title
      puts body
      return :send
    end
  else
    to=$to
  end
  to=[to] if to.class==String
  mail_str  =  "From: #{$from}\n"
  mail_str <<  "To: #{to.join(",")}\n"
  mail_str <<  "Subject: #{NKF.nkf("-SMm0j", title)}\n"
  mail_str <<  "Date: #{Time::now.strftime("%a, %d %b %Y %X %z")}\n"
  mail_str <<  "Mime-Version: 1.0\n"
  mail_str <<  "Content-Type: text/plain; charset=ISO-2022-JP\n"
  mail_str <<  "Content-Transfer-Encoding: 7bit\n"
  mail_str <<  "\n\n"
  mail_str <<  "#{NKF.nkf("-Sj", body).force_encoding("Windows-31J")}\n"
  begin
    Net::SMTP.start( $smtp,25 ) do |smtp|
      smtp.send_mail mail_str,$from,*to
    end
  rescue
    str= "次のメールは送信できませんでした。\n" << title << "\n" << body
    alert str
    popup str if test_mode?(2,3,4,5)
    return false
  end
  :send
end


#***** FTP送信 （2014.4.4 mado_Ftp.rbから移記）*****
def ftp_soshin(files,dir)
  case $test_mode
  when 0,2,7  #本番またはテストモード２、７のとき、FTP送信する。
    cnt_retry=0
    begin
      ftp = Net::FTP.new
      ftp.connect($ftp_server)
      ftp.login($account,pass())
      ftp.passive = true
      ftp.binary  = false
      ftp.chdir(dir) if dir #2017.6.24
    #アップロードでサーバの応答待ちになったとき５秒でタイムアウトにする。
    timeout(5){
      files.each {|file| ftp.put(file)}
    }
      ftp.quit
    rescue Timeout::Error
      cnt_retry+=1
      if cnt_retry<=3
        retry
      else
        title = "【エラー！】窓口混雑状況ホームページのエラー"
        body  = "FTP Timeout! \n"
        body += "３回リトライしましたが、サーバ応答待ちでアップロードできませんでした。\n\n"
        body += "至急の対応が必要です。すぐにシステム担当者に知らせてください。"
        send_mail(title,body)
        popup(body,48,title,2*60+30)
        raise
      end
    rescue => e
        # 2014.5.26 YCAN接続のエラーが生じた場合の警告メッセージを修正
        #（ポップアップ表示を付加等）
        title = "【エラー！】窓口混雑状況ホームページのエラー"
        body  = "ホームページにアップロードできませんでした！\n"
        body += "至急の対応が必要です。すぐにシステム担当者に知らせてください。\n\n"
        body += "原因としてはモニターPCがYCANに接続していない可能性があります。\n"
        body += "又は横浜市のCGIサーバーがダウンしていることも考えられます。\n"
        body += "以下はシステムのエラーログです。\n\n"
        body += e.message.force_encoding("Windows-31J")
        send_mail(title,body)
        popup(body,48,title,2*60+30)
        raise
    end
  when 1,3,4,5
    #テストモード１、３、４又は５のとき、FTPサーバ代替のフォルダ指定があるなら、HTMLファイルをそのフォルダにコピーする。
    if Myfile.dir(:subst)
      FileUtils.cp(files,Myfile.dir(:subst))
      `CopytoMAC.bat` if File.exist? "CopytoMAC.bat"
    end
  end
end


#***** FTPログインパスワードの復号 *****
def pass()
  src = File.open($ftp_pass, "r"){ |f| f.read }
  src.force_encoding("ascii-8bit")
  tmp = []
  src.each_codepoint do |cp|
    tmp << (cp ^ 255)
  end
  tmp.map{|i| i.chr}.join("")
end


#***** 実行中のruby.exeのフルパス *****
def ruby_path
  path=""
  wmi = WIN32OLE.connect('winmgmts://')
  process_set = wmi.ExecQuery("select * from Win32_Process where Name like 'ruby%'")
  process_set.each do |item|
    path=item.CommandLine.match(/[^"]*\.exe/)
  end
  path.to_s.encode("Windows-31J")
end


#***** テストモードの判定 *****
# 例:$test_mode=0のとき、test_mode?=>false,test_mode?(0)=>true
#    $test_mode=3のとき、test_mode?(2,3,4)=>true
def test_mode?(*nums)
  if defined?($test_mode)==false
    false
  elsif nums==[]
    if $test_mode==0
      false
    else
      true
    end
  elsif nums.include? $test_mode
    true
  else
    false
  end
end

#**** 棒グラフのイメージタグ ****
#       引数 bar_type ⇒  :today or :weekly_nin or :weekly_hun
def bar_chart_imgtag(bar_type,su)
  def bar_w(bar_type,su)
    return "1em" if su==0 #width=0でレイアウトが崩れるのを回避
    $bar_width[bar_type].match(/([\d|\.]+)(.*)/)
   ($1.to_f * su).round(2).to_s + $2
  end
  def bar_h(bar_type)
    $bar_height[bar_type.to_s.sub(/_.+/,"").to_sym]
  end
  def image(su)
    return $bar_zero if su==0
    $bar_image
  end
  size  = "width:#{bar_w(bar_type,su)};height:#{bar_h(bar_type)};"
  "<img src=\"#{image(su)}\" alt=\"\" style=\"#{size}\">"
end


class String
  #*** 文字列中の半角数字を全角数字に変換 ***
  def num_to_zenkaku
    self.tr("0-9", "０-９")
  end
  #*** 文字列中の全角数字を半角数字に変換 ***
  def num_to_hankaku
    self.tr("０-９", "0-9")
  end
  #*** "yyyymmdd"から"y年m月d日（曜日）"に変換 ***
  def day_to_jan
    return self unless self.match(/\d{8}/)
    date=Time.parse(self)
    m=date.month.to_s
    d=date.day.to_s
    y=date.yobi
    "#{m}月#{d}日(#{y})"
  end
  #*** "yyyymmdd"から"d日Y曜"に変換 ***
  def day_to_nichiyo
    return self unless self.match(/\d{8}/)
    date=Time.parse(self)
    d=date.day.to_s
    y=date.yobi
    "#{d}日#{y}曜"
  end
  #*** "hh:mm"から"午前/午後 h 時 mm 分"に変換 ***
  def time_to_jan
    return self unless self.match(/\d\d:\d\d/)
    ary=self.split(":")
    if self < "12:00"
      "午前#{ary[0].to_i.to_s}時#{ary[1]}分"
    elsif self=="12:00"
      "正午"
    else
      "午後#{(ary[0].to_i-12).to_s}時#{ary[1]}分"
    end
  end
  def hour
    if self=~/^(\d\d?):\d\d$/
      $1
    else
      self
    end
  end
  def minute
    if self=~/^\d\d?:(\d\d)$/
      $1.to_i.to_s
    else
      self
    end
  end
  #オブジェクトがnilなら「－」を返し、文字列ならそのまま返す。
  #（前段はNilClassでメソッド定義。）
  def nil_to_bar
    self
  end
  #オブジェクトがnilなら「（不明）」を返し、文字列ならそのまま返す。
  #（前段はNilClassでメソッド定義。）
  def nil_to_humei
    self
  end
  #*** "hh:mm"形式の文字列のまま時間計算ができるようにする。
  alias_method :string_add,:+
  def +(second)
    if second.class==Fixnum and self.match(/\d\d?:\d\d/)
      t=Time.parse(self)+second
      t.strftime("%H:%M")
    elsif second.is_a? Fixnum and self.match(/\d{8}/)  #日付の加算 2014.3.31付加
      t=Date.parse(self)+second
      t.strftime("%Y%m%d")
    else
      string_add second
    end
  end
  def -(second)
    if self.match(/\d\d:\d\d/)
      if second.class==Fixnum
        t=Time.parse(self)-second
        t.strftime("%H:%M")
      elsif second.class==String and second.match(/\d\d:\d\d/)
        t=Time.parse(self)-Time.parse(second)
        (t/60).to_i
      elsif second==nil
        0
      end
    elsif self.match(/^\d{8}$/) #日付の引き算 2014.3.31付加
      if  second.is_a? Fixnum
        t=Date.parse(self)-second
        t.strftime("%Y%m%d")
      elsif second.is_a? String and second.match(/^\d{8}$/)
        t=Date.parse(self)-Date.parse(second)
      end
    end
  end
  def seiji  #2014.4.3 付加
    if self.match(/\d\d?:\d\d/)
      m=self.minute.to_i
      if m==0
        self
      else
        self+1.hour-m.minute
      end
    else
      self
    end
  end
  def nan_yobi
    return nil unless self.match(/^\d{8}$/)
    "#{Time.parse(self).yobi}曜日"
  end
  def rinji_kaichobi?
    return nil unless self.match(/^\d{8}$/)
    $rinji_kaichobi.include? self
  end
  def syukujitu?
    return nil unless self.match(/^\d{8}$/)
    Date.parse(self).national_holiday?
  end
  def week_num
    return nil unless self.match(/^\d{8}$/)
    (self[6,2].to_i-1)/7+1
  end
  def dai_nan_yobi
    return nil unless self.match(/^\d{8}$/)
    "第#{week_num.to_s}#{self.nan_yobi}"
  end
  def variation
    return nil unless self.match(/^\d{8}$/)
    v=[self,self.nan_yobi,self.dai_nan_yobi,self.dai_nan_yobi.num_to_zenkaku]
    if $rinji_kaichobi.include? self
      v << "臨時開庁日"
    end
    v
  end
  #例外として開けない窓口の窓口番号配列
  def closed_mado
    return [] unless $closed_mado
    cdays=Array.new
    $closed_mado.each_line do |line|
      cdays << line.chomp.gsub(/("|　)/,"").split
    end
    cdays.select{|d| self.variation.include? d[0]}.map{|d| d[1]}.uniq
  end
  def closed(mado)
    self.closed_mado.include?(mado)
  end
  def kaichobi?
    return nil unless self.match(/^\d{8}$/)
    if $rinji_kaichobi.include? self
      true
    elsif $heichobi_nenmatsu_nenshi.include? self[4,4]
      false
    elsif self.syukujitu? and
          ($heichobi_syukujitu.include? self.nan_yobi or
           $heichobi_syukujitu.include? self.dai_nan_yobi or
           $heichobi_syukujitu.include? self.dai_nan_yobi.num_to_zenkaku)
      false
    elsif $kaichobi.include?  self.nan_yobi or
          $kaichobi.include?  self.dai_nan_yobi or
          $kaichobi.include?  self.dai_nan_yobi.num_to_zenkaku
      true
    else
        false
    end
  end
  def heichobi?
    ! self.kaichobi?
  end
  def kakusyu_kaichobi?
    kakusyu_kaichobi=$kaichobi.select{|day| day=~/第.*曜日/}
    today=self.variation.select{|day| day=~/第.*曜日/}
    unless kakusyu_kaichobi & today == []
      true
    else
      false
    end
  end
  #その日のログファイル
  def log_file
    if self.match(/\d{8}/)
      f=Myfile.dir(:kako_log) + "/" + self + ".log"
      return nil unless File.exist? f
      f
    else
      raise
    end
  end
  #直近の月曜日の日付
  def previous_monday
    if self.match(/\d{8}/)
      day=self
      yobi=Date.parse(day).wday
      if yobi>0
        day-yobi+1
      else
        day-6
      end
    else
      raise
    end
  end
  #当日を含む１週間(月曜から土曜まで)の日付の配列
  def days_of_week
    if self.match(/\d{8}/)
      day=self
      days=[]
      d=day.previous_monday
      (0..5).each do |i|
        days << d+i
      end
      days
    else
      raise
    end
  end
  def this_week?
    if self.match(/\d{8}/)
      self.previous_monday==Today.previous_monday
    else
      raise
    end
  end
  def last_week?
    if self.match(/\d{8}/)
      self.previous_monday+7==Today.previous_monday
    else
      raise
    end
  end
  def kaichojikan
    if self.match(/\d{8}/)
      KaichoJikan.setup(self)
    else
      raise
    end
  end
end


class Numeric
  def minute
    self*60
  end
  def hour
    self*60*60
  end
  def second
    self
  end
  def round(d=0)
    x = 10**d
    if self < 0
      (self * x - 0.5).ceil.quo(x)
    else
      (self * x + 0.5).floor.quo(x)
    end
  end
  def nin
    self.to_s << "人"
  end
end


class Fixnum
  def to_hhmm
    "%02d:00" %self
  end
  def yobi
    ["日","月","火","水","木","金","土"][self]
  end
  #エンコードのエラーになることがあるので回避
  alias_method :to_string,:to_s
  def to_s
    to_string.force_encoding("Windows-31J")
  end
end


class Time
  def yobi
    ["日","月","火","水","木","金","土"][self.wday]
  end
  def to_hhmm
    self.strftime("%H:%M")
  end
  def to_hhmmss
    self.strftime("%H:%M:%S")
  end
  def to_yymmdd
    self.strftime("%Y%m%d")
  end
  #$test_mode=2,3,4,5の場合の現在時
  class << Time; alias real_now now; end
  @@jisa ||= Time.real_now - parse($datetime) if $datetime and test_mode?(2,3,4,5)
  def self.now
    return real_now - @@jisa if defined? @@jisa
    real_now
  end
end


class NilClass
  #該当Raichosyaが存在しない場合を考慮せずに、Raichosyaに対するメソッドを使用可能とする。
  [:time_h,:bango,:id,:time_y,:time_c,:machi_su,:to_a,:time,:machi_hun].each do |method|
    define_method(method) do |*arg|
      if method==:id
        0
      else
        nil
      end
    end
  end
  #RaichoListを時刻の条件で絞り込むとき,nilと時刻の大小比較を可能とする。
  #モニター画面で警告表示等するとき,nilと待ち人数、待ち時間の数値との比較を可能とする。
  [:>,:<,:>=,:<=].each do |name|
    define_method(name) do |arg|
      if arg.class==String and arg.match(/\d\d:\d\d/)
        nil
      elsif arg.class==Fixnum
        nil
      else
        raise NoMethodError,"\"nil #{name} #{arg}\"は無効です。\n",caller
      end
    end
  end
  def nil_to_bar
    "－"
  end
  def nil_to_humei
    "（不明）"
  end
end


#以下は、独自のオブジェクトクラス定義
class VcallMonitor
  attr_reader :login_time, :monitor_started
  def initialize
    @vcall_exe=$vcall_exe
    @vcall_path=$vcall_path
    @vcall_hakkenki_address=$vcall_hakkenki_address
    @login_time=nil
    @monitor_started=nil
  end
  #***** ログインしているかどうか(ログインしているときは@login_timeをセット) *****
  def login?
    begin
      x=`quser`
      if x.class==String and x=~/\d\d?:\d\d?/
        @login_time = $&
        true
      else
        false
      end
    rescue
      #64bi版Windowsと32bit版Rubyの組合せでは quser はエラーになる。
      #エラーになったときは、ログイン後に常駐するrbファイルのプロセスの有無で判定する(2016.9.7)。
      is_running_rb
    end
  end
  def is_running_rb
    if process_id("watch_running_ruby_program.rb") or process_id("mado_Loop.rb") or process_id("monitorsys_Loop.rb")
      @login_time=Time.now.to_hhmm
      true
    else
      false
    end
  end
  #***** Windowsのイベントログの設定(おまけ) *****
  def self.set_event_log
    `runas /user:administrator wevtutil cl Application /bu:Application_bak`
    #***** ウインドウズのアプリケーションイベントログの最大サイズを1024KBに設定する。 *****
    `runas /user:administrator wevtutil sl Application /ms:64`
    #***** ウインドウズのアプリケーションイベントログを上書きモード（古いものから消去）にする。 *****
    `runas /user:administrator wevtutil sl Application /r:false /ab:false`
  end
  #***** Windowsのイベントログに結果を書き込む *****
  def self.write_event_log(event: :error,text: nil)
  #event: :success=>0,:error=>1,:worning=>2,:info=>4
    eh={:success=>0,:error=>1,:worning=>2,:info=>4}
    wsh = WIN32OLE.new('WScript.Shell')
    wsh.LogEvent(eh[event],text)
  end
  #***** アクティブウインドウのタイトルを取得する *****
  def title_of_active_window
    require 'Win32API'
    fore_window = Win32API.new('user32','GetForegroundWindow','','l')
    window_txt = Win32API.new('user32', 'GetWindowText', 'lpi','i')
    gaw=fore_window.call
    if gaw!=0
      buf="\0"*1000
      window_txt.call(gaw,buf,buf.size)
      buf.unpack("A*").first.force_encoding("Windows-31J")
    else
      "取得失敗"
    end
  end
  #***** モニタシステムのプロセスIDを取得 *****
  def process_id(exe_file=@vcall_exe)
    wmi = WIN32OLE.connect('winmgmts://')
    process_set = wmi.ExecQuery("select * from Win32_Process where CommandLine like '%#{exe_file}%'")
    process_set.each do |item|
      return item.Handle
    end
    return nil
  end
  def app_activate
    wsh = WIN32OLE.new('WScript.Shell')
    wsh.AppActivate process_id
  end
  #***** モニタシステム終了 *****
  def stop
    app_activate
    unless title_of_active_window=="取得失敗"
      wsh = WIN32OLE.new('WScript.Shell')
      wsh.SendKeys "{ESC}{ESC}"
      wsh.SendKeys "%fx"
      #wsh.SendKeys "x"
    end
    #ALT→F→Xで穏やかに終了できなかったときはプロセスを強制終了する。
    unless process_id==nil
      wmi = WIN32OLE.connect('winmgmts://')
      process_set = wmi.ExecQuery("select * from Win32_Process where Name='"+@vcall_exe+"'")
      process_set.each do |item|
        item.terminate
      end
    end
  end
  #***** モニタシステム起動 *****
  def start
    unless dir_check @vcall_path.gsub(/\"/,"")
      popup @vcall_path + "は存在しません。パスが正しいかもう一度確認してください。"
      return :vcall_path_not_exist
    end
    wsh = WIN32OLE.new('WScript.Shell')
    wsh.run(@vcall_path,3)
    sleep 5
    if process_id!=nil and wsh.AppActivate(process_id)==true
      wsh.SendKeys "{ENTER}"
      sleep 1
      wsh.SendKeys "{ENTER}"
      sleep 5
      :success
    else
      :failure
    end
  end
  #***** モニタシステム起動処理 ********************************
  #***** 起動の確認ができるまで,最大５回まで起動に(リ)トライする。**
  def start_vcall_monitor
    5.times do |i|
      if start == :success and data_communication_with_hakkenki=="通信中"
        @monitor_started = true #2015.2.19
        return :success
      else
        stop
        sleep 2
      end
    end
    return false
  end
  #***** モニタシステム再起動 *****
  def restart_vcall_monitor
    stop
    start_vcall_monitor
  end
  #*** Windowsイベント情報のCIM形式の日付を通常のローカルタイムに変換する ***
  def cim_to_localtime(cim)
    t=cim.sub(/([\-|\+])(\d\d\d)/) {$1+"0#{($2.to_i/60).to_s}"[-2,2] + "0#{($2.to_i%60).to_s}"[-2,2]}
    Time.parse(t).localtime
  end
  #***** 最新のアプリケーションイベントを取得する。 *****
  #引数 time_zone:指定した直近時間のイベントを検索する（デフォルト値は1時間以内）
  #     type:     エラーログを検索するときは「type:"エラー"」とする。ブランクにするとログタイプによらず検索する。
  #     key_word: 指定したキーワードをメッセージに含む最新のログを検索する。ブランクにすると「【モニタシステム】」を含むログ。
  def get_event(time_zone:1.hour,type:nil,key_word:"【モニタシステム】")
    limit_time = (Time.now.gmtime-time_zone).strftime("%Y/%m/%d %H:%M")
    event_h=Hash.new
    wmi = WIN32OLE.connect('winmgmts://')
    if type!=nil
      event_set = wmi.ExecQuery("select * from Win32_NTLogEvent Where Logfile = 'Application' and Type='#{type}' and TimeWritten>='#{limit_time}' and Message like '%#{key_word}%'")
    else
      event_set = wmi.ExecQuery("select * from Win32_NTLogEvent Where Logfile = 'Application' and TimeWritten>='#{limit_time}' and Message like '%#{key_word}%'")
    end
    event_set.each do |event|
      event_h[event.TimeWritten]=[event.Type,event.Message]
    end
    if event_h.size>0
      time=event_h.keys.max
      return cim_to_localtime(time).to_s + " : " + event_h[time][0] + " : " + event_h[time][1]
    else
      nil
    end
  end
  #シャットダウン
  def shutdown_pc(popup_message,time_before_shutdown)
    start_time=Time.now
    ans=popup(popup_message,65,"業務終了処理完了",time_before_shutdown)
    unless ans==2
      while Time.now<start_time+time_before_shutdown
        sleep 1
      end
      `shutdown.exe /s /f /t 5`
    else
      popup "シャットダウンまでのカウントダウンを中止しました。"
    end
  end
  #発券機からのping応答
  def ping_respons_from_hakkenki
    unless defined? @vcall_hakkenki_address
      popup "設定ファイルに発券機のIPアドレスを登録してください。",10
      return false
    end
    status={
      0 => "Success",
      11001 => "Buffer Too Small",
      11002 => "Destination Net Unreachable",
      11003 => "Destination Host Unreachable",
      11004 => "Destination Protocol Unreachable",
      11005 => "Destination Port Unreachable",
      11006 => "No Resources",
      11007 => "Bad Option",
      11008 => "Hardware Error",
      11009 => "Packet Too Big",
      11010 => "Request Timed Out",
      11011 => "Bad Request",
      11012 => "Bad Route",
      11013 => "TimeToLive Expired Transit",
      11014 => "TimeToLive Expired Reassembly",
      11015 => "Parameter Problem",
      11016 => "Source Quench",
      11017 => "Option Too Big",
      11018 => "Bad Destination",
      11032 => "Negotiating IPSEC",
      11050 => "General Failure"
    }
    wmi = WIN32OLE.connect('winmgmts://')
    respons_set = wmi.ExecQuery("select * from Win32_PingStatus where Address='"+@vcall_hakkenki_address+"'")
    respons_set.each do |item|
      return status[item.StatusCode]
    end
  end
  #発券機からのping応答の有無(念のため最大３回実行)
  def ping_respons_from_hakkenki?
    3.times do
        return true if ping_respons_from_hakkenki=="Success" or $dummy_hakkenki
    end
    false
  end
  #発券機との通信接続状況（netstat）
  #netstatコマンドをDOS窓を開かないで実行して結果を取得するため、
  #WSHのcmdを使用して結果をいったんファイルに書き出す。
  def data_communication_with_hakkenki
    return "通信中" if test_mode?(2,3,4,5)
    wsh = WIN32OLE.new('WScript.Shell')
    wsh.Run("cmd /c netstat -n > #{__dir__}/netstat.txt",0,true)
    f=File.read("#{__dir__}/netstat.txt")
    if f.match /#{@vcall_hakkenki_address}.*ESTABLISHED$/
      "通信中"
    else
      if ping_respons_from_hakkenki?
        "通信切断"
      else
        "回線途絶"
      end
    end
  end
  #***** Rubyプログラムを起動(非同期、終了を待たずに親プロセス終了) *****
  def asynchronous_call(ruby_file)
    if File.exist?(ruby_file)
      str="#{ruby_path} #{ruby_file}"
      wsh = WIN32OLE.new('WScript.Shell')
      wsh.Run(str,0,false)
      puts "「#{ruby_file}」を起動しました。"
    else
      popup "「#{ruby_file}」が見つかりません。"
    end
  end
end


#*** MadoSysFileクラス (2014.4.3) ***
#*** config.txtで指定したファイル名、フォルダーを格納する ***
class MadoSysFile
  def initialize(hinagata=nil,file_name=nil,file=nil,dir=nil)
    @hinagata  = hinagata
    @file_name = file_name
    @file      = file
    @dir       = dir
  end
  def self.setup
    hinagata  = Hash.new
    file_name = Hash.new
    file      = Hash.new
    dir       = Hash.new
    if $hinagata and $hinagata.class==Array  #古い設定形式のとき
      hinagata[:pc]           =$hinagata[0]
      hinagata[:keitai]       =$hinagata[1]
      hinagata[:sumaho]       =$hinagata[2]
      hinagata[:monitor]      =$hinagata_monitor  if defined? $hinagata_monitor
    elsif $hinagata and $hinagata.class==Hash #最新の設定形式のとき
      hinagata[:pc]           =$hinagata[:pc]
      hinagata[:keitai]       =$hinagata[:keitai]
      hinagata[:sumaho]       =$hinagata[:sumaho]
      hinagata[:monitor]      =$hinagata[:monitor]
      hinagata[:suii_hun]     =$hinagata[:suii_hun]
      hinagata[:suii_syasu]   =$hinagata[:suii_syasu]
      hinagata[:suii_machisu] =$hinagata[:suii_machisu]
    end
    if defined? $ftp_save_file and $ftp_save_file.class==Array
      file_name[:pc]          =$ftp_save_file[0]
      file_name[:keitai]      =$ftp_save_file[1]
      file_name[:sumaho]      =$ftp_save_file[2]
      file_name[:monitor]     =$kanai_save_file if defined? $kanai_save_file
    elsif defined? $ftp_save_file and $ftp_save_file.class==Hash
      file_name[:pc]          =$ftp_save_file[$hinagata[0]]
      file_name[:keitai]      =$ftp_save_file[$hinagata[1]]
      file_name[:sumaho]      =$ftp_save_file[$hinagata[2]]
      file_name[:monitor]     =$kanai_save_file if defined? $kanai_save_file
    elsif defined? $save_file_name
      keys = $save_file_name.keys
      file_name[:pc]          =$save_file_name[:pc]
      file_name[:keitai]      =$save_file_name[:keitai]
      file_name[:sumaho]      =$save_file_name[:sumaho]
      file_name[:monitor]     =$save_file_name[:monitor]      if keys.include? :monitor
      file_name[:suii_hun]    =$save_file_name[:suii_hun]     if keys.include? :suii_hun
      file_name[:suii_syasu]  =$save_file_name[:suii_syasu]   if keys.include? :suii_syasu
      file_name[:suii_machisu]=$save_file_name[:suii_machisu] if keys.include? :suii_machisu
    elsif defined? $html_file                                  #最新の設定形式のとき
      keys = $html_file.keys
      file_name[:pc]          =$html_file[:pc]
      file_name[:keitai]      =$html_file[:keitai]
      file_name[:sumaho]      =$html_file[:sumaho]
      file_name[:monitor]     =$html_file[:monitor]           if keys.include? :monitor
      file_name[:suii_hun]    =$html_file[:suii_hun]          if keys.include? :suii_hun
      file_name[:suii_syasu]  =$html_file[:suii_syasu]        if keys.include? :suii_syasu
      file_name[:suii_machisu]=$html_file[:suii_machisu]      if keys.include? :suii_machisu
    end
    file[:monitor]  =$monitor_folder+"/"+$html_file[:monitor] if $monitor_folder and defined? $html_file and $html_file[:monitor]
    file[:log]      =$vcall_data                    if $vcall_data
    file[:log]      =$vcall_data_for_test           if test_mode?(2,3,4,5) and $vcall_data_for_test
    file[:gaikyo]   =MYDOC+"/"+$gaikyo              if $gaikyo
    if $topic
      if File.dirname($topic)=="."
        file[:topic]    =DESKTOP+"/"+$topic
      else
        file[:topic]    =$topic
      end
    end
    dir[:current]   =__dir__.encode("Windows-31J")
    dir[:temp]      =dir[:current]+"/"+$temp_folder if $temp_folder
    dir[:subst]     =$substitute_folder             if $substitute_folder
    dir[:ftp]       =$ftp_dir                       if $ftp_dir
    dir[:kako_log]  =MYDOC+"/"+$logfolder           if $logfolder
    dir[:log_backup]=$log_backup_folder             if $log_backup_folder
    dir[:excel]     =$excel_folder                  if $excel_folder
    dir[:monitor]   =$monitor_folder                if $monitor_folder
    dir[:suii]      =$suii_folder                   if $suii_folder
    dir[:suii]    ||=$monitor_folder                if $monitor_folder
    def self.sub_mydoc(path)
      h={ "マイドキュメント"  => MYDOC,
          "ドキュメント"      => MYDOC,
          "My Documents"      => MYDOC,
          "MyDocuments"       => MYDOC,
          "Documents"         => MYDOC,
          "デスクトップ"      => DESKTOP,
          "Desktop"           => DESKTOP }
      return path if path==nil
      path.sub(/^(#{h.keys.join("|")})/){h[$1]}
    end
    [hinagata,file,dir].each {|h| h.each{|k,v| h[k]=sub_mydoc(v)}}
    self.new(hinagata,file_name,file,dir)
  end
  def hinagata(key=nil)
    if key==nil
      @hinagata
    else
      @hinagata[key]
    end
  end
  def file_name(key=nil)
    if key==nil
      @file_name
    else
      @file_name[key]
    end
  end
  def file(key=nil)
    if key==nil
      @file
    else
      @file[key]
    end
  end
  def dir(key=nil)
    if key==nil
      @dir
    else
      @dir[key]
    end
  end
  def temp_file(key)
    @dir[:temp]+"/"+@file[key]
  end
  def keys_of_suii #2014.6.25 追加
    $hinagata.keys.select{|key| key.to_s=~/suii/}
  end
end


#*** 券番号クラス ***
class KenBango
  attr_accessor :mini,:max
  def initialize(mini=nil,max=nil)
    @mini = mini
    @max  = max
  end
  def self.parse(ken_bango)
      ary = ken_bango.split("～")
      mini=ary[0].to_i
      max =ary[1].to_i
      self.new(mini,max)
  end
  def wariate_su
    @max-@mini+1
  end
  def range
    @mini..@max
  end
end


class KaichoJikan
  attr_reader  :kaicho,:heicho
  @@yobi_jikan=nil
  def initialize(kaicho_jikoku=nil,heicho_jikoku=nil)
    @kaicho=kaicho_jikoku
    @heicho=heicho_jikoku
  end
  def self.yobi_jikan
    return @@yobi_jikan if @@yobi_jikan
    @@yobi_jikan=Hash.new
    $kaicho_jikan.each_line do |line|
      next if line.match(/^\s*$/)
      ary=line.chomp.gsub("　","").split
      unless ary[1].match(/\d\d?:\d\d?～\d\d?:\d\d?/)
        config_error
      end
      @@yobi_jikan[ary[0]]=ary[1]
    end
    @@yobi_jikan
  end
  def self.config_error
    if test_mode? #動作テストのとき
      popup "【エラー】窓口混雑状況表示システム\n開庁時間の指定形式に誤りがあります。設定ファイル(config.txt)を見直してください。"
    else
      send_mail("【エラー】窓口混雑状況表示システム","開庁時間の指定形式に誤りがあります。設定ファイル(config.txt)を見直してください。")
    end
    raise
  end
  def self.kaicho_jikan(day)
    #該当する曜日,特定日付がないときは開庁日かどうかを追求せず、
    #"臨時開庁日"の開庁時間をセットする。
    yobi  =day.yobi
    yymmdd=day.to_yymmdd
    key  =yobi_jikan.keys.find{|k| k[0]==yobi}
    key  =yymmdd if yobi_jikan.key? yymmdd
    key||="臨時開庁日"
    yobi_jikan[key]
  end
  def self.setup(today=nil)
    return setup_for_old_config(today) if $kaicho_jikan_weekday
    unless today
      day=Time.now
    else
      day=Time.parse(today)
    end
    self.parse(kaicho_jikan(day))
  end
  #旧仕様のconfig.txtの場合
  def self.setup_for_old_config(today)
    today=Today if today==nil
    yobi  = Time.parse(today).wday
    if defined? $rinji_kaichobi and $rinji_kaichobi==today
    #臨時開庁日
      if defined? $kaicho_jikan_rinji_kaichobi
        self.parse($kaicho_jikan_rinji_kaichobi)
      else
        #臨時開庁日の開庁時間の指定がないとき土曜日の開庁時間を準用
        self.parse($kaicho_jikan_sat)
      end
    elsif yobi.between?(1,5)
    #平日（臨時開庁日でない月～金）
      self.parse($kaicho_jikan_weekday)
    else
    #土曜開庁日（臨時開庁日及び月～金以外）
      self.parse($kaicho_jikan_sat)
    end
  end
  def self.parse(str)
    kai,hei = str.split("～")
    kaicho = Time.parse(kai).strftime("%H:%M")
    heicho = Time.parse(hei).strftime("%H:%M")
    self.new(kaicho,heicho)
  end
  def mai_seiji #2014.3.31 付加
    st=@kaicho.seiji
    if @heicho.match(/:00/)
      ed=@heicho
    else
      ed=@heicho.seiji-1.hour
    end
    t=st
    ary=Array.new
    while t<=ed
      ary.push t
      t=t+1.hour
    end
    ary
  end
  def mai_ji #2014.3.31 付加
    st=@kaicho.hour.to_i
    ed=@heicho.hour.to_i
    t=st
    ary=Array.new
    while t<=ed
      ary.push t
      t=t+1
    end
    ary
  end
  def kaicho_jikan?(time)
    if (@kaicho..@heicho).include?(time)
      true
    else
      false
    end
  end
end


#*** 目安待ち時間クラス ***
class MeyasuMachijikan
  attr_accessor :jamm_mess_ary
  def initialize(jamm_mess_ary)
    @jamm_mess_ary=jamm_mess_ary
  end
  def self.parse(string)
    ary=[]
    string.each_line do |line|
     ary << line.chomp.gsub("　","").split
    end
    self.new(ary)
  end
  def meyasu_jikan(mado,machisu)
    #2014.3.27 設定ファイル(config.txt)に目安待ち時間のメッセージが
    #          登録されていない場合のエラーを回避する処理を追加。
    begin
      @jamm_mess_ary.find{|m,n,mess| m==mado and n.to_i<=machisu}[2]
    rescue
      ""
    end
  end
end


#*** ログイベントクラス(イベントの配列オブジェクト) ***
class LogEvents
  include Enumerable
  attr_reader :events #Eventクラスオブジェクトの配列
  def initialize(events)
    @events=events
  end
  def self.setup(log_file,day,mode=nil)
    return self.new(nil) if log_file==nil
    line_ary=[]
    sym={$kubun["発券"]=>:hakken,$kubun["呼出"]=>:yobidashi,$kubun["キャンセル"]=>:cancel}
    f=File.read(log_file).each_line do |line|
      date,time,kubun_code,gyomu_code,bango = line.chomp.split(",")
      next if date!=day
      break if test_mode? and mode==nil and log_file==Myfile.file(:log) and time>TimeNow
      #↑テストモードで指定フォルダのログを処理するときは現在時後のログデータは読まない。
      mado=$gyomu[gyomu_code]
      bango=bango.to_i
      kubun_code=kubun_code.to_i
      if mado==nil
        msg =  "ログファイル中に未定義の業務番号「#{gyomu_code}」があります。\n"
        msg << "config.txtの窓口番号と業務番号の設定を見直してください。"
        popup msg
        exit
      end
      next if error_data?(log_file,mado,bango,mode)
      line_ary << Event.new(time,kubun_code,sym[kubun_code],mado,bango)
    end
    #Prolog.csvは時刻同一の場合に番号が逆転する場合があるのでソートする。
    line_ary=sort(line_ary)
    self.new(line_ary)
  end
  #*** ソート *** 2014.10.27 inuzuka
  # 時刻、イベント区分コード、番号をキーにして昇順に並び替え
  # 但し、同一時刻に最終番号から最小番号に戻ったときは番号の降順を維持する。
  def self.sort(line_ary)
    $mado_array.each do |mado|
      max=$bango[mado].max
      times=line_ary.select{|event| event.kubun_code==0 and event.bango==max}.map{|event| event.time}
      times.each do |t|
        line_ary=line_ary.map do |event|
          if event.time==t and event.kubun_code==0
            if event.bango > max-20
              event.time=event.time+"0"
            else
              event.time=event.time+"1"
            end
          end
          event
        end
      end
    end
    line_ary.sort_by do |event|
      [event.time,event.kubun_code,event.bango]
    end.map do |event|
      event.time=event.time[0,5]
      event
    end
  end
  #*** 窓口番号と番号の整合性チェック ***
  def self.error_data?(log_file,mado,bango,mode)
    return false if $bango[mado].range.include? bango  #問題ないとき
    return false if mode==:prior_check                 #事前チェックのときはとりあえず全て読み込む
    return true unless test_mode?                      #本番ではエラーデータはスキップして読込継続
    #テストモードのときはエラーメッセージを表示して実行中断する。
    data_error(log_file,mado,bango)
  end
  #*** テストモードのときの警告表示。
  def self.data_error(log_file,mado,bango)
    err_mess  = "#{mado}番窓口に割当てられた番号範囲外の番号 #{bango.to_s}"
    err_mess += " がログファイル( #{log_file} )にあるためプログラムの実行を中止しました。"
    popup err_mess,48,"エラー"
    exit
  end
  def each
    @events.each do |ev|
      yield ev
    end
  end
  def size
    return 0 if @events==nil
    @events.size
  end
  def display
    self.each do |ev|
      p ev.to_a
    end
  end
  def max_bango(mado)
    self.select{|event| event.mado==mado}.max_by{|event| event.bango}.bango
  end
  def min_bango(mado)
    self.select{|event| event.mado==mado}.min_by{|event| event.bango}.bango
  end
end


#*** イベントクラス（個々のイベントログ） ***
class Event
  attr_accessor :time,:kubun_code,:kubun,:mado,:bango
  def initialize(time,kubun_code,kubun,mado,bango)
    @time,@kubun_code,@kubun,@mado,@bango = time,kubun_code,kubun,mado,bango
  end
  def to_a
    [@time,@kubun_code,@kubun,@mado,@bango]
  end
end


#*** 来庁者クラス ***
class RaichoSya
  attr_accessor :time_h, :bango, :id, :time_y, :time_c,  :machi_su
  def initialize(time_h=nil, bango="－", id=0, time_y=nil, time_c=nil, machi_su="…")
    @time_h = time_h
    @bango  = bango
    @id     = id
    @time_y = time_y
    @time_c = time_c
    @machi_su = machi_su
    yield self if block_given?
  end
  def to_a
    [@time_h, @bango, @id, @time_y, @time_c, @machi_su]
  end
  def time(kubun)
    case kubun
    when :hakken    ; @time_h
    when :yobidashi ; @time_y
    when :cancel    ; @time_c
    when :yobidashi_or_cancel
      return nil     if @time_y==nil and @time_c==nil
      return @time_c if @time_y==nil
      @time_y
    end
  end
  def hakken_time(*arg)  #2015.1.18追加
    #  @time_h==nilのときの戻り値
    #  引数(arg)…:explain   => "(不明)"
    #              else case =>   "…"
    return express_unknown(arg)  if @time_h==nil
    @time_h
  end
  def yobidashi_time(*arg)  #2015.1.18追加
    #  @time_y==nilのときの戻り値
    #  引数(arg)…:explain            =>"(キャンセル)","(待ち中)"
    #             :explain and :ended =>"(キャンセル)","(不明)"
    #             :ended              =>     "－"     ,  "…"
    #              else case          =>     "－"     ,  "－"
    return express_cancel(arg)  if @time_c!=nil
    return express_waiting(arg) if @time_y==nil
    @time_y
  end
  def machi_su_nin  #2015.1.18追加
    return @machi_su if @machi_su=="…"
    @machi_su.to_s + "人"
  end
  def machi_hun
    return nil             if @time_h == nil
    return @time_y-@time_h if @time_y != nil
    return @time_c-@time_h if @time_c != nil
    TimeNow-@time_h
  end
  def express_waiting_time(*arg)  #2015.1.18追加
    #arg…:explain=>"(キャンセル)","(不明)"
    #     :hun=>"○分"
    #     :keika=>"○分経過"
    return express_cancel(arg)    if @time_c!=nil
    return express_unknown(arg)   if @time_h==nil
    if     arg.include?(:keika) ; self.machi_hun.to_s + "分経過"
    elsif  arg.include?(:hun)   ; self.machi_hun.to_s + "分"
    else                        ; self.machi_hun.to_s
    end
  end
  def express_waited_time(*arg)  #2015.1.18追加
    #arg…:explain=>"(キャンセル)","(不明)"
    #     :hun=>"○分"
    return express_cancel(arg)   if    @time_c!=nil
    return express_unknown(arg)  if    @time_h==nil or @time_y==nil
    if     arg.include?(:hun) ;  self.machi_hun.to_s + "分"
    else                      ;  self.machi_hun.to_s
    end
  end
  def express_cancel(*arg)  #2015.1.18追加
    arg.flatten.include?(:explain)  ? "(キャンセル)" : "－"
  end
  def express_unknown(*arg)  #2015.1.18追加
    arg.flatten.include?(:explain) ?  "(不明)"       : "…"
  end
  def express_waiting(*arg)  #2015.1.18追加
    return "(不明)"   if ([:explain,:ended]-arg.flatten).empty?
    return   "…"     if arg.flatten.include?(:ended)
    return "(待ち中)" if arg.flatten.include?(:explain)
    "－"
  end
end


#*** 来庁者リストクラス ***
class RaichoList
  include Enumerable
  attr_accessor :log_file,:mado,:raicholist,:day
  def initialize(log_file=nil,mado=nil,day=nil,raicholist=[])
    @log_file=log_file
    @mado=mado
    @day=day
    @raicholist=raicholist
  end
  def self.setup(log_file,mado_array,day=Today)
    @@list=Array.new
    logs=Hash.new
    log_file=nil if File.exist?(log_file)==false
    mado_array.each do |mado|
      logs[mado] = self.new(log_file,mado,day)
      @@list << logs[mado]
    end
    events=LogEvents.setup(log_file,day)
    #*** 発券データを元に来庁者オブジェクトを生成しリストに追加する(番号が跳ぶときは補完する)。***
    events.each do |event|
      if event.kubun==:hakken
        logs[event.mado].add_raichosya(event.bango,event.time)
      end
    end
    #*** 呼出データとキャンセルデータの時刻を来庁者オブジェクトに追記する。
    events.each do |event|
      if event.kubun==:yobidashi or event.kubun==:cancel
        logs[event.mado].add_time(event.time,event.kubun,event.bango)
      end
    end
    #*** 来庁者オブジェクトに発券時の待ち人数を追記する。
    @@list.each do |logs|
      logs.add_machi_su
    end
    logs
  end
  #※※※※※※※※※ ↓セットアップ用メソッド↓ ※※※※※※※※※※※※※
  #*** 新しい来庁者オブジェクトを追加する ***
  #*** (飛び番号があったときは補完する)   ***
  def add_raichosya(bango,time_hakken=nil,time_yobidashi=nil,time_cancel=nil)
    until bango==self.last_bango
      self.add_next_bango
    end
    self[-1].time_h = time_hakken
    self[-1].time_y = time_yobidashi
    self[-1].time_c = time_cancel
  end
  #*** 次の発券番号の来庁者オブジェクトを追加する ***
  def add_next_bango
    sya=RaichoSya.new do |sya|
      sya.bango = self.next_bango
      sya.id    = self.next_id
    end
    @raicholist << sya
  end
  def last_bango
    self[-1].bango
  end
  def last_id
    return 0 if @raicholist.size==0
    self[-1].id
  end
  def next_bango
    last=self.last_bango
    mini=$bango[self.mado].mini
    max =$bango[self.mado].max
    return mini if last==nil or last==max
    last+1
  end
  def next_id
    self.last_id+1
  end
  #*** ログの呼出時刻を来庁者オブジェクトに付加 ***
  def add_time(time,kubun,bango)
    list=self.reject_sya_hakkened_after(time)
    sya=list.select{|sya| sya.bango==bango and sya.time(:yobidashi_or_cancel)==nil}[-1]
    if sya!=nil
      case kubun
      when :yobidashi  ; sya.time_y=time #同一番号が複数ある場合を考慮
      when :cancel     ; sya.time_c=time
      end
    else
      #発券データの取りこぼしがあったときは来庁者データを付加
      #(add_raichosyaに飛び番の補完機能を入れたので不要になったと思われる。)
      case kubun
      when :yobidashi; self.add_raichosya(bango,nil,time,nil) if isdropped?(bango,time)
      when :cancel   ; self.add_raichosya(bango,nil,nil,time) if isdropped?(bango,time)
      end
    end
  end
  #指定時刻より後に発券したsyaを除外した来庁者リストオブジェクト
  #(発券時刻不明のsyaがあることを考慮している。）
  def reject_sya_hakkened_after(time)
    id=self.find{|sya| sya.time(:hakken)>time}.id
    if id==0 #指定時刻より後に発券したsyaがない場合
      self
    else
      reject{|sya| sya.id>=id}
    end
  end
  def isdropped?(bango,time)
    sya=self.find{|sya| sya.bango==bango and sya.id>(last_hakken_id-50)}
    return true if last_hakken_time < time and sya==nil
    false
  end
  def last_hakken_time
    self.select{|sya| sya.time(:hakken)!=nil}[-1].time(:hakken)
  end
  def last_hakken_id
    self.select{|sya| sya.time(:hakken)!=nil}[-1].id
  end
  #*** 発券時の待ち人数を来庁者オブジェクトに付加する ***
  def add_machi_su
    self.each do |sya|
      sya.machi_su = self.machi_su(sya.id) if sya.time(:hakken)
    end
  end


  #※※※※※※※※※※  基礎ツール的メソッド ※※※※※※※※※※※※
  def add_list(list)
    @raicholist=list
  end
  #*** 来庁者オブジェクトの配列をコンソール画面に展開する。 ***
  def display
    alert "来庁者リストオブジェクト(#{self.mado}番窓口)"
    self.each{|sya| alert(sya.to_a)}
  end
  #*** 各窓口のRaichoListオブジェクトを順次処理する ***
  def self.each
    @@list.each do |raicholist|
      yield raicholist
    end
  end
  #*** 各Raichosyaオブジェクトを順次処理する ***
  def each
    @raicholist.each do |sya|
      yield sya
    end
  end
  #*** selectの戻り値をRaichoListクラスオブジェクトにする
  def select
    RaichoList.new(@log_file,@mado,@day,super)
  end
  #*** rejectの戻り値をRaichoListクラスオブジェクトにする
  def reject
    RaichoList.new(@log_file,@mado,@day,super)
  end
  def self.log_file
    if @@list.size>0
      @@list[0].log_file
    else
      Myfile.file(:log)
    end
  end

  #※※※※※※※※※※  来庁者リストの部分集合 ※※※※※※※※※※※※※※

  #*** 発券時刻と呼出し時刻のある来庁者の来庁者リストオブジェクト（2014.3.31付加） ***
  def complete
    self.select{|sya| sya.time(:hakken)!=nil and sya.time(:yobidashi)!=nil}
  end
  #***** 呼出し待ちの来庁者の来庁者リストオブジェクト ******
  def not_called
    self.select{|sya| sya.time(:yobidashi)==nil and sya.time(:cancel)==nil}
  end
  #***** 指定したidの来庁者オブジェクトを削除する(2014.4.13) *****
  def reject_id(id)
    self.reject{|sya| sya.id==id}
  end


  #※※※※※※※※※※  特定の来庁者オブジェトを返す ※※※※※※※※※※※※

  #*** 指定id番号(id=-1のときは最終id)の来庁者オブジェクト ***
  def [](id)
    return self.max_by{|sya| sya.id} if id==-1
    self.find{|sya| sya.id==id}
  end
  #*** 直近の来庁者オブジェクト ***
  def current(kubun,time=TimeNow)
    last=last_time(kubun,time)
    return RaichoSya.new() if last==nil
    sya=self.select{|sya| sya.time(kubun)==last}.max_by{|sya| sya.id}
  end
  def hakken_sya_just_before(time=TimeNow)
      current(:hakken,time)
  end
  def yobidashi_sya_just_before(time=TimeNow)
      current(:yobidashi,time)
  end
  #*** 次に呼び出す予定の来庁者オブジェクト ***
  def next_call(time=TimeNow)
    id=self.yobidashi_sya_just_before(time).id
    sya=self.find{|sya| sya.id>id and sya.time(:yobidashi)==nil and sya.time(:cancel)==nil}
#    sya ? sya : RaichoSya.new
  end

  #※※※※※※※※※※  人数を調べる ※※※※※※※※※※※※

  #*** 指定時刻の待ち人数 ***
  def machi_su(time_or_id=TimeNow)
    case time_or_id
    when 0 #RaichoSyaが空データのとき（飛び番号の補完データのときなどはid=0となる）
      return nil
    when String ; time = time_or_id
      hakken_id    = hakken_sya_just_before(time).id
      yobidashi_id = yobidashi_sya_just_before(time).id
    when Fixnum ; id   = time_or_id
    #特定の来庁者に着目した待ち人数の考え方
    #当該来庁者に発券した結果として、発券機の待ち人数の表示がx人になったとき
    #原則として当該来庁者にとっての待ち人数もx人とする。自分自身を待ち人数に
    #カウントするのは一見不合理ようだが、通常は窓口で現在受付中の人が終わるの
    #待つ必要があるので、自分の前に待っている人＋受付中の1人と考えればよい。
    #例外として、発券時刻＝呼出時刻の場合は、窓口が空いていたとみなせるので
    #待ち人数ゼロとする。
      hakken_id    = id
      yobidashi_id = yobidashi_sya_just_before(self[id].time(:hakken)).id
      # ↑指定idの人の発券時刻＝呼出時刻のとき、yobidashi_id=idになる。
      time         = self[id].time(:hakken)
    end
    canceled     = canceled(yobidashi_id,hakken_id,time) #2014.7.22
    su=hakken_id-yobidashi_id-canceled
    su=0 if su<0  #起動の遅れなどで発券時刻が記録されていないケース等
    su
  end
  def machi_su_nin(time_or_id=TimeNow)
    if time_or_id==TimeNow
      @machi_su_nin ||= self.machi_su(time_or_id).to_s + "人"
    else
      self.machi_su(time_or_id).to_s + "人"
    end
  end
  #*** 直前の待ち人数(直前3分間の最多待ち人数) ***
  def max_machi_su_within_3minutes
    if defined? @max_machi_su_within_3minutes
      @max_machi_su_within_3minutes
    else
      su=[]
      [1,2,3].each do |hun|
        su << self.machi_su(TimeNow-hun)
      end
      @max_machi_su_within_3minutes=su.max
    end
  end
  #*** 来庁者数１ id番号から計算する（実際の来庁者数に最も近い） ***
  def sya_su(time=TimeNow)
    unless @raicholist.size==0
      h=current(:hakken,time).id
      y=current(:yobidashi,time).id
      c=current(:cancel,time).id
      [h,y,c].max
    else
      0
    end
  end
  #*** 来庁者の数２ 何らかの時刻の記録のある来庁者 ***
  #（データの取りこぼしがあると時刻のない来庁者オブジェクトができることがある。）
  def size(time=TimeNow)
    l=self.select do |sya|
      sya.time(:hakken) <= time or sya.time(:yobidashi) <= time or sya.time(:cancel) <= time
    end
    l.raicholist.size
  end
  #*** ○時台の来庁者数(引数：9時台=>9,13時台=>13) ***
  def jikan_betsu_sya_su(ji)
    id1=self.current(:hakken,ji.to_hhmm-1.minute).id
    id2=self.current(:hakken,(ji+1).to_hhmm-1.minute).id
    if id2==nil
      0
    elsif id1==nil
      id2
    else
      id2-id1
    end
  end
  #**** id1とid2の間でキャンセルした来庁者の数 (2014.7.22時刻条件を付加)***
  def canceled(id1,id2,time=TimeNow)
    mado=self.mado
    i=[id1,id2]
    self.select{|sya| sya.time(:cancel)<=time}.count{|sya| sya.id>=i.min and sya.id<=i.max}
  end
  #*** 指定時刻における全窓口の合計来庁者数 ***
  def self.sya_su(time=TimeNow)
    su=0
    @@list.each do |raicholist|
      su+=raicholist.sya_su(time)
    end
    su
  end
  #*** 指定時刻における全窓口の合計待ち人数 ***
  def self.machi_su(time=TimeNow)
    su=0
    @@list.each do |raicholist|
      su+=raicholist.machi_su(time)
    end
    su
  end
  def self.machi_su_nin(time=TimeNow)
    self.machi_su(time).to_s + "人"
  end
  #*** 次に呼び出す来庁者の発券時の待ち人数 2015.10.24 ***
  def next_machi_su
    self.next_call.machi_su
  end
  #※※※※※※※※※※  時刻、時間を調べる ※※※※※※※※※

  #*** 来庁者オブジェクトに記録された最終(発券/呼出/キャンセル)時刻 ***
  def last_time(kubun,time=TimeNow)
    self.select{|sya| sya.time(kubun)<=time}.max_by{|sya| sya.time(kubun)}.time(kubun)
  end
  #*** 最新のデータ更新時刻（窓口別） ***
  def last_update_time
    map{|sya| [sya.time(:hakken),sya.time(:yobidashi),sya.time(:cancel)]}.flatten.reject{|t| t==nil}.max
  end
  #*** 最新のデータ更新時刻（全窓口） ***
  def self.last_update_time
    time=[]
    RaichoList.each do |list|
      t = list.last_update_time
      time << t unless t==nil  #2015.2.20 条件を付加
    end
    time.max
  end
  #*** 次に呼び出す来庁者の現在の待ち時間 2015.1.15 ***
  def machi_jikan(time=TimeNow)
    sya = self.next_call
    return nil if sya.id==0
    time - sya.time(:hakken)
  end
  #*** 直前の呼出しからの経過時間（窓口別） 2015.1.12 ***
  def keika_jikan(time=TimeNow)
    hakken_sya    =    hakken_sya_just_before(time)
    yobidashi_sya = yobidashi_sya_just_before(time)
    if hakken_sya.id == 0
      nil
    elsif machi_su and machi_su==0
      "－"
    elsif yobidashi_sya.id==0
      first_hakken_time = map{|sya| sya.time(:hakken)}.select{|t| t!=nil}.min
      time - first_hakken_time
    else
      time - yobidashi_sya.time(:yobidashi)
    end
  end

  #※※※※※※※※※※  データ更新状況 ※※※※※※※※※※※※

  #*** 指定時間以内のデータ更新（窓口別）***
  def update?(t)
    time=self.last_update_time
    return nil if time==nil
    if time+t>=TimeNow
      true
    else
      false
    end
  end
  #*** 指定時間以内のデータ更新（全窓口） ***
  def self.update?(t=1.hour)
    time=RaichoList.last_update_time
    return nil if time==nil
    if time+t>=TimeNow
      true
    else
      false
    end
  end
  #*** 指定時間以内のログファイル更新（全窓口） ***
  def self.logfile_update_within(t)
    logfile=self.log_file
    mtime = File.mtime(logfile)
    return :no_log_file    unless File.exist?(logfile)
    return self.update?(t) if test_mode?(2,3,4,5) #テスト用
    return :no_todays_file if mtime.to_date!=Date.today
    Time.now - mtime < t
  end
  #*** ボイスコールログの全体状況 ***
  def self.state_whole
    return "no_data"   if self.sya_su==0
    return "no_update" if self.update? == false
    "correct"
  end

  #※※※※※※※※  グラフに使用する時間毎の情報 ※※※※※※※※※※※

  #***** 毎正時の待ち人数 (2014.3.31 compare_modoを付加等)*****
  # compare_mode=:yesのときは、次の毎正時待ち時間の該当者の待ち人数を取得する。
  def maiseiji_machi_su(kaichojikan=$ku,compare_mode: :no)
    su=Hash.new
    return su if self.log_file==nil #2014.6.25 ダミーオブジェクトと空データを区別
    seiji=kaichojikan.mai_seiji
    seiji.each do |ji|
      break if self.log_file==Myfile.file(:log) and TimeNow < ji #2014.9.27 2つの条件の順序を逆転
      case compare_mode
      when :yes
        sya=self.complete.hakken_sya_just_before(ji) # machi_hunと同一の来庁者のデータとするためキャンセルした来庁者を除外
        if sya.id==0 and ji==seiji[0]              # 開庁後最初の正時(9時)でまだ来庁者がないとき 2014.7.19
          su[ji]=0
        else
          su[ji]=self.machi_su(sya.id)
        end
      when :no
        su[ji]=self.machi_su(ji)
      end
    end
    su
  end
  #***** 毎正時(or閉庁時刻前30分)の直近の発券番号の待ち時間(分) （2014.3.31付加）*****
  def maiseiji_machi_hun(kaichojikan=$ku)
    hun=Hash.new
    return su if self.log_file==nil #2014.6.25 ダミーオブジェクトと空データを区別
    seiji=kaichojikan.mai_seiji
    seiji.each do |ji|
      break if self.log_file==Myfile.file(:log) and TimeNow < ji #2014.9.27 条件の順序を逆転
      sya=self.complete.hakken_sya_just_before(ji) # キャンセルした来庁者を除外
      if sya.id==0 and ji==seiji[0]              # 開庁後最初の正時(9時)でまだ来庁者がないとき 2014.7.19
        hun[ji]=0
      else
        hun[ji]=sya.machi_hun
      end
    end
    hun
  end
  #***** 毎時の来庁者数 *****
  #KaichoJikanクラスオブジェクトを引数にするよう変更（2014.3.31）
  #戻り値例:{8=>2,9=>8,10=>20,11=>23,…}
  def maiji_sya_su(kaichojikan)
    su=Hash.new
    return su if self.log_file==nil #2014.6.25 ダミーオブジェクトと空データを区別
    kaichojikan.mai_ji.each do |ji|
      break if self.log_file==Myfile.file(:log) and TimeNow < ji.to_hhmm #2014.9.27 条件の順序を逆転
      su[ji]=self.jikan_betsu_sya_su(ji)
    end
    su
  end


  #※※※※※※※※※※  その他の統計的情報 ※※※※※※※※※※※※

  #*** 平均待ち時間（分） ***
  def average_machi_hun
    sum=0
    self.each do |sya|
      sum+=sya.machi_hun if sya.machi_hun!=nil and sya.time(:cancel)==nil
    end
    su =self.count{|sya| sya.time(:yobidashi)!=nil}
    return (sum/su).round(1) if su>0
    0
  end
end
#class RaichoList ここまで


#*****************************************
#***** ここからはオプション機能
#*****************************************

#***** 課内モニター 2015.1.18 内部コードを大幅に刷新 *****
#*** RaichoSyaクラスの拡張 ***
class RaichoSya
  #*** 発券時刻 → 呼出時刻 の文字列を返す ***
  def h2y(*mode)
    ary=mode.flatten
    self.hakken_time(ary) + " → " + self.yobidashi_time(ary)
  end
  #*** 番号別のHTMLの１行 ***
  def html_bango_betsu(mado,*mode)
    ary=mode.flatten
    str =  "<tr>"
    str << "<td><a name=\"#{mado}\">#{mado}</a></td>"
    str << "<td>#{self.bango.to_s}</td>"
    str << "<td>#{self.machi_su_nin}</td>"
    str << "<td>#{self.h2y(ary)}</td>"
    str << "<td>#{self.hun(ary)}</td>"
    str << "</tr>\n"
    str
  end
  def csv_bango_betsu(mado)
    ary=[]
    ary << mado
    ary << self.bango
    ary << self.machi_su
    ary << self.h2y(:ended)
    ary << self.hun(:excel)
    ary.join(",")
  end
  def hun(*mode)
    ary=mode.flatten
    if    ary.include?(:ended)    ; self.express_waited_time(:hun)
    elsif ary.include?(:waiting)  ; self.express_waiting_time(:keika)
    elsif ary.include?(:excel)    ; self.express_waited_time()
    end
  end
end

#*** AlertJokenクラス ***
class AlertJoken
  #@tableはCSV::Tableクラスオブジェクト
  attr_accessor :table
  def initialize(str_table)
    #str_table：カンマ区切りではなく空白区切りのテキストデータ
    def hosei #CSVパース時のコンバータ1
      lambda do |field,info|
        case info.header
        when '窓口'
          field
        when '警告方法'
          field.split(/,|、/)
        else
          field.tr('０-９＜＞＝','0-9<>=').sub(/^\d/,'==\&').sub(/^=\d/,'=\&')
        end
      end
    end
    def to_joken #CSVパース時のコンバータ2
      lambda do |field,info|
        if info.header!="窓口" and info.header!="警告方法" and field!="nil"
          hikaku_komoku_map.key(info.header).to_s + field
        else
          field
        end
      end
    end
    @alert_kijun={ :machi_su             => "待ち人数",
                   :machi_su_just_before => "直前の待ち人数",
                   :next_machi_su        => "次のお客様の発券時の待ち人数",
                   :next_machi_jikan     => "次のお客様の待ち時間",
                   :keika_jikan          => "直近の呼び出しからの経過時間"  }
    @table=CSV.parse(str_table.gsub('　',' '),
                      :headers    => true,
                      :col_sep    => "\s",
                      :converters => [hosei,to_joken],
                      :skip_blanks=> true )
  end
  def kijun
    @alert_kijun.keys
  end
  def [](mado)
    aj=Marshal.load(Marshal.dump(self)) # AJの深いコピーを作成
    aj.table.delete_if{|row| row["窓口"]!=mado}
    aj
  end
  def keys
    self.table.values_at("窓口").flatten.uniq.sort
  end
  def by(keikoku_hoho)
    aj=Marshal.load(Marshal.dump(self)) # AJの深いコピーを作成
    aj.table.delete_if{|row| not row["警告方法"].include?(keikoku_hoho)}
    aj
  end
  def compare(item)
    aj=Marshal.load(Marshal.dump(self)) # AJの深いコピーを作成
    aj.table.delete_if{|row| not row.to_s=~/(^|,)#{item}(=|<|>)/}
    aj
  end
  def hikaku_komoku_map
    {:machi_su             => "待ち人数",
     :machi_su_just_before => "直前の待ち人数",
     :next_machi_su        => "次のお客様の発券時の待ち人数",
     :next_machi_jikan     => "次のお客様の待ち時間",
     :keika_jikan          => "直近の呼び出しからの経過時間"  }
  end
  def hikaku_komoku
    hikaku_komoku_map.keys
  end
  def joken_set
    ary=@table.by_col.delete_if{|h,v| h=="窓口" or h=="警告方法"}.to_a
    ary.delete_at(0) #ヘッダーを削除
    ary.each{|j| j.delete("nil")}.map{|j| j.join(" and ")}
  end
  def joken_set_another(compare_item=:all)
    ary=@table.by_col.delete_if{|h,v| h=="窓口" or h=="警告方法"}.to_a
    ary.delete_at(0)
    set=[]
    ary.each do |j|
      j.delete("nil")
      s=j.join(" and ")
      if compare_item==:all or s.match(/(^| )#{compare_item}(=|<|>)/)
        set << s
      end
    end
    set
  end
  #真の条件があるかないか判別できればいいときは条件セットを引数にする。
  #どの条件が真かを判別する必要がある時は個別の条件を引数にする。
  #真の場合の戻り値はAND条件をバラした単独条件の配列: A and B => [A,B]
  def meet_joken?(log)
    @log=log
    def machi_su             ; @log.machi_su                     ; end
    def machi_su_just_before ; @log.max_machi_su_within_3minutes ; end
    def next_machi_su        ; @log.next_machi_su                ; end
    def next_machi_jikan     ; @log.machi_jikan                  ; end
    def keika_jikan          ; @log.keika_jikan                  ; end
    joken_set.each do |j|
      return j.split(' and ') if eval(j)
    end
    false
  end
end

#***** 窓口停滞警告メール *****
def teitai_keikoku_mail(logs)
  return nil unless defined? AJ
  aj=AJ.by("メール")
  $mado_array.each do |m|
    if aj[m].meet_joken?(logs[m])
      next_yobidashi_person    = logs[m].next_call
      next unless next_yobidashi_person
      current_yobidashi_person = logs[m].current(:yobidashi)
      next_person_machi_su     = next_yobidashi_person.machi_su
      next_person_machi_jikan  = logs[m].machi_jikan
      keika_jikan              = logs[m].keika_jikan
      #*** メールデータ作成 ***
      title  = "【#{m}番窓口注意】受付が停滞しています。"
      body   = "#{m}番窓口の受付が#{current_yobidashi_person.bango}番で止まっています。"
      body   << "\n次の番号のお客様の発券時待ち人数　：#{next_person_machi_su}人"
      body   << "\n次の番号のお客様の待ち時間　　　　：#{next_person_machi_jikan}分"
      body   << "\n現在の番号の継続時間（停滞時間）　：#{keika_jikan}分"
      #*** メール送信 ***
      send_mail(title,body)
    end
  end
end

#***** 課内モニター画面の作成 *****
def make_monitor_html(logs)
  #*** 課内モニター画面のヘッダーセクションのscript部分 ***
  def html_joken(aj,log,i)
      " "*17 + "if (i==#{i}) return #{aj.meet_joken?(log)} ;\n"
  end
  #*** 課内モニター画面の最初の概況セクション ***
  def html_gaikyo(log,mado,i)
    sya=log.current(:yobidashi)
    next_sya=log.next_call
    next_sya=RaichoSya.new unless next_sya
    str = "<tr>"
    str <<    "<td><a href=\"\##{mado}\">#{mado}</a></td>\n"
    str <<    "<td id=\"machi_su#{i.to_s}\">"
    str <<        "#{log.machi_su_nin}<br>"
    str <<        "<div id=\"machi_su_just_before#{i.to_s}\" class=\"just_before\">"
    str <<          "(#{log.max_machi_su_within_3minutes}人)"
    str <<        "</div>"
    str <<    "</td>\n"
    str <<    "<td>#{sya.bango.to_s                 }</td>\n"
    str <<    "<td>#{sya.machi_su_nin               }</td>\n"
    str <<    "<td>#{sya.express_waited_time(:hun)  }</td>\n"
    str <<    "<td id=\"next_machi_su#{i.to_s}\">"
    str <<        "#{next_sya.machi_su_nin}"
    str <<    "</td>\n"
    str <<    "<td id=\"next_machi_jikan#{i.to_s}\">"
    str <<        "#{next_sya.express_waiting_time(:hun)}"
    str <<    "</td>\n"
    str <<    "<td id=\"keika_jikan#{i.to_s}\">"
    str <<        "#{log.keika_jikan.to_s}分"
    str <<    "</td>\n"
    str <<    "<td>"
    str <<      "<div class=\"sound\">"
    str <<        "<input type=\"radio\" name=\"mado#{i.to_s}\" value=\"on\" checked=\"checked\" onClick=\"setcookie(this)\">オン"
    str <<        "<input type=\"radio\" name=\"mado#{i.to_s}\" value=\"off\" onClick=\"setcookie(this)\">オフ"
    str <<      "</div>"
    str <<    "</td>"
    str << "</tr>\n"
    if defined? AJ
      add_alert(log,mado,str)
    else
      str
    end
  end
  #警告表示を付加
  def add_alert(log,mado,str)
    t1="<span class=\"alert\">"
    t2="</span>"
    aj=AJ[mado].by("モニター")
    AJ.kijun.each do |kijun|
      if aj.compare(kijun).meet_joken?(log)
        str.sub!(/(id=\"#{kijun}.*?>)([^<]*)</,'\1'+t1+'\2'+t2+'\3'+"<")
      end
    end
    str
  end
  #*** 課内モニター画面の番号待ち状況（待ち中）のセクション ***
  def html_machichu(log)
    id = log.current(:yobidashi).id
    res= ""
    log.each do |sya|
      next if sya.id<=id
      res << sya.html_bango_betsu(log.mado,:waiting,:explain)
    end
    res
  end
  #*** 課内モニター画面の番号待ち状況（終了分）のセクション ***
  def html_syuryo(log)
    id = log.current(:yobidashi).id
    res= ""
    log.each do |sya|
      break if sya.id>id
      res << sya.html_bango_betsu(log.mado,:ended,:explain)
    end
    res
  end
  #*** ここから本処理 ****
  if Myfile.dir(:monitor)
      f=File.read(Myfile.hinagata(:monitor))
      f.sub!(/<JOKEN>/)       do |str|
        aj=AJ.by("サウンド")
        s="";$mado_array.each_with_index{|m,i| s << html_joken(aj[m],logs[m],i)} ;s
      end if defined? AJ
      f.sub!(/<GENZAI>/)     {|str| "#{Today.day_to_jan} #{TimeNow.time_to_jan}現在"}
      f.sub!(/<UKETSUKECHU>/) do |str|
        s="";$mado_array.each_with_index{|m,i| s << html_gaikyo(logs[m],m,i)} ;s
      end
      f.sub!(/<MACHICHU>/) do |str|
        s="";$mado_array.each{|m| s << html_machichu(logs[m])};s
      end
      f.sub!(/<SYURYO>/) do |str|
        s="";$mado_array.each{|m| s << html_syuryo(logs[m])}  ;s
      end
      temp = Myfile.dir(:temp)+"/"+Myfile.file_name(:monitor)
      to   = Myfile.dir(:monitor)
      File.write(temp,f)
      if File.exist? to
        FileUtils.cp(temp,to)
      elsif test_mode?
        popup "「#{$monitor_folder}」が存在しないため、課内モニタ用のHTMLを保存することができません。"
      end
  end
end
def make_csv_data(logs)
  csv=""
  $mado_array.each do |mado|
    logs[mado].each do |sya|
      csv << sya.csv_bango_betsu(mado)  << "\n"
    end
  end
  csv
end


#*****１日の概況データを保存する*****
def gaikyo_data_save(logs)
  str=""
  $mado_array.each do |mado|
    maiji_sya_su  =logs[mado].maiji_sya_su($ku).values.join(",")
    maiji_machi_su=logs[mado].maiseiji_machi_su($ku).values.join(",")
    str << "#{Today},#{YobiNum.yobi},#{mado},#{logs[mado].sya_su},,#{maiji_sya_su},,#{maiji_machi_su}\n"
  end
  file=Myfile.file(:gaikyo)
  unless File.exist? file
    head="年月日,曜日,窓口,来庁者数,時間帯別来庁者数,８時台,９時台,10時台,11時台,12時台,13時台,14時台,15時台,16時台,17時台,各現在時の待ち人数,９時,10時,11時,12時,13時,14時,15時,16時,17時\n"
    File.write(file,head)
  end
  f=File.open(file,"a+")
  f.print str
  f.close
  #ログのバックアップフォルダ(共有フォルダ)にコピーする。
  if Myfile.dir(:log_backup)
    FileUtils.cp_r(file, Myfile.dir(:log_backup), {:preserve => true})
  end
end


#***** logデータの保存と初期化 *****
def log_data_backup(option=:and_erase)
  new=[]
  file=File.read(Myfile.file(:log))
  file.each_line do |line|
    if line and line[0,8] <= Today
      new << line.chomp
    end
  end
  if new.size>0
    log_file=Myfile.dir(:kako_log)+"/"+Today+".log"
    #過去ログがすでにあるときは空ファイルで上書きしてしまいデータが消滅する危険がある。
    #そこで既存のデータにnewデータを追加したうえで重複を削除する。H26.6.25
    if File.exist? log_file
      file=File.read(log_file)
      file.each_line do |line|
        new << line.chomp if line
      end
      new.uniq!.sort! #重複行を削除
    end
    new_str=new.join("\n")
    File.write(log_file,new_str)
    if Myfile.dir(:log_backup)
      FileUtils.cp_r(log_file, Myfile.dir(:log_backup), {:preserve => true})
    end
    if option==:and_erase and test_mode? == false and File.exist? log_file
      File.write(Myfile.file(:log) , "")
    end
  end
end


#****エクセルのファイルの作成******
def make_xlsx(logs)
  str    = "#{Today.day_to_jan}の窓口状況\n\n"
  $mado_array.each do |mado|
    str << "#{mado}番窓口: 来庁者数 #{logs[mado].sya_su.to_s}、 平均待ち時間 #{logs[mado].average_machi_hun.to_s} 分\n"
  end
  str   << "\n"
  str   << "窓口,番号,発券時待ち人数,発券時刻→呼出時刻,待ち時間\n"
  str   << make_csv_data(logs)
  temp   = Myfile.dir(:temp)+"/temp.csv"
  begin
    File.write(temp,str)
    xl = WIN32OLE.new('Excel.Application')
    book = xl.Workbooks.Open(temp)
#xl.visible=true
    book.ActiveSheet.Columns("A").ColumnWidth = 8.38
    book.ActiveSheet.Columns("B").ColumnWidth = 8.38
    book.ActiveSheet.Columns("C").ColumnWidth = 14.25
    book.ActiveSheet.Columns("D").ColumnWidth = 18.63
    book.ActiveSheet.Columns("E").ColumnWidth = 8.38

    book.ActiveSheet.Range("B8").CurrentRegion.HorizontalAlignment = -4108

    (7..12).each do |i|
      book.ActiveSheet.Range("B8").CurrentRegion.Borders(i).LineStyle = 1
      book.ActiveSheet.Range("B8").CurrentRegion.Borders(i).ColorIndex = 0
      book.ActiveSheet.Range("B8").CurrentRegion.Borders(i).TintAndShade = 0
      book.ActiveSheet.Range("B8").CurrentRegion.Borders(i).Weight = 2
    end

    book.ActiveSheet.PageSetup.PrintTitleRows = "$1:$1"

    xl.Application.DisplayAlerts = "False"
    book_name="#{MYDOC}/窓口待ち状況(#{Time.parse(Today).strftime('%Y-%m-%d')}).xlsx"
    book.SaveAs("Filename"=>book_name,"FileFormat"=>51, "CreateBackup"=>"False")
    book.Close("False")
    xl.Application.DisplayAlerts = "True"
    xl.Quit
    if Myfile.dir(:excel)
      FileUtils.cp_r(book_name,Myfile.dir(:excel),{:preserve => true})
    end
  rescue =>e
#popup e.message.force_encoding("Windows-31J") + "\n\n#{temp}"
    #原因不明であるが、環境によってはOLEオートメーションのアクセスを拒否される場合がある。
    #その場合の代替処理として、同じ内容のcsvファイルを保存する。
    csv_name="#{Myfile.dir(:excel)}/窓口待ち状況(#{Time.parse(Today).strftime('%Y-%m-%d')}).csv"
    if Myfile.dir(:excel)
      FileUtils.cp_r(temp,csv_name)
    end
  end
end

