窓口混雑状況表示システム  

稼働実例  
http://cgi.city.yokohama.lg.jp/hodogaya/hokennenkin/index.html  
http://cgi.city.yokohama.lg.jp/hodogaya/hokennenkin/mado-jokyo-suii-hun.html  

システムの概要  
窓口用発券機の発券情報及び呼出し情報が逐次記録されるログファイルを読み込んで分析し、最新の呼出し番号と現在の待ち人数、待ち人数に対応する推定待ち時間などのコメントのほか、毎正時の待ち人数や待ち時間を棒グラフなどを組み込んだhtmlファイルを生成し、webサーバーにアップロードする。

必要条件    
現在のところ、連携できる発券機は明光商会（株）のボイスコールProに限定されています。
ボイスコールProのオプションであるモニタシステムをインストールし、ボイスコールProと接続したウインドウズPC上で動作します。
他社製品や明光商会（株）の他機種でもログファイルを利用できるようにしてもらえれば連携可能です。

主要なプログラムファイル  
mado_FTP.rb  
Raicholist.rb   
Suii.rb（今週/先週の混雑状況）  

設定ファイル  
config.txt

ライセンス  
MIT License
