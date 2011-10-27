[% IF ( opaccredits ) %]
	<div class="ft">
        [% opaccredits %]
     </div>
[% END %]
</div>

[% IF ( opaclanguagesdisplay || OpacKohaUrl ) %]
<div id="wrapper-ft" class="ft">
[% IF ( languages_loop && opaclanguagesdisplay ) %]
    <div id="changelanguage">
    [% UNLESS ( one_language_enabled ) %]
        <div class="lang"><strong>Languages: </strong></div>
        [% FOREACH languages_loo IN languages_loop %]
	    <div class="lang">
            [% IF ( languages_loo.group_enabled ) %]
            [% IF ( languages_loo.plural ) %]
            <a id="show[% languages_loo.rfc4646_subtag %]" class="sublangs more" href="#">[% IF ( languages_loo.native_description ) %][% languages_loo.native_description %][% ELSE %][% languages_loo.rfc4646_subtag %][% END %]</a>[% UNLESS ( loop.last ) %] | [% END %]
			<div id="sub[% languages_loo.rfc4646_subtag %]">
            <div class="bd"><ul>
            [% FOREACH sublanguages_loo IN languages_loo.sublanguages_loop %]
		[% IF ( sublanguages_loo.enabled ) %]
                [% IF ( sublanguages_loo.sublanguage_current ) %]
                    <li> [% sublanguages_loo.native_description %] [% sublanguages_loo.script_description %] [% sublanguages_loo.region_description %] [% sublanguages_loo.variant_description %] ([% sublanguages_loo.rfc4646_subtag %])</li>
                [% ELSE %]
                <li><a href="/cgi-bin/koha/opac-changelanguage.pl?language=[% sublanguages_loo.rfc4646_subtag %]"> [% sublanguages_loo.native_description %] [% sublanguages_loo.script_description %] [% sublanguages_loo.region_description %] [% sublanguages_loo.variant_description %] ([% sublanguages_loo.rfc4646_subtag %])</a></li>
                [% END %]
               [% END %]
            [% END %]
            </ul>
			</div>
			</div>
            [% ELSE %]
		      [% IF ( languages_loo.group_enabled ) %]
                [% IF ( languages_loo.current ) %]
                    [% IF ( languages_loo.native_description ) %][% languages_loo.native_description %][% ELSE %][% languages_loo.rfc4646_subtag %][% END %]
                [% ELSE %]
                    <a href="/cgi-bin/koha/opac-changelanguage.pl?language=[% languages_loo.rfc4646_subtag %]">[% IF ( languages_loo.native_description ) %][% languages_loo.native_description %][% ELSE %][% languages_loo.rfc4646_subtag %][% END %]</a>
                [% END %]
		[% END %]
            [% END %]
            [% END %][% UNLESS ( loop.last || languages_loo.plural ) %] | [% END %]
            </div>
        [% END %]
    [% END %]
    </div>
[% END %]

[% IF ( OpacKohaUrl ) %]
   <div id="ft-ptfs">
      <p id="ptfs-credit"><a href="http://koha-community.org/"><img id=kohaftr src="/opac-tmpl/prog/images/koha-logo.png"/></a> implemented by <a href="http://www.ptfs-europe.com"><img id=ptfsftr src="/opac-tmpl/prog/images/ptfs-logo.png"/></a></p>
   </div>
[% END %]

</div>
[% END %]

[% IF ( Babeltheque ) %]
<script type="text/javascript" src="http://www.babeltheque.com/bw_30.js"></script>
[% END %]

</body>
</html>
