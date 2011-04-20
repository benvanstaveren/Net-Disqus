use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'Net::Disqus',
    license             => 'perl',
    dist_author         => q{Ben van Staveren <madcat@cpan.org>},
    dist_version_from   => 'lib/Net/Disqus.pm',
    dist_abstract       => 'Disqus.com API access',
    build_requires => {
        'Test::Exception'   => 0,
        'Test::More'        => 0,
    },
    requires => {
        'version'           => 0,
        'JSON::PP'          => 0,
        'LWP::UserAgent'    => '6.02',
        'Try::Tiny'         => 0,
    },
    add_to_cleanup      => [ 'Net-Disqus-*' ],
    create_makefile_pl => 'traditional',
);
$builder->add_build_element('json');
$builder->create_build_script();
