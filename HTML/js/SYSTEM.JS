  ////////////////////////////////////////////////////////////////////
  //
  // 接近情報表示プログラム「メトロパイパー」
  // クライアントサイドプログラム
  //
  // Written by Rich Mikan(richmikan@richlab.org) at 2014/11/15
  //
  ////////////////////////////////////////////////////////////////////



  ////////////////////////////////////////////////////////////////////
  // 初期化
  ////////////////////////////////////////////////////////////////////

  // ===== グローバル変数の設定 ======================================
  var gbFarStns_disable             = true;  // 離れている駅が非表示の時はtrue
  var gdtAccTime_by_localclock      = false; // ブラウザーの時計による情報取得日時
  var gbDoing_everysecond_func      = false; // everysecond_func()実行中ならtrue
  var gbDoing_get_locinfo           = false; // get_locinfo()実行中ならtrue
  var gtInvervalID_everysecond_func = null;  // everysecond_func()のsetIntervalのID保管用
  var gtTimeoutID_set13fromsnum     = null;  // set_all_snum_to_fromsnum()のsetIntervalのID保管用
  var gtTimeoutID_set9tosnum        = null;  // set_snum_to_tosnum()のsetIntervalのID保管用
  var gtTimeoutID_get_locinfo       = null;  // get_locinfo()タイムアウト関数ID保管用
  var gsURL_of_this                 = null;  // 現在の操作が反映されたURLを保存用


  // ===== onload関数 ================================================
  function init() {
    var e, i, ls;
    var sQueryString, lsParam;
    var sFrom_snum   = '';
    var sTo_snum     = '';
    var bAuto_update = false;

    // --- 1)知りたい駅選択肢を作る関数を実行する --------------------
    set_all_snum_to_fromsnum(false);

    // --- 2)GETクエリー文字列を取得 ---------------------------------
    sQueryString = location.href.replace(/^[^?]+\?/,"");
    lsParam      = sQueryString.split('&');

    // --- 3)CGI変数の読み込み ---------------------------------------
    for (i=0; i<lsParam.length; i++) {
      ls = lsParam[i].match(/^([^=]+)=(.*)$/);
      if        (ls    === null     ) {continue;                 }
      if        (ls[1] === 'from'   ) {sFrom_snum        = ls[2];
      } else if (ls[1] === 'to'     ) {sTo_snum          = ls[2];
      } else if (ls[1] === 'autoupd') {bAuto_update      = true;
      } else if (ls[1] === 'dispall') {gbFarStns_disable = false;
      }
    }

    // --- 4)知りたい駅の選択肢を指定された駅にする -------------------
    e = document.getElementById('from_snum');
    if (! e) {return;}
    for (i=1; i<e.options.length; i++) {
      if (e.options[i].value === sFrom_snum) {
        e.selectedIndex = i;
        break;
      }
    }
    if (i === e.options.length) {return;} // 該当選択肢が無ければ終了

    // --- 5)行きたい方向駅の選択肢を指定された駅にする ---------------
    e = document.getElementById('to_snum');
    if (! e) {return;}
    set_snum_to_tosnum(false);
    for (i=1; i<e.options.length; i++) {
      if (e.options[i].value === sTo_snum) {
        e.selectedIndex = i;
        break;
      }
    }
    if (i === e.options.length) {return;} // 該当選択肢が無ければ終了

    // --- 6)在線状況問い合わせを実行する ----------------------------
    get_locinfo(bAuto_update);

    // --- 99)完了 ---------------------------------------------------
    return;
  }



  ////////////////////////////////////////////////////////////////////
  // IE8サポート
  ////////////////////////////////////////////////////////////////////

  // ===== getElementsByClassName()相当関数 ==========================
  function document_getElementsByClassName(sClassName){
    var e, i, j, ls, s;
    var leAll;      // 全エレメント
    var leRet;      // 見つかったエレメント格納用

    // --- 0)メソッドが存在するならそれを用いておしまい --------------
    if (typeof document.getElementsByClassName === 'function') {
      return document.getElementsByClassName(sClassName);
    }

    // --- 1)見つかったエレメント格納用の配列を用意 ------------------
    leRet = new Array();

    // --- 2)HTML上の全タグのエレメントを収集 ------------------------
    if (document.all){
      leAll = document.all;
    } else {
      leAll = document.getElementsByTagName("*");
    }

    // --- 3)該当クラス名が含まれるか確認 ----------------------------
    for (i=0; i<leAll.length; i++) {
      s = leAll[i].className;
      if (! s) {continue;}
      ls = s.split(' ');
      for (j=0; j<ls.length; j++) {
        if (ls[j] === sClassName) {
          leRet.push(leAll[i]);
          break;
        }
      }
    }  

    // --- 4)検索結果を返却 ------------------------------------------
    return leRet;
  }



  ////////////////////////////////////////////////////////////////////
  // Ajax関連
  ////////////////////////////////////////////////////////////////////

  // ===== Ajaxのお約束オブジェクト作成 ==============================
  function createXMLHttpRequest(){
    if(window.XMLHttpRequest){return new XMLHttpRequest()}
    if(window.ActiveXObject){
      try{return new ActiveXObject("Msxml2.XMLHTTP.6.0")}catch(e){}
      try{return new ActiveXObject("Msxml2.XMLHTTP.3.0")}catch(e){}
      try{return new ActiveXObject("Microsoft.XMLHTTP")}catch(e){}
    }
    return false;
  }


  // ===== 「知りたい駅」に駅ナンバーコードを入れる ==================
  function set_all_snum_to_fromsnum(bAsync) {
    var s, xhr;
    var sUrl_ajax = '../CGI/GET_SNUM_HTMLPART.AJAX.CGI';
    bAsync = (typeof bAsync === 'boolean') ? bAsync : true;

    // --- 1)更新ボタンとselectボックスを無効化する ------------------
    document.getElementById('reload_btn').disabled = true;
    document.getElementById('from_snum' ).disabled = true;
    document.getElementById('to_snum'   ).disabled = true;

    // --- 2)アボートタイマーをセット --------------------------------
    if ((bAsync) && (! gtTimeoutID_set13fromsnum)) {
      gtTimeoutID_set13fromsnum = window.setTimeout(function(){xhr.abort()}, 30000);
    }

    // --- 3)Ajaxコール ----------------------------------------------
    xhr = createXMLHttpRequest();
    if (! xhr) {return;}
    s = 'dummy='+parseInt((new Date)/1);               //キャッシュ対策
    xhr.open('GET', sUrl_ajax + '?' + s, bAsync);
    xhr.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded; charset=UTF-8');
    if (bAsync) {xhr.onreadystatechange = function(){set_all_snum_to_fromsnum_callback(xhr)};}
    xhr.send(s);
    if (!bAsync) {set_all_snum_to_fromsnum_callback(xhr);}

    // --- 99)コール側関数の終了 -------------------------------------
    return;
  }
  function set_all_snum_to_fromsnum_callback(xhr) {
    var e, i, j, ls;
    var bAbort = true;   // Ajax未完了で関数を抜ける場合はtrue

    // --- 0)breakdown区間設定(7まで) --------------------------------
    while (true) {

    // --- 4)アクセス成功で呼び出されたのでないなら即終了 ------------
    if (xhr.readyState != 4) {break;}

    // --- 5)Ajax受信完了処理 ----------------------------------------
    if (gtTimeoutID_set13fromsnum) {
      window.clearTimeout(gtTimeoutID_set13fromsnum); // アボートタイマー解除
      gtTimeoutID_set13fromsnum = null;
    }
    bAbort = false;
    if (xhr.status ===   0) { // ステータスが0の場合はabortでありブラウザー側の自主的な中断である
      alert('通信に失敗したため、知りたい駅候補読み込みを中断しました。本ページを再読み込みしてください。');
      break;
    }
    if (xhr.status !== 200) {
      alert('申し訳ありません、サーバーがエラーを返しました。(' + xhr.status + ')');
      break;
    }

    // --- 6)サーバーから返された部分HTMLを流し込む ------------------
    e = document.getElementById('from_snum');
    if (! e) {
      alert('HTMLが正しくないため、知りたい駅候補を受信できませんでした。');
      break;
    }
    //e.innerHTML = xhr.responseText;
    e.innerHTML = '';
    ls = xhr.responseText.replace(/\r\n|\r/g,"\n").split('\n');
    j  = 0;
    for (i=0; i<ls.length; i++) {
      if (ls[i].match(/<option\s+value="([^"]+)">([^<>]+)<\/option>/)) { //"
        e.options[j] = new Option(RegExp.$2, RegExp.$1);
        j++;
      }
    }

    // --- 7)Ajax未完の場合はここで関数中断 --------------------------
    break;}
    if (bAbort) {return;}

    // --- 8)通信に成功していれば知りたい駅selectボックスを元に戻す --
    e = document.getElementById('from_snum');
    if ((xhr.status === 200) && (e)) {
      if (e.options.length >= 2) {e.disabled = false;}
    }

    // --- 99)コールバック側関数の終了 -------------------------------
    return;
  }


  // ===== 「行きたい方面」に指定された路線の駅ナンバーコードを入れる
  function set_snum_to_tosnum(bAsync) {
    var b, e, i, s, s1, xhr;
    var sUrl_ajax = '../CGI/GET_SNUM_HTMLPART.AJAX.CGI';
    bAsync = (typeof bAsync === 'boolean') ? bAsync : true;

    // --- 0)両選択肢が同じ路線だった場合はget_locinfo()を呼び、終了 -
    e  = document.getElementById('from_snum');
    i  = e.selectedIndex;
    s  = e.options[i].value.replace(/[0-9]+$/,'').toUpperCase();
    e  = document.getElementById('to_snum'  );
    i  = e.selectedIndex;
    s1 = e.options[i].value.replace(/[0-9]+$/,'').toUpperCase();
    if (s.match(/^[A-Z]+/) && (s1 === s)) {
      document.getElementById('reload_btn').disabled = false;
      e = document.getElementById('autoupdate_request');
      b = (e) ? e.checked : false;
      get_locinfo(b);
      return;
    }

    // --- 1)更新ボタンとselectボックスを無効化する ------------------
    document.getElementById('reload_btn').disabled = true;
    document.getElementById('from_snum' ).disabled = true;
    document.getElementById('to_snum'   ).disabled = true;

    // --- 2)選択された「知りたい駅」の路線文字を取得 ----------------
    e = document.getElementById('from_snum');
    s = e.options[e.selectedIndex].value.replace(/[0-9]+$/,'');
    if (! s.match(/^[A-Za-z]$/)) {
      e = document.getElementById('to_snum'); // 有効な路線文字でなかったら
      e.selectedIndex = 0;                    // 「行きたい駅」を初期化して
      document.getElementById('from_snum' ).disabled = true;    // 終了する
      return;
    }

    // --- 3)アボートタイマーをセット --------------------------------
    if ((bAsync) && (! gtTimeoutID_set9tosnum)) {
      gtTimeoutID_set9tosnum = window.setTimeout(function(){xhr.abort()}, 30000);
    }

    // --- 4)Ajaxコール ----------------------------------------------
    xhr = createXMLHttpRequest();
    if (! xhr) {return;}
    s  = 'rwletter='+s;
    s += '&dummy='+parseInt((new Date)/1);               //キャッシュ対策
    xhr.open('GET', sUrl_ajax + '?' + s, bAsync);
    xhr.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded; charset=UTF-8');
    if (bAsync) {xhr.onreadystatechange = function(){set_snum_to_tosnum_callback(xhr)};}
    xhr.send(s);
    if (! bAsync) {set_snum_to_tosnum_callback(xhr);}

    // --- 99)コール側関数の終了 -------------------------------------
    return;
  }
  function set_snum_to_tosnum_callback(xhr) {
    var e, i, j, ls;
    var bAbort = true;   // Ajax未完了で関数を抜ける場合はtrue

    // --- 0)breakdown区間設定(8まで) --------------------------------
    while (true) {

    // --- 5)アクセス成功で呼び出されたのでないなら即終了 ------------
    if (xhr.readyState != 4) {return;}

    // --- 6)Ajax受信完了処理 ----------------------------------------
    if (gtTimeoutID_set9tosnum) {
      window.clearTimeout(gtTimeoutID_set9tosnum); // アボートタイマー解除
      gtTimeoutID_set9tosnum = null;
    }
    bAbort = false;
    if (xhr.status ===   0) { // ステータスが0の場合はabortでありブラウザー側の自主的な中断である
      alert('通信に失敗したため、行きたい駅候補読み込みを中断しました。知りたい駅を再度選択し直してください。');
      break;
    }
    if (xhr.status !== 200) {
      alert('申し訳ありません、サーバーがエラーを返しました。(' + xhr.status + ')');
      break;
    }

    // --- 7)サーバーから返された部分HTMLを流し込む ------------------
    e = document.getElementById('to_snum');
    if (! e) {
      alert('HTMLが正しくないため、知りたい駅候補を受信できませんでした。');
      break;
    }
    //e.innerHTML = xhr.responseText;
    e.innerHTML = '';
    ls = xhr.responseText.replace(/\r\n|\r/g,"\n").split('\n');
    j  = 0;
    for (i=0; i<ls.length; i++) {
      if (ls[i].match(/<option\s+value="([^"]+)">([^<>]+)<\/option>/)) { //"
        e.options[j] = new Option(RegExp.$2, RegExp.$1);
        j++;
      }
    }

    // --- 8)Ajax未完の場合はここで関数中断 --------------------------
    break;}
    if (bAbort) {return;}

    // --- 8)通信に成功していれば知りたい駅selectボックスを元に戻す --
    if (xhr.status !== 200) {
      // 失敗していた場合は、知りたい駅の選択肢を0番に戻す
      e = document.getElementById('from_snum');
      if (e) {e.selectedIndex = 0;}
    } else {
      e = document.getElementById('from_snum');
      if (e) {
        e.disabled = false;
        e = document.getElementById('to_snum');
        if (e) {e.disabled = false;}
      }
    }

    // --- 99)コールバック側関数の終了 -------------------------------
    return;
  }


  // ===== 接近情報を表示する ========================================
  //
  // [入力]
  // ・引数
  //   bAutoUpdate_req: 自動更新チェックボックスの更新内容
  // ・クラス,ID
  //   #from_snum : 知りたい駅ナンバーを取得するselectボックス
  //   #to_snum   : 行きたい方面駅ナンバーを取得するselectボックス
  //
  function get_locinfo(bAutoUpdate_req) {
    var e, s, sFrom_snum, sTo_snum, xhr;
    var sUrl_ajax = '../CGI/GET_LOCINFO.AJAX.CGI';
    var bAbort    = true;   // Ajaxコールせずに終了の場合はtrue

    // --- 0)多重起動防止 --------------------------------------------
    if (gbDoing_get_locinfo) {return;}
    gbDoing_get_locinfo = true;
    while (true) {

    // --- 1)選択された「知りたい駅」の駅ナンバー取得 ----------------
    e = document.getElementById('from_snum');
    s = e.options[e.selectedIndex].value;
    if (! s.match(/^[A-Za-z][0-9][0-9]$/)) {
      document.getElementById('reload_btn').disabled = true;
      break;
    }
    sFrom_snum = s;

    // --- 2)選択された「行きたい方面」の駅ナンバーを取得 ------------
    e = document.getElementById('to_snum');
    s = e.options[e.selectedIndex].value;
    if (! s.match(/^[A-Za-z][0-9][0-9]$/)) {
      document.getElementById('reload_btn').disabled = true;
      break;
    }
    sTo_snum = s;

    // --- 3)更新ボタンとselectボックスを無効化する ------------------
    document.getElementById('reload_btn').disabled = true;
    document.getElementById('reload_btn').value    = '更新中';
    document.getElementById('from_snum' ).disabled = true;
    document.getElementById('to_snum'   ).disabled = true;

    // --- 4)アボートタイマーをセット --------------------------------
    if (! gtTimeoutID_get_locinfo) {
      gtTimeoutID_get_locinfo = window.setTimeout(function(){xhr.abort()}, 30000);
    }

    // --- 5)Ajaxコール ----------------------------------------------
    xhr = createXMLHttpRequest();
    if (! xhr) {break;}
    s  = 'from_snum='+sFrom_snum+'&to_snum='+sTo_snum;
    s += '&dummy='+parseInt((new Date)/1);               //キャッシュ対策
    xhr.open('GET', sUrl_ajax + '?' + s, true);
    xhr.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded; charset=UTF-8');
    xhr.onreadystatechange = function(){get_locinfo_callback(xhr, bAutoUpdate_req)};
    xhr.send(null);
    bAbort = false;

    // --- 99)コール側関数の終了 -------------------------------------
    break;}
    if (bAbort) {gbDoing_get_locinfo = false;}
    return;
  }
  function get_locinfo_callback(xhr, bAutoUpdate_req) {
    var e, i, ls;
    var bAbort       = true;    // Ajax未完了で関数を抜ける場合はtrue
    var iPubUnixtime = null;    // 応答HTMLから解析したPubUnixtime値を格納する
    var iAccUnixtime = null;    // 応答HTMLから解析したAccUnixtime値を格納する
    var iValUnixtime = null;    // 応答HTMLから解析したValUnixtime値を格納する
    var bDivIdResult = false;   // <div id="result">結果タグが返されたならtrue
    var bApplyResult = false;   // 結果を結果HTML領域にハメ込むべきかを決める
    var bErrormsg    = false;   // サーバーから表示すべきエラーメッセージを受信したらtrue

    // --- 0)breakdown区間設定(9まで) --------------------------------
    while (true) {

    // --- 6)アクセス成功で呼び出されたのでないなら即終了 ------------
    if (xhr.readyState !=   4) {break;}

    // --- 7)Ajax受信完了処理 ----------------------------------------
    if (gtTimeoutID_get_locinfo) {
      window.clearTimeout(gtTimeoutID_get_locinfo); // アボートタイマー解除
      gtTimeoutID_get_locinfo = null;
    }
    bAbort = false;
    if (xhr.status ===   0) { // ステータスが0の場合はabortでありブラウザー側の自主的な中断である
      alert('通信に失敗したため、在線情報取得を中断しました。');
      break;
    }
    if (xhr.status !== 200) {
      alert('申し訳ありません、サーバーがエラーを返しました。(' + xhr.status + ')');
      break;
    }

    // --- 8)サーバーから返された部分HTMLをハメ込むべきか判定する ----
    // 発表日時、取得日時、有効期限日時を抽出する
    ls = xhr.responseText.replace(/\r\n|\r/g,"\n").split('\n');
    for (i=0; i<ls.length; i++) {
      if (ls[i].match(/<div.* id="result"/)) {bDivIdResult = true;}
      if (       ls[i].match(/ id="pub_unixtime".* value="([0-9]+)"/)) {
        iPubUnixtime = RegExp.$1 * 1;
      } else if (ls[i].match(/ id="acc_unixtime".* value="([0-9]+)"/)) {
        iAccUnixtime = RegExp.$1 * 1;
      } else if (ls[i].match(/ id="val_unixtime".* value="([0-9]+)"/)) {
        iValUnixtime = RegExp.$1 * 1;
      }
      if ((iPubUnixtime !== null) && (iAccUnixtime !== null) && (iValUnixtime !== null)) {
        if ((iAccUnixtime<iValUnixtime) || (iValUnixtime===iPubUnixtime) || (! document.getElementById('upd_interval'))) {
          // 正常系(有効期限内)、そうでなくてもまだresult領域の中身がない、
          // または業務時間外の場合は、ハメ込むべきと判定する。
          bApplyResult = true;
        }
        break;
      }
    }
    if ((iPubUnixtime === null) && (iAccUnixtime === null) && (iValUnixtime === null) && (bDivIdResult)) {
      // 時刻が全く無いが、result領域が返された場合、
      // エラーメッセージがあるので、やはりハメ込むべきと判定する。
      bErrormsg    = true;
      bApplyResult = true;
    }

    // --- 9)サーバーから返された部分HTMLを必要に応じてハメ込む ------
    e = document.getElementById('result');
    if        (! bApplyResult) {
      break;
    } else if (! e           ) {
      alert('HTMLが正しくないため、情報を受信できませんでした。');
      break;
    }
    e.innerHTML = xhr.responseText;

    // --- 10)Ajax未完の場合はここで関数中断 -------------------------
    break;}
    if (bAbort) {return;}

    // --- 10)「自動更新」チェックボックスに前回のチェック値を反映 ---
    e = document.getElementById('autoupdate_request');
    if ((xhr.status !== 200) && (e)) {
      e.checked = false;
    } else if ((typeof bAutoUpdate_req === 'boolean') && (e)) {
      e.checked = bAutoUpdate_req;
    }

    // --- 11)遠くの駅の表示・非表示を継承する -----------------------
    toggle_FurtherStations_disp(gbFarStns_disable);

    // --- 12)毎秒呼び出す関数の設定 ---------------------------------
    if (bApplyResult) {
      gdtAccTime_by_localclock = new Date(); // local時計による情報取得日時を記憶
    }
    if        ((! gtInvervalID_everysecond_func) && (! bErrormsg)) {
      gtInvervalID_everysecond_func = window.setInterval(everysecond_func, 1000);
    } else if ((  gtInvervalID_everysecond_func) && (  bErrormsg)) {
      window.clearInterval(gtInvervalID_everysecond_func);
      gtInvervalID_everysecond_func = null;
    }

    // --- 13)更新ボタンとselectボックスを元に戻す -------------------
    while (true) {
      e = document.getElementById('from_snum' );
      if (! e                 ) {break;}
      if (e.options.length < 2) {break;}
      e.disabled = false;
      e = document.getElementById('to_snum'   );
      if (! e                 ) {break;}
      if (e.options.length < 2) {break;}
      e.disabled = false;
      e = document.getElementById('autoupdate_request');
      if (e) {
        // 自動更新モードになっていて、かつ今回ハメ込みをしていなかったら
        // 更新ボタンは元に戻さない
        if ((e.checked === true) && (! bApplyResult)) {break;}
      }
      e = document.getElementById('reload_btn');
      if (! e                 ) {break;}
      e.disabled = false;
      e.value    = '更新';
      break;
    }

    // --- 99)コールバック側関数の終了 -------------------------------
    gbDoing_get_locinfo = false;
    return;
  }



  ////////////////////////////////////////////////////////////////////
  // 表示関連
  ////////////////////////////////////////////////////////////////////

  // ===== 離れている駅の表示・非表示を切り替える ====================
  //
  // [入力]
  // ・引数
  //   [bSwitch_to_disable] ……現在の状態に関わらず、
  //                            非表示状態にしたければtrue
  //                            表示状態にしたければfalse
  //                            (省略時は反転する)
  // ・次のグローバル変数を見る(なければ生成)
  //   gbFarStns_disable…………離れている駅が非表示になっている時はtrue
  // [出力]
  // ・次のグローバル変数を変更する
  //   gbFarStns_disable…………離れている駅を非表示にした時はtrue、逆はfalse
  //
  function toggle_FurtherStations_disp(bSwitch_to_disable) {
    var e, i, le;
    var leFurtherStn;
    
    // --- 引数が省略されている場合は、グローバル変数から取ってくる --
    if (typeof bSwitch_to_disable === 'undefined') {
      bSwitch_to_disable = (! gbFarStns_disable);
    }

    // --- 更新対象のエレメントを全て取得する ------------------------
    leFurtherStn = document_getElementsByClassName('further');

    // --- 表示・非表示を更新する ------------------------------------
    if (bSwitch_to_disable) {
      for (i=0; i<leFurtherStn.length; i++) {
        e = leFurtherStn[i];
        e.style.display = 'none';
      }
      gbFarStns_disable = true;
    } else {
      for (i=0; i<leFurtherStn.length; i++) {
        e = leFurtherStn[i];
        e.style.display = 'block';
      }
      gbFarStns_disable = false;
    }

    // --- 静的URLを発行・設定する -----------------------------------
    set_static_url();

    // --- 完了 ------------------------------------------------------
    return;
  }


  // ===== 毎秒呼び出される関数 ======================================
  //
  // [入力]
  // ・次のグローバル変数が必要
  //   gbDoing_everysecond_func …別プロセスが本関数を実行中か否か
  //   dtAccTime_by_localclock……問い合わせ日時(ブラウザー時計のDate型変数)
  // ・次のタグIDが必要
  //   #pub_unixtime…………………情報発表日時(サーバーのUNIX時間)
  //   #acc_unixtime…………………問い合わせ日時(サーバーのUNIX時間)
  //   #val_unixtime…………………情報有効期限日時(サーバーのUNIX時間)
  //   #autoupdate_request…………自動更新モードのチェックボックス
  //   #second…………………………情報発表日時からの経過時間表示欄
  //   #upd_interval…………………自動更新間隔秒数(サービス時間外に用いる)
  // [出力]
  // ・有効期限日時が切れていて、かつ自動更新モードなら更新関数を呼ぶ
  // ・そうでなければ#freshnessに情報発表日時からの経過時間を書き込む
  //
  function everysecond_func() {

    var b, dt, e, i, s;
    var iAccUnixtime_local, iPubUnixtime, iAccUnixtime, iValUnixtime;
    var iUpdate_interval, iNowUnixtime;
    var sFreshness;

    // --- 0)本関数が現在実行中でなければbreakdown区間を開始 ---------
    if (gbDoing_everysecond_func) {return;}
    gbDoing_everysecond_func = true;
    while (true) {

    // --- 1)ブラウザーの情報取得日時が空ならば何もせず終了 ----------
    if (typeof gdtAccTime_by_localclock !== 'object') {break;}
    iAccUnixtime_local = Math.round(gdtAccTime_by_localclock.getTime()/1000);

    // --- 2)HTMLからサーバーが返した各種日時を取得 ------------------
    e = document.getElementById('pub_unixtime');
    if (! e                        ) {break;}
    if (! e.value.match(/^[0-9]+$/)) {break;}
    iPubUnixtime = e.value;
    e = document.getElementById('acc_unixtime');
    if (! e                        ) {break;}
    if (! e.value.match(/^[0-9]+$/)) {break;}
    iAccUnixtime = e.value;
    e = document.getElementById('val_unixtime');
    if (! e                        ) {break;}
    if (! e.value.match(/^[0-9]+$/)) {break;}
    iValUnixtime = e.value;
    e = document.getElementById('upd_interval');
    if (! e                        ) {break;}
    if (! e.value.match(/^[0-9]+$/)) {break;}
    iUpdate_interval = e.value;

    // --- 3)ブラウザー時計を見て、サーバーベースの現在日時を求める --
    i = iAccUnixtime - iAccUnixtime_local;
    //
    dt = new Date();
    iNowUnixtime = Math.round(dt.getTime()/1000) + i;

    // --- 4)自動更新モードなら諸条件を見て、更新関数を呼ぶ ----------
    b = false;
    e = document.getElementById('autoupdate_request');
    if (e) {b = e.checked;}
    if (b) {
      if (iPubUnixtime != iValUnixtime) {
        if (               iNowUnixtime >= iValUnixtime    ) {
          // (条件a)サービス時間内で、有効期限を過ぎている
          get_locinfo(b);
        }
      } else {
        if ((iNowUnixtime-iAccUnixtime) >= iUpdate_interval) {
          // (条件b)サービス時間外で、前回呼出時から更新間隔以上経過している
          get_locinfo(b);
        }
      }
    }

    // --- 5)情報発表日時からの経過時間を求める ----------------------
    i = iNowUnixtime - iPubUnixtime;
    if        (i <    90) {
      sFreshness = '約' + i + '秒';
    } else if (i <  3600) {
      sFreshness = '約' + Math.floor(i/60) + '分' + i%60 + '秒';
    } else {
      sFreshness = '1時間以上';
    }

    // --- 6)計算した経過時間をHTMLに書き込む ------------------------
    e = document.getElementById('second');
    if (! e) {break;}
    e.innerHTML = sFreshness;

    // --- 99)終了 ---------------------------------------------------
    break;}
    gbDoing_everysecond_func = false;
    return;
  }


  // ===== 静的リンクを生成し、指定タグに反映 ========================
  //
  // [入力]
  // ・以下のコントロール(一部グローバル変数)の値
  //   #from_snum…………………「知りたい駅」で選択されている値をとる。
  //   #to_snum……………………「行きたい方面」で選択されている値をとる。
  //   #autoupdate_request ……自動更新要求の状態をとる。
  //   gbFarStns_disable ………遠くの駅の表示状態をとる。
  // [出力]
  // ・"static_url"クラスが設定されているエレメントに静的URL文字列を設定する
  // [備考]
  // ・少なくとも知りたい駅と、
  //   行きたい駅が設定されていなければ静的URLは設定されない。
  //
  function set_static_url() {
    var e, i, le;
    var sFrom_snum       = '';
    var sTo_snum         = '';
    var bAuto_update_req = false;

    // --- 11)「知りたい駅」を取得する -------------------------------
    e = document.getElementById('from_snum');
    if (! e    ) {return;}
    i = e.selectedIndex;
    if (i === 0) {return;}
    sFrom_snum = e.options[i].value;

    // --- 12)「行きたい方面」を取得する -----------------------------
    e = document.getElementById('to_snum');
    if (! e    ) {return;}
    i = e.selectedIndex;
    if (i === 0) {return;}
    sTo_snum = e.options[i].value;

    // --- 13)自動更新要求の状態を取得する ---------------------------
    e = document.getElementById('autoupdate_request');
    if (e) {
      bAuto_update_req = e.checked;
    }

    // --- 21)静的URLを生成する --------------------------------------
    gsURL_of_this  = location.href.replace(/\?.*$/,'');
    gsURL_of_this += '?from=' + sFrom_snum;
    gsURL_of_this += '&to='   + sTo_snum;
    if (bAuto_update_req   ) {gsURL_of_this += '&autoupd=1';}
    if (! gbFarStns_disable) {gsURL_of_this += '&dispall=1';}

    // --- 31)静的URLを設定する --------------------------------------
    le = document_getElementsByClassName('static_url');
    for (i=0; i<le.length; i++) {
      e = le[i];
      if        (e.tagName === 'A'    ) {e.href      = gsURL_of_this;
      } else if (e.tagName === 'INPUT') {e.value     = gsURL_of_this;
      } else                            {e.innerHTML = gsURL_of_this;}
    }
  }


  // ===== ブックマーク追加 ==========================================
  //
  // [入力]
  // ・以下のコントロール(一部グローバル変数)の値
  //   #from_snum…………………「知りたい駅」で選択されている値をとる。
  //   #to_snum……………………「行きたい方面」で選択されている値をとる。
  //   #autoupdate_request ……自動更新要求の状態をとる。
  //   gbFarStns_disable ………遠くの駅の表示状態をとる。
  // [出力]
  // ・"static_url"クラスが設定されているエレメントに静的URL文字列を設定する
  // [備考]
  // ・少なくとも知りたい駅と、
  //   行きたい駅が設定されていなければ静的URLは設定されない。
  //
  function add_to_bookmark() {
    var e;
    var sTitle = 'メトロパイパー';

    // --- タイトル文字列を生成する ----------------------------------
    e = document.getElementById('tile_station');
    if (e) {
      sTitle += ' - ';
      sTitle += document.getElementById('tile_station').innerHTML.replace(/<[^>]+>/g,'').replace(/\n/g,'').replace(/^\s*/,'').replace(/\s*$/,'');
    }

    // --- ブックマークを促すボタンを作る ----------------------------
    if        (document.all                           ) {   // IE
      window.external.AddFavorite(gsURL_of_this, sTitle);
    } else if (window.sidebar&&window.sidebar.addPanel) {   // Firefox
      window.sidebar.addPanel(sTitle, gsURL_of_this,'');
    } else if (window.opera                           ) {   // Opera
      e = document.getElementById('add_bookmark_btn');
      if (e) {
        e.setAttribute('href' , gsURL_of_this);
        e.setAttribute('rel'  , 'sidebar'    );
        e.setAttribute('title', sTitle       );
        e.click();
      }
    } else {
      alert('Google Chrome/Safariをお使いの方は、CtrlキーとDキーを同時に押してください。');
    }
  }
