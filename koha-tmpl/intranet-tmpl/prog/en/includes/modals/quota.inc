<!-- Add/Edit quota modal -->
<div class="modal" id="quotaModal" tabindex="-1" role="dialog" aria-labelledby="quotaLabel">
    <form method="get" id="quotaForm">
        <div class="modal-dialog">
            <div class="modal-content">
                <div class="modal-header">
                    <h1 class="modal-title" id="quotaLabel">Add Quota</h1>
                    <button type="button" class="closebtn" data-dismiss="modal" aria-label="Close">
                        <span aria-hidden="true">&times;</span>
                    </button>
                </div>
                <div class="modal-body overflow-visible">
                    <div id="quota_result"></div>
                    <input type="hidden" name="quota_id" id="quota_id">
                    <input type="hidden" name="patron_id" id="patron_id">
                    <fieldset class="rows">
                        <ol>
                            <li>
                                <label class="required" for="description">Description: </label>
                                <input type="text" id="quota_description" name="description" required="required">
                                <span class="required">Required</span>
                            </li>
                            <li>
                                <label for="quota_from" class="required">
                                    Start date:
                                </label>
                                <input type="text" id="quota_from" name="start_date"  maxlength="10" size="10" class="flatpickr" data-date_to="quota_to" />
                                <span class="required">Required</span>
                                <div class="hint">[% INCLUDE 'date-format.inc' %]</div>
                            </li>
                            <li>
                                <label for="quota_to" class="required">
                                    End date:
                                </label>
                                <input type="text" id="quota_to" name="end_date" maxlength="10"  size="10" class="flatpickr" />
                                <span class="required">Required</span>
                                <div class="hint">[% INCLUDE 'date-format.inc' %]</div>
                            </li>
                            <li>
                                <label class="required" for="allocation">Loan allocation: </label>
                                <input type="number" min="0" id="quota_allocation" name="allocation" required="required">
                                <span class="required">Required</span>
                            </li>
                        </ol>
                    </fieldset> <!-- /.brief -->
                </div> <!-- /.modal-body -->
                <div class="modal-footer">
                    <button type="button" class="btn btn-default" data-dismiss="modal">Cancel</button> 
                    <button type="submit" class="btn btn-primary" id="quotaFormSubmit">Add</button>
                </div> <!-- /.modal-footer -->
            </div> <!-- /.modal-content -->
        </div> <!-- /.modal-dialog -->
    </form>
</div> <!-- /#quotaModal -->

<!-- Delete Quota modal form -->
<div id="deleteQuotaModal" class="modal" tabindex="-1" role="dialog" aria-labelledby="deleteQuotaModalLabel">
    <form method="delete" id="deleteForm">
        <input type="hidden" name="quota_id" id="quota_id_delete">
        <input type="hidden" name="patron_id" id="patron_id_delete">
        <div class="modal-dialog" role="document">
            <div class="modal-content">
                <div class="modal-header">
                    <h1 class="modal-title" id="deleteQuotaModalLabel">Delete quota</h1>
                    <button type="button" class="closebtn" data-dismiss="modal" aria-label="Close">
                        <span aria-hidden="true">&times;</span>
                    </button>
                </div>
                <div class="modal-body">
                    <p>Are you sure you want to delete this quota?</p>
                </div>
                <div class="modal-footer">
                    <button type="button" id="deleteQuotaModaCancelBtn" data-dismiss="modal" class="btn btn-default deny"><i class="fa fa-times" aria-hidden="true"></i> No</button>
                    <button type="submit" id="deleteQuotaModaConfirmBtn" class="btn btn-default approve"><i class="fa fa-check" aria-hidden="true"></i> Yes</button>
                </div>
            </div>
        </div>
    </form>
</div>

<!-- Quota usage modal -->
<div id="quotaUsageModal" class="modal" tabindex="-1" role="dialog" aria-labelledby="quotaUsageModalLabel">
    <div class="modal-dialog" role="document">
        <div class="modal-content">
            <div class="modal-header">
                <h4 class="modal-title" id="quotaUsageModalLabel">Quota usage details</h4>
                <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
            </div>
            <div class="modal-body">
                <table id="usage_detail"></table>
            </div>
            <div class="modal-footer">
                <button type="button" id="quotaUsageModalCloseBtn" data-bs-dismiss="modal" class="btn btn-default deny"><i class="fa fa-times" aria-hidden="true"></i> Close</button>
            </div>
        </div>
    </div>
</div>

<style>
.modal-header {
    position: relative;
    padding: 15px;
}

.modal-header .closebtn {
    position: absolute;
    right: 15px;
    top: 15px;
    font-size: 21px;
    font-weight: bold;
    border: 0;
    background: transparent;
}

.modal-title {
    margin: 0;
    line-height: 1.42857143;
}
</style>
