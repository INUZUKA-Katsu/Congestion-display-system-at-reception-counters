# -*- coding: Windows-31J -*-
#--------------------------------------------------------------------------------#
#   保土ケ谷区保険年金課 窓口混雑状況表示システム Ver.3.41 (2016.3.16)           #
#                                                                                #
#          HTLM生成、FTP送信編                                                   #
#                                                                                #
#                        作成    犬塚  克 ( ka00-inuzuka@city.yokohama.jp )      #
#                        著作権  横浜市                                          #
#--------------------------------------------------------------------------------#

Encoding.default_external="Windows-31J"

#****作業ディレクトリの設定****
Dir.chdir(__dir__)


#***** 設定ファイル、ログファイル等から各種オブジェクトを作成（初期化）する。 *****
require "./ObjectInitialize.rb" unless String.const_defined? :Today


#***** 状況判定 *****
def situation
  $syuryo_hun||=5
  vc=VcallMonitor.new
  if $ku.heicho < TimeNow
    if File.exist?("#{MYDOC}/#{$logfolder}/#{Today}.log") and test_mode? == false
      return :ended
    elsif ( $ku.heicho + $syuryo_hun.minute < TimeNow and
            RaichoList.machi_su==0 and
            RaichoList.last_update_time + 10.minute < TimeNow ) or
          ( $ku.heicho + 3.hour < TimeNow )
      return :ending
    end
  end
  if $ku.kaicho > TimeNow
    return :before_open
  end
  :regular
end


#*****現在の時間帯（戻り値:"開庁前","開庁時間","閉庁後"のいずれか）*****
def time_zone()
  if TimeNow < $ku.kaicho
      "開庁前"
  elsif TimeNow.between?($ku.kaicho,$ku.heicho)
      "開庁時間"
  else $ku.heicho < TimeNow
      "閉庁後"
  end
end


#***** HP用データ0 現在日時の文字列 *****
def genzai
  "#{Today.day_to_jan} #{TimeNow.time_to_jan}現在"
end


#***** HP用データ1 ただ今の受付番号 *****
def hp_data_bango(mado)
  bango = $logs[mado].current(:yobidashi).bango
  if time_zone=="閉庁後" and $logs[mado].machi_su==0
    "－"
  else
    bango
  end
end


#***** HP用データ2 待ち人数 *****
def hp_data_machi_ninzu(mado)
  machi_su = $logs[mado].machi_su
  machi_su_nin = machi_su.to_s + "人"
  case time_zone
  when "開庁前"
    #開庁時間前は、待ち人数がゼロのときはバー（"－"）表示とする。
    if machi_su == 0
      "－"
    else
      machi_su_nin
    end
  when "開庁時間"
    machi_su_nin
  when "閉庁後"
    #閉庁時間後、すべての窓口の待ち人数がゼロになったらバー（"ー"）表示に切り替える。
    if RaichoList.machi_su==0
      "－"
    else
      machi_su_nin
    end
  end
end


#***** HP用データ3 備考欄メッセージ *****
def hp_data_message(mado)
  message_kaicho_jikan      = "本日の受付は#{$ku.kaicho.time_to_jan.num_to_zenkaku}からです。"
  message_no_data           = "まだ本日の情報はありません。"
  message_heicho_machiari   = "本日の受付は終了しました。（番号札をお待ちの方は番号をお呼びするまでお待ちください。）"
  message_heicho_machinashi = "本日の受付は終了しました。"
  message_error_no_date     = "まだ本日の情報はありません。システムに何らかの不具合が発生している可能性もあります。"
  def message_error_no_update
    "#{RaichoList.last_update_time.time_to_jan}後の新しい情報がありません。システムに何らかの不具合が発生している可能性もあります。"
  end
  def mail_error_no_date
    unless defined? $error_mail_sent
      title="【エラー！】モニタシステムを確認してください。"
      body ="まだ今日のボイスコール情報がありません。モニタシステムが正しく動作しているか確認してください。"
      send_mail(title,body)
      $error_mail_sent=true
    end
  end
  def mail_error_no_update
    unless defined? $error_mail_sent
      title="【エラー！】モニタシステムを確認してください。"
      body ="モニタシステムの情報が１時間以上更新されていません。モニタシステムが正しく動作しているか確認してください。"
      send_mail(title,body)
      $error_mail_sent=true
    end
  end

  case time_zone
  when "開庁前"
        message_kaicho_jikan
  
  when "開庁時間"
    #開庁時間を過ぎているのに今日のデータが皆無の場合
    if RaichoList.sya_su==0
      #警告メール
      mail_error_no_date
      #開庁時刻後30分未満のとき
      if TimeNow < $ku.kaicho + 30.minute
        message_no_data
      #開庁時刻後30分以上経過しているとき（システムエラーの可能性）
      else
        message_error_no_date
      end
    #１時間以上データが更新されていないとき（システムエラーの可能性）
    elsif RaichoList.last_update_time + 60.minute < TimeNow
      mail_error_no_update
      message_error_no_update
    #正常に動作しているとき（待ち時間の目安を表示）
    else
        machi_su=$logs[mado].machi_su
        $message.meyasu_jikan(mado,machi_su) if defined? $message
    end
  
  when "閉庁後"
    if $logs[mado].machi_su > 0
        message_heicho_machiari
    else
        message_heicho_machinashi
    end
  end
end


#***** HP用データ4 毎正時の待ち人数 *****
def hp_data_graph(mado)
  #WEBアクセシビリティ(棒グラフを画像データに変更)
  def bar_chart(nin)
    use_image=true #画像イメージ方式:true、 従来方式:false
    if use_image
      return bar_chart_imgtag(:today,nin)
    else
      #従来方式
      return nin>0 ? "<span>#{"|" * nin}</span>" : "&nbsp;"
    end
  end
  hash=$logs[mado].maiseiji_machi_su($ku)
  return {:title => "",:data => ""} if hash.size==0
  str=""
  hash.each do |ji,nin|
      str << "<dt>#{ji.hour}時 #{nin.to_s}人</dt>"
      str << "<dd>#{bar_chart(nin)}</dd>\n"
  end
  {:title => "(参考)今日の待ち人数の推移",:data => str}
end


#***** HP用データ5 トピック *****
#      config.txtの$topicで指定したファイルの
#      行頭に#のない行の文字を取得する。
def topic
  if Myfile.file(:topic) and File.exist? Myfile.file(:topic)
    f=File.read(Myfile.file(:topic))
    f.gsub(/#.*\n/,"").gsub(/^\n/,"")
  end
end


#*****送信データ(HTMLファイル)の作成・保存*****
#PC用と携帯・スマホ用の処理を分ける必要はなかった
#ので統合して整理した。(2014.3.31)
def make_html()
  temp_dir=Myfile.dir(:temp)
  files=Array.new
  [:pc,:keitai,:sumaho].each do |h|
    f=File.read(Myfile.hinagata(h))
    f.sub!(/<!--madoguchiTopics-->/)      {|str| topic} if topic
    f.sub!(/<!--TIME-->/)                 {|str| genzai}
    $mado_array.each do |mado|
      unless Today.closed_mado.include? mado
        f.sub!(/<!--#{mado}-BANGO-->/)      {|str| hp_data_bango(mado)}
        f.sub!(/<!--#{mado}-NINZU-->/)      {|str| hp_data_machi_ninzu(mado)}
        f.sub!(/<!--#{mado}-MESSAGE-->/)    {|str| hp_data_message(mado)}
        f.sub!(/<!--#{mado}-SANKO-Title-->/){|str| hp_data_graph(mado)[:title]}
        f.sub!(/<!--#{mado}-SANKO-->/)      {|str| hp_data_graph(mado)[:data]}
      else
        f.sub!(/<!--#{mado}-BANGO-->/)      {|str| "－"}
        f.sub!(/<!--#{mado}-NINZU-->/)      {|str| "－"}
        f.sub!(/<!--#{mado}-MESSAGE-->/)    {|str| $close_message[:pc]}
        f.sub!(/<!--#{mado}-SANKO-Title-->/){|str| ""}
        f.sub!(/<!--#{mado}-SANKO-->/)      {|str| ""}
      end
    end
    File.write(Myfile.dir(:temp)+"/"+Myfile.file_name(h),f)
    files << Myfile.dir(:temp)+"/"+Myfile.file_name(h)
  end
  files
end


#***** 通常処理 *****
def 通常処理
  files=make_html()                     #***** HTML作成 *****
  ftp_soshin(files,Myfile.dir(:ftp))    #***** FTP送信 *****
  make_monitor_html($logs)              #***** 課内モニター用HTMLファイルの作成・保存 *****
  teitai_keikoku_mail($logs)            #***** 窓口が停滞しないか監視し,一定時間停滞しているとき警告する *****
  puts "通常処理終了！"
end


#***** 開庁前処理 *****
def 開庁前処理
  if defined? $suii_open and $suii_open==:yes
    require './suii'
    files=modify_html_of_week()                   #***** 送信フォルダ中の既存HTMLを修正 *****
    ftp_soshin(files,Myfile.dir(:ftp)) if files   #***** FTP送信 *****
  end
puts "開庁前処理終了！"
  通常処理
end


#***** 終了処理 *****
def 業務終了処理
  #待ち人数があるにも関わらず発券機が落とされた場合の後処理
  #発券だけのデータを削除し待ち人数をゼロにする。
  $mado_array.each do |mado|
    $logs[mado]=$logs[mado].reject{|sya| sya.time_h>$ku.heicho and sya.time_y==nil and sya.time_c==nil}
  end
  #ホームページ、課内モニタを更新する
  通常処理

  #logデータ保存・初期化
  log_data_backup if $test_mode!=7

  #***** 推移のhtml *****
  require './suii'
  #過去ログファイルに欠落があるとき修復する。
  days_of_this_week=Today.days_of_week
  Kakolog.repair(days_of_this_week) if Kakolog.lack_of_kako_log(days_of_this_week)
  #内部モニタ用ページ(内部モニタ用⇒公開用の順序を崩さないこと)
  make_suii_for_monitor if Myfile.dir(:suii)
  #公開用ページ
  if defined? $suii_open and $suii_open==:yes
    files=make_html_of_week(Today)
    ftp_soshin(files,Myfile.dir(:ftp))
  end

  #概況データ保存
  gaikyo_data_save($logs)

  #エクセルで今日の待ち時間一覧表を作成
  make_xlsx($logs) if Myfile.dir(:excel)

  #保険年金課の更新日時変更があるか調べ、変更あるとき共通デザインを取り込む
  #load  './mado_design_renew.rb'

  puts "業務終了処理完了！"

  #システムシャットダウン
  mess="業務終了処理が完了しました。５分後にシャットダウンします。"
  VcallMonitor.new.shutdown_pc(mess,5.minute) if $test_mode!=7
  exit
end

#**********************************************#
#         ここからが実際の処理部分             #
#**********************************************#

#***** 現在時刻の設定 *****
TimeNow =Time.now.strftime("%H:%M") if String.const_defined?(:TimeNow)==false or Object.class_eval{remove_const :TimeNow}

#***** ログデータをもとに来庁者リスト(RaichoList)クラスのオブジェクトを作成 *****
$logs=RaichoList.setup(Myfile.file[:log],$mado_array)

#***** 状況に対応する処理を実行する *****
p Time.now
p "状況判定: situation=#{situation}"
case situation
  when :regular               ; 通常処理
  when :before_open           ; 開庁前処理
  when :ending                ; 業務終了処理
  when :ended                 ; puts "業務終了処理済み！"
end



