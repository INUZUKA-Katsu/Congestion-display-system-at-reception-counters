#coding:sjis

require "./objectinitialize.rb"

#**** �Ώۑ��� ****  
mado="13"

#**** �蓮�f�[�^�ǉ����O�t�@�C�� ****
add_log = "./added_by_manual.log"

TimeNow = "18:00"
$logs=RaichoList.setup(Myfile.file[:log],$mado_array)

def get_machi_su(add_log,mado)
    str = File.read(add_log)
    return nil unless str

    added_log_ary = str.strip.split("\n")
    return nil if added_log_ary==[]

    data = added_log_ary.pop
    jikoku = data.split(",")[1]
    machi_su = $logs[mado].machi_su(jikoku)
    [machi_su, jikoku, data, added_log_ary]
end


machi_su, jikoku, data, added_log_ary = get_machi_su(add_log,mado)
if machi_su
    mess = %Q|#{jikoku} �ɓ��͂����҂��l�� #{machi_su.to_s} �l ���������܂����H|
    ans = popup(mess,3)

    if ans==6
        str = ""
        res = :unmatch
        File.open(Myfile.file[:log],"r") do |f|
            f.flock(File::LOCK_EX)
            str = f.read.sub( data+"\n", "" )
            res = :done if $&
            f.flock(File::LOCK_UN)
        end
        if res == :done
            File.open(Myfile.file[:log],"w") do |f|
                f.flock(File::LOCK_EX)
                f.puts str
                f.flock(File::LOCK_UN)
            end
            File.open(add_log,"w") do |f|
                f.puts added_log_ary.join("\n")
            end
            popup("������܂����B",0,"����",10)
        else
            mess = "��������f�[�^�����O�t�@�C��(Prolog.csv)�̒��ɂ���܂���ł����B\n" +
                   "�蓮���͂ɂ��Y�����͋L�^�𖕏����܂����H"
            ans  = popup(mess,4,"������",10)
            if ans == 6
                File.open(add_log,"w") do |f|
                    f.puts added_log_ary.join("\n")
                end
                popup("�蓮�ɂ��Y�����͋L�^�𖕏����܂����B",0,"����",10)
            end
        end
    end
else
    mess = %Q|�蓮�Őݒ肳�ꂽ�҂��l���̋L�^�͂���܂���B|
    ans = popup(mess,1)
end
