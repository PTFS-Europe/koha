// Functions to be used in the agrovoc interface
function searchTerm() {
    var searchstring = document.getElementById("searchstring").value;
    var searchmode = document.getElementById('searchmode').value;
    var langEN = document.getElementById('lang_english');
    var langFR = document.getElementById('lang_french');
    var langES = document.getElementById('lang_spanish');
    var search_params = 'op=search&searchmode=' + encodeURIComponent(searchmode);
    var search_params = search_params + '&searchstring=' + encodeURIComponent(searchstring);
    if (langEN.checked) {
        search_params = search_params + '&language=' + langEN.value;
    }
    if (langFR.checked) {
        search_params = search_params + '&language=' + langFR.value;
    }
    if (langES.checked) {
        search_params = search_params + '&language=' + langES.value;
    }
    $.getJSON('search.pl',search_params,searchResults);
}

function lookupTerm(termcode, language) {
    var params = 'termcode=' + termcode;
    params = params + '&lang=' + language;

    $.getJSON('term.pl',params,displayTerm);
}

function displayTerm(termObj) {
    // remove any existing elements from termPane
    // rewrite them with the termObj
    var div1    = document.getElementById('termcodeLabel');
    var paras   = div1.getElementsByTagName("p");
    var termTxt =  document.createTextNode(termObj.concept.termcode + ": ");
    var strongTxt = document.createTextNode(termObj.labels);
    var para = document.createElement("p");
    var strongLbl = document.createElement("strong");
    strongLbl.appendChild(strongTxt);
    para.appendChild(termTxt);
    para.appendChild(strongLbl);
    div1.replaceChild(para, paras[0]);

    replaceAltLang( termObj.concept.termcode, termObj.concept.other_lang );

    replaceTList('USElist', termObj.concept.USE);
    replaceTList('NTlist', termObj.concept.NT);
    replaceTList('BTlist', termObj.concept.BT);
    replaceTList('RTlist', termObj.concept.RT);
    replaceTList('UFlist', termObj.concept.UF);
    // If there is a USE then we USE it
    if (termObj.concept.USE.length > 0) {
        addTermSaveButton(termObj.concept.USE[0].termcode, termObj.concept.USE[0].label, termObj.concept.USE[0].language);
    } else {
        addTermSaveButton(termObj.concept.termcode, termObj.labels, termObj.termlang);
    }
}

function addTermSaveButton(termcode, labels, language) {
    /*
     * Add to the div saveButtonBar
     */
    var div = document.getElementById('saveButtonBar');
    var b = document.createElement("button");
    var oldb   = div.getElementsByTagName("button");
    var scriptTxt = "saveTerm('" + termcode + "','";
    scriptTxt += escape(labels) + "','";
    scriptTxt += language + "'); return false;";

    b.className = 'green90x24';
    b.type = 'button'; // to ensure it dosent default to submit
    b.setAttribute('onclick', scriptTxt);
    var txt = document.createTextNode('Select');
    b.appendChild(txt);

    if (oldb[0]) {
        div.replaceChild(b, oldb[0]);
    } else {
        div.appendChild(b);
    }

}

function saveTerm(termcode, labels, termlang) {
    /* Write the term in the save box */
    var list = document.getElementById('savedTerms');
    var newLi = document.createElement("li");
    var txt = document.createTextNode(unescape(labels) + ': ' + termcode + ': (' + termlang + ')');
    newLi.appendChild(txt);
    list.appendChild(newLi);
}

function saveTermLeft(termcode, labels, termlang) {
    // first check for a USE element in this term
    var params = 'termcode=' + termcode + '&lang=' + termlang;
    $.getJSON( 'term.pl',params, saveCorrectTerm);
}

function saveCorrectTerm(resp) {
    var saveConcept;
    if (resp.concept.USE.length > 0) {
        saveConcept = resp.concept.USE[0];
        saveConcept.termlang = saveConcept.language;
    } else {
        saveConcept = resp.concept;
        saveConcept.termlang = resp.termlang;
        saveConcept.label = resp.labels;
    }
    var div = document.getElementById('savedTerms');
    var newPara = document.createElement("li");
    var txt = document.createTextNode(saveConcept.label + ': ' + saveConcept.termcode + ': (' + saveConcept.termlang + ')');
        newPara.appendChild(txt);
        div.appendChild(newPara);
}

function searchResults(results) {
    // arrayref of termcode matchedTerm language
    var div = document.getElementById('resultsList');
    var oldul = div.getElementsByTagName("ul")[0];
    var ul = document.createElement("ul");
    for(var i = 0; i < results.length; i++) {
        var li = document.createElement("li");
        var b        = termlinkButton(results[i].termcode, results[i].language,results[i].matchedTerm);
        li.appendChild(b);
        var s = selectCheckboxLeft(results[i].termcode, results[i].matchedTerm, results[i].language);
        li.appendChild(s);
        ul.appendChild(li);
    }
    div.replaceChild(ul,oldul);
}


function replaceAltLang(termcode, langList)
{   // langname langcode
    var div    = document.getElementById('altlang');

    var oldul = div.getElementsByTagName("ul")[0];
    var ul = document.createElement("ul");
    for(var i = 0; i < langList.length; i++) {
        var li = document.createElement("li");
        var seeIn = document.createTextNode('See in ');
        li.appendChild(seeIn);
        var b = langButton(termcode, langList[i].langcode, langList[i].langname);
        li.appendChild(b);
        ul.appendChild(li);
    }
    div.replaceChild(ul,oldul);
}

function termlinkButton(termcode, language, termtext)
{
    var b = document.createElement("button");
    var scriptTxt = "lookupTerm('" + termcode + "','";
    scriptTxt += language + "'); return false;";
    b.className = 'termlink';
    b.type = 'button'; // to ensure it dosent default to submit
    b.setAttribute('onclick', scriptTxt);
    var txt = document.createTextNode(termtext);
    b.appendChild(txt);
    return b;
}

function langButton(termcode, language, languageLabel)
{
    var b = document.createElement("button");
    var scriptTxt = "lookupTerm('" + termcode + "','";
    scriptTxt += language + "'); return false;";
    b.className = 'termlink';
    b.type = 'button'; // to ensure it dosent default to submit
    b.setAttribute('onclick', scriptTxt);
    var txt = document.createTextNode(languageLabel);
    b.appendChild(txt);
    return b;
}

function replaceTList(listId, termlist)
{
    var div = document.getElementById(listId);
    var oldul = div.getElementsByTagName("ul")[0];
    var ul = document.createElement("ul");
    for(var i = 0; i < termlist.length; i++) {
        var li = document.createElement("li");
        var b        = termlinkButton(termlist[i].termcode, termlist[i].language, termlist[i].label);
        li.appendChild(b);
        var s = selectCheckbox(termlist[i].termcode, termlist[i].label, termlist[i].language);
        li.appendChild(s);
        ul.appendChild(li);
    }
    div.replaceChild(ul,oldul);
}

function selectCheckbox(termcode, label, language)
{
    var b = document.createElement("button");
    var scriptTxt = 'saveTerm(' + termcode + ",'";
    scriptTxt += escape(label) + "','";
    scriptTxt += language + "'); return false;";

    b.type = 'button'; // to ensure it dosent default to submit
    b.className = 'selectlink';
    b.setAttribute('onclick', scriptTxt);
    var txt = document.createTextNode("select");
    b.appendChild(txt);
    return b;
}
// calls special version of saveTerm that will use the preferred term
function selectCheckboxLeft(termcode, label, language)
{
    var b = document.createElement("button");
    var scriptTxt = "saveTermLeft('" + termcode + "','";
    scriptTxt += escape(label) + "','";
    scriptTxt += language + "'); return false;";

    b.type = 'button'; // to ensure it dosent default to submit
    b.className = 'selectlink';
    b.setAttribute('onclick', scriptTxt);
    var txt = document.createTextNode("select");
    b.appendChild(txt);
    return b;
}

function termToTag(tagindex)
{
    var savedTerms = document.getElementById('savedTerms');
    var paras = savedTerms.getElementsByTagName('li');
    var terms = new Array();
    for( var i = 0; i < paras.length; i++) {
        var t = paras[i].firstChild.nodeValue;
        var termArr = t.split(/\s*:\s*/);
        terms.push(termArr);
    }

    addTerms2Rec(tagindex, terms);
    if (opener && !opener.closed) {
        opener.focus();
    }
    window.close();
    return false;
}

function addTerms2Rec(index, terms)
{
    var idx = index;
    for(var i = 0; i < terms.length; ) {
        idx = CloneField(idx);
        addTermWorker(idx,terms[i]);
       i++;
    }
}

function addTermWorker(index, termArr) {
    var t = opener.document.getElementById(index);
    var tagdata = index.split(/_/); // tagdata == tag XXX random
    var inputs = t.getElementsByTagName('input');
    sfdaRegExp = new RegExp("^tag_" + tagdata[1] + "_subfield_a");
    sfd0RegExp = new RegExp("^tag_" + tagdata[1] + "_subfield_0");
    ind2RegExp = new RegExp("^tag_" + tagdata[1] + "_indicator2");
    for (var i = 0; i < inputs.length; i++) {
        if (inputs[i].name.match(sfdaRegExp)) {
            inputs[i].value = termArr[0];
        }
        if (inputs[i].name.match(sfd0RegExp)) {
            inputs[i].value = termArr[1];
        }
        if (inputs[i].name.match(ind2RegExp)) {
            inputs[i].value = '7';
        }

    }
    var selects = t.getElementsByTagName('select');
    sfd2RegExp = new RegExp("^tag_" + tagdata[1] + "_subfield_2");
    for (var i = 0; i < selects.length; i++) {
        if (selects[i].name.match(sfd2RegExp)) {
            var language;
            var englishPattern = /EN/;
            var frenchPattern  = /FR/;
            var spanishPattern = /ES/;
            if (englishPattern.test(termArr[2]) ) {
                language =  'agrovoc';
            } else if (frenchPattern.test(termArr[2]) ) {
                language =  'agrovocf';
            } else if (spanishPattern.test(termArr[2]) ) {
                language =  'agrovocs';
            }
            var option_list = selects[i].options;
            for (var j = 0; j < option_list.length; j++) {
               if (option_list[j].value == language) {
                   option_list[j].selected = true;
               }
            }
        }
    }
}

// Copy functions from Koha cataloging.js.. not sure why we don't just load that and reference them here.. but..
var current_select2;
var Select2Utils = {
    removeSelect2: function(selects) {
        if ($.fn.select2) {
            $(selects).each(function(){
                $(this).select2('destroy');
            });
        }
    },

    initSelect2: function(selects) {
        if ($.fn.select2) {
            if ( window.CAN_user_parameters_manage_auth_values === undefined || ! CAN_user_parameters_manage_auth_values ) {
                $(selects).select2().on("select2:clear", function () {
                    $(this).on("select2:opening.cancelOpen", function (evt) {
                        evt.preventDefault();
                        $(this).off("select2:opening.cancelOpen");
                    });
                });
            } else {
                $(selects).each(function(){
                    if ( !$(this).data("category") ) {
                        $(this).select2().on("select2:clear", function () {
                            $(this).on("select2:opening.cancelOpen", function (evt) {
                                evt.preventDefault();
                                $(this).off("select2:opening.cancelOpen");
                            });
                        });
                    } else {
                        $(this).select2({
                            tags: true,
                            createTag: function (tag) {
                                return {
                                    id: tag.term,
                                    text: tag.term,
                                    newTag: true
                                };
                            },
                            templateResult: function(state) {
                                if (state.newTag) {
                                    return state.text + " " + __("(select to create)");
                                }
                                return state.text;
                            }
                        }).on("select2:select", function(e) {
                            if(e.params.data.newTag){
                                current_select2 = this;
                                var category = $(this).data("category");
                                $("#avCreate #new_av_category").html(category);
                                $("#avCreate input[name='category']").val(category);
                                $("#avCreate input[name='value']").val('');
                                $("#avCreate input[name='description']").val(e.params.data.text);

                                $(this).val($(this).find("option:first").val()).trigger('change');
                                $('#avCreate').modal({show:true});
                            }
                        }).on("select2:clear", function () {
                            $(this).on("select2:opening.cancelOpen", function (evt) {
                                evt.preventDefault();

                                $(this).off("select2:opening.cancelOpen");
                            });
                        });
                    }
                });
            }
        }
    }
};

function AddEventHandlers (oldcontrol, newcontrol, newinputid ) {
// This function is a helper for CloneField and CloneSubfield.
// It adds the event handlers from oldcontrol to newcontrol.
// newinputid is the id attribute of the cloned controlling input field
// Note: This code depends on the jQuery data for events; this structure
// is moved to _data as of jQuery 1.8.
    var ev= $(oldcontrol).data('events');
    if(typeof ev != 'undefined') {
        $.each(ev, function(prop,val) {
            $.each(val, function(prop2,val2) {
                $(newcontrol).off( val2.type );
                $(newcontrol).on( val2.type, {id: newinputid}, val2.handler );
            });
        });
    }
}

function CreateKey() {
    return parseInt(Math.random() * 100000);
}
// END Copy functions from Koha cataloging.js.. not sure why we don't just load that and reference them here.. but..

// Minor modified CloneField from Koha cataloging.js - Updates target to use 'opener' to refer to original window
function CloneField(index) {
    var original = opener.document.getElementById(index); //original <li>
    Select2Utils.removeSelect2($(original).find('select'));

    var clone = original.cloneNode(true);
    var new_key = CreateKey();
    var new_id  = original.getAttribute('id')+new_key;

    clone.setAttribute('id',new_id); // setting a new id for the parent li

    var divs = Array.from(clone.getElementsByTagName('li')).concat(Array.from(clone.getElementsByTagName('div')));

    // if hide_marc, indicators are hidden fields
    // setting a new name for the new indicator
    for(var i=0; i < 2; i++) {
        var indicator = clone.getElementsByTagName('input')[i];
        indicator.setAttribute('name',indicator.getAttribute('name')+new_key);
    }

    // settings all subfields
    var divslen = divs.length;
    for( i=0; i < divslen ; i++ ){      // foreach div/li
        if( divs[i].getAttribute("id") && divs[i].getAttribute("id").match(/^subfield/)){  // if it s a subfield

            // set the attribute for the new 'li' subfields
            divs[i].setAttribute('id',divs[i].getAttribute('id')+new_key);

            var inputs   = divs[i].getElementsByTagName('input');
            var id_input = "";
            var olddiv;
            var oldcontrol;

            for( j = 0 ; j < inputs.length ; j++ ) {
                if(inputs[j].getAttribute("id") && inputs[j].getAttribute("id").match(/^tag_/) ){
                    inputs[j].value = "";
                }
            }
            var textareas = divs[i].getElementsByTagName('textarea');
            for( j = 0 ; j < textareas.length ; j++ ) {
                if(textareas[j].getAttribute("id") && textareas[j].getAttribute("id").match(/^tag_/) ){
                    textareas[j].value = "";
                }
            }
            if( inputs.length > 0 ){
                inputs[0].setAttribute('id',inputs[0].getAttribute('id')+new_key);
                inputs[0].setAttribute('name',inputs[0].getAttribute('name')+new_key);

                try {
                    id_input = inputs[1].getAttribute('id')+new_key;
                    inputs[1].setAttribute('id',id_input);
                    inputs[1].setAttribute('name',inputs[1].getAttribute('name')+new_key);
                } catch(e) {
                    try{ // it s a select if it is not an input
                        var selects = divs[i].getElementsByTagName('select');
                        id_input = selects[0].getAttribute('id')+new_key;
                        selects[0].setAttribute('id',id_input);
                        selects[0].setAttribute('name',selects[0].getAttribute('name')+new_key);
                    }catch(e2){ // it is a textarea if it s not a select or an input
                        var textareas = divs[i].getElementsByTagName('textarea');
                        if( textareas.length > 0 ){
                            id_input = textareas[0].getAttribute('id')+new_key;
                            textareas[0].setAttribute('id',id_input);
                            textareas[0].setAttribute('name',textareas[0].getAttribute('name')+new_key);
                        }
                    }
                }
                if( $(inputs[1]).hasClass('framework_plugin') ) {
                    olddiv= original.getElementsByTagName('li')[i];
                    oldcontrol= olddiv.getElementsByTagName('input')[1];
                    AddEventHandlers( oldcontrol,inputs[1],id_input );
                }
            }
            // when cloning a subfield, re set its label too.
            var labels = divs[i].getElementsByTagName('label');
            labels[0].setAttribute('for', id_input);

            // setting its '+' and '-' buttons
            try {
                var anchors = divs[i].getElementsByTagName('a');
                for (var j = 0; j < anchors.length; j++) {
                    if(anchors[j].getAttribute('class') == 'buttonPlus'){
                        anchors[j].setAttribute('onclick',"CloneSubfield('" + divs[i].getAttribute('id') + "','" + advancedMARCEditor + "'); return false;");
                    } else if (anchors[j].getAttribute('class') == 'buttonMinus') {
                        anchors[j].setAttribute('onclick',"UnCloneField('" + divs[i].getAttribute('id') + "'); return false;");
                    } else if (anchors[j].getAttribute('class') == 'buttonDot') {
                        anchors[j].setAttribute('onclick',"openAgrovoc('" + divs[i].getAttribute('id') + "'); return false;");
                    }
                }
            }
            catch(e){
                // do nothig if ButtonPlus & CloneButtonPlus don t exist.
            }

            // button ...
            var spans=0;
            try {
                spans = divs[i].getElementsByTagName('a');
            } catch(e) {
                // no spans
            }
            if(spans){
                var buttonDot;
                if(!CloneButtonPlus){ // it s impossible to have  + ... (buttonDot AND buttonPlus)
                    buttonDot = spans[0];
                    if(buttonDot){
                        // 2 possibilities :
                        try{
                            if( $(buttonDot).hasClass('framework_plugin') ) {
                                olddiv= original.getElementsByTagName('li')[i];
                                oldcontrol= olddiv.getElementsByTagName('a')[0];
                                AddEventHandlers(oldcontrol,buttonDot,id_input);
                            }
                            try {
                                // do not copy the script section.
                                var script = spans[0].getElementsByTagName('script')[0];
                                spans[0].removeChild(script);
                            } catch(e) {
                                // do nothing if there is no script
                            }
                        } catch(e){
                            //
                        }
                    }
                }
            }

        } else { // it's a indicator div
            if ( divs[i].getAttribute("id") && divs[i].getAttribute('id').match(/^div_indicator/)) {

                // setting a new id for the indicator div
                divs[i].setAttribute('id',divs[i].getAttribute('id')+new_key);

                inputs = divs[i].getElementsByTagName('input');
                inputs[0].setAttribute('id',inputs[0].getAttribute('id')+new_key);
                inputs[1].setAttribute('id',inputs[1].getAttribute('id')+new_key);

                var CloneButtonPlus;
                try {
                    anchors = divs[i].getElementsByTagName('a');
                    for ( j = 0; j < anchors.length; j++) {
                        if (anchors[j].getAttribute('class') == 'buttonPlus') {
                            anchors[j].setAttribute('onclick',"CloneField('" + new_id + "','" + hideMarc + "','" + advancedMARCEditor + "'); return false;");
                        } else if (anchors[j].getAttribute('class') == 'buttonMinus') {
                            anchors[j].setAttribute('onclick',"UnCloneField('" + new_id + "'); return false;");
                        } else if (anchors[j].getAttribute('class') == 'expandfield') {
                            anchors[j].setAttribute('onclick',"ExpandField('" + new_id + "'); return false;");
                        } else if (anchors[j].getAttribute('class') == 'buttonPlus') {
                            anchors[j].setAttribute('onclick',"openAgrovoc('" + new_id + "'); return false;");
                        }
                    }
                }
                catch(e){
                    // do nothig CloneButtonPlus doesn't exist.
                }

            }
        }
    }

    // insert this line on the page
    original.parentNode.insertBefore(clone,original.nextSibling);

    $("ul.sortable_subfield", clone).sortable();

    Select2Utils.initSelect2($(original).find('select'));
    Select2Utils.initSelect2($(clone).find('select'));

    return new_id;
}

function clearSelectedTerms() {
    var savedTerms = document.getElementById('savedTerms');
    savedTerms.innerHTML = '';
    // while (savedTerms.firstChild) {
    //     savedTerms.removeChild(savedTerms.firstChild)
}
