[% USE Koha %]
[% PROCESS 'i18n.inc' %]
[% cwd = whole.cwd %]
[% PROCESS "${cwd}/shared-includes/form_input_helpers.inc" %]
[% IF whole.error %]
[% IF whole.status == 'missing_identifier' %]
<p><em>Please Note:</em> Mandatory field Identifier is missing.</p>
[% ELSIF whole.status == 'missing_type' %]
<p><em>Please Note:</em> Type is a mandatory field.</p>
[% ELSIF whole.status == 'missing_unauth_data' %]
<p><em>Please Note:</em> Patron data (first name, last name and e-mail) are mandatory fields.</p>
[% ELSIF whole.status == 'unauth_patron_email_exists' %]
<p><em>Please Note:</em> E-mail address already exists.</p>
[% ELSIF whole.status == 'missing_branch' %]
<p><em>Please Note:</em> Branch is a mandatory field.</p>
[% ELSIF whole.status == 'invalid_borrower' %]
<p><em>Please Note:</em> The borrower details you entered are invalid.</p>
[% ELSIF whole.status == 'invalid_branch' %]
<p><em>Please Note:</em> The branch you chose is invalid.</p>
[% ELSE %]
<p>Unhandled error</p>
[% END %]
[% END %]
[% SET opac = whole.value.other.opac %]

[% IF whole.stage == "form" %]
[% IF Koha.Preference('AutoILLBackend') %]
  <h2>Create an automatic ILL request</h2>
[% ELSE %]
  <h2>Create a manual ILL request</h2>
[% END %]
<form id="create_form" method="POST" action="">
  <fieldset class="rows">
    <legend>General details</legend>
    <ol id="general-standard-fields">
    [% WRAPPER ill_select_field id = 'type' label = t('Type') %]
      <li>
          <option value=""/>
          [% IF whole.value.other.type.lower == "book" %]
          <option value="book" selected="selected">Book</option>
          [% ELSE %]
          <option value="book">Book</option>
          [% END %]
          [% IF whole.value.other.type.lower == "chapter" %]
          <option value="chapter" selected="selected">Chapter</option>
          [% ELSE %]
          <option value="chapter">Chapter</option>
          [% END %]
          [% IF whole.value.other.type.lower == "journal" %]
          <option value="journal" selected="selected">Journal</option>
          [% ELSE %]
          <option value="journal">Journal</option>
          [% END %]
          [% IF whole.value.other.type.lower == "article" %]
          <option value="article" selected="selected">Journal article</option>
          [% ELSE %]
          <option value="article">Journal article</option>
          [% END %]
          [% IF whole.value.other.type.lower == "thesis" %]
          <option value="thesis" selected="selected">Thesis</option>
          [% ELSE %]
          <option value="thesis">Thesis</option>
          [% END %]
          [% IF whole.value.other.type.lower == "conference" %]
          <option value="conference" selected="selected">Conference</option>
          [% ELSE %]
          <option value="conference">Conference</option>
          [% END %]
          [% IF whole.value.other.type.lower == "dvd" %]
          <option value="dvd" selected="selected">DVD</option>
          [% ELSE %]
          <option value="dvd">DVD</option>
          [% END %]
          [% IF whole.value.other.type.lower == "other" %]
          <option value="other" selected="selected">Other</option>
          [% ELSE %]
          <option value="other">Other</option>
          [% END %]
          [% IF whole.value.other.type.lower == "resource" %]
          <option value="resource" selected="selected">Generic resource</option>
          [% ELSE %]
          <option value="resource">Generic resource</option>
          [% END %]
        </li>
    [% END #ill_select_field %]
    </ol>
  </fieldset>
  [% type = whole.value.other.type %]
  [% IF type %]
      [% INCLUDE "${cwd}/shared-includes/forms/${type}.inc" %]
  [% END %]
  [% INCLUDE "${cwd}/shared-includes/custom_fields.inc" %]
  <fieldset class="rows">
    <legend>Patron options</legend>
    <ol>
      <li>
        [% IF unauthenticated_ill && !logged_in_user%]
        [% PROCESS ill_text_input_field id = 'unauthenticated_first_name' label = t('First name') %]
        [% PROCESS ill_text_input_field id = 'unauthenticated_last_name' label = t('Label name') %]
        [% PROCESS ill_text_input_field id = 'unauthenticated_email' label = t('E-mail address') %]
        [% END %]
        [% WRAPPER ill_select_field id = 'branchcode' label = t('Destination library') %]
          <option value="" />
          [% FOREACH branch IN branches %]
            [% IF whole.value.other.branchcode && branch.branchcode == whole.value.other.branchcode %]
            <option value="[% branch.branchcode | html %]" selected>
              [% branch.branchname | html %]
            </option>
            [% ELSE %]
            <option value="[% branch.branchcode | html %]">
              [% branch.branchname | html %]
            </option>
            [% END %]
          [% END %]
        [% END #ill_select_field %]
      </li>
    </ol>
  </fieldset>

  <fieldset class="action">
    <input id="ill-submit" class="btn btn-default" type="submit" value="Create"/>
    <a class="cancel" href="/cgi-bin/koha/opac-illrequests.pl">Cancel</a>
  </fieldset>
  <input type="hidden" name="method" value="create" />
  <input type="hidden" name="stage" value="form" />
  <input type="hidden" name="backend" value="Standard" />
</form>

[% ELSE %]
<p>Unknown stage.  This should not have happened.

[% END %]
[% BLOCK backend_jsinclude %]
<script>
    // <![CDATA[]
    [% INCLUDE "${cwd}/shared-includes/shared.js" %]
    // ]]>
</script>
[% END %]