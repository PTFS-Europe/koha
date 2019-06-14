/* global borrowernumber advsearch dateformat _ CAN_user_borrowers_edit_borrowers number_of_adult_categories destination Sticky MSG_DATE_FORMAT_US MSG_DATE_FORMAT_ISO MSG_DATE_FORMAT_METRIC MSG_DATE_FORMAT_DMYDOT MSG_CONFIRM_UPDATE_CHILD MSG_CONFIRM_RENEW_PATRON */

$(document).ready(function(){
    $("#filteraction_off, #filteraction_on").on('click', function(e) {
        e.preventDefault();
        $('#filters').toggle();
        $('.filteraction').toggle();
    });
    if( advsearch ){
        $("#filteraction_on").toggle();
        $("#filters").show();
    } else {
        $("#filteraction_off").toggle();
    }
    $("#searchfieldstype").change(function() {
        var MSG_DATE_FORMAT = "";
        if ( $(this).val() == 'dateofbirth' ) {
            if( dateformat == 'us' ){
                MSG_DATE_FORMAT = MSG_DATE_FORMAT_US;
            } else if( dateformat == 'iso' ){
                MSG_DATE_FORMAT = MSG_DATE_FORMAT_ISO;
            } else if( dateformat == 'metric' ){
                MSG_DATE_FORMAT = MSG_DATE_FORMAT_METRIC;
            } else if( dateformat == 'dmydot' ){
                MSG_DATE_FORMAT = MSG_DATE_FORMAT_DMYDOT;
            }
            $('#searchmember').attr("title", MSG_DATE_FORMAT).tooltip('show');
        } else {
            $('#searchmember').tooltip('destroy');
        }
    });

    if( CAN_user_borrowers_edit_borrowers ){
        $("#deletepatron").click(function(){
            window.location='/cgi-bin/koha/members/deletemem.pl?member=' + borrowernumber;
        });
        $("#renewpatron").click(function(){
            confirm_reregistration();
            $(".btn-group").removeClass("open");
            return false;
        });
        $("#updatechild").click(function(e){
            if( $(this).data("toggle") == "tooltip"){ // Disabled menu option has tooltip attribute
                e.preventDefault();
            } else {
                update_child();
                $(".btn-group").removeClass("open");
            }
        });
    }

    $("#updatechild, #patronflags, #renewpatron, #deletepatron, #exportbarcodes").tooltip();
    $("#exportcheckins").click(function(){
        export_barcodes();
        $(".btn-group").removeClass("open");
        return false;
    });
    $("#printsummary").click(function(){
        printx_window("page");
        $(".btn-group").removeClass("open");
        return false;
    });
    $("#printslip").click(function(){
        printx_window("slip");
        $(".btn-group").removeClass("open");
        return false;
    });
    $("#printquickslip").click(function(){
        printx_window("qslip");
        $(".btn-group").removeClass("open");
        return false;
    });
    $("#print_overdues").click(function(){
        window.open("/cgi-bin/koha/members/print_overdues.pl?borrowernumber=" + borrowernumber, "printwindow");
        $(".btn-group").removeClass("open");
        return false;
    });
    $("#searchtohold").click(function(){
        searchToHold();
        return false;
    });
    $("#select_patron_messages").on("change",function(){
        $("#borrower_message").val( $(this).val() );
    });
});

function confirm_updatechild() {
    var is_confirmed = window.confirm( MSG_CONFIRM_UPDATE_CHILD );
    if (is_confirmed) {
        window.location='/cgi-bin/koha/members/update-child.pl?op=update&borrowernumber=' + borrowernumber;
    }
}

function update_child() {
    if( number_of_adult_categories > 1 ){
        window.open('/cgi-bin/koha/members/update-child.pl?op=multi&borrowernumber=' + borrowernumber,'UpdateChild','width=400,height=300,toolbar=no,scrollbars=yes,resizable=yes');
    } else {
        confirm_updatechild();
    }
}

function confirm_reregistration() {
    var is_confirmed = window.confirm( MSG_CONFIRM_RENEW_PATRON );
    if (is_confirmed) {
        window.location = '/cgi-bin/koha/members/setstatus.pl?borrowernumber=' + borrowernumber + '&amp;destination=' + destination + '&amp;reregistration=y';
    }
}
function export_barcodes() {
    window.open('/cgi-bin/koha/members/readingrec.pl?borrowernumber=' + borrowernumber + '&amp;op=export_barcodes');
}
var slip_re = /slip/;
function printx_window(print_type) {
    var handler = print_type.match(slip_re) ? "printslip" : "summary-print";
    window.open("/cgi-bin/koha/members/" + handler + ".pl?borrowernumber=" + borrowernumber + "&amp;print=" + print_type, "printwindow");
    return false;
}
function searchToHold(){
    var date = new Date();
    date.setTime(date.getTime() + (10 * 60 * 1000));
    $.cookie("holdfor", borrowernumber, { path: "/", expires: date });
    location.href="/cgi-bin/koha/catalogue/search.pl";
}
