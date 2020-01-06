<form id="mod_notes_multiple_[% type %]" action="/cgi-bin/koha/acqui/modordernotes_multiple.pl" method="post">
	<input type="hidden" id="orders_modified_[%type %]" name="orders_modified" value="">
	<input type="hidden" id="orders_all_[% type %]" name="orders_all" value="">
	<input type="hidden" name="type" value="[% type %]">
	<input type="hidden" name="note" value="[% note %]">
	<button style="display:none;left-margin: 2em;" type="submit" class="btn btn-default btn-xs btn_add_notes">Add note to items</button>
	<button style="left-margin: 2em" type="submit" class="btn btn-default btn-xs btn_clear_notes">Clear all item [% type %] notes</button>
</form>
