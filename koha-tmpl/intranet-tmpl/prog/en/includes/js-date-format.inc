[% USE Koha %]
[% USE raw %]
[% USE Asset %]
[% USE KohaDates %]
[% Asset.js("lib/dayjs/dayjs.min.js") | $raw %]
[% Asset.js("lib/dayjs/plugin/utc.js") | $raw %]
[% Asset.js("lib/dayjs/plugin/timezone.js") | $raw %]
[% Asset.js("lib/dayjs/plugin/customParseFormat.js") | $raw %]
<script>
    dayjs.extend(window.dayjs_plugin_utc);
    dayjs.extend(window.dayjs_plugin_timezone);
    dayjs.extend(window.dayjs_plugin_customParseFormat);
</script>
<!-- js-date-format.inc -->
<script>
    (function() {
        var def_date_format = '[% Koha.Preference('dateformat') | html %]';
        var def_time_format = '[% Koha.Preference('TimeFormat') | html %]';
        var def_tz = '[% KohaDates.tz | html %]';

        var get_date_pattern = function(format) {
            var date_pattern = 'YYYY-MM-DD';
            if(format == 'us') date_pattern = 'MM/DD/YYYY';
            if(format == 'metric') date_pattern = 'DD/MM/YYYY';
            if(format == 'dmydot') date_pattern = 'DD.MM.YYYY';
            return date_pattern;
        };

        var get_time_pattern = function(format) {
            var time_pattern = 'HH:mm';
            if(format == '12hr') time_pattern = 'hh:mm a';
            return time_pattern;
        };

        /**
         * A JS equivalent of the KohaDates TT Plugin. Passed an rfc3339 formatted date string,
         * or JS Date, the function will return a date string formatted as per the koha instance config.
         * @param {String|Date} value                   rfc3339 formatted date string or a JS Date object.
         * @param {Object} [options]                    Optional set of switches for changing date handling
         * @property {String} [options.tz]              String representing the timezone of the passed date
         * @property {Boolean} [options.no_tz_adjust]   Enable/Disable timezone adjustment
         * @property {String} [options.dateformat]
         * @property {Boolean} [options.withtime]       Enable/Disable appearance of time in returned string
         * @property {String} [options.timeformat]
         * @property {Boolean} [options.as_due_date]    Enable/Disable due date output format
         * @returns {String}                            A date string formatted as per the koha instance configuration.
         */
        window.$date = function(value, options) {
            if(!value) return '';
            let tz = (options&&options.tz)||def_tz;
            let no_tz_adjust = (options&&options.no_tz_adjust)||false;
            var m = dayjs(value);
            if ( !no_tz_adjust && ! value.match(/^\d{4}-\d{2}-\d{2}$/ ) ) {
                m = m.tz(tz);
            }

            var dateformat = (options&&options.dateformat)||def_date_format;
            var withtime = (options&&options.withtime)||false;

            if(dateformat=='rfc3339' && withtime) return m.format();

            var timeformat = (options&&options.timeformat)||def_time_format;
            var date_pattern = get_date_pattern(dateformat);
            let as_due_date = (options&&options.as_due_date);
            if (as_due_date) {
                withtime = !( m.hour() == 23 && m.minute() == 59 );
            }
            var time_pattern = !withtime?'':' '+get_time_pattern(timeformat);

            return m.format(date_pattern+time_pattern);
        }

        window.$datetime = function(value, options) {
            options = options||{};
            options.withtime = true;
            return $date(value, options);
        };

        window.$time = function(value, options) {
            if(!value) return '';
            var tz = (options&&options.tz)||def_tz;
            var m = dayjs(value);
            if(tz) m = m.tz(tz);

            var dateformat = (options&&options.dateformat);
            var timeformat = (dateformat=='rfc3339'&&'24hr')||(options&&options.timeformat)||def_time_format;

            return m.format(get_time_pattern(timeformat)+(dateformat=='rfc3339'?':ss'+(!m.isUTC()?'Z':''):''))+(dateformat=='rfc3339' && m.isUTC()?'Z':'');
        }

        window.$date_to_rfc3339 = function(value, options) {
            var dateformat = (options&&options.dateformat)||def_date_format;
            let m = dayjs(value, get_date_pattern(dateformat), true);
            return m.format("YYYY-MM-DD");
        }

        /**
        * A JS equivalent of the KohaTimes TT Plugin. Passed a time in HH:MM:SS or HH:MM format
        * the function will return a time string formatted as per the koha instance config.
        */

        window.$kohatime = function(value) {
            if(!value) return 'invalid time';
            var intime = value.split(':');
            var hours = intime[0];
            var minutes = intime[1];

            if ( hours < 0 || hours > 23 || minutes < 0 || minutes > 59 ) { return 'invalid time'; }

            if ( def_time_format == '12hr') {
                var ampm = ( hours >= 12 ) ? 'pm' : 'am';
                hours = ( hours == 0 ) ? "12" : hours;
                hours = ( hours > 12 ) ? ( hours - 12 ) : hours;

                return hours.toString().padStart(2,'0') + ':' + minutes.toString().padStart(2,'0') + " " + ampm;
            } else {
                return hours.toString().padStart(2,'0') + ':' + minutes.toString().padStart(2,'0');
            }
        }


    })();
</script>
<!-- / js-date-format.inc -->
