# -*- coding: Shift_JIS -*-
#--------------------------------------------------------------------------------#
#   �ۓy�P�J��ی��N���� �������G�󋵕\���V�X�e�� Ver.2.8 (2014.8.15)            #
#                                                                                #
#                        mado_FTP.rb �̌J��Ԃ����s��                            #
#                                                                                #
#         ���풓����mado_FTP.rb���J��Ԃ����s����B                              #
#         ���풓���ɏd�����ċN�����悤�Ƃ���Ƒ����I������B                     #
#                                                                                #
#                        �쐬    ����  �� ( ka00-inuzuka@city.yokohama.jp )      #
#                        ���쌠  ���l�s                                          #
#--------------------------------------------------------------------------------#

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

#*** mado_FTP.rb���J��Ԃ����s ****
require "./Objectinitialize.rb"
interval_second=60
loop do
  load "./mado_FTP.rb"
  sleep interval_second
end
