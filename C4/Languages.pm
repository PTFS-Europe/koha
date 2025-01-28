package C4::Languages;

# Copyright 2006 (C) LibLime
# Joshua Ferraro <jmf@liblime.com>
# Portions Copyright 2009 Chris Cormack and the Koha Dev Team
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# Koha is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Koha; if not, see <http://www.gnu.org/licenses>.


use strict;
use warnings;

use Carp qw( carp );
use CGI;
use List::MoreUtils qw( any );
use C4::Context;
use Koha::Caches;
use Koha::Cache::Memory::Lite;

our (@ISA, @EXPORT_OK);
BEGIN {
    require Exporter;
    @ISA    = qw(Exporter);
    @EXPORT_OK = qw(
        getFrameworkLanguages
        getTranslatedLanguages
        getLanguages
        getAllLanguages
    );
    push @EXPORT_OK, qw(getFrameworkLanguages getTranslatedLanguages getAllLanguages getLanguages get_bidi regex_lang_subtags language_get_description accept_language getlanguage get_rfc4646_from_iso639);
}

=head1 NAME

C4::Languages - Perl Module containing language list functions for Koha 

=head1 SYNOPSIS

use C4::Languages;

=head1 DESCRIPTION

=cut

=head1 FUNCTIONS

=head2 getFrameworkLanguages

Returns a reference to an array of hashes:

 my $languages = getFrameworkLanguages();
 for my $language(@$languages) {
    print "$language->{language_code}\n"; # language code in iso 639-2
    print "$language->{language_name}\n"; # language name in native script
    print "$language->{language_locale_name}\n"; # language name in current locale
 }

=cut

sub getFrameworkLanguages {
    # get a hash with all language codes, names, and locale names
    my $all_languages = getAllLanguages();
    my @languages;
    
    # find the available directory names
    my $dir=C4::Context->config('intranetdir')."/installer/data/";
    my $dir_h;
    opendir ($dir_h,$dir);
    my @listdir= grep { !/^\.|CVS/ && -d "$dir/$_"} readdir($dir_h);
    closedir $dir_h;

    # pull out all data for the dir names that exist
    for my $dirname (@listdir) {
        for my $language_set (@$all_languages) {

            if ($dirname eq $language_set->{language_code}) {
                push @languages, {
                    'language_code'=>$dirname, 
                    'language_description'=>$language_set->{language_description}, 
                    'native_descrition'=>$language_set->{language_native_description} }
            }
        }
    }
    return \@languages;
}

=head2 getTranslatedLanguages

Returns a reference to an array of hashes:

 my $languages = getTranslatedLanguages();
 print "Available translated languages:\n";
 for my $language(@$trlanguages) {
    print "$language->{language_code}\n"; # language code in iso 639-2
    print "$language->{language_name}\n"; # language name in native script
    print "$language->{language_locale_name}\n"; # language name in current locale
 }

=cut

sub getTranslatedLanguages {
    my ($interface, $theme, $current_language, $which) = @_;
    my @languages;
    my @enabled_languages =
      ( $interface && $interface eq 'intranet' )
      ? split ",", C4::Context->preference('StaffInterfaceLanguages')
      : split ",", C4::Context->preference('OPACLanguages');

    my $cache = Koha::Caches->get_instance;
    my $cache_key = "languages_${interface}_${theme}";
    if ($interface && $interface eq 'opac' ) {
        my $htdocs = C4::Context->config('opachtdocs');
        my $cached = $cache->get_from_cache($cache_key);
        if ( $cached ) {
            @languages = @{$cached};
        } else {
            @languages = _get_opac_language_dirs( $htdocs, $theme );
            $cache->set_in_cache($cache_key, \@languages );
        }
    }
    elsif ($interface && $interface eq 'intranet' ) {
        my $htdocs = C4::Context->config('intrahtdocs');
        my $cached = $cache->get_from_cache($cache_key);
        if ( $cached ) {
            @languages = @{$cached};
        } else {
            @languages = _get_intranet_language_dirs( $htdocs, $theme );
            $cache->set_in_cache($cache_key, \@languages );
        }
    }
    else {
        my $htdocs = C4::Context->config('intrahtdocs');
        push @languages, _get_intranet_language_dirs( $htdocs );

        $htdocs = C4::Context->config('opachtdocs');
        push @languages, _get_opac_language_dirs( $htdocs );

        my %seen;
        $seen{$_}++ for @languages;
        @languages = keys %seen;
    }
    return _build_languages_arrayref(\@languages,$current_language,\@enabled_languages);
}

=head2 getAllLanguages

Returns a reference to an array of hashes:

 my $alllanguages = getAllLanguages();
 print "Available translated languages:\n";
 for my $language(@$alllanguages) {
    print "$language->{language_code}\n";
    print "$language->{language_name}\n";
    print "$language->{language_locale_name}\n";
 }

This routine is a wrapper for getLanguages().

=cut

sub getAllLanguages {
    return getLanguages(shift);
}

=head2 getLanguages

    my $lang_arrayref = getLanguages([$lang[, $isFiltered]]);

Returns a reference to an array of hashes of languages.

- If no parameter is passed to the function, it returns english languages names
- If a $lang parameter conforming to RFC4646 syntax is passed, the function returns languages names translated in $lang
  If a language name is not translated in $lang in database, the function returns english language name
- If $isFiltered is set to true, only the detail of the languages selected in system preferences AdvanceSearchLanguages is returned.

=cut

sub getLanguages {
    my $lang = shift;
    my $isFiltered = shift;

    my $dbh = C4::Context->dbh;

    my $default_language = 'en';
    my $current_language = $default_language;
    if ($lang) {
        $current_language = regex_lang_subtags($lang)->{'language'};
    }

    my $language_list = $isFiltered ? C4::Context->preference("AdvancedSearchLanguages") : undef;
    my $language_list_cond = $language_list ? 'AND FIND_IN_SET(language_rfc4646_to_iso639.iso639_2_code, ?)' : '';

    my $sth = $dbh->prepare("
    SELECT
    language_subtag_registry.*,
    language_rfc4646_to_iso639.iso639_2_code,
    CASE
        -- If user's localized name of given lang is available
        WHEN current_language_descriptions.description IS NOT NULL
        THEN
            CASE
                -- Append native translation of given language if possible
                WHEN native_language_descriptions.description IS NOT NULL
                    AND native_language_descriptions.description != current_language_descriptions.description
                THEN CONCAT(current_language_descriptions.description, ' (', native_language_descriptions.description, ')')
                ELSE current_language_descriptions.description
            END
        ELSE -- fall back to English description
            CASE
                -- Append native translation of given language if possible
                WHEN native_language_descriptions.description IS NOT NULL
                    AND native_language_descriptions.description != language_subtag_registry.description
                THEN CONCAT(language_subtag_registry.description, ' (', native_language_descriptions.description, ')')
                ELSE language_subtag_registry.description
            END
    END AS language_description

    -- Useful if debugging the query:
    -- current_language_descriptions.description AS _current_language_descriptions_description,
    -- native_language_descriptions.description AS _native_language_descriptions_description

    FROM language_subtag_registry

    -- Grab ISO code for language
    INNER JOIN language_rfc4646_to_iso639
    ON language_rfc4646_to_iso639.rfc4646_subtag = language_subtag_registry.subtag
    AND language_rfc4646_to_iso639.iso639_2_code IS NOT NULL

    -- Grab language name in user's current language
    LEFT JOIN language_descriptions current_language_descriptions
    ON current_language_descriptions.subtag = language_subtag_registry.subtag
    AND current_language_descriptions.lang = ?
    AND current_language_descriptions.type = 'language'

    -- Grab language name in the given language itself
    LEFT JOIN language_descriptions native_language_descriptions
    ON native_language_descriptions.subtag = language_subtag_registry.subtag
    AND native_language_descriptions.lang = language_subtag_registry.subtag
    AND native_language_descriptions.type = 'language'

    WHERE language_subtag_registry.type = 'language'
    ${language_list_cond}");

    if ($language_list) {
        $sth->execute($current_language, join ',' => split(/,|\|/, $language_list));
    } else {
        $sth->execute($current_language);
    }

    my @languages_list;
    while (my $row = $sth->fetchrow_hashref) {
        push @languages_list, $row;
    }
    return \@languages_list;
}

sub _get_opac_language_dirs {
    my ( $htdocs, $theme ) = @_;

    my @languages;
    if ( $theme and -d "$htdocs/$theme" ) {
        (@languages) = _get_language_dirs($htdocs,$theme);
    }
    else {
        for my $theme ( _get_themes('opac') ) {
            push @languages, _get_language_dirs($htdocs,$theme);
        }
    }
    return @languages;
}


sub _get_intranet_language_dirs {
    my ( $htdocs, $theme ) = @_;

    my @languages;
    if ( $theme and -d "$htdocs/$theme" ) {
        @languages = _get_language_dirs($htdocs,$theme);
    }
    else {
        foreach my $theme ( _get_themes('intranet') ) {
            push @languages, _get_language_dirs($htdocs,$theme);
        }
    }
    return @languages;
}

=head2 _get_themes

Internal function, returns an array of all available themes.

  (@themes) = &_get_themes('opac');
  (@themes) = &_get_themes('intranet');

=cut

sub _get_themes {
    my $interface = shift;
    my $htdocs;
    my @themes;
    if ( $interface && $interface eq 'intranet' ) {
        $htdocs = C4::Context->config('intrahtdocs');
    }
    else {
        $htdocs = C4::Context->config('opachtdocs');
    }
    my $dir_h;
    opendir $dir_h, "$htdocs";
    my @dirlist = readdir $dir_h;
    foreach my $directory (@dirlist) {
        # if there's an en dir, it's a valid theme
        -d "$htdocs/$directory/en" and push @themes, $directory;
    }
    close $dir_h;
    return @themes;
}

=head2 _get_language_dirs

Internal function, returns an array of directory names, excluding non-language directories

=cut

sub _get_language_dirs {
    my ($htdocs,$theme) = @_;
    $htdocs //= '';
    $theme //= '';
    my @lang_strings;
    my $dir_h;
    opendir $dir_h, "$htdocs/$theme";
    for my $lang_string ( sort readdir $dir_h ) {
        next if $lang_string =~/^\./;
        next if $lang_string eq 'all';
        next if $lang_string =~/png$/;
        next if $lang_string =~/js$/;
        next if $lang_string =~/css$/;
        next if $lang_string =~/CVS$/;
        next if $lang_string =~/\.txt$/i;     #Don't read the readme.txt !
        next if $lang_string =~/img|images|famfam|js|less|lib|sound|pdf/;
        push @lang_strings, $lang_string;
    }
    close $dir_h;
    return (@lang_strings);
}

=head2 _build_languages_arrayref 

Internal function for building the ref to array of hashes

FIXME: this could be rewritten and simplified using map

=cut

sub _build_languages_arrayref {
        my ($translated_languages,$current_language,$enabled_languages) = @_;
        $current_language //= '';
        my @translated_languages = @$translated_languages;
        my @languages_loop; # the final reference to an array of hashrefs
        my @enabled_languages = @$enabled_languages;
        # how many languages are enabled, if one, take note, some contexts won't need to display it
        my $language_groups;
        my $track_language_groups;
        my $current_language_regex = regex_lang_subtags($current_language);
        # Loop through the translated languages
        for my $translated_language (@translated_languages) {
            # separate the language string into its subtag types
            my $language_subtags_hashref = regex_lang_subtags($translated_language);

            # is this language string 'enabled'?
            for my $enabled_language (@enabled_languages) {
                #warn "Checking out if $translated_language eq $enabled_language";
                $language_subtags_hashref->{'enabled'} = 1 if $translated_language eq $enabled_language;
            }
            
            # group this language, key by langtag
            $language_subtags_hashref->{'sublanguage_current'} = 1 if $translated_language eq $current_language;
            $language_subtags_hashref->{'rfc4646_subtag'} = $translated_language;
            $language_subtags_hashref->{'native_description'} = language_get_description($language_subtags_hashref->{language},$language_subtags_hashref->{language},'language');
            $language_subtags_hashref->{'script_description'} = language_get_description($language_subtags_hashref->{script},$language_subtags_hashref->{'language'},'script');
            $language_subtags_hashref->{'region_description'} = language_get_description($language_subtags_hashref->{region},$language_subtags_hashref->{'language'},'region');
            $language_subtags_hashref->{'variant_description'} = language_get_description($language_subtags_hashref->{variant},$language_subtags_hashref->{'language'},'variant');
            $track_language_groups->{$language_subtags_hashref->{'language'}}++;
            push ( @{ $language_groups->{$language_subtags_hashref->{language}} }, $language_subtags_hashref );
        }
        # $key is a language subtag like 'en'

        my %idx = map { $enabled_languages->[$_] => $_ } reverse 0 .. @$enabled_languages-1;
        my @ordered_keys = sort {
            my $aa     = '';
            my $bb     = '';
            my $acount = @{ $language_groups->{$a} };
            my $bcount = @{ $language_groups->{$b} };
            if ( $language_groups->{$a}->[0]->{enabled} ) {
                $aa = $language_groups->{$a}->[0]->{rfc4646_subtag};
            }
            elsif ( $acount > 1 ) {
                for ( my $i = 1 ; $i < $acount ; $i++ ) {
                    if ( $language_groups->{$a}->[$i]->{enabled} ) {
                        $aa = $language_groups->{$a}->[$i]->{rfc4646_subtag};
                        last;
                    }
                }
            }
            if ( $language_groups->{$b}->[0]->{enabled} ) {
                $bb = $language_groups->{$b}->[0]->{rfc4646_subtag};
            }
            elsif ( $bcount > 1 ) {
                for ( my $i = 1 ; $i < $bcount ; $i++ ) {
                    if ( $language_groups->{$b}->[$i]->{enabled} ) {
                        $bb = $language_groups->{$b}->[$i]->{rfc4646_subtag};
                        last;
                    }
                }
            }
            (         exists $idx{$aa}
                  and exists $idx{$bb}
                  and ( $idx{$aa} cmp $idx{$bb} ) )
              || ( exists $idx{$aa} and exists $idx{$bb} )
              || exists $idx{$bb}
        } keys %$language_groups;

        for my $key ( @ordered_keys ) {
            my $value = $language_groups->{$key};
            # is this language group enabled? are any of the languages within it enabled?
            my $enabled;
            for my $enabled_language (@enabled_languages) {
                my $regex_enabled_language = regex_lang_subtags($enabled_language);
                $enabled = 1 if $key eq ($regex_enabled_language->{language} // '');
            }
            push @languages_loop,  {
                            # this is only use if there is one
                            rfc4646_subtag => @$value[0]->{rfc4646_subtag},
                            native_description => language_get_description($key,$key,'language'),
                            language => $key,
                            sublanguages_loop => $value,
                            plural => $track_language_groups->{$key} >1 ? 1 : 0,
                            current => ($current_language_regex->{language} // '') eq $key ? 1 : 0,
                            group_enabled => $enabled,
                           };
        }
        return \@languages_loop;
}

sub language_get_description {
    my ($script,$lang,$type) = @_;
    my $dbh = C4::Context->dbh;
    my $desc;
    my $sth = $dbh->prepare("SELECT description FROM language_descriptions WHERE subtag=? AND lang=? AND type=?");
    #warn "QUERY: SELECT description FROM language_descriptions WHERE subtag=$script AND lang=$lang AND type=$type";
    $sth->execute($script,$lang,$type);
    while (my $descriptions = $sth->fetchrow_hashref) {
        $desc = $descriptions->{'description'};
    }
    unless ($desc) {
        $sth = $dbh->prepare("SELECT description FROM language_descriptions WHERE subtag=? AND lang=? AND type=?");
        $sth->execute($script,'en',$type);
        while (my $descriptions = $sth->fetchrow_hashref) {
            $desc = $descriptions->{'description'};
        }
    }
    return $desc;
}
=head2 regex_lang_subtags

This internal sub takes a string composed according to RFC 4646 as
an input and returns a reference to a hash containing keys and values
for ( language, script, region, variant, extension, privateuse )

=cut

sub regex_lang_subtags {
    my $string = shift;

    # Regex for recognizing RFC 4646 well-formed tags
    # http://www.rfc-editor.org/rfc/rfc4646.txt

    # regexes based on : http://unicode.org/cldr/data/tools/java/org/unicode/cldr/util/data/langtagRegex.txt
    # The structure requires no forward references, so it reverses the order.
    # The uppercase comments are fragments copied from RFC 4646
    #
    # Note: the tool requires that any real "=" or "#" or ";" in the regex be escaped.

    my $alpha   = qr/[a-zA-Z]/ ;    # ALPHA
    my $digit   = qr/[0-9]/ ;   # DIGIT
    my $alphanum    = qr/[a-zA-Z0-9]/ ; # ALPHA / DIGIT
    my $x   = qr/[xX]/ ;    # private use singleton
    my $singleton = qr/[a-w y-z A-W Y-Z]/ ; # other singleton
    my $s   = qr/[-]/ ; # separator -- lenient parsers will use [-_]

    # Now do the components. The structure is slightly different to allow for capturing the right components.
    # The notation (?:....) is a non-capturing version of (...): so the "?:" can be deleted if someone doesn't care about capturing.

    my $extlang = qr{(?: $s $alpha{3} )}x ; # *3("-" 3ALPHA)
    my $language    = qr{(?: $alpha{2,3} | $alpha{4,8} )}x ;
    #my $language   = qr{(?: $alpha{2,3}$extlang{0,3} | $alpha{4,8} )}x ;   # (2*3ALPHA [ extlang ]) / 4ALPHA / 5*8ALPHA

    my $script  = qr{(?: $alpha{4} )}x ;    # 4ALPHA 

    my $region  = qr{(?: $alpha{2} | $digit{3} )}x ;     # 2ALPHA / 3DIGIT

    my $variantSub  = qr{(?: $digit$alphanum{3} | $alphanum{5,8} )}x ;  # *("-" variant), 5*8alphanum / (DIGIT 3alphanum)
    my $variant = qr{(?: $variantSub (?: $s$variantSub )* )}x ; # *("-" variant), 5*8alphanum / (DIGIT 3alphanum)

    my $extensionSub    = qr{(?: $singleton (?: $s$alphanum{2,8} )+ )}x ;   # singleton 1*("-" (2*8alphanum))
    my $extension   = qr{(?: $extensionSub (?: $s$extensionSub )* )}x ; # singleton 1*("-" (2*8alphanum))

    my $privateuse  = qr{(?: $x (?: $s$alphanum{1,8} )+ )}x ;   # ("x"/"X") 1*("-" (1*8alphanum))

    # Define certain grandfathered codes, since otherwise the regex is pretty useless.
    # Since these are limited, this is safe even later changes to the registry --
    # the only oddity is that it might change the type of the tag, and thus
    # the results from the capturing groups.
    # http://www.iana.org/assignments/language-subtag-registry
    # Note that these have to be compared case insensitively, requiring (?i) below.

    my $grandfathered   = qr{(?: (?i)
        en $s GB $s oed
    |   i $s (?: ami | bnn | default | enochian | hak | klingon | lux | mingo | navajo | pwn | tao | tay | tsu )
    |   sgn $s (?: BE $s fr | BE $s nl | CH $s de)
)}x;

    # For well-formedness, we don't need the ones that would otherwise pass, so they are commented out here

    #   |   art $s lojban
    #   |   cel $s gaulish
    #   |   en $s (?: boont | GB $s oed | scouse )
    #   |   no $s (?: bok | nyn)
    #   |   zh $s (?: cmn | cmn $s Hans | cmn $s Hant | gan | guoyu | hakka | min | min $s nan | wuu | xiang | yue)

    # Here is the final breakdown, with capturing groups for each of these components
    # The language, variants, extensions, grandfathered, and private-use may have interior '-'

    #my $root = qr{(?: ($language) (?: $s ($script) )? 40% (?: $s ($region) )? 40% (?: $s ($variant) )? 10% (?: $s ($extension) )? 5% (?: $s ($privateuse) )? 5% ) 90% | ($grandfathered) 5% | ($privateuse) 5% };

    $string =~  qr{^ (?:($language)) (?:$s($script))? (?:$s($region))?  (?:$s($variant))?  (?:$s($extension))?  (?:$s($privateuse))? $}xi;  # |($grandfathered) | ($privateuse) $}xi;
    my %subtag = (
        'rfc4646_subtag' => $string,
        'language' => $1,
        'script' => $2,
        'region' => $3,
        'variant' => $4,
        'extension' => $5,
        'privateuse' => $6,
    );
    return \%subtag;
}

# Script Direction Resources:
# http://www.w3.org/International/questions/qa-scripts
sub get_bidi {
    my ($language_script)= @_;
    my $dbh = C4::Context->dbh;
    my $bidi;
    my $sth = $dbh->prepare('SELECT bidi FROM language_script_bidi WHERE rfc4646_subtag=?');
    $sth->execute($language_script);
    while (my $result = $sth->fetchrow_hashref) {
        $bidi = $result->{'bidi'};
    }
    return $bidi;
};

sub accept_language {
    # referenced http://search.cpan.org/src/CGILMORE/I18N-AcceptLanguage-1.04/lib/I18N/AcceptLanguage.pm
    my ($clientPreferences,$supportedLanguages) = @_;
    my @languages = ();
    if ($clientPreferences) {
        # There should be no whitespace anways, but a cleanliness/sanity check
        $clientPreferences =~ s/\s//g;
        # Prepare the list of client-acceptable languages
        foreach my $tag (split(/,/, $clientPreferences)) {
            my ($language, $quality) = split(/\;/, $tag);
            $quality =~ s/^q=//i if $quality;
            $quality = 1 unless $quality;
            next if $quality <= 0;
            # We want to force the wildcard to be last
            $quality = 0 if ($language eq '*');
            # Pushing lowercase language here saves processing later
            push(@languages, { quality => $quality,
               language => $language,
               lclanguage => lc($language) });
        }
    } else {
        carp "accept_language(x,y) called with no clientPreferences (x).";
    }
    # Prepare the list of server-supported languages
    my %supportedLanguages = ();
    my %secondaryLanguages = ();
    foreach my $language (@$supportedLanguages) {
        # warn "Language supported: " . $language->{language};
        my $subtag = $language->{rfc4646_subtag};
        $supportedLanguages{lc($subtag)} = $subtag;
        if ( $subtag =~ /^([^-]+)-?/ ) {
            $secondaryLanguages{lc($1)} = $subtag;
        }
    }

    # Reverse sort the list, making best quality at the front of the array
    @languages = sort { $b->{quality} <=> $a->{quality} } @languages;
    my $secondaryMatch = '';
    foreach my $tag (@languages) {
        if (exists($supportedLanguages{$tag->{lclanguage}})) {
            # Client en-us eq server en-us
            return $supportedLanguages{$tag->{language}} if exists($supportedLanguages{$tag->{language}});
            return $supportedLanguages{$tag->{lclanguage}};
        } elsif (exists($secondaryLanguages{$tag->{lclanguage}})) {
            # Client en eq server en-us
            return $secondaryLanguages{$tag->{language}} if exists($secondaryLanguages{$tag->{language}});
            return $supportedLanguages{$tag->{lclanguage}};
        } elsif ($tag->{lclanguage} =~ /^([^-]+)-/ && exists($secondaryLanguages{$1}) && $secondaryMatch eq '') {
            # Client en-gb eq server en-us
            $secondaryMatch = $secondaryLanguages{$1};
        } elsif ($tag->{lclanguage} =~ /^([^-]+)-/ && exists($secondaryLanguages{$1}) && $secondaryMatch eq '') {
            # FIXME: We just checked the exact same conditional!
            # Client en-us eq server en
            $secondaryMatch = $supportedLanguages{$1};
        } elsif ($tag->{lclanguage} eq '*') {
        # * matches every language not already specified.
        # It doesn't care which we pick, so let's pick the default,
        # if available, then the first in the array.
        #return $acceptor->defaultLanguage() if $acceptor->defaultLanguage();
        return $supportedLanguages->[0];
        }
    }
    # No primary matches. Secondary? (ie, en-us requested and en supported)
    return $secondaryMatch if $secondaryMatch;
    return;   # else, we got nothing.
}

=head2 getlanguage

    Select a language based on the URL parameter 'language', a cookie,
    syspref available languages & browser

=cut

sub getlanguage {
    my ($cgi) = @_;

    my $memory_cache = Koha::Cache::Memory::Lite->get_instance();
    my $cache_key = "getlanguage";
    unless ( $cgi and $cgi->param('language') ) {
        my $cached = $memory_cache->get_from_cache($cache_key);
        return $cached if $cached;
    }

    $cgi //= CGI->new;
    my $interface = C4::Context->interface;
    my $theme = C4::Context->preference( ( $interface eq 'opac' ) ? 'opacthemes' : 'template' );
    my $language;

    my $preference_to_check =
      $interface eq 'intranet' ? 'StaffInterfaceLanguages' : 'OPACLanguages';
    # Get the available/valid languages list
    my @languages;
    my $preference_value = C4::Context->preference($preference_to_check);
    if ($preference_value) {
        @languages = split /,/, $preference_value;
    }

    # Chose language from the URL
    my $cgi_param_language = $cgi->param( 'language' );
    if ( defined $cgi_param_language && any { $_ eq $cgi_param_language } @languages) {
        $language = $cgi_param_language;
    }

    # cookie
    if (not $language and my $cgi_cookie_language = $cgi->cookie('KohaOpacLanguage') ) {
        ( $language = $cgi_cookie_language ) =~ s/[^a-zA-Z_-]*//; # sanitize cookie
    }

    # HTTP_ACCEPT_LANGUAGE
    if ( !$language && $ENV{HTTP_ACCEPT_LANGUAGE} ) {
        $language = accept_language( $ENV{HTTP_ACCEPT_LANGUAGE},
            getTranslatedLanguages( $interface, $theme ) );
    }

    # Ignore a lang not selected in sysprefs
    if ( $language && not any { $_ eq $language } @languages ) {
        $language = undef;
    }

    # Pick the first selected syspref language
    $language = shift @languages unless $language;

    # Fall back to English if necessary
    $language ||= 'en';

    $memory_cache->set_in_cache( $cache_key, $language );
    return $language;
}

=head2 get_rfc4646_from_iso639

    Select a language rfc4646 code given an iso639 code

=cut

sub get_rfc4646_from_iso639 {

    my $iso_code = shift;
    my $rfc_subtag = Koha::Database->new()->schema->resultset('LanguageRfc4646ToIso639')->find({iso639_2_code=>$iso_code});
    if ( $rfc_subtag ) {
        return $rfc_subtag->rfc4646_subtag;
    } else {
        return;
    }

}

1;

__END__

=head1 AUTHOR

Joshua Ferraro

=cut
