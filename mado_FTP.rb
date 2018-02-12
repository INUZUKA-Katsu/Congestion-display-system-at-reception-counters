# -*- coding: Shift_JIS -*-
#--------------------------------------------------------------------------------#
#   �ۓy�P�J��ی��N���� �������G�󋵕\���V�X�e�� Ver.3.0 (2014.9.24)            #
#                                                                                #
#                           HTLM�����AFTP���M��                                  #
#                                                                                #
#                        �쐬    ����  �� ( ka00-inuzuka@city.yokohama.jp )      #
#                        ���쌠  ���l�s                                          #
#--------------------------------------------------------------------------------#

Encoding.default_external="Shift_JIS"

#****��ƃf�B���N�g���̐ݒ�****
Dir.chdir(__dir__)


#***** �ݒ�t�@�C���A���O�t�@�C��������e��I�u�W�F�N�g���쐬�i�������j����B *****
require "./ObjectInitialize.rb" unless String.const_defined? :Today


#***** �󋵔��� *****
def situation
  $syuryo_hun||=5
  vc=VcallMonitor.new
  if $ku.heicho < TimeNow
    if File.exist?("#{MYDOC}/#{$logfolder}/#{Today}.log") and test_mode? == false
      return :ended
    elsif ( $ku.heicho + $syuryo_hun.minute < TimeNow and RaichoList.machi_su==0  ) or
          ( vc.data_communication_with_hakkenki != "�ʐM��" ) or
          ( $ku.heicho + 2.hour < TimeNow )
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
  bango = $log[mado].current(:yobidashi).bango
  if time_zone=="����" and $log[mado].machi_su==0
    "�|"
  else
    bango
  end
end


#***** HP�p�f�[�^2 �҂��l�� *****
def hp_data_machi_ninzu(mado)
  machi_su = $log[mado].machi_su
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
        machi_su=$log[mado].machi_su
        $message.meyasu_jikan(mado,machi_su)
    end
  
  when "����"
    if $log[mado].machi_su > 0
        message_heicho_machiari
    else
        message_heicho_machinashi
    end
  end
end


#***** HP�p�f�[�^4 �������̑҂��l�� *****
def hp_data_graph(mado)
  h=$log[mado].maiseiji_machi_su($ku)
  return {:title => "",:data => ""} if h.size==0
  str=""
  h.each do |ji,su|
    if su>0
      str   << "<dt>#{ji.hour}�� #{su.to_s}�l</dt><dd><span>#{"|" * su}</span></dd>"
    else
      str   << "<dt>#{ji.hour}�� #{su.to_s}�l</dt><dd>&nbsp;</dd>"
    end
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
    f=File.read(Myfile.hinagata(h))
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
    File.write(Myfile.dir(:temp)+"/"+Myfile.file_name(h),f)
    files << Myfile.dir(:temp)+"/"+Myfile.file_name(h)
  end
  files
end


#***** ������،x�����[�� *****
def teitai_keikoku_mail
  $mado_array.each do |mado|
    if defined? $teitai_kyoyou_jikan[mado]
      kyoyou_jikan             = $teitai_kyoyou_jikan[mado]
      current_hakken_person    = $log[mado].current(:hakken)
      current_yobidashi_person = $log[mado].current(:yobidashi)
      next_yobidashi_person    = $log[mado].next_call
      keika_jikan              = TimeNow - current_yobidashi_person.time(:yobidashi)
      next_person_machi_jikan  = TimeNow - next_yobidashi_person.time(:hakken)
      if next_person_machi_jikan > kyoyou_jikan and keika_jikan > kyoyou_jikan
        title  = "�y#{mado}�ԑ������Ӂz��t����؂��Ă��܂��B"
        body   = "#{mado}�ԑ����̎�t��#{current_yobidashi_person.bango}�ԂŎ~�܂��Ă��܂��B"
        body   << "\n���݂̔ԍ��̌p�����ԁi��؎��ԁj�F#{keika_jikan}��"
        body   << "\n���̔ԍ��̂��q�l�̑҂����ԁ@�@�@�F#{next_person_machi_jikan}��"
        send_mail(title,body)
      end
    end
  end
end


#***** �ʏ폈�� *****
def �ʏ폈��
  files=make_html()                     #***** HTML�쐬 *****
  ftp_soshin(files,Myfile.dir(:ftp))    #***** FTP���M *****
  make_monitor_html($log)               #***** �ۓ����j�^�[�pHTML�t�@�C���̍쐬�E�ۑ� *****
  if defined? $teitai_kyoyou_jikan
    teitai_keikoku_mail                 #***** ��������؂��Ȃ����Ď���,��莞�Ԓ�؂��Ă���Ƃ��x������ *****
  end
  puts "�ʏ폈���I���I"
end


#***** �I������ *****
def �Ɩ��I������
  #�҂��l��������ɂ��ւ�炸�����@�����Ƃ��ꂽ�ꍇ�̌㏈��
  #���������̃f�[�^���폜���҂��l�����[���ɂ���B
  $mado_array.each do |mado|
    list   = $log[mado].raicholist
    delete = list.select{|sya| sya.time_h>$ku.heicho and sya.time_y==nil and sya.time_c==nil}
    $log[mado].raicholist = list - delete
  end
  #�z�[���y�[�W�A�ۓ����j�^���X�V����
  �ʏ폈��

  #log�f�[�^�ۑ��E������
  log_data_backup

  #***** ���ڂ�html *****
  require './suii'
  #�ߋ����O�t�@�C���Ɍ���������Ƃ��C������B
  days_of_this_week=Today.days_of_week
  Kakolog.repair(days_of_this_week) if Kakolog.lack_of_kako_log(days_of_this_week)
  #���J�p�y�[�W
  if defined? $suii_open and $suii_open==:yes
    files=make_html_of_week(Today)
    ftp_soshin(files,Myfile.dir(:ftp))
  end
  #�������j�^�p�y�[�W
  make_suii_for_monitor if Myfile.dir(:suii)

  #�T���f�[�^�ۑ�
  gaikyo_data_save($log)

  #�G�N�Z���ō����̑҂����Ԉꗗ�\���쐬
  make_xlsx($log) if Myfile.dir(:excel)

  #�ی��N���ۂ̍X�V�����ύX�����邩���ׁA�ύX����Ƃ����ʃf�U�C������荞��
  #load  './mado_design_renew.rb'

  puts "�Ɩ��I�����������I"

  #�V�X�e���V���b�g�_�E��
  mess="�Ɩ��I���������������܂����B�T����ɃV���b�g�_�E�����܂��B"
  VcallMonitor.new.shutdown_pc(mess,5.minute)
  exit
end

#**********************************************#
#         �������炪���ۂ̏�������             #
#**********************************************#

#***** ���ݎ����̐ݒ� *****
TimeNow =Time.now.strftime("%H:%M") if String.const_defined?(:TimeNow)==false or Object.class_eval{remove_const :TimeNow}

#***** ���O�f�[�^�����Ƃɗ����҃��X�g(RaichoList)�N���X�̃I�u�W�F�N�g���쐬 *****
$log=RaichoList.setup(Myfile.file[:log],$mado_array)

#***** �󋵂ɑΉ����鏈�������s���� *****
p Time.now
p "�󋵔���: situation=#{situation}"
case situation
  when :regular               ; �ʏ폈��
  when :ending                ; �Ɩ��I������
  when :ended                 ; puts "�Ɩ��I�������ς݁I"
end
