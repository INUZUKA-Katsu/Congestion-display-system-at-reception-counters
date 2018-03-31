// 繁忙期で待ち人数が他の時期に比べて突出して多くなり棒グラフがセルに入りきらなくなったとき長さを調節する。
// mado-hinagata-suii-machisu.htmlとmado-hinagata-suii-hun.htmlで、このjsファイルを読み込むようにする。

//初期設定：棒の描画領域のセル幅に占める割合
var bar2cell = 0.48;

document.addEventListener("DOMContentLoaded", function(event) {
  adjustBarSize();
});

function getBarLengths(dd){
  var lens=[];
  for(var i = 0; i < dd.length; ++i){
    var img = dd[i].firstElementChild
    if(img && img.nodeName=='IMG'){
      //lens.push(img.style.width);
      lens.push(img.clientWidth);
    }
  }
  return lens;
}

function getSpaceWidth(dd){
  for(var i = 0; i < dd.length; ++i){
    var img = dd[i].firstElementChild
    if(img && img.nodeName=='IMG'){
      img.style.width = '0px';
    }
  }
  var tableWidth = document.getElementsByTagName('table')[0].clientWidth;
  var cellWidth = tableWidth/6.3;
  var barWidth  = cellWidth*bar2cell;
  return barWidth;
}

function adjustBarSize(){
  var dd = document.getElementsByTagName('dd');
  var lens= getBarLengths(dd);
  var wid = getSpaceWidth(dd);
  var max = Math.max.apply(null, lens);
  if(max>wid){
    var hosei = wid/max;
  }else{
    var hosei = 1;
  }
  for(var i = 0; i < dd.length; ++i){
    var img = dd[i].firstElementChild
    if(img && img.nodeName=='IMG'){
      img.style.width = String(lens[i]*hosei)+'px';
    }
  }
}

