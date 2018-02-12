# -*- coding: Shift_JIS -*-

#***********************
#      ���[�����M
#***********************
def send_mail(title,body,to)
  require 'nkf'
  require 'net/smtp'
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
    Net::SMTP.start( $smtp, 25 ) do |smtp|
      smtp.send_mail mail_str,$from,*to
    end
  rescue
    print "���̃��[���͑��M�ł��܂���ł����B\n" << title << "\n" << body
  end
  "send"
end

#**************************
#  �J�������ǂ����̔���
#**************************
class Date
   require "./holiday_japan"
   def kaichobi?
     day=self
     def week_num(day)
       (day.strftime("%d").to_i-1)/7+1
     end
     if day.wday == 0
       "���j��"
     elsif day.wday==6
       case week_num(day)
       when 1  ; "��1�y�j��"
       when 3  ; "��3�y�j��"
       when 5  ; "��5�y�j��"
       else    ; true
       end
     elsif not day.strftime("%m%d").between?("0104","1228")
       "�N���N�n"
     elsif day.national_holiday? == true
       HolidayJapan.name(day)
     else
       true
     end
   end
end

#****************************
#  �J�������ƕ������̎擾
#****************************
def kaicho_jikan
  if $today.wday.between?(1,5)
    day=:weekday
  else
    day=:weekend
  end
  t=$kaicho[day].split("�`")
  {:kaicho=>t[0],:heicho=>t[1]}
end

#*****************************
#  �J�����ԓ����ǂ����̔���
#*****************************
def is_kaicho_jikan?
  if $now.between?(kaicho_jikan[:kaicho],kaicho_jikan[:heicho])
    true
  else
    false
  end
end

#*****************************
#  ���j�^PC��IP�A�h���X�擾
#*****************************
#YCAN�ڑ��[���ɂ͌Œ�IP�A�h���X���^�����Ă��炸�s�ӂɕύX����Ă��܂�
#���Ƃ�����B����ADOS�����J���̂�������邽�߂�ping�ł͂Ȃ�WMI��PingStatus
#�𗘗p���邱�ƂƂ��邪WMI��PingStatus�̓R���s���[�^���̈����ł͓��삵�Ȃ��B
#�����ŁA���̓��̏���̎��s���ɃR���s���[�^������IP�A�h���X���擾����
#�t�@�C���ɕۑ����A2��ڈȍ~�͏���ɕۑ����ꂽ�A�h���X���g�p����d�g�݂Ƃ���B
def get_ip_address
  day=$today.strftime("%y%m%d")
  #�e���̏�����s���̏����iping�ɂ����ip�A�h���X���擾���t�@�C���ۑ�����ƂƂ��ɁA���A�h���X��Ԃ��B�j
  if File.exist?('./ip_addr.txt')!=true or
    day!=File.mtime("./ip_addr.txt").strftime("%y%m%d")
    if `ping #{$monitor_pc} -4`=~/\[(\d+\.\d+\.\d+\.\d+)\]/
      File.write('./ip_addr.txt',$1)
      return $1
    else
      warning(:server_down)
      return false
    end
  #�e����2��ڈȍ~�̎��s���͕ۑ����ꂽ�A�h���X��Ԃ�
  else
    return File.read('./ip_addr.txt')
  end
end

#*********************************************************
#  ���j�^�o�b�̉����m�F
#  WMI(Windows Management Instrumentation)�̃��\�b�h���g�p
#*********************************************************
def ping_respons(address)
  require "win32ole"
  wmi = WIN32OLE.connect('winmgmts://')
  respons_set = wmi.ExecQuery("select * from Win32_PingStatus where Address='"+address+"'")
  respons_set.each do |item|
    return item.StatusCode
  end
end

#**************
#  �x�����[��
#**************
def warning(syubetu)
  if syubetu==:server_down
    body="���j�^PC��YCAN�ɐڑ�����Ă��܂���BPC���N�����Ă��Ȃ����A���͉��炩�̒ʐM��Q�������Ă��܂��B\n�����ɃV�X�e���Ǘ��҂ɒm�点�Ă��������B"
    title="�y�G���[�z���j�^PC��������܂���I"
  elsif syubetu==:setting_error
    title="�y�G���[�z���j�^PC�����Ď�"
    body="�ݒ�t�@�C��(config.txt)�Ƀ��j�^PC�̃R���s���[�^����o�^���Ă��������B"
  elsif syubetu==:test1
    title="�y�Ă��Ɓz���j�^PC�����Ď�"
    body="�ݒ�t�@�C��(config.txt)�̃��j�^PC�R���s���[�^���̓o�^OK"
  elsif syubetu==:test2
    title="�y�Ă��Ɓz���j�^PC�����Ď�"
    body="���j�^PC�ւ�ping�͐������܂����B"
  end
  send_mail(title,body,$to)
end
