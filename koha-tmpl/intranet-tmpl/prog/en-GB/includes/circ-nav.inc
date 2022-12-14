[% USE Koha %]
[% USE Branches %]
<div id="navmenu">
 <div id="navmenulist">

 <ul>
 <li><a href="/cgi-bin/koha/circ/circulation-home.pl">Circulation home</a></li>
 </ul>

 <h5>Circulation</h5>
 <ul>
 <li><a href="/cgi-bin/koha/circ/circulation.pl">Issue</a></li>
 <li><a href="/cgi-bin/koha/circ/returns.pl">Return</a></li>
 <li><a href="/cgi-bin/koha/circ/renew.pl">Renew</a></li>
 [% IF !Koha.Preference('IndependentBranchesTransfers') || CAN_user_superlibrarian %]
 <li><a href="/cgi-bin/koha/circ/branchtransfers.pl">Transfer</a></li>
 [% END %]
 [% IF !( Koha.Preference('IndependentBranches') && !CAN_user_superlibrarian && !CAN_user_editcatalogue_edit_catalogue ) %]
 [% IF Koha.Preference('UseCirculationDesks') %]
 <li><a href="/cgi-bin/koha/circ/set-library.pl">Set library and desk</a></li>
 [% ELSE %]
 <li><a href="/cgi-bin/koha/circ/set-library.pl">Set library</a></li>
 [% END %]
 [% ELSIF Koha.Preference('UseCirculationDesks') %]
 <li><a href="/cgi-bin/koha/circ/set-library.pl">Set desk</a></li>
 [% END %]
 [% IF ( fast_cataloging ) %][% IF ( CAN_user_editcatalogue_fast_cataloging ) %]
 <li><a href="/cgi-bin/koha/cataloguing/addbiblio.pl?frameworkcode=FA">Fast cataloguing</a></li>
 [% END %][% END %]
 [% IF Koha.Preference('AllowCheckoutNotes') && CAN_user_circulate_manage_checkout_notes %]
 <li><a href="/cgi-bin/koha/circ/checkout-notes.pl">Issue notes</a> [% IF pending_checkout_notes.count %]<span class="number_box"><a href="/cgi-bin/koha/circ/checkout-notes.pl">[% pending_checkout_notes.count | html %]</a></span>[% END %]</li>
 [% END %]
 </ul>

 <h5>Circulation reports</h5>
 <ul>
 <li><a href="/cgi-bin/koha/circ/view_holdsqueue.pl">Reserves queue</a></li>
 <li><a href="/cgi-bin/koha/circ/pendingreserves.pl">Reservations to pull</a></li>
 <li><a href="/cgi-bin/koha/circ/waitingreserves.pl">Reservations awaiting pickup</a></li>
 <li><a href="/cgi-bin/koha/circ/reserveratios.pl">Reserve ratios</a></li>
 <li><a href="/cgi-bin/koha/circ/transferstoreceive.pl">Transfers to receive</a></li>
 [% IF ( CAN_user_circulate_overdues_report ) %]
 <li><a href="/cgi-bin/koha/circ/overdue.pl">Overdues</a></li>
 [% END %]
 <li><a href="/cgi-bin/koha/circ/branchoverdues.pl">Overdues with fines</a></li>
 [% IF Koha.Preference('OnSiteCheckouts') %]
 <li><a href="/cgi-bin/koha/circ/on-site_checkouts.pl">Pending on-site loans</a></li>
 [% END %]
 </ul>

 </div>
</div>
