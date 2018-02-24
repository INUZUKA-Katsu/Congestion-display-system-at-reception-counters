//スマホ用ページへのリダイレクト（2018/2/24）
(function(){
  var ua = navigator.userAgent;
  var device;
  if(ua.indexOf('iPhone') > 0 || ua.indexOf('iPod') > 0 || ua.indexOf('Android') > 0 && ua.indexOf('Mobile') > 0){
    device = 'sp';
  }else if(ua.indexOf('iPad') > 0 || ua.indexOf('Android') > 0){
    device = 'tab';
  }else{
    device = 'other';
  }
  var ref = document.referrer;
  if((device=='sp' || device=='tab') && ref.indexOf('mado-jokyo-s.html')==-1){
    location.href = './mado-jokyo-s.html';
  }
})();

function XMLHttpRequestCreate(){
  try{
  // XMLHttpRequest オブジェクトを作成
      return new XMLHttpRequest();
  }catch(e){}
  // ------------------------------------------------------------
  // Internet Explorer 用
  // ------------------------------------------------------------
  try{
      return new ActiveXObject('MSXML2.XMLHTTP.6.0');
  }catch(e){}
  try{
      return new ActiveXObject('MSXML2.XMLHTTP.3.0');
  }catch(e){}
  try{
      return new ActiveXObject('MSXML2.XMLHTTP');
  }catch(e){}
  // 未対応
      return null;
}
function NoDataMessage(){
    var URL="./index.html"
    var month = {"Jan":1, "Feb":2, "Mar":3, "Apr":4, "May":5,"Jun":6,"Jul":7,"Aug":8,"Sep":9,"Oct":10,"Nov":11,"Dec":12};
    var yobi = ["日","月","火","水","木","金","土"];

  /* XMLHttpRequestオブジェクト作成 */
  var xmlhttp=XMLHttpRequestCreate();

    /* HTTPリクエスト実行 */
  xmlhttp.open("GET",URL,true);
  // HTTP/1.0 における汎用のヘッダフィールド
  xmlhttp.setRequestHeader('Pragma', 'no-cache');
  // HTTP/1.1 におけるキャッシュ制御のヘッダフィールド
  xmlhttp.setRequestHeader('Cache-Control', 'no-cache');
  // 指定日時以降に更新があれば内容を返し、更新がなければ304ステータスを返すヘッダフィールド。
  // 古い日時を指定すれば、必ず内容を返す。
  xmlhttp.setRequestHeader('If-Modified-Since', 'Thu, 01 Jun 1970 00:00:00 GMT');
    xmlhttp.send(null);

  /* レスポンスデータ処理 */
  xmlhttp.onreadystatechange=function(){
        if(xmlhttp.readyState==4 && xmlhttp.status==200){
            /* ★レスポンスヘッダ取得 */
            var r1 = xmlhttp.getResponseHeader('Date');

            var h1 = r1.split(" ");
            var year1 = h1[3];
            var mon1 = month[h1[2]]-1;
            var day1 = h1[1];
            var time1 = h1[4].split(":");
            var date1 = new Date(year1,mon1,day1,parseInt(time1[0],10)+9,time1[1],time1[2]);
            var date_str1 = (date1.getMonth()+1) + "月" + date1.getDate() + "日"  ;
            var time_str1 = date1.getHours() + "時" + date1.getMinutes() + "分";
            var yobi_str1 = yobi[date1.getDay()];

            /* ★html中の現在月日を取得 */
            var str = document.getElementById("genzai").innerHTML;
            var date_str2 = str.match(/\d\d?月\d\d?日/);

            var mess1 = "";

            if (date_str1 != date_str2){
              mess1 = "<br>　※本日" + date_str1 + "(" + yobi_str1 + ")の情報はありません。" ;
              document.getElementById("kyugyobi").innerHTML = mess1 ;
            }
        }
    }
}

window.onload=function(){
    /* ページ読み込み完了時に実行 */
    NoDataMessage();
}
