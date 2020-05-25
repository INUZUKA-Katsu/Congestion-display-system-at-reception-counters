# -*- coding: Windows-31J -*-
#---------------------------------------------------------------------------------#
#   �ۓy�P�J��ی��N���� �������G�󋵕\���V�X�e�� Ver.3.6 (2020.5.25)             #
#                                                                                 #
#                            �풓�v���O��������Ď���                             #
#                                                                                 #
#  ���umado_Loop.rb�v�����s�����m�F���A���s���łȂ���΋N������B                 #
#  ���umonitorsys_Loop.rb�v�����s�������ׁA���s���łȂ���΋N������B             #
#  �� �^�X�N�X�P�W���[���ɓo�^���Ĉ��Ԋu�Ŏ��s����B                            #
#                                                                                 #
#                        �쐬    ����  �� ( ka00-inuzuka@city.yokohama.jp )       #
#                        ���쌠  ���l�s                                           #
#---------------------------------------------------------------------------------#

Dir.chdir(__dir__)

require "./process_count"

#***** ruby�v���O�����񓯊����s�p���\�b�h *****

def ruby_path
  require 'rbconfig'
  ruby_path = RbConfig.ruby
  if File.exist? ruby_path
    ruby_path
  else
    ruby_path.sub("/bin","")
  end
end

def run(ruby_file)
  str="#{ruby_path} #{ruby_file}"
  wsh = WIN32OLE.new('WScript.Shell')
  wsh.Run(str,0,false)
end


#***** �풓�v���O�������N���i���s���łȂ��Ƃ��j *****
rb=Array.new
rb[0] = "monitorsys_Loop.rb"
rb[1] = "mado_Loop.rb"
rb.each do |rb_file|
  unless process_exist? rb_file
    run(rb_file)
    puts "#{rb_file} �����s���܂����B"
  else
    puts "#{rb_file} �͎��s���ł����B"
  end
end
