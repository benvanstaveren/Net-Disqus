#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'Net::Disqus' ) || print "Bail out!
";
}

diag( "Testing Net::Disqus $Net::Disqus::VERSION, Perl $], $^X" );
