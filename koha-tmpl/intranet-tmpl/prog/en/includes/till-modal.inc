<script type="text/javascript">
    //<![CDATA[
    $(document).ready(function()
    {
        $("#selectTillForm").submit(function()
        {

            var tillid = $('#till-select').val();
            var tillname = $("#till-select option:selected").text();
            $.ajax(
            {
                type: "GET",
                url: "/cgi-bin/koha/svc/tills/" +
                    tillid,
                success: function(data)
                {
                    $('#KohaStaffClient').text(tillname);
                    $('#selectTill').modal('hide');
                },
                error: function(data)
                {
                    $('#selectTill').modal('hide');
                }
            });
            return false; // avoid to execute the actual submit of the form.
        });

        $('#selectTillSubmit').click(function()
        {
            $("#selectTillForm").submit();
        });
    });
    //]]>
</script>

<!-- selectTill Modal -->
<div id="selectTill" class="modal hide fade" tabindex="-1" role="dialog">
    <div class="modal-header">
        <button type="button" class="closebtn" data-dismiss="modal" aria-hidden="true">x</button>
        <h3 id="selectTillHeader">Set till</h3>
    </div>
    <div class="modal-body">
        <form id="selectTillForm">
            <fieldset class="rows">
                <ol>
                    <li>
                        <label for="till">Choose till:</label>
                        <select name="till" id="till-select">
                            [% FOREACH till IN tills_loop %]
                            <option value="[% till.tillid %]">[% till.name %]</option>
                            [% END %]
                        </select>
                    </li>
                </ol>
            </fieldset>
        </form>
    </div>
    <div class="modal-footer">
        <button class="btn" data-dismiss="modal" aria-hidden="true">Close</button>
        <button type="submit" id="selectTillSubmit" class="btn btn-primary">Submit</button>
    </div>
</div>
