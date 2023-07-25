[% USE Koha %]

[% BLOCK report %]
    [% SET report = job.report %]
    [% IF report %]
        <div class="dialog message">
            [% IF job.status == 'finished' %]
                <p>Processed [% report.counter_report.total_records %] rows in report <strong>[% report.counter_report.report_type %]</strong> from <a href="/cgi-bin/koha/erm/eusage/usage_data_providers/[% report.ud_provider_id %]" title="Visit usage data provider">[% report.ud_provider_name %]</a></p>
            [% ELSIF job.status == 'started' %]
                [% IF job.progress == 0 %]
                    <p>Requesting SUSHI service</p>
                [% ELSE %]
                    <p>Creating COUNTER file and processing data</p>
                [% END %]
                <p>Please check again soon</p>
            [% END %]
            [% INCLUDE "job_progress.inc" job_id=job.id %]
            [% IF job.status == 'cancelled' %]
                <p>The job has been cancelled before it finished.</p>
            [% END %]
        </div>
    [% END %]
[% END %]

[% Asset.js("js/job_progress.js") | $raw %]

[% BLOCK detail %]
    [% FOR m IN job.messages %]
        <div class="dialog message">
            [% IF m.type == 'success' %]
                <i class="fa fa-check success"></i>
            [% ELSIF m.type == 'warning' %]
                <i class="fa fa-warning warn"></i>
            [% ELSIF m.type == 'error' %]
                <i class="fa fa-exclamation error"></i>
            [% END %]
            [% SWITCH m.code %]
            [% CASE 'object_already_exists' %]
                <span><strong>[% m.title %]</strong> already exists in this data provider and was not created. New usage statistics were verified anyway</span>
            [% CASE 'object_added' %]
                <span><strong>[% m.title %]</strong> successfully added</span>
            [% END %]
        </div>
    [% END %]
[% END %]
    [% Asset.js("js/job_progress.js") | $raw %]

[% BLOCK js %]
    [% INCLUDE 'str/job_progress.inc' job_id=job.id %]
<script>
        $(document).ready(function(){
            let job_id = [% job.id | html %];
            updateProgress(job_id, function(){
                //TODO: Update UI labels here, Requesting SUSHI Service -> "Processing records"
            });
        });

</script>
[% END %]
