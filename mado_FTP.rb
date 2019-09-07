# -*- coding: Windows-31J -*-
#--------------------------------------------------------------------------------#
#   �ۓy�P�J��ی��N���� �������G�󋵕\���V�X�e�� Ver.356 (2018.12.15)           #
#                                                                                #
#          HTLM�����AFTP���M��                                                   #
#                                                                                #
#                        �쐬    ����  �� ( ka00-inuzuka@city.yokohama.jp )      #
#                        ���쌠  ���l�s                                          #
#--------------------------------------------------------------------------------#

Encoding.default_external="Windows-31J"

#****��ƃf�B���N�g���̐ݒ�****
Dir.chdir(__dir__)


#***** �ݒ�t�@�C���A���O�t�@�C��������e��I�u�W�F�N�g���쐬�i�������j����B *****
require "./ObjectInitialize.rb" unless String.const_defined? :Today


#***** �󋵔��� *****
def situation
  $syuryo_hun||=5
  # "upload_suii"�̃I�v�V�����t����"mado_FTP.rb"���N�������Ƃ��́A
  # ���ݎ����ɂ�炸���T/��T�̐��ڂ𐶐����A�A�b�v���[�h����.
  if ARGV[0]=="UploadSuii"
    return :upload_suii
  elsif TimeNow < $ku.kaicho
    return :before_open
  elsif TimeNow < $ku.heicho and ARGV[0]=="EndingProcess"
    return :opening_hours
  elsif $ku.heicho < TimeNow
    if File.exist?("#{MYDOC}/#{$logfolder}/#{Today}.log") and test_mode? == false
      return :ended
    elsif ARGV[0]=="EndingProcess"
      return :ending
    elsif ( $ku.heicho + $syuryo_hun.minute < TimeNow and
            RaichoList.machi_su==0 and
            RaichoList.last_update_time + 10.minute < TimeNow ) or
          ( $ku.heicho + 3.hour < TimeNow )
      return :ending
    end
  end
  :regular
end


#*****���݂̎��ԑсi�߂�l:"�J���O","�J������","����"�̂����ꂩ�j*****
def time_zone()
  if TimeNow < $ku.kaicho
      "�J���O"
  elsif TimeNow.between?($ku.kaicho,$ku.heicho)
      "�J������"
  else $ku.heicho < TimeNow
      "����"
  end
end


#***** HP�p�f�[�^0 ���ݓ����̕����� *****
def genzai
  "#{Today.day_to_jan} #{TimeNow.time_to_jan}����"
end


#***** HP�p�f�[�^1 �������̎�t�ԍ� *****
def hp_data_bango(mado)
  bango = $logs[mado].current(:yobidashi).bango
  if time_zone=="����" and $logs[mado].machi_su==0
    "�|"
  else
    bango
  end
end


#***** HP�p�f�[�^2 �҂��l�� *****
def hp_data_machi_ninzu(mado)
  machi_su = $logs[mado].machi_su
  machi_su_nin = machi_su.to_s + "�l"
  case time_zone
  when "�J���O"
    #�J�����ԑO�́A�҂��l�����[���̂Ƃ��̓o�[�i"�|"�j�\���Ƃ���B
    if machi_su == 0
      "�|"
    else
      machi_su_nin
    end
  when "�J������"
    machi_su_nin
  when "����"
    #�����Ԍ�A���ׂĂ̑����̑҂��l�����[���ɂȂ�����o�[�i"�["�j�\���ɐ؂�ւ���B
    if RaichoList.machi_su==0
      "�|"
    else
      machi_su_nin
    end
  end
end


#***** HP�p�f�[�^3 ���l�����b�Z�[�W *****
def hp_data_message(mado)
  message_kaicho_jikan      = "�{���̎�t��#{$ku.kaicho.time_to_jan.num_to_zenkaku}����ł��B"
  message_no_data           = "�܂��{���̏��͂���܂���B"
  message_heicho_machiari   = "�{���̎�t�͏I�����܂����B�i�ԍ��D�����҂��̕��͔ԍ������Ăт���܂ł��҂����������B�j"
  message_heicho_machinashi = "�{���̎�t�͏I�����܂����B"
  message_error_no_date     = "�܂��{���̏��͂���܂���B�V�X�e���ɉ��炩�̕s����������Ă���\��������܂��B"
  def message_error_no_update
    "#{RaichoList.last_update_time.time_to_jan}��̐V������񂪂���܂���B�V�X�e���ɉ��炩�̕s����������Ă���\��������܂��B"
  end
  def mail_error_no_date
    unless defined? $error_mail_sent
      title="�y�G���[�I�z���j�^�V�X�e�����m�F���Ă��������B"
      body ="�܂������̃{�C�X�R�[����񂪂���܂���B���j�^�V�X�e�������������삵�Ă��邩�m�F���Ă��������B"
      send_mail(title,body)
      $error_mail_sent=true
    end
  end
  def mail_error_no_update
    unless defined? $error_mail_sent
      title="�y�G���[�I�z���j�^�V�X�e�����m�F���Ă��������B"
      body ="���j�^�V�X�e���̏�񂪂P���Ԉȏ�X�V����Ă��܂���B���j�^�V�X�e�������������삵�Ă��邩�m�F���Ă��������B"
      send_mail(title,body)
      $error_mail_sent=true
    end
  end

  case time_zone
  when "�J���O"
        message_kaicho_jikan

  when "�J������"
    #�J�����Ԃ��߂��Ă���̂ɍ����̃f�[�^���F���̏ꍇ
    if RaichoList.sya_su==0
      #�x�����[��
      mail_error_no_date
      #�J��������30�������̂Ƃ�
      if TimeNow < $ku.kaicho + 30.minute
        message_no_data
      #�J��������30���ȏ�o�߂��Ă���Ƃ��i�V�X�e���G���[�̉\���j
      else
        message_error_no_date
      end
    #�P���Ԉȏ�f�[�^���X�V����Ă��Ȃ��Ƃ��i�V�X�e���G���[�̉\���j
    elsif RaichoList.last_update_time + 60.minute < TimeNow
      mail_error_no_update
      message_error_no_update
    #����ɓ��삵�Ă���Ƃ��i�҂����Ԃ̖ڈ���\���j
    else
        machi_su=$logs[mado].machi_su
        $message.meyasu_jikan(mado,machi_su) if defined? $message
    end

  when "����"
    if $logs[mado].machi_su > 0
        message_heicho_machiari
    else
        message_heicho_machinashi
    end
  end
end


#***** HP�p�f�[�^4 �������̑҂��l�� *****
def hp_data_graph(mado)
  #WEB�A�N�Z�V�r���e�B(�_�O���t���摜�f�[�^�ɕύX)
  def bar_chart(nin)
    use_image=true #�摜�C���[�W����:true�A �]������:false
    if use_image
      return bar_chart_imgtag(:today,nin)
    else
      #�]������
      return nin>0 ? "<span>#{"|" * nin}</span>" : "&nbsp;"
    end
  end
  hash=$logs[mado].maiseiji_machi_su($ku)
  return {:title => "",:data => ""} if hash.size==0
  str=""
  hash.each do |ji,nin|
      str << "<dt>#{ji.hour}�� #{nin.to_s}�l</dt>"
      str << "<dd>#{bar_chart(nin)}</dd>\n"
  end
  {:title => "(�Q�l)�����̑҂��l���̐���",:data => str}
end


#***** HP�p�f�[�^5 �g�s�b�N *****
#      config.txt��$topic�Ŏw�肵���t�@�C����
#      �s����#�̂Ȃ��s�̕������擾����B
def topic
  if Myfile.file(:topic) and File.exist? Myfile.file(:topic)
    f=File.read(Myfile.file(:topic))
    f.gsub(/#.*\n/,"").gsub(/^\n/,"")
  end
end


#*****���M�f�[�^(HTML�t�@�C��)�̍쐬�E�ۑ�*****
#PC�p�ƌg�сE�X�}�z�p�̏����𕪂���K�v�͂Ȃ�����
#�̂œ������Đ��������B(2014.3.31)
def make_html()
  temp_dir=Myfile.dir(:temp)
  files=Array.new
  [:pc,:keitai,:sumaho].each do |h|
    f=File.read_to_sjis(Myfile.hinagata(h))
    f.sub!(/<!--madoguchiTopics-->/)      {|str| topic} if topic
    f.sub!(/<!--TIME-->/)                 {|str| genzai}
    $mado_array.each do |mado|
      unless Today.closed_mado.include? mado
        f.sub!(/<!--#{mado}-BANGO-->/)      {|str| hp_data_bango(mado)}
        f.sub!(/<!--#{mado}-NINZU-->/)      {|str| hp_data_machi_ninzu(mado)}
        f.sub!(/<!--#{mado}-MESSAGE-->/)    {|str| hp_data_message(mado)}
        f.sub!(/<!--#{mado}-SANKO-Title-->/){|str| hp_data_graph(mado)[:title]}
        f.sub!(/<!--#{mado}-SANKO-->/)      {|str| hp_data_graph(mado)[:data]}
      else
        f.sub!(/<!--#{mado}-BANGO-->/)      {|str| "�|"}
        f.sub!(/<!--#{mado}-NINZU-->/)      {|str| "�|"}
        f.sub!(/<!--#{mado}-MESSAGE-->/)    {|str| $close_message[:pc]}
        f.sub!(/<!--#{mado}-SANKO-Title-->/){|str| ""}
        f.sub!(/<!--#{mado}-SANKO-->/)      {|str| ""}
      end
    end
    File.write_acording_to_htmlmeta(Myfile.dir(:temp)+"/"+Myfile.file_name(h),f)
    files << Myfile.dir(:temp)+"/"+Myfile.file_name(h)
  end
  files
end


#***** �ʏ폈�� *****
def �ʏ폈��
  files=make_html()                     #***** HTML�쐬 *****
  ftp_soshin(files,Myfile.dir(:ftp))    #***** FTP���M *****
  make_monitor_html($logs)              #***** �ۓ����j�^�[�pHTML�t�@�C���̍쐬�E�ۑ� *****
  teitai_keikoku_mail($logs)            #***** ��������؂��Ȃ����Ď���,��莞�Ԓ�؂��Ă���Ƃ��x������ *****
  puts "�ʏ폈���I���I"
end


#***** �J���O���� *****
def �J���O����
  if defined? $suii_open and $suii_open==:yes
    require './suii'
    files=modify_html_of_week()                   #***** ���M�t�H���_���̊���HTML���C�� *****
    ftp_soshin(files,Myfile.dir(:ftp)) if files   #***** FTP���M *****
  end
puts "�J���O�����I���I"
  �ʏ폈��
end


#***** �I������ *****
def �Ɩ��I������
  #�҂��l��������ɂ��ւ�炸�����@�����Ƃ��ꂽ�ꍇ�̌㏈��
  #���������̃f�[�^���폜���҂��l�����[���ɂ���B
  $mado_array.each do |mado|
    $logs[mado]=$logs[mado].reject{|sya| sya.time_h>$ku.heicho and sya.time_y==nil and sya.time_c==nil}
  end
  #�z�[���y�[�W�A�ۓ����j�^���X�V����
  �ʏ폈��

  #log�f�[�^���ߋ����O�t�H���_�Ɉڂ��B
  LogBack.log_data_backup if $test_mode!=7
p :log_backuped
  #log�f�[�^�̏C��.�O�������̓��̃f�[�^�����݂���Ƃ����ꂼ��̓��t�t�@�C���ɐU�蕪����B
  #�i�O�̂��ߍ��������łȂ�7���O����̃��O��_������.�j
  repaired_days=LogBack.repair(Today-7..Today)
p :logfile_repaired
  #***** ���ڂ�html *****
  require './suii'

  #�������j�^�p�y�[�W(�������j�^�p�ˌ��J�p�̏���������Ȃ�����)
  make_suii_for_monitor if Myfile.dir(:suii)
p :renew_monitor_display
  #���J�p�y�[�W
  if defined? $suii_open and $suii_open==:yes
    files=make_html_of_week(Today)
    ftp_soshin(files,Myfile.dir(:ftp))
  end
p :renew_suii_page
  #�T���f�[�^�ۑ�
  gaikyo_data_save($logs)
p :gaikyo_file_saved
  #�G�N�Z���ō����̑҂����Ԉꗗ�\���쐬
  xl=MakeExcel.start_excel()
  res=MakeExcel.make_xlsx(xl,$logs) #Document�t�H���_��Myfile.dir(:excel)�̐ݒ肪����Ƃ���Myfile.dir(:excel)�ɕۑ�����.
  MakeExcel.stop_excel(xl)
  popup(res,48,"Excel�t�@�C���ۑ����s",10) if res[0]==:err
  #���O���C�������Ƃ����������G�N�Z���t�@�C����₤�B
  if Myfile.dir(:excel) and repaired_days.size>0
    xl=MakeExcel.start_excel()
    repaired_days.each do |day|
      file= Myfile.dir(:excel)+"/�����҂���(#{Time.parse(day).strftime('%Y-%m-%d')})"
      if not File.exist?(file+".xlsx") and not File.exist?(file+".csv")
        logs=RaichoList.setup(day.log_file,$mado_array,day)
        MakeExcel.make_xlsx(xl,logs,day)
      end
    end
    MakeExcel.stop_excel(xl)
  end
p :excel_file_saved
  puts "�Ɩ��I�����������I"

  #�V�X�e���V���b�g�_�E��
  if ARGV[0]=="EndingProcess"
    mess="�Ɩ��I���������������܂����B�V���b�g�_�E�����܂��B"
    VcallMonitor.new.shutdown_pc(mess,3) if $test_mode!=7
  else
    mess="�Ɩ��I���������������܂����B�T����ɃV���b�g�_�E�����܂��B"
    VcallMonitor.new.shutdown_pc(mess,5.minute) if $test_mode!=7
  end
  exit
end

#***** ���T/��T�̐��ڃy�[�W�X�V���� *****
def ���ڍX�V����
  require './suii_test'
  def log_exist?(days)
    days.each do |day|
      return true if day.log_file
    end
    nil
  end
  #Prolog.csv�ɍ���܂ł̃f�[�^���c���Ă���\��������̂ł܂��ߋ����O�𐶐�����B
  LogBack.log_data_backup(:not_erase)
  repaired_days=LogBack.repair(Today-14..Today)
  #�����ԑO�ł���ꍇ�́A�����̉ߋ����O�͗]���Ȃ̂ō폜����B
  log=Today.log_file
  if log and TimeNow < $ku.heicho
    FileUtils.rm(log)
  end
  #���T�̉ߋ����O�t�@�C�������݂��Ȃ��Ƃ��́AToday���T�ɕύX����B
  #�ߋ����O�̂���T�ɓ��B����܂ők��B
  tday=Today
  until log_exist?(tday.days_of_week) do
    tday=tday-7
  end
  #�������j�^�p�y�[�W�𐶐��A�ۑ�����B
  make_suii_for_monitor(tday) if Myfile.dir(:suii)
  #���J�p�C���[�W�𐶐��AFTP���M����B
  if defined? $suii_open and $suii_open==:yes
    files=make_html_of_week(tday)
    ftp_soshin(files,Myfile.dir(:ftp))
  end
end

#***** �蓮�I�������̒��~���� *****
def �Ɩ��I���������~
  popup("�J�Ǝ��Ԓ��͋Ɩ��I�������͎��s�ł��܂���B",48,"�Ɩ��I���������~",3)
  �ʏ폈��
  ARGV[0]=nil
end

#**********************************************#
#         �������炪���ۂ̏�������             #
#**********************************************#

#***** ���ݎ����̐ݒ� *****
TimeNow =Time.now.strftime("%H:%M") if String.const_defined?(:TimeNow)==false or Object.class_eval{remove_const :TimeNow}

#***** ���O�f�[�^�����Ƃɗ����҃��X�g(RaichoList)�N���X�̃I�u�W�F�N�g���쐬 *****
$logs=RaichoList.setup(Myfile.file[:log],$mado_array)

#***** �󋵂ɑΉ����鏈�������s���� *****
p Time.now
p "�󋵔���: situation=#{situation}"
case situation
  when :regular               ; �ʏ폈��
  when :before_open           ; �J���O����
  when :ending                ; �Ɩ��I������
  when :upload_suii           ; ���ڍX�V����
  when :opening_hours         ; �Ɩ��I���������~
  when :ended            
    puts "�Ɩ��I�������ς݁I"
    #*** �Ɩ��I�������ς݂ł��łɃ��O�t�@�C������ł���̂Ƀ}�j���A������ŋƖ��I���������w�����ꂽ�Ƃ���
    #*** ����̈Ӑ}��D�悵�A���O�t�@�C���������߂��Ă�����x�Ɩ��I���������s��.
    if ARGV[0]=="EndingProcess"
      kako_log=Today.log_file
      if File.exist? kako_log
        FileUtils.cp(kako_log, Myfile.file(:log), {:preserve => true})
        �Ɩ��I������
      end
    end
end



