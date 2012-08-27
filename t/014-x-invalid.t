#!perl

use strict; use warnings;
use FindBin qw( $Bin );
use File::Spec::Functions qw( catfile );
use HTTP::Response;
use Mock::Quick;
use Test::Exception;
use Test::More;

use lib catfile($Bin, 'inc');

use My::TestSupport qw(
    get_fh
    SAMPLE_PAYPAL_REQUEST
    SAMPLE_PAYPAL_REQUEST_SIZE
);

my ($class, $x_class);

BEGIN {
    $class = 'Business::PayPal::IPN::Modern';
    $x_class = 'Business::PayPal::IPN::X';
    use_ok( $class ) || print "Bail out!\n";
}

$ENV{CONTENT_LENGTH} = SAMPLE_PAYPAL_REQUEST_SIZE;

my $ua = qstrict(
    request => qmeth {
        my $self = shift;
        my $req = shift;
        my $resp = HTTP::Response->new(200, 'OK');

        my $paypal_request = SAMPLE_PAYPAL_REQUEST;

        if ($req->content eq "$paypal_request&cmd=_notify-validate") {
            $resp->content('VERIFIED');
        }
        else {
            $resp->content('INVALID');
        }
        return $resp;
    },
);

(my $invalid_request = SAMPLE_PAYPAL_REQUEST) =~ s/19[.]95/19.99/;

throws_ok(sub {
        $class->new(
            my_email => 'test@example.com',
            query_filehandle => get_fh(\ $invalid_request ),
            ua => $ua,
        )->verify,
    },
    "${x_class}::Invalid",
    'Invalid is thrown when PayPal responds with INVALID',
);

done_testing;

