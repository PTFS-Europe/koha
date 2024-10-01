/*! Deep linking options parsing support for DataTables
 * 2017 SpryMedia Ltd - datatables.net/license
 */

/**
 * @summary     LengthLinks
 * @description Deep linking options parsing support for DataTables
 * @version     1.0.0
 * @file        dataTables.deepLink.js
 * @author      SpryMedia Ltd (www.sprymedia.co.uk)
 * @copyright   Copyright 2017 SpryMedia Ltd.
 *
 * License      MIT - http://datatables.net/license/mit
 *
 * This feature plug-in for DataTables provides a function which will
 * take DataTables options from the browser's URL search string and
 * return an object that can be used to construct a DataTable. This
 * allows deep linking to be easily implemented with DataTables - for
 * example a URL might be `myTable?displayStart=10` which will
 * automatically cause the second page of the DataTable to be displayed.
 *
 * This plug-in works on a whitelist basis - you must specify which
 * [initialisation parameters](//datatables.net/reference/option) you
 * want the URL search string to specify. Any parameter given in the
 * URL which is not listed will be ignored (e.g. you are unlikely to
 * want to let the URL search string specify the `ajax` option).
 *
 * This specification is done by passing an array of property names
 * to the `$.fn.dataTable.ext.deepLink` function. If you do which to
 * allow _every_ parameter (I wouldn't recommend it) you can use `all`
 * instead of an array.
 *
 * @example
 *   // Allow a display start point and search string to be specified
 *   $('#myTable').DataTable(
 *     $.fn.dataTable.ext.deepLink( [ 'displayStart', 'search.search' ] )
 *   );
 *
 * @example
 *   // As above, but with a default search
 *   var options = $.fn.dataTable.ext.deepLink(['displayStart', 'search.search']);
 *
 *   $('#myTable').DataTable(
 *     $.extend( true, {
 *       search: { search: 'Initial search value' }
 *     }, options )
 *   );
 */
(function(window, document, $, undefined) {
	// Use DataTables' object builder so strings can be used to represent
	// nested objects
	var setBuilder = $.fn.dataTable.ext.internal._fnSetObjectDataFn;

	$.fn.dataTable.ext.deepLink = function(whitelist) {
		var search = location.search.replace(/^\?/, '').split('&');
		var out = {};

		for (var i = 0, ien = search.length; i < ien; i++) {
			var pair = search[i].split('=');
			var key = decodeURIComponent(pair[0]);
			var value = decodeURIComponent(pair[1]);

			// "Casting"
			if (value === 'true') {
				value = true;
			} else if (value === 'false') {
				value = false;
			} else if (!value.match(/[^\d]/) && key !== 'search.search') {
				// don't convert if searching or it'll break the search
				value = value * 1;
			} else if (value.indexOf('{') === 0 || value.indexOf('[') === 0) {
				// Try to JSON parse for arrays and obejcts
				try {
					value = $.parseJSON(value);
				} catch (e) {console.log("ERR");console.log(e);}
			}

			if (whitelist === 'all' || $.inArray(key, whitelist) !== -1) {
				var setter = setBuilder(key);
				setter(out, value);
			}
		}

        console.log(out);
		return out;
	};
})(window, document, jQuery);
