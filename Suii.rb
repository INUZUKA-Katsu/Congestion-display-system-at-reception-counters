# -*- coding: Windows-31J -*-
#--------------------------------------------------------------------------------#
#   保土ケ谷区保険年金課 窓口混雑状況表示システム Ver.352 (2017.9.10)            #
#                                                                                #
#                       過去ログの分析編                                         #
#                                                                                #
#                        作成    犬塚  克 ( ka00-inuzuka@city.yokohama.jp )      #
#                        著作権  横浜市                                          #
#--------------------------------------------------------------------------------#

Encoding.default_external="Windows-31J"
require './objectinitialize.rb' unless defined? Today
require "./holiday_japan"


class Kakolog
  attr_reader :days
  def initialize(days)
    @days=days
    @logs        = Hash.new
    @kaichojikan = Hash.new
    setup(days)
  end
  def setup(days)
    days.each do |day|
      if day.log_file
        @logs[day]        = RaichoList.setup(day.log_file,$mado_array,day)
      else
        @logs[day]        = nil
      end
      @kaichojikan[day]= KaichoJikan.setup(day)
    end
  end
  def logs(day,mado=nil)
    return nil if  @logs[day]==nil #2015.1.21
    return @logs[day] if mado==nil
    @logs[day][mado]
  end
  def kaichojikan(day)
    @kaichojikan[day]
  end
  #指定した複数日付の過去ログファイルに欠落があるか。
  #戻り値： 欠落あり=>true、欠落なし=>false (祝日は考慮しない)
  def self.lack_of_kako_log
    @days.each do |day|
      next if day>Today or day.log_file
      return true
    end
    false
  end
end

def hp_graph_data(day,log,kubun)
  kaichojikan=day.kaichojikan
  str=""
  case kubun
  when :suii_hun
    data=log.maiseiji_machi_hun(kaichojikan)
    data.each do |ji,hun|
      next if ji=="17:00"  #17時現在ははずす。
      if hun==nil
        str_hun="…分"
        hun=0
      else
        str_hun="#{hun.to_s}分"
      end
      str << "<dt>#{ji.hour}時:#{str_hun}</dt>"
      str << "<dd>#{bar_chart_imgtag(:weekly_hun,hun)}</dd>\n"
    end
  when :suii_machisu
    data=log.maiseiji_machi_su(kaichojikan,compare_mode: :yes)
    data.each do |ji,nin|
      next if ji=="17:00"  #17時現在ははずす。
      if nin==nil
        str_nin="…人"
        nin=0
      else
        str_nin="#{nin.to_s}人"
      end
      str << "<dt>#{ji.hour}時:#{str_nin}</dt>"
      str << "<dd>#{bar_chart_imgtag(:weekly_nin,nin)}</dd>\n"
    end
  when :suii_syasu
    data=log.maiji_sya_su(kaichojikan)
    data.each do |ji,nin|
      next if ji.to_i==17 or ji.to_i==8  #8時と17時をはずす。
      ji="0#{ji}"[-2,2]
      if nin==nil
        str_nin="…人"
        nin=0
      else
        str_nin="#{nin.to_s}人"
      end
      str << "<dt>#{ji.hour}時:#{str_nin}</dt>"
      str << "<dd>#{bar_chart_imgtag(:weekly_nin,nin)}</dd>\n"
    end
    str << "<dt>総計:#{log.sya_su("23:59")}人</dt><dd>#{bar_chart_imgtag(:weekly_nin,0)}</dd>\n"
  end
  str
end

#***** HP用データの表頭のタグデータ *****
def html_th(days)
  th=[]
  days.each do |day|
    if day==days[-1]
      s = "<th scope=\"col\" class=\"date table_box_r\" id=\"day#{day.day_to_nichiyo}\">#{day.day_to_jan}</th>"
    else
      s = "<th scope=\"col\" class=\"date\" id=\"day#{day.day_to_nichiyo}\">#{day.day_to_jan}</th>"
    end
    th << s
  end
  th.join("\n    ")
end

#***** HP用データのグラフ部分のタグデータ *****
#      引数kakologはKakologクラスのオブジェクト
def html_suii(kubun,kakolog,mado)
  def str(day,log,kaihei,kubun)
    case kaihei
    when :kaichobi
      "<dl>#{hp_graph_data(day,log,kubun)}</dl>"
    when :heichobi
      "(閉庁日)"
    when :kakusyu_kaichobi
      s="※#{(day.nan_yobi)[0]}曜開庁の日です。" #2014.11.7
      if $url_doyokaicho
        s="<a href=\"#{$url_doyokaicho}\">#{s}</a>"
      end
      s
    when :closed_mado
      $close_message[:suii]
    else
      #"　" #明日以降の開庁日はコメントなしのブランク表示
    end
  end
  def status(day,log,mado)
    return :heichobi         if day.heichobi?
    return :closed_mado      if day.closed(mado)
    return :kaichobi         if log
    return :kakusyu_kaichobi if day.kakusyu_kaichobi?
    :else #明日以降の開庁日
  end
  suii=""
  kakolog.days.each do |day|
    log   =kakolog.logs(day,mado)
    kaihei=status(day,log,mado)
    suii << "<td class=\"graph\" headers=\"mado#{mado} day#{day.day_to_nichiyo}\">"
    suii << "#{str(day,log,kaihei,kubun)}</td>\n"
  end
  suii
end

#***** HTMLの作成 *****
def make_html_of_week(day,use=:public)
  days=day.days_of_week
  kl=Kakolog.new(days)
  files=[]
  kubuns=Myfile.keys_of_suii
  kubuns=kubuns.reject{|key| key.to_s=~/sya_?su/} if use==:public
  kubuns.each do |kubun|
    f=File.read(Myfile.hinagata(kubun))
    #インターネットから分離された課内モニター用に外部サイトへのリンクを置換え
    $src_replace.each{|k,v| f.gsub!(k,v)} if $src_replace and use==:local
    #表頭
    f.gsub!(/<!--DAY-->/)              {|d| html_th(days)}
    #表のコンテンツ
    $mado_array.each do |mado|
      f.gsub!(/<!--#{mado}-SUII-->/)   {|str| html_suii(kubun,kl,mado)}
    end
    #外部公開用HTML。
    if use==:public
      f=delete_link(f)                       #内部モニター用のリンクを削除する。
    #内部モニター用HTML。
    elsif use==:local
      f=make_link(f,day)                     #前後の週のHTMLへのリンク等を作成する。
    end
    fname = Myfile.file_name(kubun)
    fname = fname.sub('.html',"(#{day.previous_monday}).html") unless day.this_week?
    temp_file = Myfile.dir(:temp)+"/"+fname
    File.write(temp_file,f)
    files << temp_file
  end
  files
end

#公開用ページに不要なリンク等を削除
def delete_link(str)
  str.gsub!(/<!--local-use-->.*$/)      {|w| ""} #1行すべて削除
  str.gsub!(/<!--public-use-->/)        {|w| ""} #無用のタグを削除
  str
end

#内部モニター用のリンクを作成
def make_link(str,day)
  #インデックスページへのリンク(2017.8.6)
  l='<a href="index.html">週別インデックスページへ</a>'
  str.sub!(/(前の週.*?&nbsp;.*?　)(　+)(　.*?&nbsp;.*?<!--)/m){|w| $1+l+$3}
  #前後の週や他の区分のページへのリンク
  #今週のページ
  if day.this_week?
    str.gsub!(/<!--PreviousWeek-->/)   {|w| (day-7).previous_monday}
    str.gsub!(/^.*<!--NextWeek-->.*$/) {|w| "　　　　　<br>"}
    str.gsub!(/\(<!--ThisWeek-->\)/)   {|w| ""}
  #先週のページ
  elsif day.last_week?
    str.gsub!(/<!--PreviousWeek-->/)   {|w| (day-7).previous_monday}
    str.gsub!(/\(<!--NextWeek-->\)/)   {|w| ""}
    str.gsub!(/<!--ThisWeek-->/)       {|w| day.previous_monday}
  #先週より前のページ
  else
    str.gsub!(/<!--PreviousWeek-->/)   {|w| (day-7).previous_monday}
    str.gsub!(/<!--NextWeek-->/)       {|w| (day+7).previous_monday}
    str.gsub!(/<!--ThisWeek-->/)       {|w| day.previous_monday}
  end
  #公開ページ用のリンクと不要なタグを削除する
  str.gsub!(/<!--public-use-->.*$/)    {|w| ""}
  str.gsub!(/<!--local-use-->/)        {|w| ""}
  str
end

def make_html_of_3_weeks(day)
  files=[]
  files << make_html_of_week(day,:local)
  files << make_html_of_week(day-7,:local)
  files << make_html_of_week(day-14,:local)
  files
end

def make_suii_for_monitor
  #3週間分のページをtempフォルダに作成し共有フォルダに複写する。
  files=make_html_of_3_weeks(Today)
  to=Myfile.dir(:suii)
  FileUtils.cp(files.flatten,to)
  #インデックスページを更新する。共有フォルダにファイル名を変更して複写。
  index=modify_index(files)
  to=Myfile.dir(:suii)+"/index.html"
  FileUtils.cp(index,to)
end

#***** HTMLの修正（「今週」⇒「先週」） *****
def modify_html_of_week()
  files=[]
  kubuns=Myfile.keys_of_suii
  kubuns=kubuns.reject{|key| key.to_s=~/sya_?su/}
  kubuns.each_with_index do |kubun,i|
    file=Myfile.dir(:temp)+"/"+Myfile.file_name(kubun)
    if i==0
      return nil unless File.exist?(file)
      return nil if File.mtime(file).to_yymmdd.this_week?
    end
    f=File.read(file)
    f.gsub!(/今週の/,"先週の")
    File.write(file,f)
    files << file
  end
  files
end

#週別の推移をインデックスページに記載する。
#既存のファイルがあるときは新データを加えて更新し、ないときはページを新しく作る。
def modify_index(files)
  temp_file=Myfile.dir(:temp)+"/suii-index.html"
  if File.exist? temp_file
    f=File.read(temp_file)
    rows=f.scan(/<tr>.*?<\/tr>/)
    new_rows=make_index_rows_array(files)
    rows.delete_if{|r| new_rows.find{|n| n[8,8]==r[8,8]}}
    rows=new_rows+rows
    html=make_index_file_from_rows(rows)
  else
    html=make_index_file(files)
  end
  File.write(temp_file,html)
  temp_file
end

# 週別推移のファイル名配列からhtml形式の行データ（<tr>・・・</tr>）配列を生成する。
def make_index_rows_array(files)
  kubuns=[]
  rows=[]
  Myfile.keys_of_suii.each do |k|
    case k
    when :suii_hun    ; kubuns << "待ち時間"
    when :suii_syasu  ; kubuns << "来庁者数"
    when :suii_machisu; kubuns << "待ち人数"
    else
      popup "推移のひな形の設定とプログラムがマッチしていません。エラー箇所：suii.rbのmake_index_rows_array",48,"推移の種別エラー"
      raise
    end
  end
  files.sort!{|a,b| b[0]<=>a[0]}
  files.each{|a| a.map!{|f| File.basename(f)}}
  files.each_with_index do |a,i|
    if i==0
      d=($&+7).sub!(/(\d{4})(\d{2})(\d{2})/,'\1/\2/\3') if files[1][0].match(/\d{8}/)
      a.unshift(d) if d
    else
      d=$&.sub(/(\d{4})(\d{2})(\d{2})/,'\1/\2/\3') if a[0].match(/\d{8}/)
      a.unshift(d) if d
    end
    str  = "<tr><td>#{a[0]}</td>"
    str += "<td><a href=\"#{a[1]}\">#{kubuns[0]}</a></td>"
    str += "<td><a href=\"#{a[2]}\">#{kubuns[1]}</a></td>"
    str += "<td><a href=\"#{a[3]}\">#{kubuns[2]}</a></td></tr>"
    rows<<str
  end
  rows
end

# html形式の行データ（<tr>・・・</tr>）配列からhtmlファイルを生成する。
def make_index_file_from_rows(rows)
  rows.sort!{|a,b| b[0]<=>a[0]}
  str='<html lang="ja"><head><meta charset="Shift_JIS"><style type="text/css"><!--div{text-align:center;}h1{font-size:200%}table,th,td{background-color:#ffffee;border-collapse:collapse;border:2px solid #006e2c;padding:0.3em 2em;font-size:110%;}table{margin-left:auto;margin-right:auto}--></style></head><body><a name="top"></a><div><h1>窓口混雑状況　週別インデックス</h1><p><a href="../<!--MONITOR-->">モニター画面（現在受付中番号のお客様の状況）にもどる</a></p><table><!--TABLE--></table><a href="#top">トップへ</a></div></body></html>'
  str.sub("<!--TABLE-->",rows.join).sub("<!--MONITOR-->",Myfile.file_name(:monitor))
end

def make_index_file_from_rows_another(rows)
  rows.sort!{|a,b| b[0]<=>a[0]}
  f=File.read(Myfile.hinagata(:suii_hun))
  tbl='<table class="table_box" style="margin:0.5em auto !important;">'
  f.sub!(/<table(.*?)table>/m, tbl + rows.join + '</table>' )
  f.sub!(/<h1>(.*?)<\/h1>/,    '<h1>窓口混雑状況　週別インデックス</h1>' )
  f.sub!(/<h4>(.*?)<\/h4>/,        '' )
  f.gsub!(/(<!--local-use-->)(.*モニター画面.*\n)/,'\2' )
  f.gsub!(/<!--local-use-->.*\n/,  '' )
  f.gsub!(/<!--public-use-->.*\n/, '' )
  f.sub!(/<\/head>/,'<style type="text/css"><!--td{padding:0.5em 3em!important;font-size:110%;}--></style>\n</head>')
  f
end

#*******************************************************************************
# 以下は通常の運用とは別にマニュアル操作で週別の推移ページ等を一括作成するためのオプション機能
#*******************************************************************************

#任意の期間について1週間ごとの推移のhtmlを作成する。
def make_suii_during_optional_period(day1,day2=Today,use=:local)
  day=day1
  end_day=day2.previous_monday
  days=[]
  files=[]
  while day.previous_monday <= end_day
    days << day
    day=day+7
  end
  days.each do |d|
    files << make_html_of_week(d,use)
  end
  files
end

# 週別推移のファイル名配列からインデックスページのhtmlファイルを生成する。
def make_index_file(files)
  rows=make_index_rows_array(files)
  make_index_file_from_rows(rows)
end

# 指定期間のhtmlを作成して所定のフォルダに保存する。
def rebuild_suii_for_monitor(sday,eday=Today)
  files=make_suii_during_optional_period(sday,eday)
  files
end

#マニュアル操作による一括処理
#suii.rbに”all”又は開始日(yyyymmdd形式)を引数として付加して起動した場合に作動する。
#第2引数: "repair_log", "make_suii", "make_exel"のいずれか又は組合せ（"repair_log,make_suii,make_excel"など）
#第2引数に"repair_log"が含まれるとき、ログの修復を行う。
#第2引数に"make_suii" が含まれるとき、モニター画面用の週の推移を作成する。
#第2引数に"make_exel" が含まれるとき、各日のエクセルファイルを作成する。
if ARGV[0] and ( ARGV[0]=="all" or ARGV[0].match(/^\d{8}$/) )
  def make_suii_html(start_day)
    #週別推移のファイルをtempフォルダに作成し、共有フォルダに複写する。
    files=make_suii_during_optional_period(start_day)
    FileUtils.cp(files.flatten,Myfile.dir(:suii))
    #週別推移のファイル名からインデックスのページをtempフォルダに作成し、共有フォルダに複写する。
    index=modify_index(files)
    to=Myfile.dir(:suii)+"/index.html"
    FileUtils.cp(index,to)
    popup Myfile.dir(:suii) + " に保存しました。"
  end
  if ARGV[0] == "all"
    days      = Dir.glob(Myfile.dir(:kako_log)+"/*.log").select{|l| l=~/\d{8}\.log/}.map{|l| l.match(/\d{8}/)[0]}
    start_day = days.min
  else
    start_day = ARGV[0]
    days      = (start_day..Today).to_a
  end
  if ARGV[1] and ARGV[1].match(/repair_log/)
    LogBack.repair(days)
  end
  if ARGV[1]==nil or ARGV[1].match(/make_suii/)
    make_suii_html(start_day)
  end
  if ARGV[1] and ARGV[1].match(/make_excel/) and Myfile.dir(:excel)
    TimeNow = "23:00"
    xl=start_excel()
    days.each do |day|
      xlsx    = Myfile.dir(:excel)+"/"+day+".xlsx"
      csv     = Myfile.dir(:excel)+"/"+day+".csv"
      if day.log_file and not File.exist?(xlsx) and not File.exist?(csv)
        logs=RaichoList.setup(day.log_file,$mado_array,day)
        make_xlsx(xl,logs,day)
      end
    end
    stop_excel(xl)
  end
end


#make_html_of_week("20140627",:public)
#puts make_suii_during_optional_period("20150608","20150619",:local)
#puts make_suii_for_monitor
#kubuns=Myfile.keys_of_suii.reject{|key| key.to_s=~/sya_?su/}
#p kubuns
#files=make_suii_during_optional_period("20140616",day2=Today,use=:local)


#puts make_suii_during_optional_period("20130610","20141001",:local)
