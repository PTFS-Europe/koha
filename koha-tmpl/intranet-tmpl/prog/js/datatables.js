// These default options are for translation but can be used
// for any other datatables settings
// To use it, write:
//  $("#table_id").dataTable($.extend(true, {}, dataTableDefaults, {
//      // other settings
//  } ) );
var dataTablesDefaults = {
    "language": {
        "paginate": {
            "first"    : __('First'),
            "last"     : __('Last'),
            "next"     : __('Next'),
            "previous" : __('Previous'),
        },
        "emptyTable"       : __('No data available in table'),
        "info"             : __('Showing _START_ to _END_ of _TOTAL_ entries'),
        "infoEmpty"        : __('No entries to show'),
        "infoFiltered"     : __('(filtered from _MAX_ total entries)'),
        "lengthMenu"       : __('Show _MENU_ entries'),
        "loadingRecords"   : __('Loading...'),
        "processing"       : __('Processing...'),
        "search"           : __('Search:'),
        "zeroRecords"      : __('No matching records found'),
        buttons: {
            "copyTitle"     : __('Copy to clipboard'),
            "copyKeys"      : __('Press <i>ctrl</i> or <i>⌘</i> + <i>C</i> to copy the table data<br>to your system clipboard.<br><br>To cancel, click this message or press escape.'),
            "copySuccess": {
                _: __('Copied %d rows to clipboard'),
                1: __('Copied one row to clipboard'),
            }
        }
    },
    "dom": '<"top pager"<"table_entries"ilp><"table_controls"fB>>tr<"bottom pager"ip>',
    "buttons": [{
        fade: 100,
        className: "dt_button_clear_filter",
        titleAttr: __('Clear filter'),
        enabled: false,
        text: '<i class="fa fa-lg fa-remove"></i> <span class="dt-button-text">' + __('Clear filter') + '</span>',
        available: function ( dt ) {
            // The "clear filter" button is made available if this test returns true
            if( dt.settings()[0].aanFeatures.f ){ // aanFeatures.f is null if there is no search form
                return true;
            }
        },
        action: function ( e, dt, node ) {
            dt.search( "" ).draw("page");
            node.addClass("disabled");
        }
    }],
    "lengthMenu": [[10, 20, 50, 100, -1], [10, 20, 50, 100, __('All')]],
    "pageLength": 20,
    "fixedHeader": true,
    initComplete: function( settings) {
        var tableId = settings.nTable.id
        // When the DataTables search function is triggered,
        // enable or disable the "Clear filter" button based on
        // the presence of a search string
        $("#" + tableId ).on( 'search.dt', function ( e, settings ) {
            if( settings.oPreviousSearch.sSearch == "" ){
                $("#" + tableId + "_wrapper").find(".dt_button_clear_filter").addClass("disabled");
            } else {
                $("#" + tableId + "_wrapper").find(".dt_button_clear_filter").removeClass("disabled");
            }
        });
    }
};


// Return an array of string containing the values of a particular column
$.fn.dataTableExt.oApi.fnGetColumnData = function ( oSettings, iColumn, bUnique, bFiltered, bIgnoreEmpty ) {
    // check that we have a column id
    if ( typeof iColumn == "undefined" ) return new Array();
    // by default we only wany unique data
    if ( typeof bUnique == "undefined" ) bUnique = true;
    // by default we do want to only look at filtered data
    if ( typeof bFiltered == "undefined" ) bFiltered = true;
    // by default we do not wany to include empty values
    if ( typeof bIgnoreEmpty == "undefined" ) bIgnoreEmpty = true;
    // list of rows which we're going to loop through
    var aiRows;
    // use only filtered rows
    if (bFiltered == true) aiRows = oSettings.aiDisplay;
    // use all rows
    else aiRows = oSettings.aiDisplayMaster; // all row numbers

    // set up data array
    var asResultData = new Array();
    for (var i=0,c=aiRows.length; i<c; i++) {
        iRow = aiRows[i];
        var aData = this.fnGetData(iRow);
        var sValue = aData[iColumn];
        // ignore empty values?
        if (bIgnoreEmpty == true && sValue.length == 0) continue;
        // ignore unique values?
        else if (bUnique == true && jQuery.inArray(sValue, asResultData) > -1) continue;
        // else push the value onto the result data array
        else asResultData.push(sValue);
    }
    return asResultData;
}

// List of unbind keys (Ctrl, Alt, Direction keys, etc.)
// These keys must not launch filtering
var blacklist_keys = new Array(0, 16, 17, 18, 37, 38, 39, 40);

// Set a filtering delay for global search field
jQuery.fn.dataTableExt.oApi.fnSetFilteringDelay = function ( oSettings, iDelay ) {
    /*
     * Inputs:      object:oSettings - dataTables settings object - automatically given
     *              integer:iDelay - delay in milliseconds
     * Usage:       $('#example').dataTable().fnSetFilteringDelay(250);
     * Author:      Zygimantas Berziunas (www.zygimantas.com) and Allan Jardine
     * License:     GPL v2 or BSD 3 point style
     * Contact:     zygimantas.berziunas /AT\ hotmail.com
     */
    var
        _that = this,
        iDelay = (typeof iDelay == 'undefined') ? 250 : iDelay;

    this.each( function ( i ) {
        $.fn.dataTableExt.iApiIndex = i;
        var
            $this = this,
            oTimerId = null,
            sPreviousSearch = null,
            anControl = $( 'input', _that.fnSettings().aanFeatures.f );

        anControl.unbind( 'keyup.DT' ).bind( 'keyup.DT', function(event) {
            var $$this = $this;
            if (blacklist_keys.indexOf(event.keyCode) != -1) {
                return this;
            }else if ( event.keyCode == '13' ) {
                $.fn.dataTableExt.iApiIndex = i;
                _that.fnFilter( $(this).val() );
            } else {
                if (sPreviousSearch === null || sPreviousSearch != anControl.val()) {
                    window.clearTimeout(oTimerId);
                    sPreviousSearch = anControl.val();
                    oTimerId = window.setTimeout(function() {
                        $.fn.dataTableExt.iApiIndex = i;
                        _that.fnFilter( anControl.val() );
                    }, iDelay);
                }
            }
        });

        return this;
    } );
    return this;
}

// Add a filtering delay on general search and on all input (with a class 'filter')
jQuery.fn.dataTableExt.oApi.fnAddFilters = function ( oSettings, sClass, iDelay ) {
    var table = this;
    this.fnSetFilteringDelay(iDelay);
    var filterTimerId = null;
    $(table).find("input."+sClass).keyup(function(event) {
      if (blacklist_keys.indexOf(event.keyCode) != -1) {
        return this;
      }else if ( event.keyCode == '13' ) {
        table.fnFilter( $(this).val(), $(this).attr('data-column_num') );
      } else {
        window.clearTimeout(filterTimerId);
        var input = this;
        filterTimerId = window.setTimeout(function() {
          table.fnFilter($(input).val(), $(input).attr('data-column_num'));
        }, iDelay);
      }
    });
    $(table).find("select."+sClass).on('change', function() {
        table.fnFilter($(this).val(), $(this).attr('data-column_num'));
    });
}

// Sorting on html contains
// <a href="foo.pl">bar</a> sort on 'bar'
function dt_overwrite_html_sorting_localeCompare() {
    jQuery.fn.dataTableExt.oSort['html-asc']  = function(a,b) {
        a = a.replace(/<.*?>/g, "").replace(/\s+/g, " ");
        b = b.replace(/<.*?>/g, "").replace(/\s+/g, " ");
        if (typeof(a.localeCompare == "function")) {
           return a.localeCompare(b);
        } else {
           return (a > b) ? 1 : ((a < b) ? -1 : 0);
        }
    };

    jQuery.fn.dataTableExt.oSort['html-desc'] = function(a,b) {
        a = a.replace(/<.*?>/g, "").replace(/\s+/g, " ");
        b = b.replace(/<.*?>/g, "").replace(/\s+/g, " ");
        if(typeof(b.localeCompare == "function")) {
            return b.localeCompare(a);
        } else {
            return (b > a) ? 1 : ((b < a) ? -1 : 0);
        }
    };

    jQuery.fn.dataTableExt.oSort['num-html-asc']  = function(a,b) {
        var x = a.replace( /<.*?>/g, "" );
        var y = b.replace( /<.*?>/g, "" );
        x = parseFloat( x );
        y = parseFloat( y );
        return ((x < y) ? -1 : ((x > y) ?  1 : 0));
    };

    jQuery.fn.dataTableExt.oSort['num-html-desc'] = function(a,b) {
        var x = a.replace( /<.*?>/g, "" );
        var y = b.replace( /<.*?>/g, "" );
        x = parseFloat( x );
        y = parseFloat( y );
        return ((x < y) ?  1 : ((x > y) ? -1 : 0));
    };
}

$.fn.dataTableExt.oSort['num-html-asc']  = function(a,b) {
    var x = a.replace( /<.*?>/g, "" );
    var y = b.replace( /<.*?>/g, "" );
    x = parseFloat( x );
    y = parseFloat( y );
    return ((x < y) ? -1 : ((x > y) ?  1 : 0));
};

$.fn.dataTableExt.oSort['num-html-desc'] = function(a,b) {
    var x = a.replace( /<.*?>/g, "" );
    var y = b.replace( /<.*?>/g, "" );
    x = parseFloat( x );
    y = parseFloat( y );
    return ((x < y) ?  1 : ((x > y) ? -1 : 0));
};

(function() {

/*
 * Natural Sort algorithm for Javascript - Version 0.7 - Released under MIT license
 * Author: Jim Palmer (based on chunking idea from Dave Koelle)
 * Contributors: Mike Grier (mgrier.com), Clint Priest, Kyle Adams, guillermo
 * See: http://js-naturalsort.googlecode.com/svn/trunk/naturalSort.js
 */
function naturalSort (a, b) {
    var re = /(^-?[0-9]+(\.?[0-9]*)[df]?e?[0-9]?$|^0x[0-9a-f]+$|[0-9]+)/gi,
        sre = /(^[ ]*|[ ]*$)/g,
        dre = /(^([\w ]+,?[\w ]+)?[\w ]+,?[\w ]+\d+:\d+(:\d+)?[\w ]?|^\d{1,4}[\/\-]\d{1,4}[\/\-]\d{1,4}|^\w+, \w+ \d+, \d{4})/,
        hre = /^0x[0-9a-f]+$/i,
        ore = /^0/,
        // convert all to strings and trim()
        x = a.toString().replace(sre, '') || '',
        y = b.toString().replace(sre, '') || '',
        // chunk/tokenize
        xN = x.replace(re, '\0$1\0').replace(/\0$/,'').replace(/^\0/,'').split('\0'),
        yN = y.replace(re, '\0$1\0').replace(/\0$/,'').replace(/^\0/,'').split('\0'),
        // numeric, hex or date detection
        xD = parseInt(x.match(hre), 10) || (xN.length != 1 && x.match(dre) && Date.parse(x)),
        yD = parseInt(y.match(hre), 10) || xD && y.match(dre) && Date.parse(y) || null;
    // first try and sort Hex codes or Dates
    if (yD)
        if ( xD < yD ) return -1;
        else if ( xD > yD )  return 1;
    // natural sorting through split numeric strings and default strings
    for(var cLoc=0, numS=Math.max(xN.length, yN.length); cLoc < numS; cLoc++) {
        // find floats not starting with '0', string or 0 if not defined (Clint Priest)
        var oFxNcL = !(xN[cLoc] || '').match(ore) && parseFloat(xN[cLoc]) || xN[cLoc] || 0;
        var oFyNcL = !(yN[cLoc] || '').match(ore) && parseFloat(yN[cLoc]) || yN[cLoc] || 0;
        // handle numeric vs string comparison - number < string - (Kyle Adams)
        if (isNaN(oFxNcL) !== isNaN(oFyNcL)) return (isNaN(oFxNcL)) ? 1 : -1;
        // rely on string comparison if different types - i.e. '02' < 2 != '02' < '2'
        else if (typeof oFxNcL !== typeof oFyNcL) {
            oFxNcL += '';
            oFyNcL += '';
        }
        if (oFxNcL < oFyNcL) return -1;
        if (oFxNcL > oFyNcL) return 1;
    }
    return 0;
}

jQuery.extend( jQuery.fn.dataTableExt.oSort, {
    "natural-asc": function ( a, b ) {
        return naturalSort(a,b);
    },

    "natural-desc": function ( a, b ) {
        return naturalSort(a,b) * -1;
    }
} );

}());

/* Plugin to allow sorting on data stored in a span's title attribute
 *
 * Ex: <td><span title="[% ISO_date %]">[% formatted_date %]</span></td>
 *
 * In DataTables config:
 *     "aoColumns": [
 *        { "sType": "title-string" },
 *      ]
 * http://datatables.net/plug-ins/sorting#hidden_title_string
 */
jQuery.extend( jQuery.fn.dataTableExt.oSort, {
    "title-string-pre": function ( a ) {
        var m = a.match(/title="(.*?)"/);
        if ( null !== m && m.length ) {
            return m[1].toLowerCase();
        }
        return "";
    },

    "title-string-asc": function ( a, b ) {
        return ((a < b) ? -1 : ((a > b) ? 1 : 0));
    },

    "title-string-desc": function ( a, b ) {
        return ((a < b) ? 1 : ((a > b) ? -1 : 0));
    }
} );

/* Plugin to allow sorting on numeric data stored in a span's title attribute
 *
 * Ex: <td><span title="[% decimal_number_that_JS_parseFloat_accepts %]">
 *              [% formatted currency %]
 *     </span></td>
 *
 * In DataTables config:
 *     "aoColumns": [
 *        { "sType": "title-numeric" },
 *      ]
 * http://datatables.net/plug-ins/sorting#hidden_title
 */
jQuery.extend( jQuery.fn.dataTableExt.oSort, {
    "title-numeric-pre": function ( a ) {
        var x = a.match(/title="*(-?[0-9\.]+)/)[1];
        return parseFloat( x );
    },

    "title-numeric-asc": function ( a, b ) {
        return ((a < b) ? -1 : ((a > b) ? 1 : 0));
    },

    "title-numeric-desc": function ( a, b ) {
        return ((a < b) ? 1 : ((a > b) ? -1 : 0));
    }
} );

(function() {

    /* Plugin to allow text sorting to ignore articles
     *
     * In DataTables config:
     *     "aoColumns": [
     *        { "sType": "anti-the" },
     *      ]
     * Based on the plugin found here:
     * http://datatables.net/plug-ins/sorting#anti_the
     * Modified to exclude HTML tags from sorting
     * Extended to accept a string of space-separated articles
     * from a configuration file (in English, "a," "an," and "the")
     */

    var config_exclude_articles_from_sort = __('a an the');
    if (config_exclude_articles_from_sort){
        var articles = config_exclude_articles_from_sort.split(" ");
        var rpattern = "";
        for(i=0;i<articles.length;i++){
            rpattern += "^" + articles[i] + " ";
            if(i < articles.length - 1){ rpattern += "|"; }
        }
        var re = new RegExp(rpattern, "i");
    }

    jQuery.extend( jQuery.fn.dataTableExt.oSort, {
        "anti-the-pre": function ( a ) {
            var x = String(a).replace( /<[\s\S]*?>/g, "" );
            var y = x.trim();
            var z = y.replace(re, "").toLowerCase();
            return z;
        },

        "anti-the-asc": function ( a, b ) {
            return ((a < b) ? -1 : ((a > b) ? 1 : 0));
        },

        "anti-the-desc": function ( a, b ) {
            return ((a < b) ? 1 : ((a > b) ? -1 : 0));
        }
    });

}());

// Remove string between NSB NSB characters
$.fn.dataTableExt.oSort['nsb-nse-asc'] = function(a,b) {
    var pattern = new RegExp("\x88.*\x89");
    a = a.replace(pattern, "");
    b = b.replace(pattern, "");
    return (a > b) ? 1 : ((a < b) ? -1 : 0);
}
$.fn.dataTableExt.oSort['nsb-nse-desc'] = function(a,b) {
    var pattern = new RegExp("\x88.*\x89");
    a = a.replace(pattern, "");
    b = b.replace(pattern, "");
    return (b > a) ? 1 : ((b < a) ? -1 : 0);
}

/* Define two custom functions (asc and desc) for basket callnumber sorting */
jQuery.fn.dataTableExt.oSort['callnumbers-asc']  = function(x,y) {
        var x_array = x.split("<div>");
        var y_array = y.split("<div>");

        /* Pop the first elements, they are empty strings */
        x_array.shift();
        y_array.shift();

        x_array = jQuery.map( x_array, function( a ) {
            return parse_callnumber( a );
        });
        y_array = jQuery.map( y_array, function( a ) {
            return parse_callnumber( a );
        });

        x_array.sort();
        y_array.sort();

        x = x_array.shift();
        y = y_array.shift();

        if ( !x ) { x = ""; }
        if ( !y ) { y = ""; }

        return ((x < y) ? -1 : ((x > y) ?  1 : 0));
};

jQuery.fn.dataTableExt.oSort['callnumbers-desc'] = function(x,y) {
        var x_array = x.split("<div>");
        var y_array = y.split("<div>");

        /* Pop the first elements, they are empty strings */
        x_array.shift();
        y_array.shift();

        x_array = jQuery.map( x_array, function( a ) {
            return parse_callnumber( a );
        });
        y_array = jQuery.map( y_array, function( a ) {
            return parse_callnumber( a );
        });

        x_array.sort();
        y_array.sort();

        x = x_array.pop();
        y = y_array.pop();

        if ( !x ) { x = ""; }
        if ( !y ) { y = ""; }

        return ((x < y) ?  1 : ((x > y) ? -1 : 0));
};

function parse_callnumber ( html ) {
    var array = html.split('<span class="callnumber">');
    if ( array[1] ) {
        array = array[1].split('</span>');
        return array[0];
    } else {
        return "";
    }
}

// see http://www.datatables.net/examples/advanced_init/footer_callback.html
function footer_column_sum( api, column_numbers ) {
    // Remove the formatting to get integer data for summation
    var intVal = function ( i ) {
        if ( typeof i === 'number' ) {
            if ( isNaN(i) ) return 0;
            return i;
        } else if ( typeof i === 'string' ) {
            var value = i.replace(/[a-zA-Z ,.]/g, '')*1;
            if ( isNaN(value) ) return 0;
            return value;
        }
        return 0;
    };


    for ( var indice = 0 ; indice < column_numbers.length ; indice++ ) {
        var column_number = column_numbers[indice];

        var total = 0;
        var cells = api.column( column_number, { page: 'current' } ).nodes().to$().find("span.total_amount");
        var budgets_totaled = [];
        $(cells).each(function(){ budgets_totaled.push( $(this).data('self_id') ); });
        $(cells).each(function(){
            if( $(this).data('parent_id') && $.inArray( $(this).data('parent_id'), budgets_totaled) > -1 ){
                return;
            } else {
                total += intVal( $(this).html() );
            }

        });
        total /= 100; // Hard-coded decimal precision

        // Update footer
        $( api.column( column_number ).footer() ).html(total.format_price());
    };
}

function filterDataTable( table, column, term ){
    if( column ){
        table.column( column ).search( term ).draw("page");
    } else {
        table.search( term ).draw("page");
    }
}

jQuery.fn.dataTable.ext.errMode = function(settings, note, message) {
    console.warn(message);
};

(function($) {

    /**
    * Create a new dataTables instance that uses the Koha RESTful API's as a data source
    * @param  {Object}  options         Please see the dataTables documentation for further details
    *                                   We extend the options set with the `criteria` key which allows
    *                                   the developer to select the match type to be applied during searches
    *                                   Valid keys are: `contains`, `starts_with`, `ends_with` and `exact`
    * @param  {Object}  column_settings The arrayref as returned by TableSettings.GetColums function available
    *                                   from the columns_settings template toolkit include
    * @param  {Boolean} add_filters     Add a filters row as the top row of the table
    * @param  {Object}  default_filters Add a set of default search filters to apply at table initialisation
    * @return {Object}                  The dataTables instance
    */
    $.fn.kohaTable = function(options, columns_settings, add_filters, default_filters) {
        var settings = null;

        if ( add_filters ) {
            $(this).find('thead tr').clone(true).appendTo( $(this).find('thead') );
        }

        if(options) {
            if(!options.criteria || ['contains', 'starts_with', 'ends_with', 'exact'].indexOf(options.criteria.toLowerCase()) === -1) options.criteria = 'contains';
            options.criteria = options.criteria.toLowerCase();
            settings = $.extend(true, {}, dataTablesDefaults, {
                        'deferRender': true,
                        "paging": true,
                        'serverSide': true,
                        'searching': true,
                        'pagingType': 'full_numbers',
                        'processing': true,
                        'language': {
                            'emptyTable': (options.emptyTable) ? options.emptyTable : __("No data available in table")
                        },
                        'ajax': {
                            'type': 'GET',
                            'cache': true,
                            'dataSrc': 'data',
                            'beforeSend': function(xhr, settings) {
                                this._xhr = xhr;
                                if(options.embed) {
                                    xhr.setRequestHeader('x-koha-embed', Array.isArray(options.embed)?options.embed.join(','):options.embed);
                                }
                                if(options.header_filter && options.query_parameters) {
                                    xhr.setRequestHeader('x-koha-query', options.query_parameters);
                                    delete options.query_parameters;
                                }
                            },
                            'dataFilter': function(data, type) {
                                var json = {data: JSON.parse(data)};
                                if(total = this._xhr.getResponseHeader('x-total-count')) {
                                    json.recordsTotal = total;
                                    json.recordsFiltered = total;
                                }
                                if(total = this._xhr.getResponseHeader('x-base-total-count')) {
                                    json.recordsTotal = total;
                                }
                                return JSON.stringify(json);
                            },
                            'data': function( data, settings ) {
                                var length = data.length;
                                var start  = data.start;

                                var dataSet = {
                                    _page: Math.floor(start/length) + 1,
                                    _per_page: length
                                };


                                function build_query(col, value){
                                    var parts = [];
                                    var attributes = col.data.split(':');
                                    for (var i=0;i<attributes.length;i++){
                                        var part = {};
                                        var attr = attributes[i];
                                        part[!attr.includes('.')?'me.'+attr:attr] = options.criteria === 'exact'
                                            ? value
                                            : {like: (['contains', 'ends_with'].indexOf(options.criteria) !== -1?'%':'') + value + (['contains', 'starts_with'].indexOf(options.criteria) !== -1?'%':'')};
                                        parts.push(part);
                                    }
                                    return parts;
                                }

                                var filter = data.search.value;
                                // Build query for each column filter
                                var and_query_parameters = settings.aoColumns
                                .filter(function(col) {
                                    return col.bSearchable && typeof col.data == 'string' && data.columns[col.idx].search.value != ''
                                })
                                .map(function(col) {
                                    var value = data.columns[col.idx].search.value;
                                    return build_query(col, value)
                                })
                                .map(function r(e){
                                    return ($.isArray(e) ? $.map(e, r) : e);
                                });

                                // Build query for the global search filter
                                var or_query_parameters = settings.aoColumns
                                .filter(function(col) {
                                    return col.bSearchable && typeof col.data == 'string' && data.columns[col.idx].search.value == '' && filter != ''
                                })
                                .map(function(col) {
                                    var value = filter;
                                    return build_query(col, value)
                                })
                                .map(function r(e){
                                    return ($.isArray(e) ? $.map(e, r) : e);
                                });

                                if ( default_filters ) {
                                    and_query_parameters.push(default_filters);
                                }
                                query_parameters = and_query_parameters;
                                query_parameters.push(or_query_parameters);
                                if(query_parameters.length) {
                                    query_parameters = JSON.stringify(query_parameters.length === 1?query_parameters[0]:{"-and": query_parameters});
                                    if(options.header_filter) {
                                        options.query_parameters = query_parameters;
                                    } else {
                                        dataSet.q = query_parameters;
                                        delete options.query_parameters;
                                    }
                                } else {
                                    delete options.query_parameters;
                                }

                                dataSet._match = options.criteria;

                                if(options.columns) {
                                    var order = data.order;
                                    var orderArray = new Array();
                                    order.forEach(function (e,i) {
                                        var order_col      = e.column;
                                        var order_by       = options.columns[order_col].data;
                                        order_by           = order_by.split(':');
                                        var order_dir      = e.dir == 'asc' ? '+' : '-';
                                        Array.prototype.push.apply(orderArray,order_by.map(x => order_dir + (!x.includes('.')?'me.'+x:x)));
                                    });
                                    dataSet._order_by = orderArray.filter((v, i, a) => a.indexOf(v) === i).join(',');
                                }

                                return dataSet;
                            }
                        }
                    }, options);
        }

        var counter = 0;
        var hidden_ids = [];
        var included_ids = [];

        $(columns_settings).each( function() {
            var named_id = $( 'thead th[data-colname="' + this.columnname + '"]', this ).index( 'th' );
            var used_id = settings.bKohaColumnsUseNames ? named_id : counter;
            if ( used_id == -1 ) return;

            if ( this['is_hidden'] == "1" ) {
                hidden_ids.push( used_id );
            }
            if ( this['cannot_be_toggled'] == "0" ) {
                included_ids.push( used_id );
            }
            counter++;
        });

        var exportColumns = ":visible:not(.noExport)";
        if( settings.hasOwnProperty("exportColumns") ){
            // A custom buttons configuration has been passed from the page
            exportColumns = settings["exportColumns"];
        }

        var export_format = {
            body: function ( data, row, column, node ) {
                var newnode = $(node);

                if ( newnode.find(".noExport").length > 0 ) {
                    newnode = newnode.clone();
                    newnode.find(".noExport").remove();
                }

                return newnode.text().replace( /\n/g, ' ' ).trim();
            }
        }

        var export_buttons = [
            {
                extend: 'excelHtml5',
                text: __("Excel"),
                exportOptions: {
                    columns: exportColumns,
                    format:  export_format
                },
            },
            {
                extend: 'csvHtml5',
                text: __("CSV"),
                exportOptions: {
                    columns: exportColumns,
                    format:  export_format
                },
            },
            {
                extend: 'copyHtml5',
                text: __("Copy"),
                exportOptions: {
                    columns: exportColumns,
                    format:  export_format
                },
            },
            {
                extend: 'print',
                text: __("Print"),
                exportOptions: {
                    columns: exportColumns,
                    format:  export_format
                },
            }
        ];

        settings[ "buttons" ] = [
            {
                fade: 100,
                className: "dt_button_clear_filter",
                titleAttr: __("Clear filter"),
                enabled: false,
                text: '<i class="fa fa-lg fa-remove"></i> <span class="dt-button-text">' + __("Clear filter") + '</span>',
                action: function ( e, dt, node, config ) {
                    dt.search( "" ).draw("page");
                    node.addClass("disabled");
                }
            }
        ];

        if( included_ids.length > 0 ){
            settings[ "buttons" ].push(
                {
                    extend: 'colvis',
                    fade: 100,
                    columns: included_ids,
                    className: "columns_controls",
                    titleAttr: __("Columns settings"),
                    text: '<i class="fa fa-lg fa-gear"></i> <span class="dt-button-text">' + __("Columns") + '</span>',
                    exportOptions: {
                        columns: exportColumns
                    }
                }
            );
        }

        settings[ "buttons" ].push(
            {
                extend: 'collection',
                autoClose: true,
                fade: 100,
                className: "export_controls",
                titleAttr: __("Export or print"),
                text: '<i class="fa fa-lg fa-download"></i> <span class="dt-button-text">' + __("Export") + '</span>',
                buttons: export_buttons
            }
        );

        $(".dt_button_clear_filter, .columns_controls, .export_controls").tooltip();

        if ( add_filters ) {
            settings['orderCellsTop'] = true;
        }

        var table = $(this).dataTable(settings);

        table.DataTable().on("column-visibility.dt", function(){
            if( typeof columnsInit == 'function' ){
                // This function can be created separately and used to trigger
                // an event after the DataTable has loaded AND column visibility
                // has been updated according to the table's configuration
                columnsInit();
            }
        }).columns( hidden_ids ).visible( false );

        if ( add_filters ) {
            var table_dt = table.DataTable();
            $(this).find('thead tr:eq(1) th').each( function (i) {
                var is_searchable = table_dt.settings()[0].aoColumns[i].bSearchable;
                if ( is_searchable ) {
                    var title = $(this).text();
                    var existing_search = table_dt.column(i).search();
                    if ( existing_search ) {
                        $(this).html( '<input type="text" value="%s" style="width: 100%" />'.format(existing_search) );
                    } else {
                        var search_title = _("%s search").format(title);
                        $(this).html( '<input type="text" placeholder="%s" style="width: 100%" />'.format(search_title) );
                    }

                    $( 'input', this ).on( 'keyup change', function () {
                        if ( table_dt.column(i).search() !== this.value ) {
                            table_dt
                                .column(i)
                                .search( this.value )
                                .draw();
                        }
                    } );
                } else {
                    $(this).html('');
                }
            } );
        }

        return table;
    };

})(jQuery);
