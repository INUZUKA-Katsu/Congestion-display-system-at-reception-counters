# -*- coding: Shift_JIS -*-
#--------------------------------------------------------------------------------#
#   保土ケ谷区保険年金課 窓口混雑状況表示システム Ver.2.9 (2014.9.18)            #
#                                                                                #
#                       過去ログの分析編                                         #
#                                                                                #
#                        作成    犬塚  克 ( ka00-inuzuka@city.yokohama.jp )      #
#                        著作権  横浜市                                          #
#--------------------------------------------------------------------------------#

Encoding.default_external="Shift_JIS"
require './objectinitialize.rb' unless defined? Today
require "./holiday_japan"

class String
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
end

class Kakolog
  attr_reader :days
  def initialize(days)
    @days=days
    @log         = Hash.new
    @kaichojikan = Hash.new
    setup(days)
  end
  def setup(days)
    days.each do |day|
      if day.log_file
        @log[day]        = RaichoList.setup(day.log_file,$mado_array,day)
      else
        @log[day]        = nil
      end
      @kaichojikan[day]= KaichoJikan.setup(day)
    end
  end
  def log(day,mado=nil)
    if mado==nil
      @log[day]
    else
      @log[day][mado]
    end
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

def hp_graph_data(kubun,log,kaichojikan)
  str=""
  case kubun
  when :suii_hun
    data=log.maiseiji_machi_hun(kaichojikan)
    data.each do |ji,hun|
      next if ji=="17:00"  #17時現在ははずす。
      if hun==nil
        str << "<dt>#{ji.hour}時：…分</dt><dd>&nbsp;</dd>\n"
      elsif hun>1
        str << "<dt>#{ji.hour}時：#{hun.to_s}分</dt><dd><span>#{"i" * (hun/2).to_i}</span></dd>\n"
      else
        str << "<dt>#{ji.hour}時：#{hun.to_s}分</dt><dd>&nbsp;</dd>\n"
      end
    end
  when :suii_machisu
    data=log.maiseiji_machi_su(kaichojikan,compare_mode: :yes)
    data.each do |ji,nin|
      next if ji=="17:00"  #17時現在ははずす。
      if nin==nil
        str << "<dt>#{ji.hour}時：…人</dt><dd>&nbsp;</dd>\n"
      elsif nin>1
        str << "<dt>#{ji.hour}時：#{nin.to_s}人</dt><dd><span>#{"i" * nin.to_i}</span></dd>\n"
      else
        str << "<dt>#{ji.hour}時：#{nin.to_s}人</dt><dd>&nbsp;</dd>\n"
      end
    end
  when :suii_syasu
    data=log.maiji_sya_su(kaichojikan)
    data.each do |ji,nin|
      next if ji.to_i==17 or ji.to_i==8  #8時と17時をはずす。
      ji="0#{ji}"[-2,2]
      if nin==nil
        str << "<dt>#{ji}時:…人</dt><dd>&nbsp;</dd>\n"
      elsif nin>1
        str << "<dt>#{ji}時:#{nin.to_s}人</dt><dd><span>#{"i" * nin.to_i}</span></dd>\n"
      else
        str << "<dt>#{ji}時:#{nin.to_s}人</dt><dd>&nbsp;</dd>\n"
      end
    end
    str << "<dt>総計:#{log.sya_su("23:59")}人</dt><dd>&nbsp;</dd>\n"
  end
  str
end

#***** HP用データの表頭のタグデータ *****
def html_th(days)
  th=[]
  days.each do |day|
    th.push(day.day_to_jan)
  end
  s="<th nowrap class=\"date\">\n"+th.join("</th><th nowrap class=\"date\">")+"</th>"
  s=s.sub(/(date)(\">[^>]*<\/th>)$/,'\1 table_box_r\2')
  s
end

#***** HP用データのグラフ部分のタグデータ *****
#      引数kakologはKakologクラスのオブジェクト
def html_suii(kubun,kakolog,mado)
  suii=""
  kakolog.days.each do |day|
    if kakolog.log(day)
      unless day.closed_mado.include? mado
        log         = kakolog.log(day,mado)
        kaichojikan = kakolog.kaichojikan(day)
        suii << "<td class=""graph""><dl>\n"+hp_graph_data(kubun,log,kaichojikan)+"</dl></td>\n"
      else
        suii << "<td class=""graph"">"+$close_message[:suii]+"</td>\n"
      end
    elsif day.heichobi?
      suii << "<td class=""graph"">(閉庁日)</td>\n"
    elsif day.kakusyu_kaichobi?
      unless day.closed_mado.include? mado
        ku=kakolog.kaichojikan(day)
        kaichojikan=ku.kaicho+"～"+ku.heicho
        suii << "<td class=""graph"">※土曜開庁の日です。</td>\n"
      else
        suii << "<td class=""graph"">"+$close_message[:suii]+"</td>\n"
      end
    else
      suii << "<td class=""graph"">　</td>\n"
    end
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
    #外部公開用HTML。内部向け用のリンクを削除し、土曜開庁日の説明ページへのリンクを張る。
    if use==:public
      f=delete_link(f)
      f=add_link_to_doyokaicho(f)
    #内部モニター用HTML。前後の週のHTMLへのリンク等を作成する。
    elsif use==:local
      f=make_link(f,day)
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

#公開用ページに土曜開庁日の説明ページへのリンクを付加
def add_link_to_doyokaicho(str)
  url = "http://www.city.yokohama.lg.jp/hodogaya/madoguti/doyou-kaichou.html"
  str.gsub!(/土曜開庁.*日/)              {|w| "<a href=\"#{url}\">#{$&}</a>"}
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

#make_html_of_week("20140627",:public)
#puts make_suii_during_optional_period("20130701","20140530",:local)
#puts make_suii_for_monitor
#kubuns=Myfile.keys_of_suii.reject{|key| key.to_s=~/sya_?su/}
#p kubuns
#files=make_suii_during_optional_period("20140616",day2=Today,use=:local)

