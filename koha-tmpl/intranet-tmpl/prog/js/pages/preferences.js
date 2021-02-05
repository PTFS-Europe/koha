/* global KOHA CodeMirror to_highlight search_jumped humanMsg dataTablesDefaults themelang */
// We can assume 'KOHA' exists, as we depend on KOHA.AJAX

KOHA.Preferences = {
    Save: function ( form ) {
        if ( ! $(form).valid() ) {
            humanMsg.displayAlert( __("Error: presence of invalid data prevent saving. Please make the corrections and try again.") );
            return;
        }

        modified_prefs = $( form ).find( '.modified' );
        // $.serialize removes empty value, we need to keep them.
        // If a multiple select has all its entries unselected
        var unserialized = new Array();
        $(modified_prefs).each(function(){
            if ( $(this).attr('multiple') && $(this).val() == null ) {
                unserialized.push($(this));
            }
        });
        data = modified_prefs.serialize();
        $(unserialized).each(function(){
            data += '&' + $(this).attr('name') + '=';
        });
        if ( !data ) {
            humanMsg.displayAlert( __("Nothing to save") );
            return;
        }
        KOHA.AJAX.MarkRunning($(form).find('.save-all'), __("Saving...") );
        KOHA.AJAX.Submit( {
            data: data,
            url: '/cgi-bin/koha/svc/config/systempreferences/',
            success: function ( data ) { KOHA.Preferences.Success( form ) },
            complete: function () { KOHA.AJAX.MarkDone( $( form ).find( '.save-all' ) ) }
        } );
    },
    Success: function ( form ) {
        var msg = "";
        modified_prefs.each(function(){
            var modified_pref = $(this).attr("id");
            modified_pref = modified_pref.replace("pref_","");
            msg += "<strong>" + __("Saved preference %s").format(modified_pref) + "</strong>\n";
        });
        humanMsg.displayAlert(msg);

        $( form )
            .find( '.modified-warning' ).remove().end()
            .find( '.modified' ).removeClass('modified');
        KOHA.Preferences.Modified = false;
    }
};

function mark_modified() {
    $( this.form ).find( '.save-all' ).prop('disabled', false);
    $( this ).addClass( 'modified' );
    var name_cell = $( this ).parents( '.name-row' ).find( '.name-cell' );
    if ( !name_cell.find( '.modified-warning' ).length )
        name_cell.append('<em class="modified-warning">(' + __("modified") + ')</em>');
    KOHA.Preferences.Modified = true;
}

window.onbeforeunload = function () {
    if ( KOHA.Preferences.Modified ) {
        return __("You have made changes to system preferences.");
    }
};

// Add event handlers to any elements with .expand-textarea classes
// this allows the CodeMirror widget to be displayed
function addExpandHandler() {
    // Don't duplicate click event handlers
    const ev = $._data($('.expand-textarea'), 'events');
    if (ev && ev.click) {
        return;
    }
    $(".expand-textarea").on("click", function (e) {
        e.preventDefault();
        $(this).hide();
        var target = $(this).data("target");
        var syntax = $(this).data("syntax");
        $("#collapse_" + target).show();
        if (syntax) {
            var editor = CodeMirror.fromTextArea(document.getElementById("pref_" + target), {
                lineNumbers: true,
                mode: syntax,
                lineWrapping: true,
                viewportMargin: Infinity,
                gutters: ["CodeMirror-lint-markers"],
                lint: true
            });
            editor.on("change", function () {
                mark_modified.call($("#pref_" + target)[0]);
            });
            editor.on("blur", function () {
                editor.save();
            });
        } else {
            $("#pref_" + target).show();
        }
    });
}

// Add event handlers to any elements with .collapse-textarea classes
// this allows the hiding of the CodeMirror widget
function addCollapseHandler() {
    // Don't duplicate click event handlers
    const ev = $._data($('.collapse-textarea'), 'events');
    if (ev && ev.click) {
        return;
    }
    $(".collapse-textarea").on("click", function (e) {
        e.preventDefault();
        $(this).hide();
        var target = $(this).data("target");
        var syntax = $(this).data("syntax");
        $("#expand_" + target).show();
        if (syntax) {
            var editor = $("#pref_" + target).next(".CodeMirror")[0].CodeMirror;
            editor.toTextArea();
        }
        $("#pref_" + target).hide();
    });
}

// Add a handler for any consent delete links
function addConsentDeleteHandler() {
    // Don't duplicate click event handlers
    const ev = $._data($('.consentDelete'), 'events');
    if (ev && ev.click) {
        return;
    }
    $('.consentDelete').on('click', function (e) {
        e.preventDefault();
        const target = $(this).data('target');
        const proceed = confirm(__('Are you sure you want to delete this consent item?'));
        if (proceed) {
            $('#' + target).remove();
        }
    });
}

$( document ).ready( function () {

    $("table.preferences").dataTable($.extend(true, {}, dataTablesDefaults, {
        "sDom": 't',
        "aoColumnDefs": [
            { "aTargets": [ -1 ], "bSortable": false, "bSearchable": false }
        ],
        "bPaginate": false
    }));

    $( '.prefs-tab' )
        .find( 'input.preference, textarea.preference' ).on('input', function () {
            if ( this.defaultValue === undefined || this.value != this.defaultValue ) mark_modified.call( this );
        } ).end()
        .find( 'select.preference' ).change( mark_modified );
    $('.preference-checkbox').change( function () {
        $('.preference-checkbox').addClass('modified');
        mark_modified.call(this);
    } );

    $(".set_syspref").click(function() {
        var s = $(this).attr('data-syspref');
        var v = $(this).attr('data-value');
        // populate the input with the value in data-value
        $("#pref_"+s).val(v);
        // pass the DOM element to trigger "modified" to enable submit button
        mark_modified.call($("#pref_"+s)[0]);
        return false;
    });

    $(".sortable").sortable();
    $(".sortable").on( "sortchange", function( event, ui ) {
        // This is not exact but we just need to trigger a change
        $(ui.item.find('input:first')).change();
    } );

    $( '.prefs-tab .action .cancel' ).click( function () { KOHA.Preferences.Modified = false } );

    $( '.prefs-tab .save-all' ).prop('disabled', true).click( function () {
        KOHA.Preferences.Save( this.form );
        return false;
    });

    addExpandHandler();

    addCollapseHandler();

    $("h3").attr("class", "expanded").attr("title", __("Click to collapse this section"));
    var collapsible = $(".collapsed,.expanded");

    $(collapsible).on("click",function(){
        var h3Id = $(this).attr("id");
        var panel = $("#collapse_" + h3Id);
        if(panel.is(":visible")){
            $(this).addClass("collapsed").removeClass("expanded").attr("title", __("Click to expand this section") );
            panel.hide();
        } else {
            $(this).addClass("expanded").removeClass("collapsed").attr("title", __("Click to collapse this section") );
            panel.show();
        }
    });

    $(".pref_sublink").on("click", function(){
        /* If the user clicks a sub-menu link in the sidebar,
           check to see if it is collapsed. If so, expand it */
        var href = $(this).attr("href");
        href = href.replace("#","");
        var panel = $("#collapse_" + href );
        if( panel.is(":hidden") ){
            $("#" + href).addClass("expanded").removeClass("collapsed").attr("title", __("Click to collapse this section") );
            panel.show();
        }
    });

    if ( to_highlight ) {
        var words = to_highlight.split( ' ' );
        $( '.prefs-tab table' ).find( 'td, th' ).not( '.name-cell' ).each( function ( i, td ) {
            $.each( words, function ( i, word ) { $( td ).highlight( word ) } );
        } ).find( 'option, textarea' ).removeHighlight();
    }

    if ( search_jumped ) {
        document.location.hash = "jumped";
    }

    $("#pref_UpdateItemLocationOnCheckin").change(function(){
        var the_text = $(this).val();
        var alert_text = '';
        if (the_text.indexOf('_ALL_:') != -1) alert_text = __("Note: _ALL_ value will override all other values") + '\n';
        var split_text  =the_text.split("\n");
        var alert_issues = '';
        var issue_count = 0;
        var reg_check = /.*:\s.*/;
        for (var i=0; i < split_text.length; i++){
            if ( !split_text[i].match(reg_check) && split_text[i].length ) {
                alert_issues+=split_text[i]+"\n";
                issue_count++;
            }
        }
        if (issue_count) alert_text += "\n" + __("The following values are not formatted correctly:") + "\n" + alert_issues;
        if ( alert_text.length )  alert(alert_text);
    });

    $(".prefs-tab form").each(function () {
        $(this).validate({
            rules: { },
            errorPlacement: function(error, element) {
                var placement = $(element).parent();
                if (placement) {
                    $(placement).append(error)
                } else {
                    error.insertAfter(element);
                }
            }
        });
    });

    $(".preference-email").each(function() {
        $(this).rules("add", {
            email: true
        });
    });


    $(".modalselect").on("click", function(){
        var datasource = $(this).data("source");
        var exclusions = $(this).data("exclusions").split('|');
        var pref_name = this.id.replace(/pref_/, '');
        var pref_value = this.value;
        var prefs = pref_value.split("|");

        $.getJSON( themelang + "/modules/admin/preferences/" + datasource + ".json", function( data ){
            var items = [];
            var checked = "";
            var style = "";
            $.each( data, function( key, val ){
                if( prefs.indexOf( val ) >= 0 ){
                    checked = ' checked="checked" ';
                } else {
                    checked = "";
                }
                if( exclusions.indexOf( val ) >= 0 ){
                    style = "disabled";
                    disabled = ' disabled="disabled" ';
                    checked  = "";
                } else {
                    style = "";
                    disabled = "";
                }
                items.push('<label class="' + style +'"><input class="dbcolumn_selection" type="checkbox" id="' + key + '"' + checked + disabled + ' name="pref" value="' + val + '" /> ' + key + '</label>');
            });
            $("<div/>", {
                "class": "columns-2",
                html: items.join("")
            }).appendTo("#prefModalForm");
        });
        $("#saveModalPrefs").data("target", this.id );
        $("#saveModalPrefs").data("type", "modalselect" );
        $("#prefModalLabel").text( pref_name );
        $("#prefModal").modal("show");
    });

    // Initialise the content of our modal, using the function
    // specified in the data-initiator attribute
    $('.modaljs').on('click', function () {
        const init = $(this).data('initiator');
        if (init) {
            window[init](this);
            $("#prefModal").modal("show");
        }
    });

    // Initialise the content of our modal, if we are dealing
    // with a modalselect modal
    function prepareModalSelect(formfieldid) {
        var prefs = [];
        $("#prefModal input[type='checkbox']").each(function(){
            if( $(this).prop("checked") ){
                prefs.push( this.value );
            }
        });
        return prefs.join("|");
    }

    // Return a checkbox with an appropriate checked state
    function checkBox(id, className, state) {
        return state ?
            '<input id="' + id + '" type="checkbox" class="' + className + '" checked>' :
            '<input id="' + id + '" type="checkbox" class="' + className + '">';
    }

    // Create a consentJS item, correctly populated
    function createConsentJSItem(item, idx) {
        const id = 'ConsentJS_' + idx;
        const code = item.code && item.code.length > 0 ? atob(item.code) : '';
        const itemId = item.id && item.id.length > 0 ? item.id : '';
        return '<div id="' + id + '" class="consentJSItem" data-id="' + itemId + '">' +
               '    <div class="consentRow">' +
               '        <div class="consentItem">' +
               '            <label class="required" for="name_' + id + '">' + __('Name') + ':</label>' +
               '            <input id="name_' + id + '" class="metaName" type="text" value="' + item.name + '"><span class="required">' + __('Required') + '</span>' +
               '        </div >' +
               '        <div class="consentItem">' +
               '            <label class="required" for="description_' + id + '">' + __('Description') + ':</label>' +
               '            <input id="description_' + id + '" class="metaDescription" type="text" value="' + item.description + '"><span class="required">' + __('Required') + '</span>' +
               '        </div>' +
               '        <div class="consentItem">' +
               '            <label for="opacConsent_' + id + '">' + __('Requires consent in OPAC') + ':</label>' +
                            checkBox('opacConsent_' + id, 'opacConsent', item.opacConsent) +
               '        </div>' +
               '        <div class="consentItem">' +
               '            <label for="staffConsent_' + id + '">' + __('Requires consent in staff interface') + ':</label>' +
                            checkBox('staffConsent_' + id, 'staffConsent', item.staffConsent) +
               '        </div >' +
               '        <div class="consentItem">' +
               '            <label for="matchPattern_' + id + '">' + __('String used to identify cookie name') + ':</label>' +
               '            <input id="matchPattern_' + id + '" class="metaMatchPattern" type="text" value="' + item.matchPattern + '"><span class="required">' + __('Required') + '</span>' +
               '        </div >' +
               '        <div class="consentItem">' +
               '            <label for="cookieDomain' + id + '">' + __('Cookie domain') + ':</label>' +
               '            <input id="cookieDomain' + id + '" class="metaCookieDomain" type="text" value="' + item.cookieDomain + '"><span class="required">' + __('Required') + '</span>' +
               '        </div >' +
               '        <div class="consentItem">' +
               '            <label for="cookiePath' + id + '">' + __('Cookie path') + ':</label>' +
               '            <input id="cookiePath' + id + '" class="metaCookiePath" type="text" value="' + item.cookiePath + '"><span class="required">' + __('Required') + '</span>' +
               '        </div >' +
               '    </div >' +
               '    <div class="consentRow codeRow">' +
               '        <textarea style="display:none;" id="pref_' + id + '" class="preference preference-code codemirror" rows="10" cols="40">' + code + '</textarea>' +
               '        <div>' +
               '            <a id="expand_' + id + '" class="expand-textarea" data-target="' + id + '" data-syntax="javascript" href="#">' + __('Click to expand') + '</a>' +
               '            <a id="collapse_' + id + '" class="collapse-textarea" data-target="' + id + '" data-syntax="javascript" href="#" style="display:none">' + __('Click to collapse') + '</a>' +
               '        </div >' +
               '    </div>' +
               '    <a class="consentDelete" data-target="' + id + '" href="#">Delete</a>' +
               '</div > ';
    }

    // Return the markup for all consentJS items concatenated
    function populateConsentMarkup(items) {
        return items.reduce(function (acc, current, idx) {
            return acc + createConsentJSItem(current, idx);
        }, '');
    }

    // Return the markup for a validation warning
    function populateValidationWarning() {
        return '<div id="consentJSWarning" class="error" style="display:none;">' + __('You must complete all fields') + '</div>';
    }

    // Return a new, empty consent item
    function emptyConsentItem() {
        return {
            name: '',
            description: '',
            matchPattern: '',
            cookieDomain: '',
            cookiePath: '',
            code: '',
            consentInOpac: false,
            consentInStaff: false
        };
    }

    // Add the handler for a new empty consent item
    function addNewHandler() {
        $("#consentJSAddNew").on("click", function (e) {
            e.preventDefault();
            const currentLen = $('.consentJSItem').length;
            const newItem = emptyConsentItem();
            const markup = createConsentJSItem(newItem, currentLen);
            $('#prefModal .modal-body #consentJSItems').append($(markup));
            addExpandHandler();
            addCollapseHandler();
            addConsentDeleteHandler();
        });
    }

    // Populate the consentJS modal, we also initialise any
    // event handlers that are required. This function is added
    // to the window object so we can call it if we are passed it's name
    // as a data-initiator attribute
    // (e.g.)
    // const f = 'populateConsentJS';
    // window[f]();
    window.populateConsentJS = function(el) {
        let items = [];
        let decoded = '';
        if (el.value && el.value.length > 0) {
            try {
                decoded = atob(el.value);
            } catch (err) {
                throw (__(
                    'Unable to Base64 decode value stored in ConsentJS syspref: ' +
                    err.message
                ));
            }
            try {
                items = JSON.parse(decoded);
            } catch (err) {
                throw (__(
                    'Unable to JSON parse decoded value stored in ConsentJS syspref: ' +
                    err.message
                ));
            }
        }
        const markup = populateConsentMarkup(items);
        const validationWarning = populateValidationWarning();
        const pref_name = el.id.replace(/pref_/, '');
        $('#saveModalPrefs').data('target', el.id);
        $('#prefModalLabel').text( pref_name );
        $('#prefModal .modal-body').html($('<div id="consentJSItems">' + validationWarning + markup + '</div><div><a href="#" id="consentJSAddNew">' + __('Add new code') + '</a></div>'));
        addExpandHandler();
        addCollapseHandler();
        addNewHandler();
        addConsentDeleteHandler();
    }

    // Prepare the data in the UI for sending back as a syspref.
    // We validate that everything is what we expect. This function is added
    // to the window object so we can call it if we are passed it's name
    // as a data-initiator attribute
    // e.g.
    // const f = 'prepareConsentJS';
    // window[f]();
    window.prepareConsentJS = function () {
        const items = $('.consentJSItem');
        const invalid = [];
        const valid = [];
        items.each(function () {
            const id = $(this).data('id').length > 0 ?
                $(this).data('id') :
                '_' + Math.random().toString(36).substr(2, 9);
            const name = $(this).find('.metaName').val();
            const desc = $(this).find('.metaDescription').val();
            const matchPattern = $(this).find('.metaMatchPattern').val();
            const cookieDomain = $(this).find('.metaCookieDomain').val();
            const cookiePath = $(this).find('.metaCookiePath').val();
            const opacConsent = $(this).find('.opacConsent').is(':checked')
            const staffConsent = $(this).find('.staffConsent').is(':checked');
            const code = $(this).find('.preference-code').val();
            // If the name, description, match pattern code are empty, then they've
            // added a new entry, but not filled it in, we can skip it
            if (
                name.length === 0 &&
                desc.length === 0 &&
                matchPattern.length === 0 &&
                cookieDomain.length === 0 &&
                cookiePath.length === 0 &&
                code.length === 0
            ) {
                return;
            }
            // They've filled in at least some info
            if (
                (name.length === 0) ||
                (desc.length === 0) ||
                (matchPattern.length === 0) ||
                (cookiePath.length === 0) ||
                (code.length === 0)
            ) {
                invalid.push(this);
            } else {
                const obj = {
                    id: id,
                    name: name,
                    description: desc,
                    matchPattern: matchPattern,
                    cookieDomain: cookieDomain,
                    cookiePath: cookiePath,
                    opacConsent: opacConsent,
                    staffConsent: staffConsent,
                    code: btoa(code)
                }
                valid.push(obj);
            }
        });
        // We failed validation
        if (invalid.length > 0) {
            $('#consentJSWarning').show();
            return false;
        }
        $('#consentJSWarning').hide();
        if (valid.length === 0) {
            return '';
        }
        const json = JSON.stringify(valid);
        const base64 = btoa(json);
        return base64;
    }

    $("#saveModalPrefs").on("click", function(){
        var formfieldid = $("#" + $(this).data("target"));
        let finalString = "";
        if ($(this).data("type") == "modalselect") {
            finalString = prepareModalSelect(formfieldid);
        } else {
            const processor = $(".modaljs").data("processor");
            finalString = window[processor]();
        }
        // A processor can return false if any of the submitted
        // data has failed validation
        if (finalString !== false) {
            formfieldid.val(finalString).addClass("modified");
            mark_modified.call( formfieldid );
            KOHA.Preferences.Save( formfieldid.closest("form") );
            $("#prefModal").modal("hide");
        }
    });

    $("#prefModal").on("hide.bs.modal", function(){
        $("#prefModalLabel,#prefModalForm").html("");
        $("#saveModalPrefs").data("target", "" );
    });

    $("#select_all").on("click",function(e){
        e.preventDefault();
        $(".dbcolumn_selection:not(:disabled)").prop("checked", true);
    });
    $("#clear_all").on("click",function(e){
        e.preventDefault();
        $(".dbcolumn_selection").prop("checked", false);
    });

} );
