<div class="modal" id="addQuickAddUserModal" tabindex="-1" role="dialog"
        aria-labelledby="addQuickAddUserModalLabel" aria-hidden="true">
        <form id="quick_add_user_form">
        <div class="modal-dialog modal-md" role="document">
            <div class="modal-content modal-md">
                <div class="modal-header">
                    <button type="button" class="closebtn" data-dismiss="modal"
                        aria-label="Close">
                        <span aria-hidden="true">&times;</span>
                    </button>
                    <h4 class="modal-title" id="addQuickAddUserModalLabel">Add patron
                    </h4>
                </div>
                <div class="modal-body">
                    <fieldset class="rows" id="quick_add_user_fieldset">
                        <ol>
                            <li>
                                <label for="surname" class="required">
                                    Surname: </label>
                                <input type="text" id="surname_quick_add" name="surname" size="20"
                                    value="" required="" class="noEnterSubmit">
                                <span class="required">Required</span>
                            </li>
                            <li>
                                <label for="cardnumber" class="required">
                                    Card number:
                                </label>
                                <!-- NOTE: div.hint closing tag isn't on the same line -->
                                <input type="text" id="cardnumber_quick_add" name="cardnumber" size="20"
                                    value="" minlength="1" maxlength="32" required=""
                                    class="noEnterSubmit">
                                <span class="required">Required</span>
                                <span id="cn_max" class="required" style="display: none;">Card number
                                    must not be more than 32 characters.</span>
                                <div class="hint">Card number must be between 1 and 32 characters.
                                </div>
                                <!--/div.hint -->
                            </li>
                            <li>
                                <label for="libraries" class="required">Library:</label>
                                <select name="branchcode" id="libraries_quick_add"
                                    class="noEnterSubmit">
                                    
                                </select>
                                <span class="required">Required</span>
                            </li>
                            <li>
                                <label for="categorycode_entry" class="required">Category: </label>
                                <select id="categorycode_entry_quick_add" name="categorycode"
                                    class="noEnterSubmit">
                                </select>
                                <span class="required">Required</span>
                            </li>
                        </ol>
                    </fieldset>
                </div> <!-- /.modal-body -->
                <div class="modal-footer">
                    <input type="hidden" id="quick_add_user_biblio" name="biblio_id"
                        value="test">
                    <button type="submit" class="btn btn-primary"
                        id="addConfirm">Submit <i id="user-submit-spinner"
                            class="fa fa-spinner fa-pulse fa-fw"
                            style="display:none"></i></button>
                    <button type="button" class="btn btn-default"
                        data-dismiss="modal">Cancel</button>
                </div> <!-- /.modal-footer -->
            </div> <!-- /.modal-content -->
        </div> <!-- /.modal-dialog -->
        </form>
    </div> <!-- /#addQuickAddUserModal -->