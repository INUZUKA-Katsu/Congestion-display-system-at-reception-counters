function XMLHttpRequestCreate(){
	try{
	// XMLHttpRequest �I�u�W�F�N�g���쐬
    	return new XMLHttpRequest();
	}catch(e){}
	// ------------------------------------------------------------ 
	// Internet Explorer �p
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
	// ���Ή�
    	return null;
}
function NoDataMessage(){
    var URL="./index.html"
    var month = {"Jan":1, "Feb":2, "Mar":3, "Apr":4, "May":5,"Jun":6,"Jul":7,"Aug":8,"Sep":9,"Oct":10,"Nov":11,"Dec":12};
    var yobi = ["��","��","��","��","��","��","�y"];

	/* XMLHttpRequest�I�u�W�F�N�g�쐬 */ 
	var xmlhttp=XMLHttpRequestCreate();

    /* HTTP���N�G�X�g���s */ 
	xmlhttp.open("GET",URL,true);
	// HTTP/1.0 �ɂ�����ėp�̃w�b�_�t�B�[���h
	xmlhttp.setRequestHeader('Pragma', 'no-cache');
	// HTTP/1.1 �ɂ�����L���b�V������̃w�b�_�t�B�[���h
	xmlhttp.setRequestHeader('Cache-Control', 'no-cache'); 
	// �w������ȍ~�ɍX�V������Γ��e��Ԃ��A�X�V���Ȃ����304�X�e�[�^�X��Ԃ��w�b�_�t�B�[���h�B
	// �Â��������w�肷��΁A�K�����e��Ԃ��B
	xmlhttp.setRequestHeader('If-Modified-Since', 'Thu, 01 Jun 1970 00:00:00 GMT'); 
    xmlhttp.send(null);

	/* ���X�|���X�f�[�^���� */
	xmlhttp.onreadystatechange=function(){
        if(xmlhttp.readyState==4 && xmlhttp.status==200){
            /* �����X�|���X�w�b�_�擾 */
            var r1 = xmlhttp.getResponseHeader('Date');

            var h1 = r1.split(" ");
            var year1 = h1[3];
            var mon1 = month[h1[2]]-1;
            var day1 = h1[1];
            var time1 = h1[4].split(":");
            var date1 = new Date(year1,mon1,day1,parseInt(time1[0],10)+9,time1[1],time1[2]);
            var date_str1 = (date1.getMonth()+1) + "��" + date1.getDate() + "��"  ;
            var time_str1 = date1.getHours() + "��" + date1.getMinutes() + "��";
            var yobi_str1 = yobi[date1.getDay()];

            /* ��html���̌��݌������擾 */
            var str = document.getElementById("genzai").innerHTML;
            var date_str2 = str.match(/\d\d?��\d\d?��/);

            var mess1 = "";
            var mess2 = "";

            if (date_str1 != date_str2) mess1 = "<br>�@���{��" + date_str1 + "(" + yobi_str1 + ")�̏��͂���܂���B" ;
            document.getElementById("kyugyobi").innerHTML = mess1 ;

            mess2="�i�ēǍ���" + date_str1 + " " + time_str1 + "�j" ;
            document.getElementById("res").innerHTML=mess2;
        }
    }
}

window.onload=function(){
    /* �y�[�W�ǂݍ��݊������Ɏ��s */
    NoDataMessage();
}
