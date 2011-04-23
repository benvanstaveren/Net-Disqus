use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'Net::Disqus',
    license             => 'perl',
    dist_author         => q{Ben van Staveren <madcat@cpan.org>},
    dist_version_from   => 'lib/Net/Disqus.pm',
    dist_abstract       => 'Disqus.com API access',
    configure_requires  => {
        'Module::Build'     => '0.38',
    },
    build_requires => {
        'Test::Exception'   => 0,
        'Test::More'        => 0,
    },
    requires => {
        'Class::Accessor'   => 0,
        'JSON::PP'          => 0,
        'LWP::UserAgent'    => '6.02',
        'Try::Tiny'         => 0,
        'URI'               => 0,
        'URI::Escape'       => 0,
    },
    add_to_cleanup      => [ 'Net-Disqus-*' ],
);
$builder->add_build_element('json');
$builder->create_build_script();
