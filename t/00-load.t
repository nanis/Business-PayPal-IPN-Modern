#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'Business::PayPal::IPN::Modern' ) || print "Bail out!\n";
}

diag( "Testing Business::PayPal::IPN::Modern $Business::PayPal::IPN::Modern::VERSION, Perl $], $^X" );
