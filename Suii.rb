# -*- coding: Windows-31J -*-
#--------------------------------------------------------------------------------#
#   保土ケ谷区保険年金課 窓口混雑状況表示システム Ver.3.4 (2016.2.17 )           #
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
  #指定日付の過去ログファイル(存否を問わない)
  def self.kako_log_of(day)
    "#{Myfile.dir(:kako_log)}/#{day}.log"
  end
  #指定した複数日付の過去ログファイルに欠落があるか。
  #戻り値： 欠落あり=>true、欠落なし=>false (祝日は考慮しない)
  def self.lack_of_kako_log(*days)
    days.flatten.each do |day|
      next if day>Today or File.exist? kako_log_of(day)
      return true
    end
    false
  end
  #過去ログファイルに含まれる{日付=>ログデータ}
  def self.lines_of(file)
    if File.exist? file
      h    = Hash.new
      ary  = File.readlines(file)
      days = ary.map{|line| $& if line=~/^\d{8}/}.uniq
      days.each do |day|
        h[day]=ary.select{|line| line[0,8]==day}.map{|line| line.chomp}
      end
      h
    else
      false
    end
  end
  def self.save_kako_log(date,lines)
    file=kako_log_of(date)
    lines.concat File.readlines(file) if File.exist? file
    ary=lines.select{|line| line=~/\d{8}/ and $&==date}.map{|line| line.chomp}.uniq
    File.open(file,"w") do |f|
      ary.each{|l| f.puts l}
    end
  end
  #他の日付のファイルに他の日付のログが含まれていないかを調べ
  #当該日付名のログファイルを作成する。
  def self.repair(*days)
    days.flatten.each do |day|
      file=kako_log_of(day)
      if File.exist? file
        h = lines_of(file)
        if h.keys.select{|date| date != day}.size>0
          h.each do |date,lines|
            save_kako_log(date,lines)
            p "A log file of date:#{date} was saved(repaired)."
          end
        end
      end
    end
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
      s = '<th scope="col" class="date table_box_r">'+day.day_to_jan+'</th>'
    else
      s = '<th scope="col" class="date">'+day.day_to_jan+'</th>'
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
    suii << "<td class=\"graph\" headers=\"#{mado}番窓 #{day.day_to_nichiyo}\">"
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
  files.flatten
end

def make_suii_for_monitor
  files=make_html_of_3_weeks(Today)
  files.each do |file|
    to=Myfile.dir(:suii)
    FileUtils.cp(file,to)
  end
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


#指定期間のhtmlを作成して所定のフォルダに保存する。
if 1==0
  files=make_suii_during_optional_period("20140512","20140517",:local)
  files.each do |file|
    to=Myfile.dir(:suii)
    FileUtils.cp(file,to)
  end
  popup Myfile.dir(:suii) + " に保存しました。"
end

#make_html_of_week("20140627",:public)
#puts make_suii_during_optional_period("20150608","20150619",:local)
#puts make_suii_for_monitor
#kubuns=Myfile.keys_of_suii.reject{|key| key.to_s=~/sya_?su/}
#p kubuns
#files=make_suii_during_optional_period("20140616",day2=Today,use=:local)


#puts make_suii_during_optional_period("20130610","20141001",:local)
