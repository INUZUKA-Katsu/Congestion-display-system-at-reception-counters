# -*- coding: Shift_JIS -*-
#--------------------------------------------------------------------------------#
#   �ۓy�P�J��ی��N���� �������G�󋵕\���V�X�e�� Ver.3.2 (2015.2.20)            #
#                                                                                #
#              ���j�^�[�V�X�e���ڑ��Ď��������Đڑ���                            #
#                                                                                #
#                        �쐬    ����  �� ( ka00-inuzuka@city.yokohama.jp )      #
#                        ���쌠  ���l�s                                          #
#--------------------------------------------------------------------------------#

Encoding.default_external="Shift_JIS"

#****��ƃf�B���N�g���̐ݒ�****
Dir.chdir(__dir__)

#***** ��d�N���h�~ *****
require "./process_count"
rb_file = File.basename(__FILE__)
if process_count(rb_file) > 1
  p "This program process exist."
  puts "�I��"
  exit
else
  p "Start resident"
end

#****�ݒ�t�@�C���̓Ǎ���****
load './config.txt'
load './config_for_development.txt' if [2,3,4,5].include?($test_mode) and $development_mode==true

#****�e�X�g���[�h�S�̂Ƃ��͂����ŏI��****
if $test_mode==4
  fname=File.basename(__FILE__).force_encoding("Shift_JIS")
  puts "�e�X�g���[�h�S�Ȃ̂Łu#{fname}�v�͎��s���܂���B"
  exit
end

#****���C�u�����̓Ǎ���****
require "./Raicholist.rb"

#****�J�����Ԃ̃Z�b�g�A�b�v****
Today   =Time.now.strftime("%Y%m%d")
YobiNum =Time.now.wday
$ku=KaichoJikan.setup(Today)

#****�����Ԍ�ł���Ƃ��͂����ŏI��****
if $ku.heicho < Time.now.to_hhmm
  puts "#{Time.now.to_hhmm} ���������߂��Ă��邽�ߏI�����܂��B"
  exit
end

#****VcallMonitor�I�u�W�F�N�g�Z�b�g�A�b�v****
$vcall=VcallMonitor.new

#���j�^�V�X�e���N���p���W���[��
module StartMonitor
  def self.send_mail_by_situation(result)
  #���[�����b�Z�[�W
    case result
    when :start
      title = "���j�^�V�X�e���N���i���������j"
      body  = "���j�^�V�X�e���̉^�p���j�^��ʂ��J���܂����B���������ł��B"
    when :start_error
      title = "�y�x���z���j�^�V�X�e���N�����s"
      body  = "���j�^�V�X�e���̉^�p���j�^��ʂ�\�����邱�Ƃ��ł��܂���ł����B"
      body << "�蓮����ɂ���ĉ^�p���j�^��ʂ�\�������Ă��������B"
    end
    send_mail(title,body)
  end
  def self.write_log(result)
  #�C�x���g���O�ɋL�^
    case result
    when :start
      syubetu = :success
      body    = "�y���j�^�V�X�e���z���j�^�V�X�e���̉^�p���j�^��ʂ��J���܂����B���������ł��B"
    when :start_error
      syubetu = :error
      body    = "�y���j�^�V�X�e���z���j�^�V�X�e���̉^�p���j�^��ʂ��J�����Ƃ��ł��܂���ł����B���̂܂܂ł̓z�[���y�[�W�ɍ����̍��G�󋵂��f�ڂ��邱�Ƃ��ł��܂���B"
    end
    VcallMonitor.write_event_log(event: syubetu, text: body)
  end
end

#�ڑ��Ď�&�����Đڑ��p���W���[��
module AutCon
  def self.send_mail_by_situation(result)
  #���[�����b�Z�[�W
    case result
    when :first_info
      title = "�y�x���I�z���j�^�V�X�e���������@����ؒf����܂����I"
      body  = "�����@�̓d���������Ă��邱�Ƃ��m�F���Ă��烂�j�^�V�X�e�����ċN������K�v������܂��B"
      body << "�������G�󋵕\���V�X�e���́A�����@�̉������m�F�ł��������A���j�^�V�X�e�����ċN������"
      body << "�����@�Ƃ̍Đڑ������݂܂��B"
    when :reconnect_error
      title = "�y�x���I�z���j�^�V�X�e���Ɣ����@���Đڑ����邱�Ƃ��ł��܂���B"
      body = "���j�^�V�X�e���������@����ؒf���ꂽ���ߎ����Đڑ������݂܂������ڑ��ł��܂���ł����B"
      body += "���̂܂܂ł̓z�[���y�[�W�̍X�V���ł��Ȃ��̂ŁA�����ɏ󋵂��m�F���đΏ����Ă��������B"
    when :connect
      title = "�y�񍐁z���j�^�V�X�e���Ɣ����@�̍Đڑ�����"
      body = "���j�^�V�X�e�����ċN�����A�����@�ƍĐڑ����܂����B"
    when :start_error # 2015.2.20 1st stage �ŋN���ł��Ȃ��܂� 2nd stage �ɐi�񂾏ꍇ
      title = "�y�x���z���j�^�V�X�e���N�����s"
      body  = "���j�^�V�X�e���̉^�p���j�^��ʂ�\�����邱�Ƃ��ł��܂���ł����B"
      body << "�蓮����ɂ���ĉ^�p���j�^��ʂ�\�������Ă��������B"
    end
    send_mail(title,body)
  end
  def self.write_log(result)
  #�C�x���g���O�ɋL�^
    case result
    when :first_info
      syubetu = :error
      body    = "�y���j�^�V�X�e���z�@�����@����ؒf����܂����B"
    when :reconnect_error
      syubetu = :error
      body    = "�y���j�^�V�X�e���z�@�����@�ɐڑ��ł��܂���ł����B"
    when :ping_error
      syubetu = :error
      body    = "�y���j�^�V�X�e���z�@�����@����ping�̉���������܂���B"
    when :connect
      syubetu = :success
      body    = "�y���j�^�V�X�e���z�@�{�C�X�R�[�����j�^�V�X�e�����N����,�����@�ƍĐڑ����܂����B"
    end    
    VcallMonitor.write_event_log(event: syubetu, text: body)
  end
end

#��O�������̏I���������W���[��
module AtRaise
  def self.send_mail_by_situation
  #���[�����b�Z�[�W
    title = "�y���j�^�V�X�e���z�펞�Ď��v���O�����I��"
    body  = "���j�^�V�X�e���펞�Ď��v���O�������I�����܂����B"
    send_mail(title,body)
  end
  def self.write_log
  #�C�x���g���O�ɋL�^
    syubetu = :error
    body    = "�y���j�^�V�X�e���z�펞�Ď��v���O�������I�����܂����B"
    VcallMonitor.write_event_log(event: syubetu, text: body)
  end
end
#��O�ɂ��I�����̏���
END{
  unless $ku.heicho < Time.now.to_hhmm
    AtRaise.send_mail_by_situation
    AtRaise.write_log
  end
}

#********************  ���j�^�V�X�e���N��  ***********************
p "1st stage"
5.times do |i|
  break if $vcall.data_communication_with_hakkenki == "�ʐM��"
  $vcall.stop if $vcall.process_id  #2�d�N���������
  case $vcall.start
  when :success
    sleep 2
    $vcall.app_activate
    if $vcall.data_communication_with_hakkenki == "�ʐM��"
      StartMonitor.send_mail_by_situation(:start)
      StartMonitor.write_log(:start)
      break
    else
      sleep 5
      next if i<4
      StartMonitor.send_mail_by_situation(:start_error)
      StartMonitor.write_log(:start_error)
      #���j�^�V�X�e���s�N���̂܂� 2nd stage �ɐi�ށB
    end
    sleep 1
  when :vcall_path_not_exist
  #�ݒ肪�Ԉ���Ă����Ƃ�
    popup "���j�^�V�X�e���N���E�펞�Ď��v���O�������I�����܂��B"
    exit
  end
end


#********************  �����@�Ƃ̏펞�ڑ��Ď��E�����Đڑ�  ***********************
p "2nd stage"
loop do
  sleep 30
  p Time.now
  next  if $ku.kaicho > Time.now.to_hhmm                           # �J�����ԑO�͉��������ҋ@
  break if $ku.heicho < Time.now.to_hhmm                           # �����Ԍ�͏I��
  case $vcall.data_communication_with_hakkenki                     # �����@�Ƃ̒ʐM�󋵂��m�F����B
  when "�ʐM��"
    p "�ʐM��"
    next
  when "�ʐM�ؒf"
    sleep 3
    next unless $vcall.data_communication_with_hakkenki=="�ʐM�ؒf" # �O�̂���3�b�҂��čĊm�F�B
    if $vcall.monitor_started
      mes = :first_info
    else
      mes = :start_error
    end
    AutCon.send_mail_by_situation(mes)                              # ��͂�_���Ȃ�ŏ��̕񍐃��[���𑗐M�B
    AutCon.write_log(mes)
    $vcall.restart_vcall_monitor                                    # ���j�^�V�X�e�����ċN��
    if $vcall.data_communication_with_hakkenki=="�ʐM��"            # �����������m�F
      AutCon.send_mail_by_situation(:connect)
      AutCon.write_log(:connect)
    else
      AutCon.send_mail_by_situation(:reconnect_error)
      AutCon.write_log(:reconnect_error)
    end
  when "����r��"                                                  # ping�������Ȃ��Ƃ�
    sleep 3
    next unless $vcall.data_communication_with_hakkenki=="����r��" # �O�̂���3�b�҂��čĊm�F�B
    AutCon.send_mail_by_situation(:ping_error)
    AutCon.write_log(:ping_error)
  end
end
