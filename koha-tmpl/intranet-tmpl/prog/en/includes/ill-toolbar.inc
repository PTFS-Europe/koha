<script type="text/javascript">
//<![CDATA[
$(document).ready(function(){
});
//]]>
</script>

[% IF ILLModule and CAN_user_ill %]
<div id="toolbar" class="btn-toolbar">
    <a id="ill-view" class="btn btn-small" href="/cgi-bin/koha/ill/ill-requests.pl">
        <i class="icon-search"></i>View Requests</a>
    <a id="ill-new" class="btn btn-small" href="/cgi-bin/koha/ill/ill-new.pl">
        <i class="icon-plus"></i>New ILL Request</a>
    <div class="btn-group">
        <button class="btn btn-small dropdown-toggle" data-toggle="dropdown">
            <i class="icon-print"></i> Example Dropdown <span class="caret"></span>
        </button>
            <ul class="dropdown-menu">
                [% IF ( CAN_user_borrowers ) %]
                <li><a id="ex_perms" href="#">Example Permissions</a></li>
                [% END %]
                <li><a id="ex_entry" href="#">Example Entry</a></li>
            </ul>
    </div>
</div>
[% END %]
[% IF debug %]
    [% USE Dumper %]
    <h2>Debugging Output</h2>
    <dl>
        <dt>Request</dt>
        <dd>
            [% Dumper.dump(recv) %]
        </dd>
        <dt>Reply</dt>
        <dd>
            [% Dumper.dump(reply) %]
        </dd>
    </dl>
[% END %]
 
