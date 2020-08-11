#coding:sjis

require "./objectinitialize.rb"

#**** 対象窓口 ****  
mado="13"

#**** 手動データ追加ログファイル ****
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
    mess = %Q|#{jikoku} に入力した待ち人数 #{machi_su.to_s} 人 を取り消しますか？|
    ans = popup(mess,3)

    if ans==6
        str=""
        File.open(Myfile.file[:log],"r") do |f|
            f.flock(File::LOCK_EX)
            str = f.read.sub( data+"\n", "" )
            f.flock(File::LOCK_UN)
        end
        File.open(Myfile.file[:log],"w") do |f|
            f.flock(File::LOCK_EX)
            f.puts str
            f.flock(File::LOCK_UN)
        end
        File.open(add_log,"w") do |f|
            f.puts added_log_ary.join("\n")
        end
        popup("取消しました。",0,"完了",10)
    end
else
    mess = %Q|手動で設定された待ち人数の記録はありません。|
    ans = popup(mess,1)
end
