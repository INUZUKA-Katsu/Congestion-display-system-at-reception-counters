# -*- coding: Windows-31J -*-
#--------------------------------------------------------------------------------#
#   �ۓy�P�J��ی��N���� �������G�󋵕\���V�X�e�� Ver.353 (2018.3.21)            #
#                                                                                #
#                      <<�I�u�W�F�N�g�̐����i�������j>>                          #
#                                                                                #
#                        �쐬    ����  �� ( ka00-inuzuka@city.yokohama.jp )      #
#                        ���쌠  ���l�s                                          #
#--------------------------------------------------------------------------------#

#*****�ݒ�t�@�C��(conf�t�@�C���ŕϐ���ݒ�)*****
load "./config.txt"


#*****�^�p���[�h****
#�e�X�g���[�h�̎w�肪�Ȃ��Ƃ��͉^�p���[�h�Ƃ���B
$test_mode=0 until defined? $test_mode


#*****�e�X�g���p�̐ݒ�t�@�C��*****
#     �{�Ԋ��̋��L�t�H���_�����݂��Ȃ����œ���e�X�g����Ƃ��A
#     �y�є����@�ɐڑ����Ă��Ȃ�PC�œ���e�X�g����Ƃ��g�p 
load "./config_for_development.txt" if [2,3,4,5].include?($test_mode) and $development_mode==true


#*****���C�u�����̓ǂݍ���*****
require "./Raicholist"


#*****�ݒ�t�@�C���̓Ǎ��݊m�F�t�@�C���u�ݒ�l�ꗗ.txt�v��ۑ��i2017.11.5, 2018.3.21 Raicholist.rb��ǂݍ��񂾌�Ɉڒu�j*****
ConfigSet.make_table_of_setted_value if [1,2,3,4,5,6].include?($test_mode)


#***** �ݒ�t�@�C��������MadoSysFile�N���X�I�u�W�F�N�g��ݒ�(2014.3.31) *****
Myfile=MadoSysFile.setup


#***** �ݒ�t�@�C���̎w��t�H���_�����݂��Ȃ��Ƃ��̓t�H���_���쐬 *****
ConfigSet.setup_dir if test_mode?


#***** ���ݓ��̐ݒ� *****
Today   =Time.now.strftime("%Y%m%d")
YobiNum =Time.now.wday
#p TimeNow


#****�����ԍ��̔z��*****
if $mado_bango.class==String
  $mado_array = $mado_bango.split(",")
  #���o�[�W�����Ƃ̌݊����ێ�(2016.3.8)
else
  $mado_array = $mado_bango
end


#****�������Ƃ̔ԍ��̊��蓖�Ă����ԍ��iKenBango�j�N���X�̕ϐ��Ɋi�[******
#�g������F$bango["8"].mini => 301
#          $bango["8"].max  => 600
#          $bango["8"].wariates_su => 300
unless $bango
  ConfigSet.mado_bango_check if test_mode?
  $bango=Hash.new
  $mado_array.each do |mado|
    $bango[mado]=KenBango.parse($ken_bango[mado])
  end
end


#***** �ݒ�t�@�C���̃f�[�^�����ƂɊJ�������A���������J�����ԁiKaichoJikan�j�N���X�̕ϐ��Ɋi�[ *****
#�g������F$ku.kaicho => "08:45"
#          $ku.heicho => "17:00"
$ku=KaichoJikan.setup(Today) unless $ku


#***** �������G�󋵃��b�Z�[�W��ڈ��҂����ԁiMeyasuMachijikan�j�N���X�̕ϐ��Ɋi�[ *****
$message=MeyasuMachijikan.parse($jam_message) if defined? $jam_message

#***** �����󋵂ɂ��x��(���ӊ��N)�̏�����AlertJoken�N���X�̕ϐ��Ɋi�[ 2015/10/10*****
AJ=AlertJoken.new($keikoku_joken) if defined? $keikoku_joken


#***** �ݒ�`�F�b�N(�e�X�g���[�h�U�̂Ƃ��̂�) *****
if test_mode?(6)
  exit if ConfigSet.check_all_test_mode6 == false or test_mode?(6)
end

#***** �e�X�g�p���O�f�[�^�̃`�F�b�N *****
if test_mode?(2,3,4,5)
  ConfigSet.log_file_check
end

#�ȉ��̓v���O�����̓���m�F�p�i�e�X�g���[�h�T�̂Ƃ����s�j
#������������������������������������������������������������������
#***** �����҃��X�g�I�u�W�F�N�g�̊m�F�i�R���\�[����ʂɕ\���j*****
#������������������������������������������������������������������
if $test_mode == 5
  #***** ���ݎ����̐ݒ� *****
  TimeNow =Time.now.strftime("%H:%M") if String.const_defined?(:TimeNow)==false or Object.class_eval{remove_const :TimeNow}
  #***** ���O�f�[�^�����Ƃɗ����҃��X�g(RaichoList)�N���X�̃I�u�W�F�N�g���쐬 *****
  $log=RaichoList.setup(Myfile.file[:log],$mado_array)
  $mado_array.each do |mado|
    p $log[mado][-1] #�e���̍ŏI�����҃I�u�W�F�N�g
  end
  $mado_array.each do |mado|
    $log[mado].display
  end
  puts "\n�����Ґ�(�����҃I�u�W�F�N�g�̐�) => " << RaichoList.sya_su.to_s
  puts "�P���Ԉȓ��ɍX�V���ꂽ��?        => " << RaichoList.update?.to_s
  puts "�����S�̂̏�                   => " << RaichoList.state_whole
  puts "�����S�̂̑҂��l��               => " << RaichoList.machi_su.nin

  puts ""
  alert("�����Ґ�")
  $mado_array.each do |mado|
    alert(mado+"�ԑ���:"+$log[mado].sya_su.to_s)
  end
  alert("��   �v:" + RaichoList.sya_su.to_s)
  
  puts ""
  alert("���ϑ҂�����")
  $mado_array.each do |mado|
    alert mado+"�ԑ���: "+$log[mado].average_machi_hun.to_s+"��"
  end
  
  puts ""
  alert("���Ԃ��Ƃ̗����Ґ�")
  $mado_array.each do |mado|
    (8..17).each do |ji|
      if ji.to_hhmm < TimeNow
        alert "#{mado}�� #{ji.to_s}����: #{$log[mado].jikan_betsu_sya_su(ji).to_s}�l"
      end
    end
  end
end

def ����e�X�g
  p RaichoList.last_update_time
  p RaichoList.update?
  p RaichoList.logfile_update_within 50.minute
  p $log["7"].maiji_sya_su($ku)
  RaichoList.events.display
  p RaichoList.events.select{|ev| ev.kubun_code==0}
  RaichoList.part_events("9",:hakken).each{|l| p l}
  RaichoList.part_events("9",:yobidashi).each{|l| p l}
  p $log["9"].current(:yobidashi,TimeNow).id
  RaichoList.part_events.each{|l| p l}

  puts "�I��"
end
����e�X�g if 1==0

#***** AlertJoken�N���X�̓���`�F�b�N(�J���p) *****
def alert_joken�e�X�g
  p AJ["7"]
  p AJ["7"].by("���[��").table.to_a
  p AJ["7"].by("���j�^�[").joken_set_another("next_machi_jikan")
  p AJ["7"].by("���j�^�[").compare("next_machi_jikan").joken_set
end
alert_joken�e�X�g if 1==0


