package Business::PayPal::IPN::Modern;

use 5.008001;
our $VERSION = '0.001_001';
$VERSION = eval $VERSION;

use strict;
use warnings;

our $MAX_PAYPAL_REQUEST_SIZE = 4_096;

{
    use Moo;
    use HTTP::Request;

    use Exception::Class (
        'PayPalIPN_Exception',

        'PayPalIPN_Invalid_Exception' => {
            isa => 'PayPalIPN_Exception',
        },

        'PayPalIPN_Invalid_ReceiverEmail_Exception' => {
            isa => 'PayPalIPN_Exception',
            fields => [ qw( got expected )],
        },

        'PayPalIPN_Connection_Exception' => {
            isa => 'PayPalIPN_Exception',
            fields => [qw( ua_error )],
        },

        'PayPalIPN_ReadRequestFailed_Exception' => {
            isa => 'PayPalIPN_Exception',
        },

        'PayPalIPN_RequestTooBig_Exception' => {
            isa => 'PayPalIPN_ReadRequestFailed_Exception',
            fields => [qw( limit )],
        },

        'PayPalIPN_NoContentLength_Exception' => {
            isa => 'PayPalIPN_ReadRequestFailed_Exception',
        },

        'PayPalIPN_ReadQueryFailed_Exception' => {
            isa => 'PayPalIPN_ReadRequestFailed_Exception',
            fields => [qw( os_error )],
        },

        'PayPalIPN_NoUAException' => {
            isa => 'PayPalIPN_Exception',
        },

        'PayPalIPN_VerifyRequestFailed_Exception' => {
            isa => 'PayPalIPN_Exception',
        },
    );

    my @fields = (
        # Information about you:
        # Check email address to make sure that this is not a spoof
        'receiver_email',
        'receiver_id',
        'residence_country',

        # Information about the transaction:
        # Testing with the Sandbox
        'test_ipn',
        'transaction_subject',

        # Keep this ID to avoid processing the transaction twice
        'txn_id',
        'txn_type',

        # Information about your buyer:
        'payer_email',
        'payer_id',
        'payer_status',
        'first_name',
        'last_name',
        'address_city',
        'address_country',
        'address_country_code',
        'address_name',
        'address_state',
        'address_status',
        'address_street',
        'address_zip',

        # Information about the payment:
        # Your custom field
        'custom',
        'handling_amount',
        'item_name',
        'item_number',
        'mc_currency',
        'mc_fee',
        'mc_gross',
        'payment_date',
        'payment_fee',
        'payment_gross',
        # Status, which determines whether the transaction is complete
        'payment_status',
        # Kind of payment
        'payment_type',
        'protection_eligibility',
        'quantity',
        'shipping',
        'tax',

        # Other information about the transaction:
        # IPN version; can be ignored
        'notify_version',
        'charset',
        'verify_sign',
    );

    has cgi_class => (
        is => 'ro',
        default => sub {
            my $class = eval {
                require CGI::Simple;
                1;
            } ? 'CGI::Simple' : 'CGI';
            return $class;
        },
    );

    has content => (
        is => 'ro',
        init_arg => undef,
        writer => '_set_content',
    );

    has is_verified => (
        is => 'ro',
        init_arg => undef,
        default => sub { 0 },
        writer => '_set_is_verified',
    );

    has my_email => (
        is => 'ro',
        required => 1,
    );

    has max_paypal_request_size => (
        is => 'ro',
        default => sub { $MAX_PAYPAL_REQUEST_SIZE },
    );

    has paypal_gateway => (
        is => 'ro',
        default => sub { 'https://www.paypal.com/cgi-bin/webscr' },
    );

    has query_filehandle => (
        is => 'ro',
        default => sub { \*STDIN },
    );

    has ua_class => (
        is => 'ro',
        default => sub {
            my $class;
            eval {
                require LWP::UserAgent;
                1;
            } and $class = 'LWP::UserAgent';
            return $class if defined $class;

            PayPalIPN_NoUAException->throw(
                error =>
                "No user agent provided in the constructor and attempt to require 'LWP::UserAgent' failed",
            );
        },
    );

    has fields => (
        is => 'ro',
        init_arg => undef,
        default => sub { \@fields },
    );

    for my $field ( @fields ) {
        has $field => (
            is => 'ro',
            init_arg => undef,
            writer => "_set_$field"
        );
    }

    sub _verify {
        my $self = shift;

        my $content_length = $ENV{CONTENT_LENGTH};
        defined($content_length)
            or PayPalIPN_NoContentLength_Exception->throw(
                error => 'No $ENV{CONTENT_LENGTH}',
            );

        my $limit = $self->max_paypal_request_size;
        if ($content_length > $limit) {
            PayPalIPN_RequestTooBig_Exception->throw(
                error => "CONTENT_LENGTH > $limit",
                limit => $limit,
            );
        }

        my $content;
        my $ret = read $self->query_filehandle, $content, $limit;

        unless (defined $ret) {
            my $os_error = $!;
            PayPalIPN_ReadQueryFailed_Exception->throw(
                error => 'Failed to read from input',
                os_error => $os_error,
            );
        }

        # post back to PayPal system to validate
        $content .= '&cmd=_notify-validate';
        eval sprintf('require %s', $self->ua_class);

        # save copy to parse with $cgi_class after verification
        $self->_set_content($content);

        my $ua = $self->ua_class->new;
        my $req = HTTP::Request->new(
            POST => $self->paypal_gateway,
        );

        $req->content_type('application/x-www-form-urlencoded');
        $req->content($content);

        my $res = eval { $ua->request($req) };
        unless ($res->is_success) {
            PayPalIPN_VerifyRequestFailed_Exception->throw(
                error => $res->status_line,
            );
        }

        my $msg = $res->content;

        if ($msg eq 'INVALID') {
            PayPalIPN_Invalid_Exception->throw(
                error => "PayPal responded with 'INVALID'",
            );
        }

        if ($msg ne 'VERIFIED') {
            PayPalIPN_Invalid_Exception->throw(
                error => sprintf("Unexpected PayPal response: '%s'", $msg),
            )
        }

        return 1;
    }

    sub _init {
        my $self = shift;

        open my $fh, '<', \ $self->content;
        my $cgi = $self->cgi_class->new($fh);

        my $fields = $self->fields;
        for my $field ( @$fields ) {
            my $setter = "_set_$field";
            $self->$setter( $cgi->param( $field ) );
        }

        return;
    }

    sub verify_and_init {
        my $self = shift;
        $self->_verify;
        $self->_init;
        return;
    }
}

'Business::PayPal::IPN::Modern';

__END__

=head1 NAME

Business::PayPal::IPN::Modern - An attempt to improve Business::PayPal::IPN

=head1 VERSION

Version 0.001

=head1 BACKGROUND

C<Business::PayPal::IPN::Modern> implements PayPal IPN version 2.6. See
L<https://cms.paypal.com/uk/cgi-bin/?cmd=_render-content&amp;content_ID=developer/e_howto_admin_IPNIntro>.

I do not know the history of PayPal's IPN. The current (2012/08/22) version
2.6 requires that the order of parameters not be changes when the request is
sent back to PayPal for verification. C<Business::PayPal::IPN> stores the
request variables in a hash before the post back to PayPal, which changes
the order of those variables.

C<Business::PayPal::IPN> ties you to L<CGI>. PayPal's sample Perl does not
provide a means to limit the amount of data read from the connection. See
L<https://cms.paypal.com/cms_content/GB/en_GB/files/developer/IPN_PERL.txt>

I<Explain how this module handles things>

=head1 SYNOPSIS

    use Business::PayPal::IPN::Modern;

    my $ipn = Business::PayPal::IPN::Modern->new;

=head1 EXPORT

None.

=head1 METHODS


=head1 AUTHOR

A. Sinan Unur, C<< <'nanis at cpan.org'> >>

=head1 REPOSITORY

You can find this module's repository on GitHub:
L<https://github.com/nanis/Business-PayPal-IPN-Modern>. It will be moved to
CPAN when it is working well.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Business::PayPal::IPN::Modern

=head1 BUGS

For now, please report bugs using GitHub's issue tracker at
L<https://github.com/nanis/Business-PayPal-IPN-Modern/issues>.

=head1 ACKNOWLEDGEMENTS

Sherzod Ruzmetov's
L<Business-PayPal-IPN|http://search.cpan.org/dist/Business-PayPal-IPN>
provided the starting point for this module.

=head1 LICENSE AND COPYRIGHT

Copyright 2012 A. Sinan Unur.

This program is released under the terms of Artistic License 2.0. See
L<http://www.perlfoundation.org/artistic_license_2_0>.

