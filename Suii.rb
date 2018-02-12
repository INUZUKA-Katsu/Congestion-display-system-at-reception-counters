# -*- coding: Shift_JIS -*-
#--------------------------------------------------------------------------------#
#   �ۓy�P�J��ی��N���� �������G�󋵕\���V�X�e�� Ver.2.9 (2014.9.18)            #
#                                                                                #
#                       �ߋ����O�̕��͕�                                         #
#                                                                                #
#                        �쐬    ����  �� ( ka00-inuzuka@city.yokohama.jp )      #
#                        ���쌠  ���l�s                                          #
#--------------------------------------------------------------------------------#

Encoding.default_external="Shift_JIS"
require './objectinitialize.rb' unless defined? Today
require "./holiday_japan"

class String
  #���̓��̃��O�t�@�C��
  def log_file
    if self.match(/\d{8}/)
      f=Myfile.dir(:kako_log) + "/" + self + ".log"
      return nil unless File.exist? f
      f
    else
      raise
    end
  end
  #���߂̌��j���̓��t
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
  #�������܂ނP�T��(���j����y�j�܂�)�̓��t�̔z��
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
  #�w����t�̉ߋ����O�t�@�C��(���ۂ���Ȃ�)
  def self.kako_log_of(day)
    "#{Myfile.dir(:kako_log)}/#{day}.log"
  end
  #�w�肵���������t�̉ߋ����O�t�@�C���Ɍ��������邩�B
  #�߂�l�F ��������=>true�A�����Ȃ�=>false (�j���͍l�����Ȃ�)
  def self.lack_of_kako_log(*days)
    days.flatten.each do |day|
      next if day>Today or File.exist? kako_log_of(day)
      return true
    end
    false
  end
  #�ߋ����O�t�@�C���Ɋ܂܂��{���t=>���O�f�[�^}
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
  #���̓��t�̃t�@�C���ɑ��̓��t�̃��O���܂܂�Ă��Ȃ����𒲂�
  #���Y���t���̃��O�t�@�C�����쐬����B
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
      next if ji=="17:00"  #17�����݂͂͂����B
      if hun==nil
        str << "<dt>#{ji.hour}���F�c��</dt><dd>&nbsp;</dd>\n"
      elsif hun>1
        str << "<dt>#{ji.hour}���F#{hun.to_s}��</dt><dd><span>#{"i" * (hun/2).to_i}</span></dd>\n"
      else
        str << "<dt>#{ji.hour}���F#{hun.to_s}��</dt><dd>&nbsp;</dd>\n"
      end
    end
  when :suii_machisu
    data=log.maiseiji_machi_su(kaichojikan,compare_mode: :yes)
    data.each do |ji,nin|
      next if ji=="17:00"  #17�����݂͂͂����B
      if nin==nil
        str << "<dt>#{ji.hour}���F�c�l</dt><dd>&nbsp;</dd>\n"
      elsif nin>1
        str << "<dt>#{ji.hour}���F#{nin.to_s}�l</dt><dd><span>#{"i" * nin.to_i}</span></dd>\n"
      else
        str << "<dt>#{ji.hour}���F#{nin.to_s}�l</dt><dd>&nbsp;</dd>\n"
      end
    end
  when :suii_syasu
    data=log.maiji_sya_su(kaichojikan)
    data.each do |ji,nin|
      next if ji.to_i==17 or ji.to_i==8  #8����17�����͂����B
      ji="0#{ji}"[-2,2]
      if nin==nil
        str << "<dt>#{ji}��:�c�l</dt><dd>&nbsp;</dd>\n"
      elsif nin>1
        str << "<dt>#{ji}��:#{nin.to_s}�l</dt><dd><span>#{"i" * nin.to_i}</span></dd>\n"
      else
        str << "<dt>#{ji}��:#{nin.to_s}�l</dt><dd>&nbsp;</dd>\n"
      end
    end
    str << "<dt>���v:#{log.sya_su("23:59")}�l</dt><dd>&nbsp;</dd>\n"
  end
  str
end

#***** HP�p�f�[�^�̕\���̃^�O�f�[�^ *****
def html_th(days)
  th=[]
  days.each do |day|
    th.push(day.day_to_jan)
  end
  s="<th nowrap class=\"date\">\n"+th.join("</th><th nowrap class=\"date\">")+"</th>"
  s=s.sub(/(date)(\">[^>]*<\/th>)$/,'\1 table_box_r\2')
  s
end

#***** HP�p�f�[�^�̃O���t�����̃^�O�f�[�^ *****
#      ����kakolog��Kakolog�N���X�̃I�u�W�F�N�g
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
      suii << "<td class=""graph"">(����)</td>\n"
    elsif day.kakusyu_kaichobi?
      unless day.closed_mado.include? mado
        ku=kakolog.kaichojikan(day)
        kaichojikan=ku.kaicho+"�`"+ku.heicho
        suii << "<td class=""graph"">���y�j�J���̓��ł��B</td>\n"
      else
        suii << "<td class=""graph"">"+$close_message[:suii]+"</td>\n"
      end
    else
      suii << "<td class=""graph"">�@</td>\n"
    end
  end
  suii
end

#***** HTML�̍쐬 *****
def make_html_of_week(day,use=:public)
  days=day.days_of_week
  kl=Kakolog.new(days)
  files=[]
  kubuns=Myfile.keys_of_suii
  kubuns=kubuns.reject{|key| key.to_s=~/sya_?su/} if use==:public
  kubuns.each do |kubun|
    f=File.read(Myfile.hinagata(kubun))
    #�\��
    f.gsub!(/<!--DAY-->/)              {|d| html_th(days)}
    #�\�̃R���e���c
    $mado_array.each do |mado|
      f.gsub!(/<!--#{mado}-SUII-->/)   {|str| html_suii(kubun,kl,mado)}
    end
    #�O�����J�pHTML�B���������p�̃����N���폜���A�y�j�J�����̐����y�[�W�ւ̃����N�𒣂�B
    if use==:public
      f=delete_link(f)
      f=add_link_to_doyokaicho(f)
    #�������j�^�[�pHTML�B�O��̏T��HTML�ւ̃����N�����쐬����B
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

#���J�p�y�[�W�ɕs�v�ȃ����N�����폜
def delete_link(str)
  str.gsub!(/<!--local-use-->.*$/)      {|w| ""} #1�s���ׂč폜
  str.gsub!(/<!--public-use-->/)        {|w| ""} #���p�̃^�O���폜
  str
end

#���J�p�y�[�W�ɓy�j�J�����̐����y�[�W�ւ̃����N��t��
def add_link_to_doyokaicho(str)
  url = "http://www.city.yokohama.lg.jp/hodogaya/madoguti/doyou-kaichou.html"
  str.gsub!(/�y�j�J��.*��/)              {|w| "<a href=\"#{url}\">#{$&}</a>"}
  str
end

#�������j�^�[�p�̃����N���쐬
def make_link(str,day)
  #�O��̏T�⑼�̋敪�̃y�[�W�ւ̃����N
  #���T�̃y�[�W
  if day.this_week?
    str.gsub!(/<!--PreviousWeek-->/)   {|w| (day-7).previous_monday}
    str.gsub!(/^.*<!--NextWeek-->.*$/) {|w| "�@�@�@�@�@<br>"}
    str.gsub!(/\(<!--ThisWeek-->\)/)   {|w| ""}
  #��T�̃y�[�W
  elsif day.last_week?
    str.gsub!(/<!--PreviousWeek-->/)   {|w| (day-7).previous_monday}
    str.gsub!(/\(<!--NextWeek-->\)/)   {|w| ""}
    str.gsub!(/<!--ThisWeek-->/)       {|w| day.previous_monday}
  #��T���O�̃y�[�W
  else
    str.gsub!(/<!--PreviousWeek-->/)   {|w| (day-7).previous_monday}
    str.gsub!(/<!--NextWeek-->/)       {|w| (day+7).previous_monday}      
    str.gsub!(/<!--ThisWeek-->/)       {|w| day.previous_monday}
  end
  #���J�y�[�W�p�̃����N�ƕs�v�ȃ^�O���폜����
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


#�C�ӂ̊��Ԃɂ���1�T�Ԃ��Ƃ̐��ڂ�html���쐬����B
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

