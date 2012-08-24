package Business::PayPal::IPN::Modern::X;

our $VERSION = '0.001_001';
$VERSION = eval $VERSION;

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



__END__

=pod

=encoding utf-8

=head1 NAME

Business::PayPal::IPN::Modern::X - Exceptions for Business::PayPal::Modern::IPN

=head1 SYNOPSIS


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

