# -*- coding: Windows-31J -*-
#--------------------------------------------------------------------------------#
#   �ۓy�P�J��ی��N���� �������G�󋵕\���V�X�e�� Ver.352 (2017.9.10)            #
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
  #�w�肵���������t�̉ߋ����O�t�@�C���Ɍ��������邩�B
  #�߂�l�F ��������=>true�A�����Ȃ�=>false (�j���͍l�����Ȃ�)
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
      s = "<th scope=\"col\" class=\"date table_box_r\" id=\"day#{day.day_to_nichiyo}\">#{day.day_to_jan}</th>"
    else
      s = "<th scope=\"col\" class=\"date\" id=\"day#{day.day_to_nichiyo}\">#{day.day_to_jan}</th>"
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
    suii << "<td class=\"graph\" headers=\"mado#{mado} day#{day.day_to_nichiyo}\">"
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
    #�C���^�[�l�b�g���番�����ꂽ�ۓ����j�^�[�p�ɊO���T�C�g�ւ̃����N��u����
    $src_replace.each{|k,v| f.gsub!(k,v)} if $src_replace and use==:local
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
  #�C���f�b�N�X�y�[�W�ւ̃����N(2017.8.6)
  l='<a href="index.html">�T�ʃC���f�b�N�X�y�[�W��</a>'
  str.sub!(/(�O�̏T.*?&nbsp;.*?�@)(�@+)(�@.*?&nbsp;.*?<!--)/m){|w| $1+l+$3}
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
  files
end

def make_suii_for_monitor
  #3�T�ԕ��̃y�[�W��temp�t�H���_�ɍ쐬�����L�t�H���_�ɕ��ʂ���B
  files=make_html_of_3_weeks(Today)
  to=Myfile.dir(:suii)
  FileUtils.cp(files.flatten,to)
  #�C���f�b�N�X�y�[�W���X�V����B���L�t�H���_�Ƀt�@�C������ύX���ĕ��ʁB
  index=modify_index(files)
  to=Myfile.dir(:suii)+"/index.html"
  FileUtils.cp(index,to)
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

#�T�ʂ̐��ڂ��C���f�b�N�X�y�[�W�ɋL�ڂ���B
#�����̃t�@�C��������Ƃ��͐V�f�[�^�������čX�V���A�Ȃ��Ƃ��̓y�[�W��V�������B
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

# �T�ʐ��ڂ̃t�@�C�����z�񂩂�html�`���̍s�f�[�^�i<tr>�E�E�E</tr>�j�z��𐶐�����B
def make_index_rows_array(files)
  kubuns=[]
  rows=[]
  Myfile.keys_of_suii.each do |k|
    case k
    when :suii_hun    ; kubuns << "�҂�����"
    when :suii_syasu  ; kubuns << "�����Ґ�"
    when :suii_machisu; kubuns << "�҂��l��"
    else
      popup "���ڂ̂ЂȌ`�̐ݒ�ƃv���O�������}�b�`���Ă��܂���B�G���[�ӏ��Fsuii.rb��make_index_rows_array",48,"���ڂ̎�ʃG���["
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

# html�`���̍s�f�[�^�i<tr>�E�E�E</tr>�j�z�񂩂�html�t�@�C���𐶐�����B
def make_index_file_from_rows(rows)
  rows.sort!{|a,b| b[0]<=>a[0]}
  str='<html lang="ja"><head><meta charset="Shift_JIS"><style type="text/css"><!--div{text-align:center;}h1{font-size:200%}table,th,td{background-color:#ffffee;border-collapse:collapse;border:2px solid #006e2c;padding:0.3em 2em;font-size:110%;}table{margin-left:auto;margin-right:auto}--></style></head><body><a name="top"></a><div><h1>�������G�󋵁@�T�ʃC���f�b�N�X</h1><p><a href="../<!--MONITOR-->">���j�^�[��ʁi���ݎ�t���ԍ��̂��q�l�̏󋵁j�ɂ��ǂ�</a></p><table><!--TABLE--></table><a href="#top">�g�b�v��</a></div></body></html>'
  str.sub("<!--TABLE-->",rows.join).sub("<!--MONITOR-->",Myfile.file_name(:monitor))
end

def make_index_file_from_rows_another(rows)
  rows.sort!{|a,b| b[0]<=>a[0]}
  f=File.read(Myfile.hinagata(:suii_hun))
  tbl='<table class="table_box" style="margin:0.5em auto !important;">'
  f.sub!(/<table(.*?)table>/m, tbl + rows.join + '</table>' )
  f.sub!(/<h1>(.*?)<\/h1>/,    '<h1>�������G�󋵁@�T�ʃC���f�b�N�X</h1>' )
  f.sub!(/<h4>(.*?)<\/h4>/,        '' )
  f.gsub!(/(<!--local-use-->)(.*���j�^�[���.*\n)/,'\2' )
  f.gsub!(/<!--local-use-->.*\n/,  '' )
  f.gsub!(/<!--public-use-->.*\n/, '' )
  f.sub!(/<\/head>/,'<style type="text/css"><!--td{padding:0.5em 3em!important;font-size:110%;}--></style>\n</head>')
  f
end

#*******************************************************************************
# �ȉ��͒ʏ�̉^�p�Ƃ͕ʂɃ}�j���A������ŏT�ʂ̐��ڃy�[�W�����ꊇ�쐬���邽�߂̃I�v�V�����@�\
#*******************************************************************************

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

# �T�ʐ��ڂ̃t�@�C�����z�񂩂�C���f�b�N�X�y�[�W��html�t�@�C���𐶐�����B
def make_index_file(files)
  rows=make_index_rows_array(files)
  make_index_file_from_rows(rows)
end

# �w����Ԃ�html���쐬���ď���̃t�H���_�ɕۑ�����B
def rebuild_suii_for_monitor(sday,eday=Today)
  files=make_suii_during_optional_period(sday,eday)
  files
end

#�}�j���A������ɂ��ꊇ����
#suii.rb�Ɂhall�h���͊J�n��(yyyymmdd�`��)�������Ƃ��ĕt�����ċN�������ꍇ�ɍ쓮����B
#��2����: "repair_log", "make_suii", "make_exel"�̂����ꂩ���͑g�����i"repair_log,make_suii,make_excel"�Ȃǁj
#��2������"repair_log"���܂܂��Ƃ��A���O�̏C�����s���B
#��2������"make_suii" ���܂܂��Ƃ��A���j�^�[��ʗp�̏T�̐��ڂ��쐬����B
#��2������"make_exel" ���܂܂��Ƃ��A�e���̃G�N�Z���t�@�C�����쐬����B
if ARGV[0] and ( ARGV[0]=="all" or ARGV[0].match(/^\d{8}$/) )
  def make_suii_html(start_day)
    #�T�ʐ��ڂ̃t�@�C����temp�t�H���_�ɍ쐬���A���L�t�H���_�ɕ��ʂ���B
    files=make_suii_during_optional_period(start_day)
    FileUtils.cp(files.flatten,Myfile.dir(:suii))
    #�T�ʐ��ڂ̃t�@�C��������C���f�b�N�X�̃y�[�W��temp�t�H���_�ɍ쐬���A���L�t�H���_�ɕ��ʂ���B
    index=modify_index(files)
    to=Myfile.dir(:suii)+"/index.html"
    FileUtils.cp(index,to)
    popup Myfile.dir(:suii) + " �ɕۑ����܂����B"
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
