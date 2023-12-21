<!-- Add problem report modal -->
<div class="modal" id="reportProblemModal" tabindex="-1" role="dialog" aria-labelledby="reportProblemModalLabel" aria-hidden="true">
    <div class="modal-dialog modal-lg">
        <div class="modal-content">
            <div class="modal-header">
                <h3 class="modal-title" id="reportProblemModalLabel">Report a problem</h3>
                <button type="button" class="closebtn" data-dismiss="modal" aria-label="Close">
                    <span aria-hidden="true">&times;</span>
                </button>
            </div>
            <div class="modal-body">
                <fieldset id="problem_fieldset">
                    <div class="form-group">
                        <label for="problem_recipient">Recipient: </label>
                        [% IF library.inbound_email_address && library.inbound_email_address != Koha.Preference('KohaAdminEmailAddress') %]
                            <select name="recipient" id="recipient">
                                <option value="library">A librarian</option>
                                <option value="admin">System administrator</option>
                            </select>
                        [% ELSE %]
                            <span>System administrator</span>
                        [% END %]
                    </div>
                    <div class="form-group">
                        <label for="problem_subject">Subject: </label>
                        <input type="text" name="problem_subject" id="problem_subject" required="required"/>
                    </div>
                    <div class="form-group">
                        <label for="problem_body">Please describe the problem: </label>
                        <textarea class="form-control" name="problem_body" id="problem_body" aria-describedby="helpBlock" required="required" rows="15"></textarea>
                    </div>
                </fieldset>
            </div>
            <div class="modal-footer">
                <input type="hidden" name="page_url" id="page_url" value="">
                <input type="hidden" name="reporter_id" id="problem_reporter" value="[% logged_in_user.borrowernumber | html %]">
                <button type="submit" class="addConfirm btn btn-primary">Submit <i id="problem-submit-spinner" class="fa fa-spinner fa-pulse fa-fw" style="display:none"></i></button>
                <button type="button" class="btn btn-default" data-dismiss="modal">Cancel</button>
            </div>
        </div>
    </div>
</div>
