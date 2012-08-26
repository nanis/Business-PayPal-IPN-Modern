package Business::PayPal::IPN::Modern;

use 5.008001;
our $VERSION = '0.001_001';
$VERSION = eval $VERSION;

use strict;
use warnings;

our $PAYPAL_GATEWAY = 'https://www.paypal.com/cgi-bin/webscr';
our $PAYPAL_MAX_REQUEST_SIZE = 16 * 1_024;

{
    use Carp qw( croak );
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

    has my_email => (
        is => 'ro',
        required => 1,
    );

    has paypal_max_request_size => (
        is => 'ro',
        default => sub { $PAYPAL_MAX_REQUEST_SIZE },
        writer => '__set_paypal_max_request_size',
    );

    has paypal_gateway => (
        is => 'ro',
        default => sub { $PAYPAL_GATEWAY },
        writer => '__set_paypal_gateway',
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
        my $ex = shift;
        my $base = 'Business::PayPal::IPN::X';

        {
            local $@;

            unless (defined( eval "require $base" )) {
                my $x = $@;
                croak "Failed to require '$base': $@";
            }
        }

        $base->import;
        $ex = "${base}::$ex";

        $ex->throw(@_);
    }

    for my $attr ( @paypal_attr ) {
        has $attr => (
            is => 'ro',
            init_arg => undef,
            writer => "_set_$attr"
        );
    }

    sub verify {
        my $self = shift;

        my $content_length = $ENV{CONTENT_LENGTH};
        unless ( defined $content_length ) {
            $self->throw(
                MissingContentLength => (
                    error => 'No $ENV{CONTENT_LENGTH}',
                ),
            );
        }

        my $limit = $self->paypal_max_request_size;
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

        my $req = HTTP::Request->new(
            POST => $self->paypal_gateway,
        );

        $req->content_type('application/x-www-form-urlencoded');
        $req->content($content);

        my $res = eval { $self->ua->request($req) };
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

    sub init {
        my $self = shift;

        open my $fh, '<', \ $self->content;
        my $cgi = $self->cgi_factory->();

        my $fields = $self->fields;
        for my $field ( @$fields ) {
            my $setter = "_set_$field";
            $self->$setter( $cgi->param( $field ) );
        }

        return;
    }

    sub check_receiver_email {
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

    sub verify_init_check {
        my $self = shift;
        $self->verify;
        $self->init;
        $self->check_receiver_email;
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

=head2 check_receiver_email

Call after the request from PayPal has been verified using C<verify> and the
PayPal attributes have been initialized using C<init>. Throws an exception
if the C<receiver_email> in the request does not match the C<my_email> value
specified in the object constructor.

=head2 init

Call to initialize PayPal attributes after verifying the request using
C<verify>.

=head2 throw

Convenience method to throw an exception of the specified sub-type. Provides
a central location where the mapping of exceptions to implementations of
those exceptions can be replaced.

=head2 verify

Verify that the request was sent by PayPal. Throws an exception if the
request is invalid or cannot be verified.

=head2 verify_init_check

Convenience method to call C<verify>, C<init>, and C<check_receiver_email>.

=head1 ATTRIBUTES

=head2 Attributes affecting object behavior

All attributes are read only. You can override the default values for the
attributes listed in this section by passing them to the constructor.

=over 4

=item cgi_factory

A coderef that will initialize a new CGI object from a filehandle. By
default, this module returns instances of L<CGI::Simple>. Make sure
to C<require> the module first.

=item content

The content of the original request.

=item my_email

The email address to expect in the C<receiver_email> field of the request
from PayPal.

=item paypal_attr

The list of attributes to be filled in using the information provided in the
PayPal request.

=item paypal_gateway

The URI to contact to verify the request.

=item paypal_max_request_size

Maximum size of the request to expect from PayPal. The default is 16K.

=item query_filehandle

Read initial PayPal request from this file handle.

=item ua

The user agent object to use to contact PayPal to verify the request. The
default is L<LWP::UserAgent>. This attribute is mainly provided to make
testing easier. Any object providing a C<request> method that provides and
appropriate response will do.

=back

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

