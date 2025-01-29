<!-- Add/Edit quota modal -->
<div class="modal" id="quotaModal" tabindex="-1" role="dialog" aria-labelledby="quotaLabel">
    <form method="get" id="quotaForm">
        <div class="modal-dialog">
            <div class="modal-content">
                <div class="modal-header">
                    <h1 class="modal-title" id="quotaLabel"></h1>
                    <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
                </div>
                <div class="modal-body overflow-visible">
                    <div id="quota_result"></div>
                    <input type="hidden" name="quota_id" id="quota_id">
                    <input type="hidden" name="patron_id" id="quota_patron_id">
                    <fieldset class="rows">
                        <ol>
                            <li>
                                <label class="required" for="amount">Returned to patron: </label>
                                <input type="text" inputmode="numeric" pattern="[0-9]*" id="amount" name="amount" required="required">
                                <span class="required">Required</span>
                            </li>
                        </ol>
                    </fieldset> <!-- /.brief -->
                </div> <!-- /.modal-body -->
                <div class="modal-footer">
                    <button type="submit" class="btn btn-primary approve" id="quotaFormSubmit"></button>
                    <button type="button" class="btn btn-default deny cancel" data-bs-dismiss="modal"><i class="fa fa-times"></i> Cancel</button>
                </div> <!-- /.modal-footer -->
            </div> <!-- /.modal-content -->
        </div> <!-- /.modal-dialog -->
    </form>
</div> <!-- /#quotaModal -->
