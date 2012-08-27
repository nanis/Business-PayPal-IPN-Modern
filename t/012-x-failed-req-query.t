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

$ENV{CONTENT_LENGTH} = 0;

throws_ok(sub {
        $class->new(
            my_email => 'test@example.com',
            paypal_max_request_size => 0,
            query_filehandle => undef,
            ua => undef,
        )->verify,
    },
    "${x_class}::FailedReadQuery",
    'FailedReadQuery thrown when reading from specified filehandle fails',
);

done_testing;

