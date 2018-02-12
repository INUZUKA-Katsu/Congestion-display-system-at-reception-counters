# -*- coding: Windows-31J -*-
#--------------------------------------------------------------------------------#
#   �ۓy�P�J��ی��N���� �������G�󋵕\���V�X�e�� Ver.352 (2017.9.8)             #
#                                                                                #
#          �G�N�Z���t�@�C���}�j���A���쐬��                                      #
#                                                                                #
#                        �쐬    ����  �� ( ka00-inuzuka@city.yokohama.jp )      #
#                        ���쌠  ���l�s                                          #
#--------------------------------------------------------------------------------#

Encoding.default_external="Windows-31J"

#***** �ݒ�t�@�C���A���O�t�@�C��������e��I�u�W�F�N�g���쐬�i�������j����B *****
require "./ObjectInitialize.rb"

#****��ƃf�B���N�g���̐ݒ�****
Dir.chdir(__dir__)

if ARGV[0] and ARGV[0]=~/^\d{8}$/
  Today     = ARGV[0]
  TimeNow = "23:59"
  log_file=Myfile.dir(:kako_log)+"/"+Today+".log"

  if File.exist?(log_file) and Myfile.dir(:excel)
    $logs=RaichoList.setup(log_file,$mado_array,Today)
    make_xlsx($logs)
    popup Myfile.dir(:suii) + " �ɕۑ����܂����B"
  else
    popup "�G���[!\n\""+Today+"\"�̃��O�t�@�C����������܂���."
  end
elsif ARGV[0]
  popup "���t�̎w�肪�Ԉ���Ă���Ǝv���܂�.yyyymmdd�`���̐���8���œ��t���w�肵�Ă�������."
else
  popup "yyyymmdd�`���̐���8���œ��t���w�肵�Ă�������."
end

