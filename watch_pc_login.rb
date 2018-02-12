# -*- coding: Windows-31J -*-
#--------------------------------------------------------------------------------#
#   �ۓy�P�J��ی��N���� �������G�󋵕\���V�X�e�� Ver.2.8 (2014.8.15)            #
#                                                                                #
#              ���j�^�[�p�o�b���O�C���Ď���                                      #
#                64bit��Windows��32bit��ruby�̑g�����ł�                         #
#                ���O�C���̔��肪�ł��Ȃ����Ƃ��������Ă��܂��B                  #
#                                                                                #
#                        �쐬    ����  �� ( ka00-inuzuka@city.yokohama.jp )      #
#                        ���쌠  ���l�s                                          #
#--------------------------------------------------------------------------------#


Encoding.default_external="Windows-31J"

#****��ƃf�B���N�g���̐ݒ�****
Dir.chdir(__dir__)

#****�ݒ�t�@�C���̓Ǎ���****
load './config.txt'
load './config_for_development.txt' if [2,3,4,5].include?($test_mode) and $development_mode==true

#****���C�u�����̓Ǎ���****
require "./Raicholist.rb"

#****�J�����Ԃ̃Z�b�g�A�b�v****
Today   =Time.now.strftime("%Y%m%d")
YobiNum =Time.now.wday
$ku=KaichoJikan.setup(Today)

#****VcallMonitor�I�u�W�F�N�g�Z�b�g�A�b�v****
$vcall=VcallMonitor.new

#***** ���O�C�������W���[�� *****
module WatchLogin
  def self.send_mail_by_situation(result)
    case result
    when :switch_on
      title="���j�^�o�b�N��(�����O�C��)"
      body    = "���j�^�o�b�N�����܂���(�܂����O�C���͂��Ă��܂���)�B"
    when :login
      title="���j�^�o�b���O�C��"
      body ="���O�C�������F#{$vcall.login_time}"
    when :login_error
      title="�y�x���z���j�^�o�b�Ƀ��O�C�����Ă��܂���B"
      body ="�����Ƀ��j�^PC�Ƀ��O�C�����A���j�^�V�X�e���𗧂��グ�Ă��������B"
    end
    send_mail(title,body)
  end
  def self.write_log(result)
    case result
    when :switch_on
      syubetu = :success
      body    = "���j�^�o�b�N�����܂���(�܂����O�C�����Ă܂���)�B"
    when :login
      syubetu = :success
      body    = "���j�^�o�b�Ƀ��O�C�����܂����B(#{Time.now.to_hhmm})"
    when :login_error
      syubetu = :error
      body    = "���j�^�o�b�Ƀ��O�C�����Ă��܂���B(#{Time.now.to_hhmm})"
    end
    VcallMonitor.write_event_log(event: syubetu, text: body)
  end
end

#********************  ���O�C���Ď�  ***********************
unless $vcall.login?
  WatchLogin.send_mail_by_situation(:switch_on)
  WatchLogin.write_log(:switch_on)
  until $vcall.login?
    #�J��������10���O�ɂȂ��Ă����O�C�����Ă��Ȃ��Ƃ��A
    #�T�b���ƂɍĊm�F���A1�����ƂɌx�����[���𔭐M����B
    now=Time.now
    p now
    if now.to_hhmm >= $ku.kaicho - 10.minute and now.sec < 5
      WatchLogin.send_mail_by_situation(:login_error)
      WatchLogin.write_log(:login_error)
      
    end
    sleep 5
  end
end
WatchLogin.send_mail_by_situation(:login)
WatchLogin.write_log(:login)

