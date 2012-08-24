package Business::PayPal::IPN::Modern;

use 5.008001;
our $VERSION = '0.001_001';
$VERSION = eval $VERSION;

use strict;
use warnings;

our $MAX_PAYPAL_REQUEST_SIZE = 16 * 1_024;

{
    use Moo;
    use HTTP::Request;

    my @paypal_attr = (
        # Information about you:
        'receiver_email',
        'receiver_id',
        'residence_country',

        # Information about the transaction:
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
        'payment_status',
        'payment_type',
        'protection_eligibility',
        'quantity',
        'shipping',
        'tax',

        # Other information about the transaction:
        'notify_version',
        'charset',
        'verify_sign',
    );

    has cgi_factory => (
        is => 'ro',
        default => sub {
            sub {
                my $fh = shift;
                require CGI::Simple;
                return CGI::Simple->new( $fh );
            }
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

    has paypal_attr => (
        is => 'ro',
        init_arg => undef,
        default => sub { \@paypal_attr },
    );

    has query_filehandle => (
        is => 'ro',
        default => sub { \*STDIN },
    );

    has ua => (
        is => 'ro',
        default => sub {
            require LWP::UserAgent;
            return LWP::UserAgent->new;
        },
    );

    sub throw {
        my $self = shift;
        my $exception = shift;
        my $base = 'Business::PayPal::IPN::Modern::X';

        eval "require $base";

        $exception->throw(@_);
    }

    for my $attr ( @paypal_attr ) {
        has $attr => (
            is => 'ro',
            init_arg => undef,
            writer => "_set_$attr"
        );
    }

    sub _verify {
        my $self = shift;

        my $content_length = $ENV{CONTENT_LENGTH};
        unless ( defined $content_length ) {
            $self->throw(
                MissingContentLength => (
                    error => 'No $ENV{CONTENT_LENGTH}',
                ),
            );
        }

        my $limit = $self->max_paypal_request_size;
        if ($content_length > $limit) {
            $self->throw(
                RequestTooBig => (
                    error => "CONTENT_LENGTH > $limit",
                    limit => $limit,
                ),
            );
        }

        my $content;
        my $ret = read $self->query_filehandle, $content, $limit;

        unless (defined $ret) {
            my $os_error = $!;
            $self->throw(FailedReadQuery => (
                    error => 'Failed to read from input',
                    os_error => $os_error,
                ),
            );
        }

        # post back to PayPal system to validate
        $content .= '&cmd=_notify-validate';

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
            $self->throw(FailedVerifyRequest => (
                    error => $res->status_line,
                ),
            );
        }

        my $msg = $res->content;

        if ($msg eq 'INVALID') {
            $self->throw(Invalid => (
                    error => "PayPal responded with 'INVALID'",
                ),
            );
        }

        if ($msg ne 'VERIFIED') {
            $self->throw(Unknown => (
                    error => "Unexpected PayPal response: '$msg'",
                )
            );
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

    sub _check_receiver_email {
        my $self = shift;

        if ($self->my_email ne $self->receiver_email) {
            $self->throw(MismatchedReceiverEmail => (
                expected => $self->my_email,
                got => $self->received_email,
                error => sprintf(
                    "Receiver email addresses don't match." .
                    "Expected: '%s'; got '%s'",
                    $self->my_email,
                    $self->receiver_email,
                ),
            ));
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

=head1 ATTRIBUTES

=head2 Attributes affecting object behavior

=over 4

=item cgi_class

=item content

=item is_verified

=item my_email

=item max_paypal_request_size

=item paypal_gateway

=item query_filehandle

=item ua_class

=over

=head2 PayPal response attributes

=head3 Information about you:

=over 4

=item receiver_email

=item receiver_id

=item residence_country

=back

=head3 Information about the transaction:

=over 4

=item test_ipn

True if testing with the Sandbox.

=item transaction_subject

=item txn_id

Keep this ID to avoid processing the transaction twice.

=item txn_type

=back

=head3 Information about your buyer:

=over 4

=item payer_email

=item payer_id

=item payer_status

=item first_name

=item last_name

=item address_city

=item address_country

=item address_country_code

=item address_name

=item address_state

=item address_status

=item address_street

=item address_zip

=back

=head3 Information about the payment:

=over 4

=item custom

Your custom field.

=item handling_amount

=item item_name

=item item_number

=item mc_currency

=item mc_fee

=item mc_gross

=item payment_date

=item payment_fee

=item payment_gross

=item payment_status

Status, which determines whether the transaction is complete.

=item payment_type

Kind of payment.

=item protection_eligibility

=item quantity

=item shipping

=item tax

=back

=head3 Other information about the transaction:

=over 4

=item notify_version

IPN version; PayPal documentation says it can be ignored.

=item charset

=item verify_sign

=back

=head1 METHODS

=head2 verify_and_init

TODO: Document this.

=head1 EXCEPTIONS

TODO: Document this

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

