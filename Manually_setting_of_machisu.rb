#coding:sjis

require "./objectinitialize.rb"

#**** �Ώۑ��� ****  
mado="13"

#**** �蓮�f�[�^�ǉ����O�t�@�C�� ****
add_log = "./added_by_manual.log"

def data_sort(log)
    str=File.read(log)
    p str
    if str
        sorted = str.split("\n").sort.join("\n")
        File.open(log,"w") do |s|
            s.puts sorted
        end
    end
end

def id2bango(id,mado)
    mini=$bango[mado].mini
    max =$bango[mado].max
    range = max-mini+1
    bango =  mini + (id % range) - 1
    bango
end

def get_machisu
    mess1 = '12�ԁi�}�C�i���o�[�J�[�h�j�����̌��݂̑҂��l���𔼊p�����œ��͂��Ă��������B'
    inputed_su = get_input(mess1, title='�҂��l���蓮�ݒ�')
    if inputed_su
        if inputed_su.match(/^\d\d?$/)
            mess2 = %Q|12�ԁi�}�C�i���o�[�J�[�h�j�����̌��݂̑҂��l���� #{inputed_su.to_s} �l �Ɛݒ肵�܂��B|
            ans = popup(mess2,3)
        elsif inputed_su.match(/^\d\d\d$/)
            mess2 = %Q|�u#{inputed_su}�v�ŊԈႢ�Ȃ��ł����H\n�@���̂܂ܐݒ肷��Ƃ��� "�͂�"�A\n�@���͂���蒼���Ƃ��� "������" ��I�����Ă��������B|
            ans = popup(mess2,3)
            if ans==7
                ans = :re_input
            end
        else
            mess2 = %|�u#{inputed_su}�v�͓��͊ԈႢ�Ǝv���܂��B�������͂���蒼���Ă��������B|
            ans = popup(mess2,1)
            if ans==1
                ans = :re_input
            end
       end
    else
        ans = 0
    end
    [ans, inputed_su]
end

ans, inputed_su = 0, 0
loop{
    ans, inputed_su = get_machisu
    break if ans != :re_input
}

if ans==6
    TimeNow =Time.nowb.strftime("%H:%M") if String.const_defined?(:TimeNow)==false or Object.class_eval{remove_const :TimeNow}
    $logs=RaichoList.setup(Myfile.file[:log],$mado_array)
    last_sya = $logs[mado].yobidashi_sya_just_before
    cancel_su = $logs[mado].select{|sya| sya.time(:cancel) and sya.id > last_sya.id}.size
    add_id = last_sya.id + cancel_su + inputed_su.to_i
    hakken_bango =  id2bango(add_id,mado)
 
    #p "*****canceled*****"
    #$logs[mado].select{|sya| sya.time(:cancel) }.display
    #p "*****���̎��ԑт̃L�����Z��*****"
    #$logs[mado].select{|sya| sya.time(:cancel) }.select{|sya| sya.time(:cancel)>last_sya.time(:hakken)}.display 
    #p "machisu_nyuryoku =>" + inputed_su.to_s
    #p "last_sya.id => " + last_sya.id.to_s
    #p "cancel_su =>" + cancel_su.to_s
    #p "add_id => " + add_id.to_s

    data = [ Today, TimeNow, "0", $gyomu.key(mado), hakken_bango ].join(",")
    [Myfile.file[:log],add_log].each do |log|
        p log
        File.open(log,"a") do |f|
            f.flock(File::LOCK_EX)
            f.puts data
            f.flock(File::LOCK_UN)
        end
    end
    if test_mode?
        data_sort(Myfile.file[:log])
    end
    popup("�ۑ����܂����B",0,"�ݒ�I��",10)
end
