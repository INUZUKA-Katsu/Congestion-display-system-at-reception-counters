# -*- coding: Windows-31J -*-
#--------------------------------------------------------------------------------#
#   �ۓy�P�J��ی��N���� �������G�󋵕\���V�X�e�� Ver.352 (2017.9.9)             #
#                                                                                #
#          �ߋ����O�t�@�C���̏C����                                              #
#                                                                                #
#                        �쐬    ����  �� ( ka00-inuzuka@city.yokohama.jp )      #
#                        ���쌠  ���l�s                                          #
#--------------------------------------------------------------------------------#

Encoding.default_external="Windows-31J"

#***** �ݒ�t�@�C���A���O�t�@�C��������e��I�u�W�F�N�g���쐬�i�������j����B *****
require "./ObjectInitialize.rb"
require "./Suii.rb"

#****��ƃf�B���N�g���̐ݒ�****
Dir.chdir(__dir__)

if ARGV[0] and ARGV[0]=~/^\d{8}$/
  Day     = ARGV[0]
  KakoLog.new(Day..Today,:simple).repair
end
