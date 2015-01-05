package Koha::CM;

use base Exporter;

# This is a hardcoded placeholder
# as there is no means at present to extract this
# from session state

our @EXPORT = ('SessionTillId');

sub SessionTillId {
    return 1;    # my dummy record
}
1;
