#!perl -T

use HTTP::Response;
use Mock::Quick;
use Test::Exception;
use Test::More;

BEGIN {
    use_ok( 'Business::PayPal::IPN::Modern' ) || print "Bail out!\n";
}

run();
done_testing();

sub run {

    my $ua = qstrict(
        request => qmeth {
            my $self = shift;
            my $req = shift;
            my $resp = HTTP::Response->new(200, 'OK');

            if ($req->content eq "$paypal_request&cmd=_notify-validate") {
                $resp->content('VERIFIED');
            }
            else {
                $resp->content('INVALID');
            }
        },
    );

    my $paypal_request = join '&', qw(
        mc_gross=19.95
        protection_eligibility=Eligible
        address_status=confirmed
        payer_id=LPLWNMTBWMFAY
        tax=0.00
        address_street=1+Main+St
        payment_date=20%3A12%3A59+Jan+13%2C+2009+PST
        payment_status=Completed
        charset=windows-1252
        address_zip=95131
        first_name=Test
        mc_fee=0.88
        address_country_code=US
        address_name=Test+User
        notify_version=2.6
        custom=
        payer_status=verified
        address_country=United+States
        address_city=San+Jose
        quantity=1
        verify_sign=AtkOfCXbDm2hu0ZELryHFjY-Vb7PAUvS6nMXgysbElEn9v-1XcmSoGtf
        payer_email=gpmac_1231902590_per%40paypal.com
        txn_id=61E67681CH3238416
        payment_type=instant
        last_name=User
        address_state=CA
        receiver_email=gpmac_1231902686_biz%40paypal.com
        payment_fee=0.88
        receiver_id=S8XGHLYDW9T3S
        txn_type=express_checkout
        item_name=
        mc_currency=USD
        item_number=
        residence_country=US
        test_ipn=1
        handling_amount=0.00
        transaction_subject=
        payment_gross=19.95
        shipping=0.00
    );

    throws_ok(sub {
            Business::PayPal::IPN::Modern->new(
                my_email => 'test@example.com',
                query_filehandle => get_fh(\ ''),
                ua => $ua,
            )->verify,
        },
        'Business::PayPal::IPN::X::MissingContentLength',
        'MissingContentLength exception thrown with no $ENV{CONTENT_LENGTH}'
    );

    {
        local $ENV{CONTENT_LENGTH} = 1;
        throws_ok(sub {
                Business::PayPal::IPN::Modern->new(
                    my_email => 'test@example.com',
                    paypal_max_request_size => 0,
                    query_filehandle => get_fh( \ ''),
                    us => $ua,
                )->verify,
            },
            'Business::PayPal::IPN::X::RequestTooBig',
            'RequestTooBig thrown with $ENV{CONTENT_LENGTH} > paypal_max_request_size',
        );
    }

    {
        local $ENV{CONTENT_LENGTH} = 0;
        throws_ok(sub {
                Business::PayPal::IPN::Modern->new(
                    my_email => 'test@example.com',
                    paypal_max_request_size => 0,
                    query_filehandle => undef,
                    ua => $ua,
                )->verify,
            },
            'Business::PayPal::IPN::X::FailedReadQuery',
            'FailedReadQuery thrown when reading from specified filehandle fails',
        );
    }
}

sub get_fh {
    my $paypal_req = shift;

    open my $fh, '<', $paypal_req
        or die "Cannot get a filehandle to string: $!";

    return $fh;
}
