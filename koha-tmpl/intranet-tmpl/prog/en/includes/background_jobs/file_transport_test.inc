[% USE Koha %]

[% SET report = job.decoded_data %]
[% BLOCK report %]
    [% IF job.status == 'finished' %]
        [% IF report.status == 'errors' %]
        <div class="alert alert-alert">
            Connection test completed with errors
        </div>
        [% ELSE %]
        <div class="alert alert-success">
            Connection test completed without errors
        </div>
        [% END %]
    [% ELSIF job.status == 'cancelled' %]
        <span>The connection test was cancelled before it finished.</span>
    [% END %]
[% END %]

[% BLOCK detail %]
    [% FOREACH operation IN report.operations %]
        [% IF operation.status == 'error' %]
        <div class="text-danger">
            <i class="fa-solid fa-circle-xmark"></i> [% operation.operation %] failed.
        </div>
        [% ELSE %]
        <div class="text-success">
            <i class="fa-solid fa-circle-check"></i> [% operation.operation %] passed.
        </div>
        [% END %]
    [% END %]
    [% IF job.status == 'cancelled' %]
        <span>The connection test was cancelled before it finished.</span>
    [% END %]
[% END %]

[% BLOCK js %]
[% END %]
