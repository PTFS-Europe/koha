use strict;
use warnings;

package HTML::FromANSI::Tiny::Bootstrap;

use parent qw(HTML::FromANSI::Tiny);

our %ATTR_TO_CLASS = (
    black      => 'text-primary',
    red        => 'text-danger',
    green      => 'text-success',
    yellow     => 'text-warning',
    blue       => 'text-info',
    magenta    => '',
    cyan       => '',
    white      => 'text-muted',
    on_black   => 'bg-primary',
    on_red     => 'bg-danger',
    on_green   => 'bg-success',
    on_yellow  => 'bg-warning',
    on_blue    => 'bg-info',
    on_magenta => '',
    on_cyan    => '',
    on_white   => '',
);

sub attr_to_class {
    $ATTR_TO_CLASS{ $_[1] } || $_[1];
}

1;
