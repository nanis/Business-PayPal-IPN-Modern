use 5.008001;
use strict;
use warnings;
use ExtUtils::MakeMaker;

# Various bits copied shamelessly from Moo's Makefile.PL

my %BUILD_DEPS = (
    'Mock::Quick' => '1.104',
    'Test::More' => '0.96',
);

my %RUN_DEPS = (
    'Exception::Class' => '1.32',
    'Moo' => '1.000003',
);

my %extra_info = (
    resources => {
        homepage => 'https://github.com/nanis/Business-PayPal-IPN-Modern',
        bugtracker  => {
            web =>
            'https://github.com/nanis/Business-PayPal-IPN-Modern/issues',
        },
        repository =>
        'git://github.com/nanis/Business-PayPal-IPN-Modern.git',
    }
);

# have to do this since old EUMM dev releases miss the eval $VERSION line
my $mymeta_works = do {
    no warnings; $ExtUtils::MakeMaker::VERSION >= 6.5707
};
my $mymeta = do {
    no warnings; $ExtUtils::MakeMaker::VERSION >= 6.5702
};

my $license_works = do {
    no warnings; $ExtUtils::MakeMaker::VERSION >= 6.3002
};

WriteMakefile(
    NAME                => 'Business::PayPal::IPN::Modern',
    AUTHOR              => q{A. Sinan Unur <'nanis@cpan.org'>},
    VERSION_FROM        => 'lib/Business/PayPal/IPN/Modern.pm',
    ABSTRACT_FROM       => 'lib/Business/PayPal/IPN/Modern.pm',
    ($license_works ? ('LICENSE'=> 'artistic_2') : ()),
    PL_FILES            => {},
    PREREQ_PM => {
        %RUN_DEPS,
        ($mymeta_works ? () : (%BUILD_DEPS)),
    },
    ($mymeta_works
        ? (
            # BUILD_REQUIRES makes MYMETA right, requires stops META being
            # wrong
            BUILD_REQUIRES => \%BUILD_DEPS,
            META_ADD => { requires => \%RUN_DEPS, %extra_info }
        ) : (
            # META_ADD both to get META right - only Makefile written
            META_ADD => {
                requires => \%RUN_DEPS,
                build_requires => \%BUILD_DEPS, %extra_info,
            }
        )
    ),
    dist => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean => {
        FILES => 'Business-PayPal-IPN-Modern-*'
    },
);

