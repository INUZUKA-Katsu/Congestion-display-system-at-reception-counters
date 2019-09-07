# -*- coding: Windows-31J -*-
#--------------------------------------------------------------------------------#
#   �ۓy�P�J��ی��N���� �������G�󋵕\���V�X�e�� Ver.356 (2018.12.15)           #
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
      log_file=day.log_file
      if log_file
        @logs[day]        = RaichoList.setup(log_file,$mado_array,day)
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
  def self.lack_of_kako_log(*days)  # 2018.3.21 Bug fix�inot use on new version.�j
    days.flatten.each do |day|                    
      next if day>Today or day.log_file
      return true
    end
    false
  end
#************* �ȉ��͉��ʌ݊��̂��߂̃��\�b�h************
  #�w����t�̉ߋ����O�t�@�C��(���ۂ���Ȃ�)   2018.10.3 �ǉ�
  def self.kako_log_of(day)
    "#{Myfile.dir(:kako_log)}/#{day}.log"
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
#************* ���ʌ݊����\�b�h�͂����܂� ********************
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
    when :rinji_kaichobi                         #2018.3.21
      s="���Վ��J�����ł��B"
      unless $url_rinjikaicho
        $url_rinjikaicho="http://www.city.yokohama.lg.jp/shimin/madoguchi/koseki/2018spring.html"
      end
      "<a href=\"#{$url_rinjikaicho}\">#{s}</a>"
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
    return :rinji_kaichobi   if day.rinji_kaichobi?         #2018.3.21
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
    f=File.read_to_sjis(Myfile.hinagata(kubun))
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
    if use==:local and day.this_week? == false
      fname = fname.sub('.html',"(#{day.previous_monday}).html")
    end
    temp_file = Myfile.dir(:temp)+"/"+fname
    File.write_acording_to_htmlmeta(temp_file,f)
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

def make_suii_for_monitor(day=Today)
  #3�T�ԕ��̃y�[�W��temp�t�H���_�ɍ쐬�����L�t�H���_�ɕ��ʂ���B
  files=make_html_of_3_weeks(day)
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
    f=File.read_to_sjis(file)
    f.gsub!(/���T��/,"��T��")
    File.write_acording_to_htmlmeta(file,f)
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

  #���ʌ݊��̂��߂̃R�[�h(��������)
  module Excel;end
  #excel�t�@�C���������\�b�h�i�߂�l�F�ۑ������t�@�C�������̓G���[���b�Z�[�W�j
  #���� alt_csv: :ture =>excel�t�@�C�������ŗ�O�����������Ƃ�csv�t�@�C����ۑ�����.
  #              :only =>excel�t�@�C���ł͂Ȃ�csv�t�@�C����ۑ�����.
  #              ���̑�=>excel�t�@�C�������ŗ�O�����������Ƃ��̓V�X�e���̃G���[���b�Z�[�W��Ԃ�.
  module MakeExcel
    def self.file_name(day=Today,dir: :temp,file: :excel)
      if dir == :temp
        if    file == :csv
          res = "#{Myfile.dir(:temp)}/temp.csv"
        elsif file == :excel
          res = "#{Myfile.dir(:temp)}/temp.xlsx"
        end
      else
        base = "�����҂���(#{Time.parse(day).strftime('%Y-%m-%d')})"
        if    dir == :mydoc and file == :csv
          res = "#{MYDOC}/#{base}.csv"
        elsif dir == :mydoc and file == :excel
          res = "#{MYDOC}/#{base}.xlsx"
        elsif dir == :excel and file == :csv
          res = "#{Myfile.dir(:excel)}/#{base}.csv"
        elsif dir == :excel and file == :excel
          res = "#{Myfile.dir(:excel)}/#{base}.xlsx"
        end
      end
      res.gsub('/','\\')
  	end
    #CSV�t�@�C���𐶐��A�ꎞ�ۑ��p�t�H���_�ɕۑ�
    def self.make_csv(logs,day)
      str    = "#{day[0,4]}�N#{day.day_to_jan}�̑�����\n\n"
      $mado_array.each do |mado|
        str << "#{mado}�ԑ���: �����Ґ� #{logs[mado].sya_su.to_s}�A ���ϑ҂����� #{logs[mado].average_machi_hun.to_s} ��\n"
      end
      str   << "\n"
      str   << "����,�ԍ�,�������҂��l��,�����������ďo����,�҂�����\n"
      str   << make_csv_data(logs)
      temp  = file_name(dir: :temp,file: :csv)
      File.write(temp,str)
      return temp
    end
    #CSV�t�@�C�����G�N�Z���œǍ���Ő��`���A�ꎞ�ۑ��p�t�H���_�ɕۑ�
    def self.make_book_from_csv(xl,csv_file)
      book     = xl.Workbooks.Open(csv_file)    
      my_table = book.ActiveSheet.Range("B8").CurrentRegion
      #��
      [10,10,16,20,10].each_with_index do |width,i|
        book.ActiveSheet.Columns(i+1).ColumnWidth = width
      end
      #�����Z���^�[����
      my_table.HorizontalAlignment = Excel::XlCenter
      #�r��
      direction=[]
      direction << Excel::XlEdgeTop
      direction << Excel::XlEdgeBottom
      direction << Excel::XlEdgeLeft
      direction << Excel::XlEdgeRight
      direction << Excel::XlInsideVertical
      direction << Excel::XlInsideHorizontal
      direction.each do |d|
        my_table.Borders(d).LineStyle = Excel::XlContinuous
        my_table.Borders(d).ColorIndex = 0
        my_table.Borders(d).TintAndShade = 0
        my_table.Borders(d).Weight = Excel::XlThin
      end
      #������̃^�C�g���s
      book.ActiveSheet.PageSetup.PrintTitleRows = "$1:$1"
      #�G�N�Z���t�@�C���Ƃ��ĕۑ�����B
      temp = file_name(dir: :temp,file: :excel)
      book.SaveAs("Filename"=>temp,"FileFormat"=>51, "CreateBackup"=>"False")
      book.Close("False")
      return temp
    end
    #�ꎞ�ۑ��p�t�H���_�̃t�@�C���𖼑O�����ă}�C�h�L�������g�Ƌ��L�t�H���_�ɕۑ�
    def self.save_file(src_name,dest_name1,dest_name2,overwrite: true)
      FileUtils.cp_r(src_name,dest_name1,{:preserve => true})
      if Myfile.dir(:excel) and Dir.exist? Myfile.dir(:excel)
        if overwrite==true or not File.exist?(dest_name2)
          FileUtils.cp_r(src_name,dest_name2,{:preserve => true})
          res = [:ok,dest_name2]
        elsif File.exist?(dest_name2)
          res = [:ok,dest_name1,dest_name2]
        else
          res = [:ok,dest_name1]              
        end
      else
        res = [:ok,dest_name1]
      end
      return res
    end
    def self.make_xlsx(xl,logs,day=Today,alt_csv: true,overwrite: true)
      temp_csv  = make_csv(logs,day)
      if alt_csv != :only
        begin
          temp_xlsx   = make_book_from_csv(xl,temp_csv)
          dest_name1  = file_name(day,dir: :mydoc,file: :excel)
          dest_name2  = file_name(day,dir: :excel,file: :excel)
          res         = save_file(temp_xlsx,dest_name1,dest_name2,overwrite: overwrite)
          p "A Excel file of date:#{day} was saved."
          return res
        rescue =>e
          if alt_csv == true
            dest_name1 = file_name(day,dir: :mydoc,file: :csv)
            dest_name2 = file_name(day,dir: :excel,file: :csv)
            res        = save_file(temp_csv,dest_name1,dest_name2,overwrite: overwrite)
            p "A CSV file of date:#{day} was saved."
            return res
          else
            mess = "�G���[! \n#{e.message.force_encoding('Windows-31J')}+(#{Time.parse(day).strftime('%Y-%m-%d')})"
            return [:err,mess,temp_csv]
          end
        end      
      else  # alt_csv==:only �̂Ƃ�
        dest_name1 = file_name(day,dir: :mydoc,file: :csv)        
        dest_name2 = file_name(day,dir: :excel,file: :csv)
        res        = save_file(temp_csv,dest_name1,dest_name2,overwrite: overwrite)
        p "A CSV file of date:#{day} was saved."
        return res
      end
    end
    def self.start_excel()
      begin
        xl = WIN32OLE.new('Excel.Application')
        xl.Application.DisplayAlerts = "False"
        WIN32OLE.const_load(xl, Excel) unless defined? Excel::XlAll
        return xl
      rescue
        return nil
      end
    end
    def self.stop_excel(xl)
      return if xl==nil
      xl.Application.DisplayAlerts = "True"
      xl.Quit
    end
  end
  #���ʌ݊��̂��߂̃R�[�h�i�����܂Łj

  #�w������܂ޏT���獡���܂ł̏T���Ƃ̐��ڂ̃y�[�W�̐���
  def make_suii_html(start_day)
    #�T�ʐ��ڂ̃t�@�C����temp�t�H���_�ɍ쐬���A���L�t�H���_�ɕ��ʂ���B
    files=make_suii_during_optional_period(start_day)
    FileUtils.cp(files.flatten,Myfile.dir(:suii))
    #�T�ʐ��ڂ̃t�@�C��������C���f�b�N�X�̃y�[�W��temp�t�H���_�ɍ쐬���A���L�t�H���_�ɕ��ʂ���B
    index=modify_index(files)
    to=Myfile.dir(:suii)+"/index.html"
    FileUtils.cp(index,to)
    #popup Myfile.dir(:suii) + " �ɕۑ����܂����B"
  end
  def get_days(start_day)
    def calendar_days(start_day)
      day       = start_day
      days      = []
      while day <= Today
        days << day
        day  =  day+1
      end
      days
    end
    def having_log_days()
      Dir.glob(Myfile.dir(:kako_log)+"/*.log").
                   select{|l| l=~/\d{8}\.log/}.
                   map{|l| l.match(/\d{8}/)[0]}
    end
    if start_day != "all" and start_day > Today
      popup("�����ȑO�̓��t���w�肵�Ă��������B",48,"���t���s���ł�.")
      exit
    end
    if start_day == "all"
      return having_log_days()
    else
      return calendar_days(start_day) & having_log_days()
    end
  end

  #����������s����

  #***** ��Q������"repair_log"�������Ă���ꍇ�̏��� *****
  days = get_days(ARGV[0])

  if ARGV[1] and ARGV[1].match(/repair_log/)
    begin
      LogBack.repair(days)
    rescue
      #���ʌ݊��̂��߂̃R�[�h
      Kakolog.repair(days)
    end
  end

  #***** ��Q���������w��A�܂��͑�Q������"make_suii"�������Ă���ꍇ�̏��� *****
  if ARGV[1]==nil or ARGV[1].match(/make_suii/)
    make_suii_html(days.min)
  end

  #***** ��Q������"make_excel"�������Ă���ꍇ�̏��� *****
  if ARGV[1] and ARGV[1].match(/make_excel/)
    TimeNow = "23:00"
    xl = MakeExcel.start_excel()
    saved   = []
    existed = []
    err     = []
    days.each do |day|
      log_file = day.log_file
      temp     = MakeExcel.file_name(day,dir: :temp, file: :csv)
      xlsx     = MakeExcel.file_name(day,dir: :excel,file: :excel)
      csv1     = MakeExcel.file_name(day,dir: :mydoc,file: :csv)      
      csv2     = MakeExcel.file_name(day,dir: :excel,file: :csv)
      logs=RaichoList.setup(log_file,$mado_array,day)
      #xlsx�𐶐����A�}�C�h�L�������g�ɕۑ�����B
      #���L�t�H���_�ɓ����t�@�C�����Ȃ��Ƃ��͋��L�t�H���_�ɂ��ۑ�����.
      res = MakeExcel.make_xlsx(xl,logs,day,alt_csv: false,overwrite: false)
      if res[0]==:ok
      #xlsx�����Ȃ��Ƃ��}�C�h�L�������g�ɕۑ��ł����Ƃ���:ok���߂�.
        saved   << res[1]
        existed << res[2] unless res[2]==[]
      else
      #xlsx���ۑ��ł��Ȃ������Ƃ���csv�t�@�C�����}�C�h�L�������g�ɕۑ�����B
      #���L�t�H���_�ɓ����t�@�C�����Ȃ��Ƃ��͋��L�t�H���_�ɂ��ۑ�����.
        err     << res[1]
        res = MakeExcel.save_file(temp,csv1,csv2,overwrite: false)
        saved   << res[1]
        existed << res[2] unless res[2]==[]
      end
    end
    MakeExcel.stop_excel(xl)
    #���ʂ̕\��
    mydoc  = MYDOC.gsub('/','\\')
    xldir = Myfile.dir(:excel).gsub('/','\\')
    saved_at_mydoc     = saved.select{|f| File.dirname(f)==mydoc}
    saved_at_mydoc_str = "#{mydoc}�ɁA���̃t�@�C����ۑ����܂����B\n"+
                         saved_at_mydoc.map{|f| f and File.basename(f)}.
                         join("\n") unless saved_at_mydoc==[]

    saved_at_excel     = saved.select{|f| File.dirname(f)==xldir}
    saved_at_excel_str = "#{xldir}�ɁA���̃t�@�C����ۑ����܂����B\n"+
                         saved_at_excel.map{|f| f and File.basename(f)}.
                         join("\n") unless saved_at_excel==[]

    existed_at_mydoc     = existed.select{|f| f and File.dirname(f)==mydoc}
    existed_at_mydoc_str = "#{mydoc}�ɂ́A���łɎ��̃t�@�C�������݂��Ă��܂����B\n"+
                           existed_at_mydoc.map{|f| File.basename(f)}.
                           join("\n") unless existed_at_mydoc==[]

    existed_at_excel     = existed.select{|f| f and File.dirname(f)==xldir}
    existed_at_excel_str = "#{xldir}�ɂ́A���łɎ��̃t�@�C�������݂��Ă��܂����B\n"+
                           existed_at_excel.map{|f| File.basename(f)}.
                           join("\n") unless existed_at_excel==[]

    mes_arry = []
    mes_arry << existed_at_excel_str if existed_at_excel
    #mes_arry << existed_at_mydoc_str if existed_at_mydoc
    mes_arry << saved_at_excel_str   if saved_at_excel
    #mes_arry << saved_at_mydoc_str   if saved_at_mydoc
    mes = mes_arry.join("\n\n")
    popup mes
  end
  popup "�I�����܂����B"
end


#make_html_of_week("20140627",:public)
#puts make_suii_during_optional_period("20150608","20150619",:local)
#puts make_suii_for_monitor
#kubuns=Myfile.keys_of_suii.reject{|key| key.to_s=~/sya_?su/}
#p kubuns
#files=make_suii_during_optional_period("20140616",day2=Today,use=:local)


#puts make_suii_during_optional_period("20130610","20141001",:local)
