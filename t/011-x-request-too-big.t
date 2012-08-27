#!perl

use strict; use warnings;
use FindBin qw( $Bin );
use File::Spec::Functions qw( catfile );
use Test::Exception;
use Test::More;

use lib catfile($Bin, 'inc');

use My::TestSupport qw( get_fh );

my ($class, $x_class);

BEGIN {
    $class = 'Business::PayPal::IPN::Modern';
    $x_class = 'Business::PayPal::IPN::X';
    use_ok( $class ) || print "Bail out!\n";
}

local $ENV{CONTENT_LENGTH} = 1;

throws_ok(sub {
        $class->new(
            my_email => 'test@example.com',
            paypal_max_request_size => 0,
            query_filehandle => get_fh( \ ''),
            ua => undef,
        )->verify,
    },
    "${x_class}::RequestTooBig",
    'RequestTooBig thrown with $ENV{CONTENT_LENGTH} > paypal_max_request_size',
);

done_testing;

