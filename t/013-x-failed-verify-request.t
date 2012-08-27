#!perl

use strict; use warnings;
use FindBin qw( $Bin );
use File::Spec::Functions qw( catfile );
use HTTP::Response;
use Mock::Quick;
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

my $fail_ua = qstrict(
    request => qmeth {
        my $self = shift;
        return HTTP::Response->new(500, 'Failed');
    },
);

throws_ok(sub {
        $class->new(
            my_email => 'test@example.com',
            paypal_max_request_size => 1,
            query_filehandle => get_fh(\ ''),
            ua => $fail_ua,
        )->verify,
    },
    "${x_class}::FailedVerifyRequest",
    'FailedVerifyRequest thrown when verify request fails',
);

done_testing;

