#!/usr/bin/env perl -T 

use Test::More tests => 7;
use Test::Exception;

use_ok 'Net::Disqus';
use_ok 'Net::Disqus::Exception';

my $nd = Net::Disqus->new(api_secret => 'foo');

throws_ok { $nd->application->listUsage } qr/No such API endpoint/, 'Caught invalid method call exception 1';
throws_ok { $nd->applications->listusage } qr/No such API endpoint/, 'Caught invalid method call exception 2';
throws_ok { $nd->fetch('/application/listUsage') } qr/No such API endpoint/, "fetch throws ok";

throws_ok { $nd->applications->listUsage } qr/Invalid API key/, 'Net::Disqus->applications->listUsage() works';
throws_ok { $nd->fetch('/applications/listUsage') } qr/Invalid API key/, "Net::Disqus->fetch('/applications/listUsage') works";

done_testing();
