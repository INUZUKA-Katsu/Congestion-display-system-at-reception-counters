# -*- coding: Shift_JIS -*-
#--------------------------------------------------------------------------------#
#   �ۓy�P�J��ی��N���� �������G�󋵕\���V�X�e�� Ver.2.8 (2014.8.15)            #
#                                                                                #
#                             ��d�N���h�~���\�b�h��                             #
#                                                                                #
#                        �쐬    ����  �� ( ka00-inuzuka@city.yokohama.jp )      #
#                        ���쌠  ���l�s                                          #
#--------------------------------------------------------------------------------#

#***** ��d�N���h�~���̂��߂̃��\�b�h *****
require "win32ole"
def process_count(exe_file)
  pids=Array.new
  wmi = WIN32OLE.connect('winmgmts://')
  process_set = wmi.ExecQuery("select * from Win32_Process where CommandLine like '%#{exe_file}%'")
  process_set.each do |item|
    pids << item.ProcessID
  end
  pids.size 
end
def process_exist?(exe_file)
  c=process_count(exe_file)
  if c==0
    false
  else
    true
  end
end
