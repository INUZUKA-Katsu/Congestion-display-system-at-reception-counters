# -*- coding: Shift_JIS -*-

#*********************************************************************
#*************              ******************************************
#*************   �����ݒ�   ******************************************
#*************              ******************************************
#*********************************************************************

#���j�^PC�̃R���s���[�^��
$monitor_pc="YH-99-99999999"

#�x�����[���̑��M���E���M��A���[���T�[�o�̎w��
$from = "xx-hokennenkin@city.yokohama.jp"
$to   = ["xx-hokennenkin@city.yokohama.jp","xxxxxxxx@docomo.ne.jp"]
$smtp = "smtp.office.ycan"

#�J������
$kaicho=Hash.new
$kaicho[:weekday] = "08:45�`17:00"   #�����̊J������
$kaicho[:weekend] = "09:00�`12:00"   #�y���̊J������

#************* �������ݒ肱���܂� ***********************************

Dir.chdir(__dir__)
require "./tools"
require "date"

$today = Date.today
$now   = Time.now.strftime("%H:%M")
#test_mode=true #�e�X�g�̂Ƃ��͍s����#���폜����B

#***** �e�X�g(�J�����E���Ԕ���) *********************
if defined?(test_mode) and test_mode==true
  $today = Date.parse("2014/6/13")
  $now   = "08:46"
  def ping_respons(address)
    1
  end
end
#****************************************************

unless defined? $monitor_pc
  warning(:setting_error)
  exit
end

if $today.kaichobi? != true
  puts $today.kaichobi?
  exit
end

if is_kaicho_jikan? == false
  puts "�J�����Ԃł͂���܂���"
  exit
end

address=get_ip_address
if ping_respons(address)==0
  puts "����ł�"
else
  puts "���j�^�o�b���烌�X�|���X������܂���!"
  warning(:server_down)
end
