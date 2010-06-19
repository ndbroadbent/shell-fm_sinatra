function setRefresh() {
    window.setTimeout("ajaxRefresh(true);",7000);
    window.setTimeout("fakeTimerCountdown();",1000);
}

function ajaxRefresh(repeat) {
    $("#spinner").show();
    $.getJSON('info.json', function(data) {
        $("#spinner").hide();
        $('#station-link').html(data.station_link);
        $('#artist-link').html(data.artist_link);
        $('#title-link').html(data.title_link);
        $('#album-link').html(data.album_link);
        $('#album-image').html(data.album_image);
        $("#volumeslider").slider("value", parseInt(data.volume));
        remain_s = data.remain_s;
        total_s = data.total_s;
        updateRemainingtime(remain_s, total_s);
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
        // fade in the flash message, for 5 seconds
        $('.flash').html(response);
        $('.flash').slideDown();
        setTimeout("$('.flash').slideUp();", 5000);
    })
}

function ajaxPlay(station, prefix) {
    $("#playspinner").show();
    var url = prefix+station;
    $.get('/cmd/play?station='+url,{},function(response){
        $("#playspinner").hide();
        setTimeout("ajaxRefresh(false);", 2000); // refresh after delay

        // fade in the flash message, for 5 seconds
        $('.flash').html(response);
        $('.flash').slideDown();
        setTimeout("$('.flash').slideUp();", 5000);
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

function fakeTimerCountdown() {
    if (remain_s > 0) {
        remain_s -= 1;
        updateRemainingtime(remain_s, total_s);
    }
    // we must keep the repeating timer rolling, even if time == 0
    window.setTimeout("fakeTimerCountdown()",1000);
}

function volumeChange() { return false;}

