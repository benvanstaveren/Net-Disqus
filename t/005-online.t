#!perl -T
use Test::More;
use Test::Exception;


if(!$ENV{DISQUS_API_SECRET}) {
    plan skip_all => 'No online testing requested, set the DISQUS_API_SECRET environment variable to your secret api key to test against the live Disqus API';
} else {
    plan tests => 14;
    
    use_ok 'Net::Disqus';
    use_ok 'Net::Disqus::Exception';

    my $nd = Net::Disqus->new(api_secret => $ENV{DISQUS_API_SECRET} );
    my $r = $nd->applications->listUsage();

    ok($r->{code} == 0, "return code is 0");
    ok(ref($r->{response}) eq 'ARRAY', "return response is arrayref");
    ok($nd->rate_limit > 0, "rate limit is set after invalid request");
    ok($nd->rate_limit_remaining > 0, "rate limit remaining is set after invalid request");
    ok($nd->rate_limit_reset > 0, "rate limit  reset is set after invalid request");
    ok($nd->rate_limit_wait > 0, "rate limit wait time is set");

    $r = $nd->fetch('/applications/listUsage');

    ok($r->{code} == 0, " fetch: return code is 0");
    ok(ref($r->{response}) eq 'ARRAY', " fetch: return response is arrayref");
    ok($nd->rate_limit > 0, " fetch: rate limit is set after invalid request");
    ok($nd->rate_limit_remaining > 0, " fetch: rate limit remaining is set after invalid request");
    ok($nd->rate_limit_reset > 0, " fetch: rate limit  reset is set after invalid request");
    ok($nd->rate_limit_wait > 0, " fetch: rate limit wait time is set");

    done_testing();
}

