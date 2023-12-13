use Modern::Perl;

return {
    bug_number  => "27378",
    description => "LOCAL UPGRADE",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        # If ConsentJS exists, copy content to CookieConsentedJS
        my ($count) = $dbh->selectrow_array(q{
            SELECT COUNT(*)
            FROM systempreferences
            WHERE variable = 'ConsentJS'
        });

        if ($count) {
            $dbh->do(q{
                UPDATE IGNORE systempreferences SET variable = 'CookieConsentedJS' WHERE variable = 'ConsentJS';
            });
            $dbh->do(q{
                DELETE IGNORE FROM systempreferences WHERE variable = 'ConsentJS';
            });
            say $out "Updated ConsentJS system preference to 'CookieConsentedJS'";
        } else {
            $dbh->do(q{
                INSERT IGNORE INTO systempreferences (variable, value, explanation, options, type) VALUES ('CookieConsentedJS', '', 'Add Javascript code that will run if cookie consent is provided (e.g. tracking code).', '', 'Free');
            });
            say $out "Added new system preference 'CookieConsentedJS'";
        }

        # Ensure CookieConsent preference exists
        $dbh->do(
            q| INSERT IGNORE INTO systempreferences (variable, value, explanation, options, type) VALUES ('CookieConsent', '0', 'Require cookie consent to be displayed', '', 'YesNo'); |
        );
        say $out "Added new system preference 'CookieConsent'";

        # Migrate CookieConsentBar from preference to html customisations
        say $out "You may need to copy CookieConsentBar content into the HTML Customizations area";

        # Migrate CookieConsentPopup from preference to html customisations
        say $out "You may need to copy CookieConsentPopup content into the HTML Customizations area";
    },
};
