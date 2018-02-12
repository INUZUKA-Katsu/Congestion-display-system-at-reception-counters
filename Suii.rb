# -*- coding: Windows-31J -*-
#--------------------------------------------------------------------------------#
#   �ۓy�P�J��ی��N���� �������G�󋵕\���V�X�e�� Ver.3.4 (2016.2.17 )           #
#                                                                                #
#                       �ߋ����O�̕��͕�                                         #
#                                                                                #
#                        �쐬    ����  �� ( ka00-inuzuka@city.yokohama.jp )      #
#                        ���쌠  ���l�s                                          #
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

def hp_graph_data(day,log,kubun)
  kaichojikan=day.kaichojikan
  str=""
  case kubun
  when :suii_hun
    data=log.maiseiji_machi_hun(kaichojikan)
    data.each do |ji,hun|
      next if ji=="17:00"  #17�����݂͂͂����B
      if hun==nil
        str_hun="�c��"
        hun=0
      else
        str_hun="#{hun.to_s}��"
      end
      str << "<dt>#{ji.hour}��:#{str_hun}</dt>"
      str << "<dd>#{bar_chart_imgtag(:weekly_hun,hun)}</dd>\n"
    end
  when :suii_machisu
    data=log.maiseiji_machi_su(kaichojikan,compare_mode: :yes)
    data.each do |ji,nin|
      next if ji=="17:00"  #17�����݂͂͂����B
      if nin==nil
        str_nin="�c�l"
        nin=0
      else
        str_nin="#{nin.to_s}�l"
      end
      str << "<dt>#{ji.hour}��:#{str_nin}</dt>"
      str << "<dd>#{bar_chart_imgtag(:weekly_nin,nin)}</dd>\n"
    end
  when :suii_syasu
    data=log.maiji_sya_su(kaichojikan)
    data.each do |ji,nin|
      next if ji.to_i==17 or ji.to_i==8  #8����17�����͂����B
      ji="0#{ji}"[-2,2]
      if nin==nil
        str_nin="�c�l"
        nin=0
      else
        str_nin="#{nin.to_s}�l"
      end
      str << "<dt>#{ji.hour}��:#{str_nin}</dt>"
      str << "<dd>#{bar_chart_imgtag(:weekly_nin,nin)}</dd>\n"
    end
    str << "<dt>���v:#{log.sya_su("23:59")}�l</dt><dd>#{bar_chart_imgtag(:weekly_nin,0)}</dd>\n"
  end
  str
end

#***** HP�p�f�[�^�̕\���̃^�O�f�[�^ *****
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

#***** HP�p�f�[�^�̃O���t�����̃^�O�f�[�^ *****
#      ����kakolog��Kakolog�N���X�̃I�u�W�F�N�g
def html_suii(kubun,kakolog,mado)
  def str(day,log,kaihei,kubun)
    case kaihei
    when :kaichobi
      "<dl>#{hp_graph_data(day,log,kubun)}</dl>"
    when :heichobi
      "(����)"
    when :kakusyu_kaichobi
      s="��#{(day.nan_yobi)[0]}�j�J���̓��ł��B" #2014.11.7
      if $url_doyokaicho
        s="<a href=\"#{$url_doyokaicho}\">#{s}</a>"
      end
      s
    when :closed_mado
      $close_message[:suii]
    else
      #"�@" #�����ȍ~�̊J�����̓R�����g�Ȃ��̃u�����N�\��
    end
  end
  def status(day,log,mado)
    return :heichobi         if day.heichobi?
    return :closed_mado      if day.closed(mado)
    return :kaichobi         if log
    return :kakusyu_kaichobi if day.kakusyu_kaichobi?
    :else #�����ȍ~�̊J����
  end
  suii=""
  kakolog.days.each do |day|
    log   =kakolog.logs(day,mado)
    kaihei=status(day,log,mado)
    suii << "<td class=\"graph\" headers=\"#{mado}�ԑ� #{day.day_to_nichiyo}\">"
    suii << "#{str(day,log,kaihei,kubun)}</td>\n"
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
    #�O�����J�pHTML�B
    if use==:public
      f=delete_link(f)                       #�������j�^�[�p�̃����N���폜����B
    #�������j�^�[�pHTML�B
    elsif use==:local
      f=make_link(f,day)                     #�O��̏T��HTML�ւ̃����N�����쐬����B
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

#***** HTML�̏C���i�u���T�v�ˁu��T�v�j *****
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
    f.gsub!(/���T��/,"��T��")
    File.write(file,f)
    files << file
  end
  files
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


#�w����Ԃ�html���쐬���ď���̃t�H���_�ɕۑ�����B
if 1==0
  files=make_suii_during_optional_period("20140512","20140517",:local)
  files.each do |file|
    to=Myfile.dir(:suii)
    FileUtils.cp(file,to)
  end
  popup Myfile.dir(:suii) + " �ɕۑ����܂����B"
end

#make_html_of_week("20140627",:public)
#puts make_suii_during_optional_period("20150608","20150619",:local)
#puts make_suii_for_monitor
#kubuns=Myfile.keys_of_suii.reject{|key| key.to_s=~/sya_?su/}
#p kubuns
#files=make_suii_during_optional_period("20140616",day2=Today,use=:local)


#puts make_suii_during_optional_period("20130610","20141001",:local)
