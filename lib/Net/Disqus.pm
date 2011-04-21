package Net::Disqus;
use warnings;
use strict;
use version;
use JSON::PP;
use LWP::UserAgent;
use Try::Tiny;
use Net::Disqus::Exception;
use base 'Class::Accessor';

__PACKAGE__->mk_ro_accessors(qw(api_key api_secret api_url ua));
__PACKAGE__->mk_accessors(qw(interfaces rate_limit rate_limit_remaining rate_limit_reset fragment path));

our $VERSION = qv('0.1.1');
our $AUTOLOAD;

sub new {
    my $class = shift;

    die Net::Disqus::Exception->new({ code => 500, text => '"new" is not an instance method'}) if(ref($class));

    my %args = (
        secure => 0,
        ua => LWP::UserAgent->new,
        (@_ == 1 && ref $_[0] eq 'HASH') ? %{$_[0]} : @_,
        interfaces => {},
        api_url => 'http://disqus.com/api/3',
        );

    die Net::Disqus::Exception->new({ code => 500, text => "missing required argument 'api_secret'"}) unless $args{'api_secret'};

    $args{'api_url'} = 'https://secure.disqus.com/api/3' if($args{'secure'});
    my $self = $class->SUPER::new({%args});

    $self->ua->agent(sprintf('%s/%s', __PACKAGE__, $VERSION));

    my $if_file = $INC{'Net/Disqus.pm'};
    $if_file =~ s/(.*)\.pm$/$1/;
    $if_file .= '/interfaces.json';

    my $interfaces;

    open my $fh, '<', $if_file || die Net::Disqus::Exception->new({ code => 500, text => 'could not open interfaces.json'});
    {
        local $/;
        $self->interfaces(JSON::PP::decode_json(<$fh>));
    }
    close($fh);
    return $self;
}

sub fetch {
    my $self = shift;
    my $url  = shift;
    my $t = $self;

    $url =~ s/^\///;
    my @url = split(/\//, $url);
    my $last = pop(@url);

    $t = $t->$_ for(@url);
    return $t->$last(@_);
}

sub rate_limit_wait {   
    my $self = shift;
    my $now = time();
    my $reset = $self->rate_limit_reset || 0;

    return undef unless($reset > 0); 
    return undef if($now > $reset);

    my $diff = $reset - $now;
    my $remaining = $self->rate_limit_remaining;
    
    # we can do X requests every Y seconds to fill it up right
    # to the reset time
    my $wait = int($diff/$remaining);
    $wait-- if($wait * $remaining > $diff); 
    return $wait;
}

sub _mk_request {
    my $self = shift;
    my $fragment = $self->fragment;
    my %args = (@_);

    $self->fragment(undef);

    my $url = sprintf('%s%s.json', $self->api_url, $self->path);
    my $method = lc($fragment->{method}) || 'get';
    my $required = $fragment->{required} || [];

    for(@$required) {
        die Net::Disqus::Exception->new({ code => 500, text => "missing required argument '$_'"}) unless($args{$_});
    }

    my $res = $self->ua->$method($url, { api_secret => $self->api_secret, %args});
    my $obj;
    try {
        $obj = JSON::PP::decode_json($res->content);
    } catch {
        die Net::Disqus::Exception->new({code => 500, text => ($res->content =~ /Maintenance \(400\) - DISQUS/i) ? 'Disqus is doing maintenance' : $res->content});
    };
    die Net::Disqus::Exception->new({code => $obj->{code}, text => $obj->{response}}) if($res->code != 200);

    # set the rate limit headers
    $self->rate_limit($res->header('X-Ratelimit-Limit'));
    $self->rate_limit_remaining($res->header('X-Ratelimit-Remaining'));
    $self->rate_limit_reset($res->header('X-Ratelimit-Reset'));

    return JSON::PP::decode_json($res->content);
}

sub AUTOLOAD {
    my $self = shift;
    my $fragment = ((($_ = $AUTOLOAD) =~ s/.*://) ? $_ : "");
    return if($fragment eq uc($fragment));

    unless($self->fragment) {
        $self->fragment($self->interfaces);
        $self->path('');
    }
    $self->path($self->path . '/' . $fragment);
    if($self->fragment->{$fragment}) {
        $self->fragment($self->fragment->{$fragment});

        return ($self->fragment->{method}) 
            ? $self->_mk_request(@_)
            : $self;
    } else {
        $self->fragment(undef);
        my $path = $self->path and $self->path(undef);
        die Net::Disqus::Exception->new({ code => 500, text => "No such API endpoint"});
    }
}
        
1;
__END__
=head1 NAME

Net::Disqus - Disqus.com API access

=head1 VERSION

Version 0.01

=head1 SYNOPSIS

    use Net::Disqus;
    my $disqus = Net::Disqus->new(
        api_secret  => 'your_api_secret',
        %options,
        );

    my $reactions = $disqus->reactions->list(...);

=head1 OBJECT METHODS

=head2 new(%options)
    
Creates a new Net::Disqus object. Arguments that can be passed to the constructor:

    api_secret  (REQUIRED)  Your Disqus API secret
    secure      (optional)  When set, will use HTTPS instead of HTTP
    ua          (optional)  An LWP::UserAgent instance. Use this if you want to set your own options on it.

=head2 rate_limit

Returns the rate limit you have on the Disqus API.

=head2 rate_limit_remaining

Returns the number of requests you have remaining out of your rate limit.

=head2 rate_limit_reset

Returns an epoch time when your rate limit will be reset.

=head2 rate_limit_wait

Returns the number of seconds you have to wait after the last performed request to exactly use up your rate limit before it's reset. Will return undef if the rate limit values aren't set.
An example:

        while(1) {
            my $reactions = $disqus->reactions->list(forum => 'mysite');
            my $wait = $diqus->rate_limit_wait;
            ...
            sleep($wait || 60); 
        }

=head1 API METHOD DOCUMENTATION

For a list of API methods and their arguments, please see L<http://disqus.com/api/docs/>. 

=head1 CALLING API METHODS

You can call API methods either by their full URL:

    $disqus->fetch('/reactions/list', forum => 'foo')
    
Or you can get the same result like this:

    $disqus->reactions->list(forum => 'foo');

Use whatever you're more comfortable with.

=head1 EXCEPTION HANDLING

When errors occur, Net::Disqus will die and throw a Net::Disqus::Exception object. The object contains two properties, 'code' and 'text. Use the below table to find out what the error was:

    Code    Text
    -------------------------------------------------------------------------------
    0       Success
    1       Endpoint not valid
    2       Missing or invalid argument
    3       Endpoint resource not valid
    4       You must provide an authenticated user for this method
    5       Invalid API key
    6       Invalid API version
    7       You cannot access this resource using %(request_method)s
    8       A requested object was not found
    9       You cannot access this resource using your %(access_type)s API key
    10      This operation is not supported
    11      Your API key is not valid on this domain
    12      This application does not have enough privileges to access this resource
    13      You have exceeded the rate limit for this resource
    14      You have exceeded the rate limit for your account
    15      There was internal server error while processing your request
    16      Your request timed out
    17      The authenticated user does not have access to this feature
    500*    No such API endpoint
    500*    <variable>

The above list was taken from L<http://disqus.com/api/docs/errors/>. The HTTP status codes are not returned in the exception object. Exception code '500' is Net::Disqus' own, and will
either contain the 'No such API endpoint' message if you are trying to access an endpoint not defined, or whatever error LWP::UserAgent encountered.

=head1 EXCEPTION HANDLING EXAMPLES

An example using Try::Tiny:

    my $nd = Net::Disqus->new(api_secret => 'reallyinvalid');
    my $res;

    try {
        $res = $nd->reactions->list(forum => 'foo');
    } catch {
        # $_ contains the Net::Disqus::Exception object
        #
        # $_->code should contain '5' and $_->text should contain 'Invalid API Key'
    };

Another example:

    my $nd = Net::Disqus->new(api_secret => 'myrealapikeygoeshere');
    my $res;

    try {
        $res = $nd->fetch('/this/isnt/good');
    } catch {
        # $_ contains the Net::Disqus::Exception object
        #
        # $_->code should contain '500' and $_->text should contain 'No such API endpoint'
    };

=head1 AUTHOR

Ben van Staveren, C<< <madcat at cpan.org> >>

=head1 BUGS AND/OR CONTRIBUTING

Please report any bugs or feature requests through the web interface at L<https://bitbucket.org/xirinet/net-disqus/issues>. If you want to contribute code or patches, feel free to fork the Mercurial repository located at L<https://bitbucket.org/xirinet/net-disqus> and make pull requests for any patches you have.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Net::Disqus


You can also look for information at:

=over 4

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Net-Disqus>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Net-Disqus>

=item * Search CPAN

L<http://search.cpan.org/dist/Net-Disqus/>

=back

=head1 ACKNOWLEDGEMENTS

Parts of the code based on Disqus' official Python lib.

=head1 LICENSE AND COPYRIGHT

Copyright 2011 Ben van Staveren.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

=cut
