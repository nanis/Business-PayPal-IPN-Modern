package Business::PayPal::IPN::X;

our $VERSION = '0.001_001';
$VERSION = eval $VERSION;

my $class;

BEGIN {
    $class = 'Business::PayPal::IPN::X';
}

use Exception::Class (
    $class,

    "${class}::Invalid" => {
        isa => $class,
        description => 'PayPal says the request we received is not valid',
    },

    "${class}::InvalidReceiverEmail" => {
        isa => $class,
        fields => [ qw( got expected )],
        description => 'Receiver email in verified PayPal request does not match what we were told to expect in "my_email"',
    },

    "${class}::Connection" => {
        isa => $class,
        fields => [qw( ua_error )],
        description => 'Connection problem during request verification',
    },

    "${class}::FailedReadRequest" => {
        isa => $class,
        decription => 'Failed to read request from PayPal',
    },

    "${class}::RequestTooBig" => {
        isa => $class,
        fields => [qw( limit )],
        description => 'The request from PayPal is larger than we are willing to accept',
    },

    "${class}::MissingContentLength" => {
        isa => $class,
        decription => '$ENV{CONTENT_LENGTH} is undef',
    },

    "${class}::FailedReadQuery" => {
        isa => $class,
        fields => [qw( os_error )],
        description => 'Failed to read query',
    },

    "${class}::FailedVerifyRequest" => {
        isa => $class,
        description => 'Request to verify information received failed',
    },
);


1;

__END__

=pod

=encoding utf-8

=head1 NAME

Business::PayPal::IPN::Modern::X - Exceptions for Business::PayPal::Modern::IPN

=head1 SYNOPSIS

    Business::PayPal::IPN::Modern::X::FailedReadRequest->throw(
        error => '...',
    );

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

=head1 LICENSE AND COPYRIGHT

Copyright 2012 A. Sinan Unur.

This program is released under the terms of Artistic License 2.0. See
L<http://www.perlfoundation.org/artistic_license_2_0>.

