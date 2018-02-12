# -*- coding: Shift_JIS -*-
#--------------------------------------------------------------------------------#
#   �ۓy�P�J��ی��N���� �������G�󋵕\���V�X�e�� Ver.3.1 (2014.10.27)           #
#                                                                                #
#        <<�I�u�W�F�N�g��`�A���[�e�B���e�B���\�b�h�y�уI�v�V�����@�\>>          #
#                                                                                #
#                        �쐬    ����  �� ( ka00-inuzuka@city.yokohama.jp )      #
#                        ���쌠  ���l�s                                          #
#--------------------------------------------------------------------------------#

Encoding.default_external="Shift_JIS"

require "fileutils"
require 'net/ftp'
require 'timeout'
require 'win32ole'
require 'time'
require "logger"
require 'nkf'
require 'net/smtp'
require "date"
require "./holiday_japan"


#*** �}�C�h�L�������g�t�H���_ ***
wsh = WIN32OLE.new('WScript.Shell')
MYDOC=wsh.SpecialFolders('MyDocuments').force_encoding("Shift_JIS")
DESKTOP=wsh.SpecialFolders('Desktop').force_encoding("Shift_JIS")
wsh=nil


#*** �A���[�g��\�����A���O�ɏo�͂��� ***
def alert(str)
  print str
  print "\n"
end


#**** �|�b�v�A�b�v ***
#     �V�X�e���^�p���̓|�b�v�A�b�v���g�p���Ȃ����ƁB���b�Z�[�W�ɋC�t���Ȃ��ԃV�X�e�����X�g�b�v���Ă��܂��B
#     icon_and_button:  16=>stop,32=>?,48=>!,64=>i
#                       0=>OK,  1=>OK�E�L�����Z��,  3=>�͂��E�������E�L�����Z��, 4=>�͂��E������
#     �߂�l: 1=>OK, 2=>�L�����Z��, 6=>�͂�, 7=>������

def popup(str,icon_and_button=64,title="���b�Z�[�W",delay_time=0)
  wsh = WIN32OLE.new('WScript.Shell')
  wsh.Popup(str,delay_time,title,icon_and_button)
end


#*** �C���v�b�g�{�b�N�X��\�����A���͒l���擾 ***
def get_input(prompt='', title='')
  cmd="InputBox(\"#{prompt}\",\"#{title}\")"
  sc = WIN32OLE.new("ScriptControl")
  sc.language = "VBScript"
  sa = sc.eval(cmd)
  sa
end


#*** �t�H���_�̃`�F�b�N ***
def dir_check(dir)
  return false if dir==nil
  return false unless defined? dir
  return false unless File.exist? dir
  true
end


class ConfigSet
  #*** �f�B���N�g���`�F�b�N�i�Ȃ���΍쐬����j ***
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
      FileUtils.mkdir_p dir #���݂��Ȃ��Ƃ��͍��
      :success
    rescue
      if test_mode?(1,3,4,5)
        popup("�t�H���_ #{dir} ���쐬���邱�Ƃ��ł��܂���ł����B�ݒ�t�@�C���̓��e���m�F���Ă��������B",48,"�f�B���N�g���G���[",30)
      else
        send_mail("�y�G���[�z�������G�󋵕\���V�X�e��","�t�H���_ #{dir} �͑��݂��܂���B�ݒ�t�@�C���̓��e���m�F���Ă��������B")
      end
      :error
    end
  end
  #config.txt �̑����ԍ��֘A�ϐ��̐������`�F�b�N�i�����ݒ�ŊԈႢ�₷���j2014.4.4 �t��
  def self.mado_bango_check
    return unless test_mode? #�e�X�g���[�h�̂Ƃ��̂ݎ��s
    return @@bango if defined? @@bango
    @@bango=true
    mado_array=$mado_bango.split(",").sort
    ans=[]
    ans << "$ken_bango"           unless $ken_bango.keys.sort==mado_array
    ans << "$gyomu"               unless $gyomu.values.sort==mado_array
    ans << "$teitai_kyoyou_jikan" unless $teitai_kyoyou_jikan.keys.sort==mado_array
    mado=[]
    $jam_message.each_line do |line|
      next if line =~ /����.*�҂��l��.*���b�Z�[�W/
      mado << $& if line =~ /[^\s]+/
    end
    ans << "$jam_message"         unless mado.uniq.sort==mado_array
    unless ans==[]
      popup "�ݒ�t�@�C���� " + ans.join("�A") + " �̑����ԍ��ɕs����������܂��Bconfig.txt ���J���ďC�����Ă��������B"
      return false
    end
    @@bango
  end
  #FTP�T�[�o�A�N�Z�X�`�F�b�N
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
  #���[�����M�`�F�b�N
  def self.mail_check
    title = "���[�����M�e�X�g"
    body  = "�������G�󋵕\���V�X�e������̃��[�����M�e�X�g�ł��B"
    send_mail(title,body) #���������:send�A�S�z�����false���Ԃ�
  end
  #config.txt�Ƀe�X�g���[�h�U�����邩�i�ŐV�d�l��config.txt���j
  def self.has_test_mode6?
    config=File.read("./config.txt")
    if config.match("�e�X�g���[�h�U")
      true
    else
      false
    end
  end
  #�e�X�g���[�h�U�̏ꍇ�̃I�[���ݒ�`�F�b�N
  def self.check_all_test_mode6
    mes = "�����ԍ��ݒ�̐������A�w��t�H���_�̗L���AFTP�T�[�o�ւ̃A�N�Z�X�A���[�����M�����`�F�b�N���܂��B\n"
    mes << "���̊m�F�ɂ͑����̎��Ԃ�������ꍇ������܂��B���΂炭���҂����������B"
    popup mes,64,"���҂���������",10

    dir_err  = "�t�H���_�̎w����������K�v������܂��B"
    bango_err= "�����ԍ��Ɋ֘A����w��ɕs����������܂��B"
    ftp_err  = "FTP�T�[�o�ɐڑ��ł��܂���ł����BFTP�T�[�o��URL�A�A�J�E���g�A�p�X���[�h���������Ă��������B"
    mail_err = "���[���T�[�o�ɐڑ��ł��܂���ł����BSMTP�T�[�o��URL�A�A�J�E���g���������Ă��������B"

    res=Hash.new
    res[:dir]  =dir_err   unless setup_dir           #�f�B���N�g���`�F�b�N
    res[:bango]=bango_err unless mado_bango_check    #�����ԍ��`�F�b�N
    res[:ftp]  =ftp_err   unless ftp_check           #FTP�T�[�o�`�F�b�N
    res[:mail] =mail_err  unless mail_check          #���[�����M�`�F�b�N
    if res.size==0
      popup "�`�F�b�N���ڂ͂��ׂĖ�肠��܂���ł����B"
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
  #���O�t�@�C���E���O�f�[�^�̐������`�F�b�N(�e�X�g���[�h2,3,4,5�̂Ƃ��g�p)
  def self.log_file_check
    file =File.expand_path(Myfile.file(:log))
    fname=File.basename(file)
    dir  =File.dirname(file)
    kako_log = "#{Myfile.dir(:kako_log)}/#{Today}.log"
    unless File.exist? file
      popup "���O�t�@�C���u#{fname}�v���A�w�肳�ꂽ�t�H���_�u#{dir}�v�ɂ���܂���B",48,"�G���["
      exit
    end
    log_events=LogEvents.setup(file,Today,:prior_check)
    if log_events.size==0
      if File.exist? kako_log
        FileUtils.cp(kako_log, Myfile.file(:log))
        log_events=LogEvents.setup(file,Today,:prior_check)
      else
        popup "�e�X�g�p�̃��O�t�@�C���u#{file}�v�ɂ́A�e�X�g�p���t #{$datetime.match(/\d{4}\/\d\d?\/\d\d?/)} �̃f�[�^������܂���B\n" << 
              "�e�X�g�p�̃��O�t�@�C������łȂ��Ƃ���΁Aconfig.txt �� $datetime ���e�X�g�p�f�[�^�ɍ��킹�ďC������K�v������Ǝv���܂��B" ,48,"�G���["
        exit
      end
    end
    range=Hash.new
    wariate=nil
    $mado_array.each do |mado|
      mini=log_events.min_bango(mado)
      max =log_events.max_bango(mado)
      range[mado]=[mini,max]
      if mini #�f�[�^�F��:mini=nil�̂Ƃ�������
        wariate=:error unless $bango[mado].range.include? mini
        wariate=:error unless $bango[mado].range.include? max
      end
    end
    if wariate==:error
      mes =  "config.txt �̌��ԍ��̊��蓖�ĂƖ������錔�ԍ������O�t�@�C���ɂ���܂��B\n"
      mes << "�z�z���ꂽ�e�X�g�p�̃��O�t�@�C���̂��߂��Ǝv���܂��B\n"
      mes << "�ꎞ�I�Ɍ��ԍ��̊��蓖�Ă�ύX���Ă��̂܂܃e�X�g�𑱍s���܂����H\n"
      mes << "(50�b�Ԍo�߂����Ƃ������̂܂ܑ��s���܂��B)"
      ans=popup(mes,51,"�G���[",50)
      if ans==6
        $mado_array.each do |mado|
          $bango[mado].mini=range[mado][0]
          $bango[mado].max =range[mado][1]
        end
      else
        popup "����e�X�g���I�����܂��B\n config.txt �̌��ԍ��̊��蓖�Ă�_�����Ă��������B"
        exit
      end
    end
  end
end


#***** �G���[�|�b�v�A�b�v�{�G���[���O(�ŐV200�s��ێ��B�J�����g�t�H���_�ɍ쐬) *****
END{
  def lotation(file,max_lines=200)
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
    backtrace=$!.backtrace.map{|s| s.force_encoding("Shift_JIS")}.join("\n  ")
    message=$!.message.force_encoding("Shift_JIS")
    error_mes="#{$!.class}:#{message}\n  #{backtrace}\n"
    popup(error_mes,16,"�G���[�̂��ߏI�����܂��B",50) unless message=="exit"
    logger.error(error_mes)
  end
  lotation('error.log')
}


#***** ���[�� *****
def send_mail(title,body)
  if test_mode?
    if test_mode?(6) or $smtp_usable==nil or ($smtp_usable and $smtp_usable==true)
      to=$to_on_trial #�e�X�g�p�A�h���X�ɑ��M
    else
      #�e�X�g���[�h6�ȊO�̂Ƃ��A���[�����M�����Ȃ����Ƃ�$smtp_usable=false�Ŗ��������Ƃ��̓R���\�[���ɕ\��
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
  mail_str <<  "#{NKF.nkf("-Sj", body).force_encoding("Shift_JIS")}\n"
  begin
    Net::SMTP.start( $smtp,25 ) do |smtp|
      smtp.send_mail mail_str,$from,*to
    end
  rescue
    str= "���̃��[���͑��M�ł��܂���ł����B\n" << title << "\n" << body
    alert str
    popup str if test_mode?(2,3,4,5)
    return false
  end
  :send
end


#***** FTP���M �i2014.4.4 mado_Ftp.rb����ڋL�j*****
def ftp_soshin(files,dir)
  case $test_mode
  when 0,2  #�{�Ԃ܂��̓e�X�g���[�h�Q�̂Ƃ��AFTP���M����B
    cnt_retry=0
    begin
      ftp = Net::FTP.new
      ftp.connect($ftp_server)
      ftp.login($account,pass())
      ftp.passive = true
      ftp.binary  = false
      ftp.chdir(dir)
    #�A�b�v���[�h�ŃT�[�o�̉����҂��ɂȂ����Ƃ��T�b�Ń^�C���A�E�g�ɂ���B
    timeout(5){
      files.each {|file| ftp.put(file)}
    }
      ftp.quit
    rescue Timeout::Error
      cnt_retry+=1
      if cnt_retry<=3
        retry
      else
        title = "�y�G���[�I�z�������G�󋵃z�[���y�[�W�̃G���["
        body  = "FTP Timeout! \n"
        body += "�R�񃊃g���C���܂������A�T�[�o�����҂��ŃA�b�v���[�h�ł��܂���ł����B\n\n"
        body += "���}�̑Ή����K�v�ł��B�����ɃV�X�e���S���҂ɒm�点�Ă��������B"
        send_mail(title,body)
        popup(body,48,title,2*60+30)
        raise
      end
    rescue => e
        # 2014.5.26 YCAN�ڑ��̃G���[���������ꍇ�̌x�����b�Z�[�W���C��
        #�i�|�b�v�A�b�v�\����t�����j
        title = "�y�G���[�I�z�������G�󋵃z�[���y�[�W�̃G���["
        body  = "�z�[���y�[�W�ɃA�b�v���[�h�ł��܂���ł����I\n"
        body += "���}�̑Ή����K�v�ł��B�����ɃV�X�e���S���҂ɒm�点�Ă��������B\n\n"
        body += "�����Ƃ��Ă̓��j�^�[PC��YCAN�ɐڑ����Ă��Ȃ��\��������܂��B\n"
        body += "���͉��l�s��CGI�T�[�o�[���_�E�����Ă��邱�Ƃ��l�����܂��B\n"
        body += "�ȉ��̓V�X�e���̃G���[���O�ł��B\n\n"
        body += e.message.force_encoding("Shift_JIS")
        send_mail(title,body)
        popup(body,48,title,2*60+30)
        raise
    end
  when 1,3,4,5
    #�e�X�g���[�h�P�A�R�A�S���͂T�̂Ƃ��AFTP�T�[�o��ւ̃t�H���_�w�肪����Ȃ�AHTML�t�@�C�������̃t�H���_�ɃR�s�[����B
    if Myfile.dir(:subst)
      FileUtils.cp(files,Myfile.dir(:subst))
    end
  end
end


#***** FTP���O�C���p�X���[�h�̕��� *****
def pass()
  src = File.open($ftp_pass, "r"){ |f| f.read }
  src.force_encoding("ascii-8bit")
  tmp = []
  src.each_codepoint do |cp| 
    tmp << (cp ^ 255) 
  end
  tmp.map{|i| i.chr}.join("")
end


#***** ���s����ruby.exe�̃t���p�X *****
def ruby_path
  path=""
  wmi = WIN32OLE.connect('winmgmts://')
  process_set = wmi.ExecQuery("select * from Win32_Process where Name like 'ruby%'")
  process_set.each do |item|
    path=item.CommandLine.match(/[^"]*\.exe/)
  end
  path.to_s.encode("Shift_JIS")
end


#***** �e�X�g���[�h�̔��� *****
# ��:$test_mode=0�̂Ƃ��Atest_mode?=>false,test_mode?(0)=>true
#    $test_mode=3�̂Ƃ��Atest_mode?(2,3,4)=>true
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


class String
  #*** �����񒆂̔��p������S�p�����ɕϊ� ***
  def han; [0,1,2,3,4,5,6,7,8,9];end
  def zen; ["�O","�P","�Q","�R","�S","�T","�U","�V","�W","�X"];end
  def num_to_zenkaku
    han.each do |num|
      self.gsub!(num.to_s,zen[num])
    end
    self
  end
  #*** �����񒆂̑S�p�����𔼊p�����ɕϊ� ***
  def num_to_hankaku
    zen.each do |num|
      self.gsub!(num,zen.index(num).to_s)
    end
    self
  end
  #*** "yyyymmdd"����"y�Nm��d���i�j���j"�ɕϊ� ***
  def day_to_jan
    return self unless self.match(/\d{8}/)
    date=Time.parse(self)
    m=date.month.to_s
    d=date.day.to_s
    y=date.yobi
    "#{m}��#{d}��(#{y})"
  end
  #*** "hh:mm"����"�ߑO/�ߌ� h �� mm ��"�ɕϊ� ***
  def time_to_jan
    return self unless self.match(/\d\d:\d\d/)
    ary=self.split(":")
    if self < "12:00"
      "�ߑO#{ary[0].to_i.to_s}��#{ary[1]}��"
    elsif self=="12:00"
      "����"
    else
      "�ߌ�#{(ary[0].to_i-12).to_s}��#{ary[1]}��"
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
  #�I�u�W�F�N�g��nil�Ȃ�u�|�v��Ԃ��A������Ȃ炻�̂܂ܕԂ��B
  #�i�O�i��NilClass�Ń��\�b�h��`�B�j
  def nil_to_bar
    self
  end
  #�I�u�W�F�N�g��nil�Ȃ�u�i�s���j�v��Ԃ��A������Ȃ炻�̂܂ܕԂ��B
  #�i�O�i��NilClass�Ń��\�b�h��`�B�j
  def nil_to_humei
    self
  end
  #*** "hh:mm"�`���̕�����̂܂܎��Ԍv�Z���ł���悤�ɂ���B
  alias_method :string_add,:+
  def +(second)
    if self.match(/\d\d?:\d\d/) and second.class==Fixnum
      t=Time.parse(self)+second
      t.strftime("%H:%M")
    elsif self.match(/\d{8}/) and second.is_a? Fixnum #���t�̉��Z 2014.3.31�t��
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
    elsif self.match(/^\d{8}$/) #���t�̈����Z 2014.3.31�t��
      if  second.is_a? Fixnum 
        t=Date.parse(self)-second
        t.strftime("%Y%m%d")
      elsif second.is_a? String and second.match(/^\d{8}$/)
        t=Date.parse(self)-Date.parse(second)
      end
    end
  end
  def seiji  #2014.4.3 �t��
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
    "#{Time.parse(self).yobi}�j��"
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
    "��#{week_num.to_s}#{self.nan_yobi}"
  end
  def variation
    return nil unless self.match(/^\d{8}$/)
    v=[self,self.nan_yobi,self.dai_nan_yobi,self.dai_nan_yobi.num_to_zenkaku]
    if $rinji_kaichobi.include? self
      v << "�Վ��J����"
    end
    v
  end
  #��O�Ƃ��ĊJ���Ȃ������̑����ԍ��z��
  def closed_mado
    return [] unless $closed_mado
    cdays=Array.new
    $closed_mado.each_line do |line|
      cdays << line.chomp.gsub(/("|�@)/,"").split
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
    kakusyu_kaichobi=$kaichobi.select{|day| day=~/��.*�j��/}
    today=self.variation.select{|day| day=~/��.*�j��/}
    unless kakusyu_kaichobi & today == []
      true
    else
      false
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
    self.to_s << "�l"
  end
end


class Fixnum
  def to_hhmm
    "%02d:00" %self
  end
  def yobi
    ["��","��","��","��","��","��","�y"][self]
  end
  #�G���R�[�h�̃G���[�ɂȂ邱�Ƃ�����̂ŉ��
  alias_method :to_string,:to_s
  def to_s
    to_string.force_encoding("Shift_JIS")
  end
end


class Time
  def yobi
    ["��","��","��","��","��","��","�y"][self.wday]
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
  #$test_mode=2,3,4,5�̏ꍇ�̌��ݎ�
  class << Time; alias real_now now; end
  @@jisa ||= Time.real_now - parse($datetime) if $datetime and test_mode?(2,3,4,5)
  def self.now
    return real_now - @@jisa if defined? @@jisa
    real_now
  end
end


class NilClass
  def method_missing(method,*)
    #�O�i�FRaichoList�������̏����ōi�荞�ނƂ�,nil�Ǝ����̑召��r���\�Ƃ���B
    #��i�F�Y��Raichosya�����݂��Ȃ��ꍇ���l�������ɁARaichosya�ɑ΂��郁�\�b�h���g�p�\�Ƃ���B
    if [:>,:<,:>=,:<=].include?(method) or RaichoSya.instance_methods.include? method
      nil
    end
  end
  def nil_to_bar
    "�|"
  end
  def nil_to_humei
    "�i�s���j"
  end
end


#�ȉ��́A�Ǝ��̃I�u�W�F�N�g�N���X��`
class VcallMonitor
  attr_reader :login_time
  def initialize
    @vcall_exe=$vcall_exe
    @vcall_path=$vcall_path
    @moniter_system_window_title=$moniter_system_window_title
    @vcall_hakkenki_address=$vcall_hakkenki_address
    @login_time=nil
  end
  #***** ���O�C�����Ă��邩�ǂ���(���O�C�����Ă���Ƃ���@login_time���Z�b�g) *****
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
      nil
    end
  end
  #***** Windows�̃C�x���g���O�̐ݒ�(���܂�) *****
  def self.set_event_log
    `runas /user:administrator wevtutil cl Application /bu:Application_bak`
    #***** �E�C���h�E�Y�̃A�v���P�[�V�����C�x���g���O�̍ő�T�C�Y��1024KB�ɐݒ肷��B *****
    `runas /user:administrator wevtutil sl Application /ms:64`
    #***** �E�C���h�E�Y�̃A�v���P�[�V�����C�x���g���O���㏑�����[�h�i�Â����̂�������j�ɂ���B *****
    `runas /user:administrator wevtutil sl Application /r:false /ab:false`
  end
  #***** Windows�̃C�x���g���O�Ɍ��ʂ��������� *****
  def self.write_event_log(event: :error,text: nil)
  #event: :success=>0,:error=>1,:worning=>2,:info=>4
    eh={:success=>0,:error=>1,:worning=>2,:info=>4}
    wsh = WIN32OLE.new('WScript.Shell')
    wsh.LogEvent(eh[event],text)
  end
  #***** �A�N�e�B�u�E�C���h�E�̃^�C�g�����擾���� *****
  def title_of_active_window
    require 'Win32API'
    fore_window = Win32API.new('user32','GetForegroundWindow','','l')
    window_txt = Win32API.new('user32', 'GetWindowText', 'lpi','i')
    gaw=fore_window.call
    if gaw!=0
      buf="\0"*1000
      window_txt.call(gaw,buf,buf.size)
      buf.unpack("A*").first.force_encoding("Shift_JIS")
    else
      "�擾���s"
    end
  end
  #***** ���j�^�V�X�e���̃v���Z�XID���擾 *****
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
  #***** ���j�^�V�X�e���I�� *****
  def stop
    app_activate
    unless title_of_active_window=="�擾���s"
      wsh = WIN32OLE.new('WScript.Shell')
      wsh.SendKeys "{ESC}{ESC}"
      wsh.SendKeys "%fx"
      #wsh.SendKeys "x"
    end
    #ALT��F��X�ŉ��₩�ɏI���ł��Ȃ������Ƃ��̓v���Z�X�������I������B
    unless process_id==nil
      wmi = WIN32OLE.connect('winmgmts://')
      process_set = wmi.ExecQuery("select * from Win32_Process where Name='"+@vcall_exe+"'")
      process_set.each do |item|
        item.terminate
      end
    end
  end
  #***** ���j�^�V�X�e���N�� *****
  def start
    unless dir_check @vcall_path.gsub(/\"/,"")
      popup @vcall_path + "�͑��݂��܂���B�p�X����������������x�m�F���Ă��������B"
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
  #***** ���j�^�V�X�e���N������ ********************************
  #***** �N���̊m�F���ł���܂�,�ő�T��܂ŋN����(��)�g���C����B**
  def start_vcall_monitor
    5.times do |i|
      if start == :success and data_communication_with_hakkenki=="�ʐM��"
        return :success
      else
        stop
        sleep 2
      end
    end
    return false
  end
  #***** ���j�^�V�X�e���ċN�� *****
  def restart_vcall_monitor
    stop
    start_vcall_monitor
  end
  #*** Windows�C�x���g����CIM�`���̓��t��ʏ�̃��[�J���^�C���ɕϊ����� ***
  def cim_to_localtime(cim)
    t=cim.sub(/([\-|\+])(\d\d\d)/) {$1+"0#{($2.to_i/60).to_s}"[-2,2] + "0#{($2.to_i%60).to_s}"[-2,2]}
    Time.parse(t).localtime
  end
  #***** �ŐV�̃A�v���P�[�V�����C�x���g���擾����B *****
  #���� time_zone:�w�肵�����ߎ��Ԃ̃C�x���g����������i�f�t�H���g�l��1���Ԉȓ��j
  #     type:     �G���[���O����������Ƃ��́utype:"�G���["�v�Ƃ���B�u�����N�ɂ���ƃ��O�^�C�v�ɂ�炸��������B
  #     key_word: �w�肵���L�[���[�h�����b�Z�[�W�Ɋ܂ލŐV�̃��O����������B�u�����N�ɂ���Ɓu�y���j�^�V�X�e���z�v���܂ރ��O�B
  def get_event(time_zone:1.hour,type:nil,key_word:"�y���j�^�V�X�e���z")
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
  #�V���b�g�_�E��
  def shutdown_pc(popup_message,time_before_shutdown)
    start_time=Time.now
    ans=popup(popup_message,65,"�Ɩ��I����������",time_before_shutdown)
    unless ans==2
      while Time.now<start_time+time_before_shutdown
        sleep 1
      end
      `shutdown.exe /s /f /t 5`
    else
      popup "�V���b�g�_�E���܂ł̃J�E���g�_�E���𒆎~���܂����B"
    end
  end
  #�����@�����ping����
  def ping_respons_from_hakkenki
    unless defined? @vcall_hakkenki_address
      popup "�ݒ�t�@�C���ɔ����@��IP�A�h���X��o�^���Ă��������B",10
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
  #�����@�����ping�����̗L��(�O�̂��ߍő�R����s)
  def ping_respons_from_hakkenki?
    3.times do
        return true if ping_respons_from_hakkenki=="Success" or $dummy_hakkenki
    end
    false
  end
  #�����@�Ƃ̒ʐM�ڑ��󋵁inetstat�j
  #netstat�R�}���h��DOS�����J���Ȃ��Ŏ��s���Č��ʂ��擾���邽�߁A
  #WSH��cmd���g�p���Č��ʂ���������t�@�C���ɏ����o���B
  def data_communication_with_hakkenki
    wsh = WIN32OLE.new('WScript.Shell')
    wsh.Run("cmd /c netstat -n > #{__dir__}/netstat.txt",0,true)
    f=File.read("#{__dir__}/netstat.txt")
    if f.match /#{@vcall_hakkenki_address}.*ESTABLISHED$/
      "�ʐM��"
    else
      if ping_respons_from_hakkenki?
        "�ʐM�ؒf"
      else
        "����r��"
      end
    end
  end
  #***** Ruby�v���O�������N��(�񓯊��A�I����҂����ɐe�v���Z�X�I��) *****
  def asynchronous_call(ruby_file)
    if File.exist?(ruby_file)
      str="#{ruby_path} #{ruby_file}"  
      wsh = WIN32OLE.new('WScript.Shell')
      wsh.Run(str,0,false)
      puts "�u#{ruby_file}�v���N�����܂����B"
    else
      popup "�u#{ruby_file}�v��������܂���B"
    end
  end
end


#*** MadoSysFile�N���X (2014.4.3) ***
#*** config.txt�Ŏw�肵���t�@�C�����A�t�H���_�[���i�[���� ***
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
    if $hinagata and $hinagata.class==Array  #�Â��ݒ�`���̂Ƃ�
      hinagata[:pc]           =$hinagata[0]                 
      hinagata[:keitai]       =$hinagata[1]
      hinagata[:sumaho]       =$hinagata[2]
      hinagata[:monitor]      =$hinagata_monitor  if defined? $hinagata_monitor
    elsif $hinagata and $hinagata.class==Hash #�ŐV�̐ݒ�`���̂Ƃ�
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
    elsif defined? $html_file                                  #�ŐV�̐ݒ�`���̂Ƃ�
      keys = $html_file.keys
      file_name[:pc]          =$html_file[:pc]
      file_name[:keitai]      =$html_file[:keitai]
      file_name[:sumaho]      =$html_file[:sumaho]
      file_name[:monitor]     =$html_file[:monitor]           if keys.include? :monitor
      file_name[:suii_hun]    =$html_file[:suii_hun]          if keys.include? :suii_hun
      file_name[:suii_syasu]  =$html_file[:suii_syasu]        if keys.include? :suii_syasu
      file_name[:suii_machisu]=$html_file[:suii_machisu]      if keys.include? :suii_machisu
    end
    file[:monitor]  =$monitor_folder+"/"+$html_file[:monitor] if $html_file[:monitor]
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
    dir[:current]   =__dir__.force_encoding("Shift_JIS")
    dir[:temp]      =dir[:current]+"/"+$temp_folder if $temp_folder
    dir[:subst]     =$substitute_folder             if $substitute_folder
    dir[:ftp]       =$ftp_dir                       if $ftp_dir
    dir[:kako_log]  =MYDOC+"/"+$logfolder           if $logfolder
    dir[:log_backup]=$log_backup_folder             if $log_backup_folder
    dir[:excel]     =$excel_folder                  if $excel_folder
    dir[:monitor]   =$monitor_folder                if $monitor_folder
    dir[:suii]      =$suii_folder                   if $suii_folder
    dir[:suii]    ||=dir[:monitor]+"/suii"          if $monitor_folder
    def self.sub_mydoc(path)
      h={ "�}�C�h�L�������g"  => MYDOC,
          "�h�L�������g"      => MYDOC,
          "My Documents"      => MYDOC,
          "MyDocuments"       => MYDOC,
          "Documents"         => MYDOC,
          "�f�X�N�g�b�v"      => DESKTOP,
          "Desktop"           => DESKTOP }
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
  def keys_of_suii #2014.6.25 �ǉ�
    $hinagata.keys.select{|key| key.to_s=~/suii/}
  end
end


#*** ���ԍ��N���X ***
class KenBango
  attr_accessor :mini,:max
  def initialize(mini=nil,max=nil)
    @mini = mini
    @max  = max
  end
  def self.parse(ken_bango)
      ary = ken_bango.split("�`")
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
	    ary=line.chomp.gsub("�@","").split
      unless ary[1].match(/\d\d?:\d\d?�`\d\d?:\d\d?/)
	      config_error
      end
      @@yobi_jikan[ary[0]]=ary[1]
	  end
    @@yobi_jikan
  end
  def self.config_error
    if test_mode? #����e�X�g�̂Ƃ�
      popup "�y�G���[�z�������G�󋵕\���V�X�e��\n�J�����Ԃ̎w��`���Ɍ�肪����܂��B�ݒ�t�@�C��(config.txt)���������Ă��������B"
    else
      send_mail("�y�G���[�z�������G�󋵕\���V�X�e��","�J�����Ԃ̎w��`���Ɍ�肪����܂��B�ݒ�t�@�C��(config.txt)���������Ă��������B")
    end
    raise
  end
  def self.kaicho_jikan(day)
    #�Y������j��,������t���Ȃ��Ƃ��͊J�������ǂ�����ǋ������A
    #"�Վ��J����"�̊J�����Ԃ��Z�b�g����B
    yobi  =day.yobi
    yymmdd=day.to_yymmdd
    key  =yobi_jikan.keys.find{|k| k[0]==yobi}
    key  =yymmdd if yobi_jikan.key? yymmdd
    key||="�Վ��J����" 
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
  #���d�l��config.txt�̏ꍇ
  def self.setup_for_old_config(today)
    today=Today if today==nil
    yobi  = Time.parse(today).wday
    if defined? $rinji_kaichobi and $rinji_kaichobi==today
    #�Վ��J����
      if defined? $kaicho_jikan_rinji_kaichobi
        self.parse($kaicho_jikan_rinji_kaichobi)
      else
        #�Վ��J�����̊J�����Ԃ̎w�肪�Ȃ��Ƃ��y�j���̊J�����Ԃ����p
        self.parse($kaicho_jikan_sat) 
      end
    elsif yobi.between?(1,5)
    #�����i�Վ��J�����łȂ����`���j
      self.parse($kaicho_jikan_weekday)
    else
    #�y�j�J�����i�Վ��J�����y�ь��`���ȊO�j
      self.parse($kaicho_jikan_sat)
    end
  end  
  def self.parse(str)
    kai,hei = str.split("�`")
    kaicho = Time.parse(kai).strftime("%H:%M")
    heicho = Time.parse(hei).strftime("%H:%M")
    self.new(kaicho,heicho)
  end
  def mai_seiji #2014.3.31 �t��
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
  def mai_ji #2014.3.31 �t��
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


#*** �ڈ��҂����ԃN���X ***
class MeyasuMachijikan
  attr_accessor :jamm_mess_ary
  def initialize(jamm_mess_ary)
    @jamm_mess_ary=jamm_mess_ary
  end
  def self.parse(string)
    ary=[]
    string.each_line do |line|
     ary << line.chomp.gsub("�@","").split
    end
    self.new(ary)
  end
  def meyasu_jikan(mado,machisu)
    #2014.3.27 �ݒ�t�@�C��(config.txt)�ɖڈ��҂����Ԃ̃��b�Z�[�W��
    #          �o�^����Ă��Ȃ��ꍇ�̃G���[��������鏈����ǉ��B
    begin
      @jamm_mess_ary.find{|m,n,mess| m==mado and n.to_i<=machisu}[2]
    rescue  
      ""
    end
  end
end


#*** ���O�C�x���g�N���X(�C�x���g�̔z��I�u�W�F�N�g) ***
class LogEvents
  include Enumerable
  attr_reader :events #Event�N���X�I�u�W�F�N�g�̔z��
  def initialize(events)
    @events=events
  end
  def self.setup(log_file,day,mode=nil)
    return self.new(nil) if log_file==nil
    line_ary=[]
    sym={$kubun["����"]=>:hakken,$kubun["�ďo"]=>:yobidashi,$kubun["�L�����Z��"]=>:cancel}
    f=File.read(log_file).each_line do |line|
      date,time,kubun_code,gyomu_code,bango = line.chomp.split(",")
      next if date!=day
      break if test_mode? and mode==nil and log_file==Myfile.file(:log) and time>TimeNow
      #���e�X�g���[�h�Ŏw��t�H���_�̃��O����������Ƃ��͌��ݎ���̃��O�f�[�^�͓ǂ܂Ȃ��B
      mado=$gyomu[gyomu_code]
      bango=bango.to_i
      kubun_code=kubun_code.to_i
      next if error_data?(log_file,mado,bango,mode)
      line_ary << Event.new(time,kubun_code,sym[kubun_code],mado,bango)
    end
    #Prolog.csv�͎�������̏ꍇ�ɔԍ����t�]����ꍇ������̂Ń\�[�g����B
    line_ary=sort(line_ary)
    self.new(line_ary)
  end
  #*** �\�[�g *** 2014.10.27 inuzuka
  # �����A�C�x���g�敪�R�[�h�A�ԍ����L�[�ɂ��ď����ɕ��ёւ�
  # �A���A���ꎞ���ɍŏI�ԍ�����ŏ��ԍ��ɖ߂����Ƃ��͔ԍ��̍~�����ێ�����B
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
  #*** �����ԍ��Ɣԍ��̐������`�F�b�N ***
  def self.error_data?(log_file,mado,bango,mode)
    return false if $bango[mado].range.include? bango  #���Ȃ��Ƃ�
    return false if mode==:prior_check                 #���O�`�F�b�N�̂Ƃ��͂Ƃ肠�����S�ēǂݍ���
    return true unless test_mode?                      #�{�Ԃł̓G���[�f�[�^�̓X�L�b�v���ēǍ��p��
    #�e�X�g���[�h�̂Ƃ��̓G���[���b�Z�[�W��\�����Ď��s���f����B
    data_error(log_file,mado,bango) 
  end
  #*** �e�X�g���[�h�̂Ƃ��̌x���\���B
  def self.data_error(log_file,mado,bango)
    err_mess  = "#{mado}�ԑ����Ɋ����Ă�ꂽ�ԍ��͈͊O�̔ԍ� #{bango.to_s}"
    err_mess += " �����O�t�@�C��( #{log_file} )�ɂ��邽�߃v���O�����̎��s�𒆎~���܂����B"
    popup err_mess,48,"�G���["
    exit
  end
  def each
    @events.each do |ev|
      yield ev
    end
  end
  def size
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


#*** �C�x���g�N���X�i�X�̃C�x���g���O�j ***
class Event
  attr_accessor :time,:kubun_code,:kubun,:mado,:bango
  def initialize(time,kubun_code,kubun,mado,bango)
    @time,@kubun_code,@kubun,@mado,@bango = time,kubun_code,kubun,mado,bango
  end
  def to_a
    [@time,@kubun_code,@kubun,@mado,@bango]
  end
end


#*** �����҃N���X ***
class RaichoSya  
  attr_accessor :time_h, :bango, :id, :time_y, :time_c, :machi_su
  def initialize(time_h=nil, bango="�|", id=nil, time_y=nil, time_c=nil, machi_su=nil)
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
  def machi_hun
    return nil             if @time_h == nil
    return @time_y-@time_h if @time_y != nil
    return @time_c-@time_h if @time_c != nil
    TimeNow-@time_h
  end
end


#*** �����҃��X�g�N���X ***
class RaichoList
  include Enumerable
  attr_accessor :log_file,:mado,:raicholist,:day
  def initialize(log_file=nil,mado=nil,day=nil)
    @log_file=log_file
    @mado=mado
    @day=day
    @raicholist=Array.new
  end
  def self.setup(log_file,mado_array,day=Today)
    @@list=Array.new
    log=Hash.new
    log_file=nil if File.exist?(log_file)==false
    mado_array.each do |mado|
      log[mado] = self.new(log_file,mado,day)      
      @@list << log[mado]
    end
    @@events=LogEvents.setup(log_file,day)
    @@events.each do |event|
      if event.kubun==:hakken
        log[event.mado].add_raichosya(event.bango,event.time)
      end
    end
    @@events.each do |event|
      if event.kubun==:yobidashi or event.kubun==:cancel
        log[event.mado].add_time(event.time,event.kubun,event.bango)
      end
    end
    @@list.each do |log|
      log.add_machi_su
    end
    log
  end
  #������������������ ���Z�b�g�A�b�v�p���\�b�h�� ��������������������������  
  #*** �V���������҃I�u�W�F�N�g��ǉ����� ***
  #*** (��єԍ����������Ƃ��͕⊮����)   ***
  def add_raichosya(bango,time_hakken=nil,time_yobidashi=nil,time_cancel=nil)
    until bango==self.last_bango
      self.add_next_bango
    end
    self[-1].time_h = time_hakken
    self[-1].time_y = time_yobidashi
    self[-1].time_c = time_cancel
  end
  #*** ���̔����ԍ��̗����҃I�u�W�F�N�g��ǉ����� ***
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
  #*** ���O�̌ďo�����𗈒��҃I�u�W�F�N�g�ɕt�� ***
  def add_time(time,kubun,bango)
    list=self.reject_sya_hakkened_after(time)
    sya=list.select{|sya| sya.bango==bango and sya.time(:yobidashi_or_cancel)==nil}[-1]
    if sya.id>0
      case kubun
      when :yobidashi  ; sya.time_y=time #����ԍ�����������ꍇ���l��
      when :cancel     ; sya.time_c=time
      end
    else
      #�����f�[�^�̎�肱�ڂ����������Ƃ��͗����҃f�[�^��t��
      #(add_raichosya�ɔ�єԂ̕⊮�@�\����ꂽ�̂ŕs�v�ɂȂ����Ǝv����B)
      case kubun
      when :yobidashi; self.add_raichosya(bango,nil,time,nil) if isdropped?(bango,time)
      when :cancel   ; self.add_raichosya(bango,nil,nil,time) if isdropped?(bango,time)
      end
    end
  end
  #�w�莞������ɔ�������sya�����O���������҃��X�g�I�u�W�F�N�g
  def reject_sya_hakkened_after(time)
    id=self.find{|sya| sya.time(:hakken)>time}.id
    unless id==nil
      self.reject{|sya| sya.id>=id}
    else
      self
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
  #*** �������̑҂��l���𗈒��҃I�u�W�F�N�g�ɕt������ ***
  def add_machi_su
    self.each do |sya|
      sya.machi_su = self.machi_su(sya.id) if sya.time(:hakken)
    end
  end
  
  
  #��������������������  ��b�c�[���I���\�b�h ������������������������
  def add_list(list)
    @raicholist=list
  end
  def self.events
    @@events
  end
  #*** events�z��̕����W�� 2014.07.19�C�� ***
  def self.part_events(mado=nil,kubun=nil)
    m,k = mado,kubun
    return self.events                                              if m==nil and k==nil
    return self.events.select{|event| event.kubun== k}              if m==nil
    return self.events.select{|event| event.mado == m}              if k==nil
    self.events.select       {|event| event.kubun== k and mado== m}
  end
  #*** �����҃I�u�W�F�N�g�̔z����R���\�[����ʂɓW�J����B ***
  def display
    alert "�����҃��X�g�I�u�W�F�N�g(#{self.mado}�ԑ���)"
    self.each{|sya| alert(sya.to_a)}
  end
  #*** �e������RaichoList�I�u�W�F�N�g�������������� ***
  def self.each
    @@list.each do |raicholist|
      yield raicholist
    end
  end
  #*** �eRaichosya�I�u�W�F�N�g�������������� ***
  def each
    @raicholist.each do |sya|
      yield sya
    end
  end
  #*** select�̖߂�l��RaichoList�N���X�I�u�W�F�N�g�ɂ���
  def select
    l=@raicholist.select  do |sya|
      yield sya
    end
    list=RaichoList.new
    list.add_list(l)
    list
  end
  #*** reject�̖߂�l��RaichoList�N���X�I�u�W�F�N�g�ɂ���
  def reject
    l=@raicholist.reject  do |sya|
      yield sya
    end
    list=RaichoList.new
    list.add_list(l)
    list  
  end
  def self.log_file
    if @@list.size>0
      @@list[0].log_file
    else
      Myfile.file(:log)
    end
  end

  #��������������������  �����҃��X�g�̕����W�� ����������������������������
  
  #*** ���������ƌďo�������̂��闈���҂̗����҃��X�g�I�u�W�F�N�g�i2014.3.31�t���j ***
  def complete
    self.select{|sya| sya.time(:hakken)!=nil and sya.time(:yobidashi)!=nil}
  end
  #***** �ďo���҂��̗����҂̗����҃��X�g�I�u�W�F�N�g ******
  def not_called
    self.select{|sya| sya.time(:yobidashi)==nil and sya.time(:cancel)==nil}
  end
  #***** �w�肵��id�̗����҃I�u�W�F�N�g���폜����(2014.4.13) *****
  def reject_id(id)
    self.reject{|sya| sya.id==id}
  end

  
  #��������������������  ����̗����҃I�u�W�F�g��Ԃ� ������������������������
  
  #*** �w��id�ԍ�(id=-1�̂Ƃ��͍ŏIid)�̗����҃I�u�W�F�N�g ***
  def [](id)
    return self.max_by{|sya| sya.id} if id==-1
    self.find{|sya| sya.id==id}
  end
  #*** ���߂̗����҃I�u�W�F�N�g ***
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
  #*** ���ɌĂяo���\��̗����҃I�u�W�F�N�g ***
  def next_call(time=TimeNow)
    id=self.yobidashi_sya_just_before(time).id
    id=0 if id==nil # 2014.4.22
    list=self.not_called.select{|sya| sya.id>id}
    return RaichoSya.new() if list.size==0
    list.min{|sya| sya.id}
  end
  
  
  #��������������������  �l���𒲂ׂ� ������������������������
  
  #*** �w�莞���̑҂��l�� ***
  def machi_su(time_or_id=TimeNow)
    case time_or_id.class.to_s
    when "String" ; time = time_or_id
      hakken_id    = hakken_sya_just_before(time).id
      yobidashi_id = yobidashi_sya_just_before(time).id
      hakken_id    = 0 if hakken_id==nil        #�܂��N�ɂ��������Ă��Ȃ��Ƃ�
    when "Fixnum" ; id   = time_or_id
    #����̗����҂ɒ��ڂ����҂��l���̍l����
    #���Y�����҂ɔ����������ʂƂ��āA�����@�̑҂��l���̕\����x�l�ɂȂ����Ƃ�
    #�����Ƃ��ē��Y�����҂ɂƂ��Ă̑҂��l����x�l�Ƃ���B�������g��҂��l����
    #�J�E���g����͈̂ꌩ�s�����悤�����A�ʏ�͑����Ō��ݎ�t���̐l���I����
    #�҂K�v������̂ŁA�����̑O�ɑ҂��Ă���l�{��t����1�l�ƍl����΂悢�B
    #��O�Ƃ��āA�����������ďo�����̏ꍇ�́A�������󂢂Ă����Ƃ݂Ȃ���̂�
    #�҂��l���[���Ƃ���B
      hakken_id    = id
      yobidashi_id = yobidashi_sya_just_before(self[id].time(:hakken)).id
      # ���w��id�̐l�̔����������ďo�����̂Ƃ��Ayobidashi_id=id�ɂȂ�B
      time         = self[id].time(:hakken)
    end
    yobidashi_id = 0 if yobidashi_id==nil  #�܂��N���Ăяo���Ă��Ȃ��Ƃ�
    canceled     = canceled(yobidashi_id,hakken_id,time) #2014.7.22
    su=hakken_id-yobidashi_id-canceled
    su=0 if su<0  #�N���̒x��ȂǂŔ����������L�^����Ă��Ȃ��P�[�X��
    su
  end
  #*** �����Ґ��P id�ԍ�����v�Z����i���ۂ̗����Ґ��ɍł��߂��j ***
  def sya_su(time=TimeNow)
    unless @raicholist.size==0
      h=current(:hakken,time).id
      y=current(:yobidashi,time).id
      c=current(:cancel,time).id
      [h,y,c].reject{|kubun| kubun==nil}.max
    else
      0
    end
  end
  #*** �����҂̐��Q ���炩�̎����̋L�^�̂��闈���� ***
  #�i�f�[�^�̎�肱�ڂ�������Ǝ����̂Ȃ������҃I�u�W�F�N�g���ł��邱�Ƃ�����B�j
  def size(time=TimeNow)
    l=self.select do |sya|
      sya.time(:hakken) <= time or sya.time(:yobidashi) <= time or sya.time(:cancel) <= time
    end
    l.raicholist.size
  end
  #*** ������̗����Ґ�(�����F9����=>9,13����=>13) ***
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
  #**** id1��id2�̊ԂŃL�����Z�����������҂̐� (2014.7.22����������t��)***
  def canceled(id1,id2,time=TimeNow)
    mado=self.mado
    i=[id1,id2]
    self.select{|sya| sya.time(:cancel)<=time}.count{|sya| sya.id>=i.min and sya.id<=i.max}
  end
  #*** �w�莞���ɂ�����S�����̍��v�����Ґ� ***
  def self.sya_su(time=TimeNow)
    su=0
    @@list.each do |raicholist|
      su+=raicholist.sya_su(time)
    end
    su
  end
  #*** �w�莞���ɂ�����S�����̍��v�҂��l�� ***  
  def self.machi_su(time=TimeNow)
    su=0
    @@list.each do |raicholist|
      su+=raicholist.machi_su(time)
    end
    su
  end


  #��������������������  �����𒲂ׂ� ������������������������  
  
  #*** �����҃I�u�W�F�N�g�ɋL�^���ꂽ�ŏI(����/�ďo/�L�����Z��)���� ***
  def last_time(kubun,time=TimeNow)
    self.select{|sya| sya.time(kubun)<=time}.max_by{|sya| sya.time(kubun)}.time(kubun)
  end
  #*** �ŐV�̃f�[�^�X�V�����i�����ʁj ***
  def last_update_time
    events=RaichoList.part_events(self.mado)
    events.max_by{|event| event.time}.time
  end
  #*** �ŐV�̃f�[�^�X�V�����i�S�����j ***
  def self.last_update_time
    events=RaichoList.events
    events.max_by{|events| events.time}.time
  end
  

  #��������������������  �f�[�^�X�V�� ������������������������  

  #*** �w�莞�Ԉȓ��̃f�[�^�X�V�i�����ʁj***
  def update?(t)
    time=self.last_update_time
    return nil if time==nil
    if time+t>=TimeNow
      true
    else
      false
    end
  end
  #*** �w�莞�Ԉȓ��̃f�[�^�X�V�i�S�����j ***
  def self.update?(t=1.hour)
    time=RaichoList.last_update_time
    return nil if time==nil
    if time+t>=TimeNow
      true
    else
      false
    end
  end
  #*** �w�莞�Ԉȓ��̃��O�t�@�C���X�V�i�S�����j ***
  def self.logfile_update_within(t)
    logfile=self.log_file
    mtime = File.mtime(logfile) 
    return :no_log_file    unless File.exist?(logfile)
    return self.update?(t) if test_mode?(2,3,4,5) #�e�X�g�p
    return :no_todays_file if mtime.to_date!=Date.today
    return Time.now - mtime < t
  end
  #*** �{�C�X�R�[�����O�̑S�̏� ***
  def self.state_whole
    return "no_data"   if self.events.size==0
    return "no_update" if self.update? == false
    "correct"
  end

  #����������������  �O���t�Ɏg�p���鎞�Ԗ��̏�� ����������������������  

  #***** �������̑҂��l�� (2014.3.31 compare_modo��t����)*****
  # compare_mode=:yes�̂Ƃ��́A���̖������҂����Ԃ̊Y���҂̑҂��l�����擾����B
  def maiseiji_machi_su(kaichojikan=$ku,compare_mode: :no)
    su=Hash.new
    return su if self.log_file==nil #2014.6.25 �_�~�[�I�u�W�F�N�g�Ƌ�f�[�^�����
    seiji=kaichojikan.mai_seiji
    seiji.each do |ji|
      break if self.log_file==Myfile.file(:log) and TimeNow < ji #2014.9.27 2�̏����̏������t�]
      case compare_mode
      when :yes
        sya=self.complete.hakken_sya_just_before(ji) # machi_hun�Ɠ���̗����҂̃f�[�^�Ƃ��邽�߃L�����Z�����������҂����O
        if sya.id==nil and ji==seiji[0]              # �J����ŏ��̐���(9��)�ł܂������҂��Ȃ��Ƃ� 2014.7.19
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
  #***** ������(or�������O30��)�̒��߂̔����ԍ��̑҂�����(��) �i2014.3.31�t���j*****
  def maiseiji_machi_hun(kaichojikan=$ku)
    hun=Hash.new
    return su if self.log_file==nil #2014.6.25 �_�~�[�I�u�W�F�N�g�Ƌ�f�[�^�����
    seiji=kaichojikan.mai_seiji
    seiji.each do |ji|
      break if self.log_file==Myfile.file(:log) and TimeNow < ji #2014.9.27 �����̏������t�]
      sya=self.complete.hakken_sya_just_before(ji) # �L�����Z�����������҂����O
      if sya.id==nil and ji==seiji[0]              # �J����ŏ��̐���(9��)�ł܂������҂��Ȃ��Ƃ� 2014.7.19
        hun[ji]=0
      else
        hun[ji]=sya.machi_hun
      end
    end
    hun
  end
  #***** �����̗����Ґ� *****
  #KaichoJikan�N���X�I�u�W�F�N�g�������ɂ���悤�ύX�i2014.3.31�j
  #�߂�l��:{8=>2,9=>8,10=>20,11=>23,�c}
  def maiji_sya_su(kaichojikan)
    su=Hash.new
    return su if self.log_file==nil #2014.6.25 �_�~�[�I�u�W�F�N�g�Ƌ�f�[�^�����
    kaichojikan.mai_ji.each do |ji|
      break if self.log_file==Myfile.file(:log) and TimeNow < ji.to_hhmm #2014.9.27 �����̏������t�]
      su[ji]=self.jikan_betsu_sya_su(ji)
    end
    su
  end


  #��������������������  ���̑��̓��v�I��� ������������������������  

  #*** ���ϑ҂����ԁi���j ***
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



#*****************************************
#***** ��������̓I�v�V�����@�\
#*****************************************

#***** �ۓ����j�^�[ *****
def make_monitor_data(log)
  str_tag1 = ""
  str_tag2 = ""
  str_tag3 = ""
  str_csv  = ""
  $mado_array.each do |mado|
    sya=log[mado].yobidashi_sya_just_before
    if sya.id==nil
      bango             = "�|"
      hakken_ji_machisu = "�|"
      machi_hun         = "�|"
      machisu_now       = "�|"
      id                = nil
    else
      bango             = sya.bango.to_s
      hakken_ji_machisu = sya.machi_su.to_s
      machi_hun         = sya.machi_hun.to_s
      hakken_ji_machisu = "���" if hakken_ji_machisu ==""
      machi_hun         = "���" if machi_hun==""
      machisu_now       = log[mado].machi_su
      id                = sya.id
    end
    sya2=log[mado].next_call   
    if sya2.id!=nil and sya2.time(:hakken) != nil
    # 2014.4.1 ���2�ڂ̏�����t��(���������s���̏ꍇ�̃G���[�����)
      machi_hun_of_next_num = (TimeNow - sya2.time(:hakken)).to_i.to_s
      if sya.time(:yobidashi) < sya2.time(:hakken)
        keika_hun = (TimeNow - sya2.time(:hakken)).to_i.to_s
      else
        keika_hun = (TimeNow - sya.time(:yobidashi)).to_i.to_s
      end
    else
      machi_hun_of_next_num = "�|"
      keika_hun             = "�|"
    end
    str_tag1 << "<tr><td><a href=\"\##{mado}\">#{mado}</a></td>"
    str_tag1 << "<td>#{bango}</td>"
    str_tag1 << "<td>#{hakken_ji_machisu}�l</td>"
    str_tag1 << "<td>#{machi_hun}��</td>"
    if machisu_now.to_i > 19
      str_tag1 << "<td><span class=\"alert\">#{machisu_now}�l</span></td>"
    else
      str_tag1 << "<td>#{machisu_now}�l</td>"
    end
    if machi_hun_of_next_num.to_i > 49
      str_tag1 << "<td><span class=\"alert\">#{machi_hun_of_next_num}��</span></td>"
    else
      str_tag1 << "<td>#{machi_hun_of_next_num}��</td>"
    end
    if keika_hun.to_i > 10
      str_tag1 << "<td><span class=\"alert\">#{keika_hun}��</span></td>\n"
    else
      str_tag1 << "<td>#{keika_hun}��</td>\n"
    end
    mado_start = true
    log[mado].each do |sya|
        bango = sya.bango.to_s
        su    = sya.machi_su.to_s
        hun   = sya.machi_hun.to_s
        su    = "���" if su ==""
        hun   = "���" if hun==""
      if sya.time(:hakken)==nil and sya.time(:yobidashi)==nil and sya.time(:cancel)==nil
        time     = "�s�� �� �s��"
        ary = [mado,  bango,  "���",  time,  "���"]
        if id!=nil and sya.id < id
          str_tag3 << "<tr><td>" << ary.join("</td><td>") << "</td></tr>\n"
        else
          str_tag2 << "<tr><td>" << ary.join("</td><td>") << "</td></tr>\n"
        end
      elsif sya.time_y==nil and sya.time_c==nil
        if id!=nil and sya.id < id
          time     = sya.time(:hakken) + "�� (�s���j"
          ary = [mado,  bango,  su+"�l",  time,  "���"]
          str_tag3 << "<tr><td>" << ary.join("</td><td>") << "</td></tr>\n"
        else
          time     = sya.time(:hakken) + "�� (�҂���)"
          ary = [mado,  bango,  su+"�l",  time,  hun+"���o��"]
          str_tag2 << "<tr><td>" << ary.join("</td><td>") << "</td></tr>\n"
        end
      else
        if sya.time_c!=nil
          time     = sya.time(:hakken).nil_to_humei + "��" + "�L�����Z��"
        elsif sya.time_y!=nil
          time     = sya.time(:hakken).nil_to_humei + "��" + sya.time(:yobidashi)
        end
        ary = [mado,bango,su+"�l",time,hun+"��"]
        if mado_start==true
          str_tag3 << "<tr><td><a name=\"#{mado}\"></a>" << ary.join("</td><td>") << "</td></tr>\n"
          mado_start=false
        else
          str_tag3 << "<tr><td>" << ary.join("</td><td>") << "</td></tr>\n"
        end
        ary = [mado,bango,su,time,hun]
        str_csv  << ary.join(",") << "\n"
      end
    end
  end
  [str_tag1,str_tag2,str_tag3,str_csv]
end
def make_monitor_html(log)
  if Myfile.dir(:monitor)
      $monitor_data = make_monitor_data(log)
      f=File.read(Myfile.hinagata(:monitor))
      f.sub!(/<GENZAI>/)      {|str| genzai}
      f.sub!(/<UKETSUKECHU>/) {|str| $monitor_data[0]}
      f.sub!(/<MACHICHU>/)    {|str| $monitor_data[1]}
      f.sub!(/<SYURYO>/)      {|str| $monitor_data[2]}
      temp = Myfile.dir(:temp)+"/"+Myfile.file_name(:monitor)
      to   = Myfile.dir(:monitor)
      File.write(temp,f)
      if File.exist? to
        FileUtils.cp(temp,to)
      elsif test_mode?
        popup "�u#{$monitor_folder}�v�����݂��Ȃ����߁A�ۓ����j�^�p��HTML��ۑ����邱�Ƃ��ł��܂���B"
      end
  end
end


#*****�P���̊T���f�[�^��ۑ�����*****
def gaikyo_data_save(log)
  str=""
  $mado_array.each do |mado|
    maiji_sya_su  =log[mado].maiji_sya_su($ku).values.join(",")
    maiji_machi_su=log[mado].maiseiji_machi_su($ku).values.join(",")
    str << "#{Today},#{YobiNum.yobi},#{mado},#{log[mado].sya_su},,#{maiji_sya_su},,#{maiji_machi_su}\n"
  end
  file=Myfile.file(:gaikyo)
  unless File.exist? file
    head="�N����,�j��,����,�����Ґ�,���ԑѕʗ����Ґ�,�W����,�X����,10����,11����,12����,13����,14����,15����,16����,17����,�e���ݎ��̑҂��l��,�X��,10��,11��,12��,13��,14��,15��,16��,17��\n"
    File.write(file,head)
  end
  f=File.open(file,"a+")
  f.print str
  f.close
  #���O�̃o�b�N�A�b�v�t�H���_(���L�t�H���_)�ɃR�s�[����B
  if Myfile.dir(:log_backup)
    FileUtils.cp_r(file, Myfile.dir(:log_backup), {:preserve => true})
  end
end


#***** log�f�[�^�̕ۑ��Ə����� *****
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
    #�ߋ����O�����łɂ���Ƃ��͋�t�@�C���ŏ㏑�����Ă��܂��f�[�^�����ł���댯������B
    #�����Ŋ����̃f�[�^��new�f�[�^��ǉ����������ŏd�����폜����BH26.6.25
    if File.exist? log_file 
      file=File.read(log_file)
      file.each_line do |line|
        new << line.chomp if line
      end
      new.uniq!.sort! #�d���s���폜
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
  log_data_nendo_koshin
end


#***** ���O�t�@�C���p�� *****
#      �����p���ɏ����ĂQ�N�ȏ�o�߂������O�t�@�C�����폜���� 
def log_data_nendo_koshin
#  require "date"
  y=(Date.today << 3).year-2
  kijunbi_jan="#{y.to_s}�N4��1��"
  kijunbi_ymd=Date.new(y,4,1).strftime("%Y%m%d")
  dir=Dir.open(Myfile.dir(:kako_log))
    x=true
    while name=dir.read
      if name=~/(\d{8})\.log/
        if $1<kijunbi_ymd
          if x==true
            x=false
            ans=popup("#{kijunbi_jan}���Â��t�@�C�����폜���Ă������ł����H","���O�t�@�C���폜",3)
            break if ans!=6
          end
          File.delete Myfile.dir(:kako_log)+"/"+name
        end
      end
    end
  dir.close
end


#****�G�N�Z���̃t�@�C���̍쐬******
def make_xlsx(log)
  $monitor_data=make_monitor_data unless defined? $monitor_data
  str    = "#{Time.parse(Today).strftime('%Y�N%m��%d��')}�̑�����\n\n"
  $mado_array.each do |mado|
    str += "#{mado}�ԑ���: �����Ґ� #{log[mado].sya_su.to_s}�A ���ϑ҂����� #{log[mado].average_machi_hun.to_s} ��\n" 
  end
  str   += "\n"
  str   += "����,�ԍ�,�������҂��l��,�����������ďo����,�҂�����\n"
  str   += $monitor_data[3]
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
    book_name="#{MYDOC}/�����҂���(#{Time.parse(Today).strftime('%Y-%m-%d')}).xlsx"
    book.SaveAs("Filename"=>book_name,"FileFormat"=>51, "CreateBackup"=>"False")
    book.Close("False")
    xl.Application.DisplayAlerts = "True"
    xl.Quit
    if Myfile.dir(:excel)
      FileUtils.cp_r(book_name,Myfile.dir(:excel),{:preserve => true})
    end
  rescue
    #�����s���ł��邪�A���ɂ���Ă�OLE�I�[�g���[�V�����̃A�N�Z�X�����ۂ����ꍇ������B
    #���̏ꍇ�̑�֏����Ƃ��āA�������e��csv�t�@�C����ۑ�����B
    csv_name="#{Myfile.dir(:excel)}/�����҂���(#{Time.parse(Today).strftime('%Y-%m-%d')}).csv"
    if Myfile.dir(:excel)
      FileUtils.cp_r(temp,csv_name)
    end
  end
end
