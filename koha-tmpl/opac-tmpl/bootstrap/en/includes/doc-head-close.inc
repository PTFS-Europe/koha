[% USE raw %]
[% USE Koha %]
[% USE Branches %]
[%- USE KohaPlugins -%]
[% USE Asset %]
<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
<meta name="generator" content="Koha" />
<!-- leave this for stats -->
<meta name="viewport" content="width=device-width, initial-scale=1" />
<meta name="csrf-token" content="[% Koha.GenerateCSRF | $raw %]" />
[% IF ( Koha.Preference('OpacMetaDescription') ) %]
    <meta name="description" content="[% Koha.Preference('OpacMetaDescription') | html %]" />
[% END %]
[% IF ( Koha.Preference('OpacMetaRobots') ) %]
    <meta name="robots" content="[% Koha.Preference('OpacMetaRobots') | html %]" />
[% END %]
<link rel="shortcut icon" href="[% IF ( Koha.Preference('OpacFavicon') ) %][% Koha.Preference('OpacFavicon') | url %][% ELSE %][% interface | url %]/[% theme | url %]/images/favicon.ico[% END %]" type="image/x-icon" />
<link rel="apple-touch-icon" href="[% IF ( Koha.Preference('OpacFavicon') ) %][% Koha.Preference('OpacFavicon') | url %][% ELSE %][% interface | url %]/[% theme | url %]/images/favicon.ico[% END %]" type="image/x-icon" />
[% IF ( Koha.Preference('opaclayoutstylesheet') && Koha.Preference('opaclayoutstylesheet') != "opac.css" ) %]
    [% SET opaclayoutstylesheet = Koha.Preference('opaclayoutstylesheet') %]
[% ELSE %]
    [% IF ( bidi ) %]
        [% SET opaclayoutstylesheet = 'opac-rtl.css' %]
    [% ELSE %]
        [% SET opaclayoutstylesheet = 'opac.css' %]
    [% END %]
[% END %]
[% IF (opaclayoutstylesheet.match('^https?:|^\/')) %]
    <link rel="stylesheet" type="text/css" href="[% opaclayoutstylesheet | url %]" />
[% ELSE %]
    [% Asset.css("css/" _ opaclayoutstylesheet) | $raw %]
[% END %]
[% IF ( Koha.Preference('OpacAdditionalStylesheet') ) %]
    [% SET OpacAdditionalStylesheet = Koha.Preference('OpacAdditionalStylesheet') %]
    [% IF (OpacAdditionalStylesheet.match('^https?:|^\/')) %]
        <link rel="stylesheet" type="text/css" href="[% OpacAdditionalStylesheet | url %]" />
    [% ELSE %]
        <link rel="stylesheet" type="text/css" href="[% interface | url %]/[% theme | url %]/css/[% OpacAdditionalStylesheet | url %]" />
    [% END %]
[% END %]
[% IF ( opac_css_override ) %]
    <link rel="stylesheet" type="text/css" href="[% interface | url %]/[% theme | url %]/css/[% opac_css_override | url %]" />
[% END %]
[% IF ( bidi ) %]
    [% Asset.css("css/print-rtl.css", { media = "print" }) | $raw %]
[% ELSE %]
    [% Asset.css("css/print.css", { media = "print" }) | $raw %]
[% END %]
[% IF ( Koha.Preference('OPACUserCSS') ) %]
    <!-- prettier-ignore-start -->
    <style>[% Koha.Preference('OPACUserCSS') | $raw %]</style>
    <!-- prettier-ignore-end -->
[% END %]
[% IF Branches.GetBranchSpecificCSS( Branches.GetLoggedInBranchcode() || default_branch) %]
    <!-- prettier-ignore-start -->
    <style>
        [% Branches.GetBranchSpecificCSS( Branches.GetLoggedInBranchcode() || default_branch) | $raw %]
    </style>
    <!-- prettier-ignore-end -->
[% END %]
[% IF SCO_login %]
    [% SET SCOUserCSS = Koha.Preference('SCOUserCSS') %]
    [% IF SCOUserCSS %]
        <!-- prettier-ignore-start -->
        <style>[% SCOUserCSS | $raw %]</style>
        <!-- prettier-ignore-end -->
    [% END %]
[% END %]
[% IF ( Koha.Preference('OPACBaseURL') ) %]
    <link rel="search" type="application/opensearchdescription+xml" href="[% Koha.Preference('OPACBaseURL') | url %]/cgi-bin/koha/opac-search.pl?format=opensearchdescription" title="Search [% LibraryNameTitle | html %]" />
    <link rel="unapi-server" type="application/xml" title="unAPI" href="[% Koha.Preference('OPACBaseURL') | url %]/cgi-bin/koha/unapi" />
[% END %]
[% FILTER collapse %]
    [% PROCESS cssinclude %]
[% END %]
<script>
    var Koha = {};
    function _(s) { return s } // dummy function for gettext
    const is_logged_in = [% IF logged_in_user %]true[% ELSE %]false[% END %]
</script>
[% IF lang && lang != 'en' %]
    [% Asset.js(lang _ '/js/locale_data.js') | $raw %]
[% END %]
[% Asset.js('js/Gettext.js') | $raw %]
[% Asset.js('js/i18n.js') | $raw %]

[% Asset.css("lib/fontawesome/css/fontawesome.min.css") | $raw %]
[% Asset.css("lib/fontawesome/css/brands.min.css") | $raw %]
[% Asset.css("lib/fontawesome/css/solid.min.css") | $raw %]
[% PROCESS 'html_helpers.inc' %]
[% KohaPlugins.get_plugins_opac_head | $raw %]
