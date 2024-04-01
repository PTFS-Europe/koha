[% BLOCK translate_log_module %]
[%    SWITCH module %]
[%        CASE 'AUTH'         %]<span>Authentication</span>[% UNLESS Koha.Preference('AuthFailureLog') || Koha.Preference('AuthScuccessLog') %] <i class="fa-solid fa-triangle-exclamation" title="Log not enabled"></i>[% END %]
[%        CASE 'CATALOGUING'  %]<span>Catalog</span>[% UNLESS Koha.Preference('CataloguingLog') %] <i class="fa-solid fa-triangle-exclamation" title="Log not enabled"></i>[% END %]

[%        CASE 'AUTHORITIES'  %]<span>Authorities</span>[% UNLESS Koha.Preference('AuthoritiesLog') %] <i class="fa-solid fa-triangle-exclamation" title="Log not enabled"></i>[% END %]

[%        CASE 'MEMBERS'      %]<span>Patrons</span>[% UNLESS Koha.Preference('BorrowersLog') %] <i class="fa-solid fa-triangle-exclamation" title="Log not enabled"></i>[% END %]

[%        CASE 'ACQUISITIONS' %]<span>Acquisitions</span>[% UNLESS Koha.Preference('AcquisitionLog') %]<i class="fa-solid fa-triangle-exclamation" title="Log not enabled"></i>[% END %]

[%        CASE 'SERIAL'       %]<span>Serials</span>[% UNLESS Koha.Preference('SubscriptionLog') %] <i class="fa-solid fa-triangle-exclamation" title="Log not enabled"></i>[% END %]

[%        CASE 'HOLDS'        %]<span>Holds</span>[% UNLESS Koha.Preference('HoldsLog') %] <i class="fa-solid fa-triangle-exclamation" title="Log not enabled"></i>[% END %]

[%        CASE 'ILL'          %]<span>Interlibrary loans</span>[% UNLESS Koha.Preference('IllLog') %] <i class="fa-solid fa-triangle-exclamation" title="Log not enabled"></i>[% END %]

[%        CASE 'CIRCULATION'  %]<span>Circulation</span>[% UNLESS Koha.Preference('IssueLog') %] <i class="fa-solid fa-triangle-exclamation" title="Log not enabled"></i>[% END %]

[%        CASE 'CLAIMS'       %]<span>Claims</span>[% UNLESS Koha.Preference('ClaimsLog') %] <i class="fa-solid fa-triangle-exclamation" title="Log not enabled"></i>[% END %]

[%        CASE 'FINES'        %]<span>Fines</span>[% UNLESS Koha.Preference('FinesLog') %] <i class="fa-solid fa-triangle-exclamation" title="Log not enabled"></i>[% END %]

[%        CASE 'SYSTEMPREFERENCE' %]<span>System preferences</span>

[%        CASE 'CRONJOBS' %]<span>Cron jobs</span>[% UNLESS Koha.Preference('CronjobLog') %] <i class="fa-solid fa-triangle-exclamation" title="Log not enabled"></i>[% END %]

[%        CASE 'REPORTS'      %]<span>Reports</span>[% UNLESS Koha.Preference('ReportsLog') %] <i class="fa-solid fa-triangle-exclamation" title="Log not enabled"></i>[% END %]

[%        CASE 'SEARCHENGINE' %]<span>Search engine</span>

[%        CASE 'NOTICES'      %]<span>Notices</span>[% UNLESS Koha.Preference('NoticesLog') %] <i class="fa-solid fa-triangle-exclamation" title="Log not enabled"></i>[% END %]
[%        CASE 'NEWS'      %]<span>News</span>[% UNLESS Koha.Preference('NewsLog') %] <i class="fa-solid fa-triangle-exclamation" title="Log not enabled"></i>[% END %]
[%        CASE 'RECALLS'      %]<span>Recalls</span>[% UNLESS Koha.Preference('RecallsLog') %] <i class="fa-solid fa-triangle-exclamation" title="Log not enabled"></i>[% END %]

[%        CASE %][% module | html %]
[%    END %]
[% END %]

[% BLOCK translate_log_action %]
[%    SWITCH action %]
[%        CASE 'ADD'    %]<span>Add</span>
[%        CASE 'DELETE' %]<span>Delete</span>
[%        CASE 'MODIFY' %]<span>Modify</span>
[%        CASE 'ISSUE'  %]<span>Checkout</span>
[%        CASE 'RETURN' %]<span>Return</span>
[%        CASE 'CREATE' %]<span>Create</span>
[%        CASE 'CANCEL' %]<span>Cancel</span>
[%        CASE 'FILL'   %]<span>Fill</span>
[%        CASE 'RESUME' %]<span>Resume</span>
[%        CASE 'SUSPEND' %]<span>Suspend</span>
[%        CASE 'RENEW'  %]<span>Renew</span>
[%        CASE 'RENEWAL' %]<span>Renew</span>
[%        CASE 'CHANGE PASS' %]<span>Change password</span>
[%        CASE 'RESET PASS' %]<span>Reset password</span>
[%        CASE 'ADDCIRCMESSAGE' %]<span>Add circulation message</span>
[%        CASE 'MODCIRCMESSAGE' %]<span>Modify circulation message</span>
[%        CASE 'DELCIRCMESSAGE' %]<span>Delete circulation message</span>
[%        CASE 'STATUS_CHANGE'  %]<span>Change ILL request status</span>
[%        CASE 'PATRON_NOTICE'  %]<span>ILL notice sent to patron</span>
[%        CASE 'ADD_BASKET' %]<span>Create an acquisitions basket</span>
[%        CASE 'MODIFY_BASKET' %]<span>Modify an acquisitions basket</span>
[%        CASE 'MODIFY_BASKET_HEADER' %]<span>Modify an acquisitions basket header</span>
[%        CASE 'MODIFY_BASKET_USERS' %]<span>Modify an acquisitions basket's users</span>
[%        CASE 'CLOSE_BASKET' %]<span>Close an acquisitions basket</span>
[%        CASE 'APPROVE_BASKET' %]<span>Approve an acquisitions basket</span>
[%        CASE 'REOPEN_BASKET' %]<span>Reopen an acquisitions basket</span>
[%        CASE 'CANCEL_ORDER' %]<span>Cancel an order</span>
[%        CASE 'CREATE_ORDER' %]<span>Create an order</span>
[%        CASE 'MODIFY_ORDER' %]<span>Modify an order</span>
[%        CASE 'CREATE_INVOICE_ADJUSTMENT' %]<span>Create an invoice adjustment</span>
[%        CASE 'UPDATE_INVOICE_ADJUSTMENT' %]<span>Modify an invoice adjustment</span>
[%        CASE 'DELETE_INVOICE_ADJUSTMENT' %]<span>Delete an invoice adjustment</span>
[%        CASE 'RECEIVE_ORDER' %]<span>Receive an order</span>
[%        CASE 'MODIFY_BUDGET' %]<span>Modify a budget</span>
[%        CASE 'CREATE_FUND' %]<span>Create a fund</span>
[%        CASE 'MODIFY_FUND' %]<span>Modify a fund</span>
[%        CASE 'DELETE_FUND' %]<span>Delete a fund</span>
[%        CASE 'Run'    %]<span>Run</span>
[%        CASE 'End'    %]<span>End</span>
[%        CASE 'EDIT_MAPPINGS' %]<span>Edit mappings</span>
[%        CASE 'RESET_MAPPINGS' %]<span>Reset mappings</span>
[%        CASE 'SERIAL CLAIM' %]<span>Serial claim</span>
[%        CASE 'ACQUISITION CLAIM' %]<span>Acquisition claim</span>
[%        CASE 'ACQUISITION ORDER' %]<span>Acquisition order</span>
[%        CASE 'OVERDUE' %]<span>Overdue</span>
[%        CASE 'EXPIRE'  %]<span>Expire</span>
[%        CASE %][% action | html %]
[%    END %]
[% END %]

[% BLOCK translate_log_interface %]
[%    SWITCH log_interface.upper %]
[%        CASE 'INTRANET'    %]<span>Staff interface</span>
[%        CASE 'OPAC'        %]<span>OPAC</span>
[%        CASE 'SIP'         %]<span>SIP</span>
[%        CASE 'COMMANDLINE' %]<span>Command-line</span>
[%        CASE 'API'         %]<span>REST API</span>
[%        CASE 'CRON'        %]<span>Cron job</span>
[%        CASE 'UPGRADE'     %]<span>Upgrade</span>
[%        CASE %]<span>[% log_interface | html %]</span>
[%    END %]
[% END %]