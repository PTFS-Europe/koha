	(function(window, document, $, undefined) {
	$.fn.dataTable.ext.deepLink = function(whitelist) {
        var search = location.search.replace(/^\?/, "").split("&");
        var out = {};
        for (var i = 0, ien = search.length; i < ien; i++) {
            var pair = search[i].split("=");
            var key = decodeURIComponent(pair[0]);
            var value = decodeURIComponent(pair[1]);
            // "Casting"
            if (value === "true") {
                value = true;
            } else if (value === "false") {
                value = false;
            } else if (!value.match(/[^\d]/) && key !== "search.search") {
                // don't convert if searching or it'll break the search
                value = value * 1;
            } else if (value.indexOf("{") === 0 || value.indexOf("[") === 0) {
                // Try to JSON parse for arrays and obejcts
                try {
                    value = $.parseJSON(value);
                } catch (e) {}
            }

			var setBuilder = $.fn.dataTable.ext.internal._fnSetObjectDataFn;

            if (whitelist === "all" || $.inArray(key, whitelist) !== -1) {
                var setter = setBuilder(key);
                setter(out, value, {});
            }
        }
        return out;
    };
})(window, document, jQuery);
