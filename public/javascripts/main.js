function setRefresh() {
    window.setTimeout("ajaxRefresh(true);",7000);
    window.setTimeout("fakeTimerCountdown();",1000);
    updateStatus();
}

function ajaxRefresh(repeat) {
    $.getJSON('info.json', function(data) {
        $('#station-link').html(data.station_link);
        $('#artist-link').html(data.artist_link);
        $('#title-link').html(data.title_link);
        $('#album-link').html(data.album_link);
        $('#album-image').html(data.album_image);
        $("#volumeslider").slider("value", parseInt(data.volume));
        remain_s = data.remain_s;
        total_s = data.total_s;
        updateRemainingtime(remain_s, total_s);

        status = data.status;
        updateStatus();

        // update browser title.
        $('title').html(data.artist + " - " + data.title + " - shell.fm");
    });
    // Reset the timer to repeat.
    if (repeat==true) {
        window.setTimeout("ajaxRefresh(true);",7000);
    }
}

function ajaxCommand(cmd) {
    // set icon to spinner
    $("#"+cmd).attr("src", "/images/ui-anim_basic_16x16.gif");
    $.get('/cmd/'+cmd,{},function(response){
        $('#'+cmd).attr('src', '/images/'+cmd+'.png'); // set icon back to normal
        setTimeout("ajaxRefresh(false);", 2000); // refresh after delay
        flash_message(response);
    })
}

function ajaxPlay(station, prefix) {
    $("#playspinner").show();
    var url = prefix+station;
    $.get('/cmd/play?station='+url,{},function(response){
        $("#playspinner").hide();
        setTimeout("ajaxRefresh(false);", 2000); // refresh after delay
        flash_message(response);
    })
}

function pad2(number) {
    return (number < 10 ? '0' : '') + number;
}

function updateRemainingtime(s, t) {
    $("#progresstime").progressbar("value", (t - s) / t * 100);
    var sMins = parseInt(s / 60);
    var sSecs = parseInt(s % 60);
    var tMins = parseInt(t / 60);
    var tSecs = parseInt(t % 60);
    document.getElementById("remainlabel").innerHTML = pad2(sMins) + ":" + pad2(sSecs);
    document.getElementById("totallabel").innerHTML = pad2(tMins) + ":" + pad2(tSecs);
}

function updateStatus() {
    if (status == "paused" || status == "stopped") {
        $("#message-shadow #message").html(status);
        $("#message-shadow").show();
    } else {
        $("#message-shadow").hide();
    }
}


function fakeTimerCountdown() {
    if (remain_s > 0 && status == "playing") {
        remain_s -= 1;
        updateRemainingtime(remain_s, total_s);
    }
    // we must keep the repeating timer rolling, even if time == 0
    window.setTimeout("fakeTimerCountdown()",1000);
}

function volumeChange(vol) {
    $("#volspinner").show();
    $.get('/cmd/volume?vol='+vol,{},function(response){
        $("#volspinner").hide();
        flash_message(response);
    })
    return false;
}

function flash_message(msg) {
    // fade in the flash message, for 5 seconds
    $('.flash').html(msg);
    $('.flash').slideDown();
    setTimeout("$('.flash').slideUp();", 5000);
    return false;
}

