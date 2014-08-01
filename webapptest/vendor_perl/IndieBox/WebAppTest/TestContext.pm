#!/usr/bin/perl
#
# Passed to an AppTest. Holds the run-time information the test needs to function.
#
# This file is part of webapptest.
# (C) 2012-2014 Indie Computing Corp.
#
# webapptest is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# webapptest is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with webapptest.  If not, see <http://www.gnu.org/licenses/>.
#

use strict;
use warnings;

package IndieBox::WebAppTest::TestContext;

use fields qw( siteJson appConfigJson scaffold appTest testPlan ip curl cookieFile errors );
use IndieBox::Logging qw( debug );
use IndieBox::WebAppTest::TestingUtils;
use IndieBox::Utils;

##
# Instantiate the TextContext.
# $scaffold: the scaffold used for the test
# $appTest: the AppTest being executed
# $testPlan: the TestPlan being execited
# $ip: the IP address at which the application being tested can be accessed
sub new {
    my $self          = shift;
    my $siteJson      = shift;
    my $appConfigJson = shift;
    my $scaffold      = shift;
    my $appTest       = shift;
    my $testPlan      = shift;
    my $ip            = shift;

    unless( ref $self ) {
        $self = fields::new( $self );
    }

    $self->{siteJson}      = $siteJson;
    $self->{appConfigJson} = $appConfigJson;
    $self->{scaffold}      = $scaffold;
    $self->{appTest}       = $appTest;
    $self->{testPlan}      = $testPlan;
    $self->{ip}            = $ip;
    $self->{errors}        = [];

    $self->clearHttpSession();

    return $self;
}

##
# Determine the hostname of the application being tested
# return: hostname
sub hostName {
    my $self = shift;

    return $self->{siteJson}->{hostname};
}

##
# Determine the context path of the application being tested
# return: context, e.g. /foo
sub context {
    my $self = shift;

    return $self->{appTest}->getTestContext();
}

##
# Determine the fill context path of the application being tested
# return: full context, e.g. http://example.com/foo
sub fullContext {
    my $self = shift;

    my $url = 'http://' . $self->hostName . $self->context();
    return $url;
}

##
# Clear all HTTP session information.
sub clearHttpSession {
    my $self = shift;

    my $hostName   = $self->hostName;
    my $ip         = $self->{ip};
    my $cookieFile = File::Temp->new();

    $self->{cookieFile} = $cookieFile->filename;
    
    $self->{curl} = "curl -s -v --cookie-jar '$cookieFile' -b '$cookieFile' --resolve '$hostName:80:$ip' --resolve '$hostName:443:$ip'";
    # -v to get HTTP headers
}

##
# Perform an HTTP GET request. If the URL does not contain a protocol and
# hostname but starts with a slash, "http://hostname" with the hostname 
# of the site being tested is prepended.
# $url: URL to access
# return: hash containing content and headers of the HTTP response
sub absGet {
    my $self = shift;
    my $url  = shift;

    if( $url !~ m!^[a-z]+://! ) {
        if( $url !~ m!^/! ) {
            $self->error( 'Cannot access URL without protocol or leading slash:', $url );
            return {};
        }
        $url = 'http://' . $self->hostName . $url;
    }

    debug( 'Accessing url', $url );

    my $cmd = $self->{curl};
    $cmd .= " '$url'";
    
    my $stdout;
    my $stderr;
    if( IndieBox::Utils::myexec( $cmd, undef, \$stdout, \$stderr )) {
        $self->error( 'HTTP request failed:', $stderr );
    }

    return { 'content' => $stdout,
             'headers' => $stderr,
             'url'     => $url };
}

##
# Perform an HTTP GET request on the application being tested, appending to the context URL.
# $relativeUrl: appended to the application's context URL
# return: hash containing content and headers of the HTTP response
sub get {
    my $self        = shift;
    my $relativeUrl = shift;

    return $self->absGet( $self->context() . $relativeUrl );
}

##
# Perform an HTTP POST request. If the URL does not contain a protocol and
# hostname but starts with a slash, "http://hostname" with the hostname 
# of the site being tested is prepended.
# $url: URL to access
# $postPars: hash of posted parameters
# return: hash containing content and headers of the HTTP response
sub absPost {
    my $self     = shift;
    my $url      = shift;
    my $postPars = shift;

    if( $url !~ m!^[a-z]+://! ) {
        if( $url !~ m!^/! ) {
            $self->error( 'Cannot access URL without protocol or leading slash:', $url );
            return {};
        }
        $url = 'http://' . $self->hostName . $url;
    }

    debug( 'Posting to url', $url );

    my $postData = join(
            '&',
            map { IndieBox::Utils::uri_escape( $_ ) . '=' . IndieBox::Utils::uri_escape( $postPars->{$_} ) } keys %$postPars );
    
    my $cmd = $self->{curl};
    $cmd .= " -d '$postData'";
    $cmd .= " '$url'";
    
    my $stdout;
    my $stderr;
    if( IndieBox::Utils::myexec( $cmd, undef, \$stdout, \$stderr )) {
        $self->error( 'HTTP request failed:', $stderr );
    }
    return { 'content'     => $stdout,
             'headers'     => $stderr,
             'url'         => $url,
             'postpars'    => $postPars,
             'postcontent' => $postData };
}

##
# Perform an HTTP POST request on the application being tested, appending to the context URL,
# with the provided payload.
# $relativeUrl: appended to the application's context URL
# $payload: hash of posted parameters
# return: hash containing content and headers of the HTTP response
sub post {
    my $self        = shift;
    my $relativeUrl = shift;
    my $postData    = shift;

    return $self->absPost( $self->context() . $relativeUrl, $postData );
}

##
# Test that an HTTP GET on a relative URL returns a page that contains certain content.
# Convenience method to make tests more concise.
# $relativeUrl: appended to the application's context URL
# $content: the content to look for in the response
# $status: optional HTTP status to look for
sub getMustContain {
    my $self        = shift;
    my $relativeUrl = shift;
    my $content     = shift;
    my $status      = shift;

    my $response = $self->get( $relativeUrl );
    my $ret = $self->mustContain( $response, $content );
    if( defined( $status )) {
        $ret &= $self->mustStatus( $response, $status );
    }
    return $ret;
}

##
# Test that an HTTP GET on a relative URL returns a page that matches a regular expression.
# Convenience method to make tests more concise.
# $relativeUrl: appended to the application's context URL
# $regex: the regex for the content to look for in the response
# $status: optional HTTP status to look for
sub getMustMatch {
    my $self        = shift;
    my $relativeUrl = shift;
    my $regex       = shift;
    my $status      = shift;

    my $response = $self->get( $relativeUrl );
    my $ret = $self->mustMatch( $response, $regex );
    if( defined( $status )) {
        $ret &= $self->mustStatus( $response, $status );
    }
    return $ret;
}

##
# Test that an HTTP GET on a relative URL redirects to a certain other URL.
# Convenience method to make tests more concise.
# $relativeUrl: appended to the application's context URL
# $target: the destination URL
# $status: optional HTTP status to look for
sub getMustRedirect {
    my $self        = shift;
    my $relativeUrl = shift;
    my $target      = shift;
    my $status      = shift;

    my $response = $self->get( $relativeUrl );
    my $ret = $self->mustRedirect( $response, $target );
    if( defined( $status )) {
        $ret &= $self->mustStatus( $response, $status );
    }
    return $ret;
}

##
# Look for certain content in a response.
# $response: the response
# $content: the content to look for in the response
sub mustContain {
    my $self     = shift;
    my $response = shift;
    my $content  = shift;

    if( $response->{content} !~ m!\Q$content\E! ) {
        debugResponse( $response );
        return $self->error( 'Response content does not contain', $content );
    }
    return 0;
}

##
# Look for a regular expression match on the content in a response
# $response: the response
# $regex: the regex for the content to look for in the response
sub mustRegex {
    my $self     = shift;
    my $response = shift;
    my $regex    = shift;
    
    if( $response->{content} !~ m!$regex! ) {
        debugResponse( $response );
        return $self->error( 'Response content does not match regex', $regex );
    }
    return 0;
}

##
# Look for a redirect to a certain URL in the response
# $response: the response
# $target: the redirect target
sub mustRedirect {
    my $self     = shift;
    my $response = shift;
    my $target   = shift;
    
    if( $target !~ m!^https?://! ) {
        if( $target !~ m!^/! ) {
            return $self->error( 'Cannot look for target URL without protocol or leading slash', $target );
        }
        $target = $self->fullContext() . $target;
    }

    if( $response->{headers} !~ m!Location: $target! ) {
        debugResponse( $response );
        return $self->error( 'Response is not redirecting to', $target );
    }
    return 0;
}

##
# Look for an HTTP status in the response
# $response: the response
# $status: the HTTP status
sub mustStatus {
    my $self     = shift;
    my $response = shift;
    my $status   = shift;

    if( $response->{headers} !~ m!HTTP/1\.1 $status! ) {
        debugResponse( $response );
        return $self->error( 'Response does not have HTTP status $status' );
    }
    return 0;
}

##
# Emit a response in the debug level of the log
# $response: the response
sub debugResponse {
    my $response = shift;

    my $msg = "Response:\n";
    $msg .= IndieBox::Utils::printHashAsColumns( $response );

    debug( $msg );
}

##
# Report an error.
# @args: error message
sub error {
    my $self = shift;
    my @args = @_;

    IndieBox::Logging::error( @_ );

    push @{$self->{errors}}, join( ' ', @_ );
    
    return 1;
}

##
# Obtain reported errors and clear the buffer
# return: array of errors; may be empty
sub errorsAndClear {
    my $self = shift;

    my @ret = @{$self->{errors}};
    $self->{errors} = [];

    return @ret;
}

##
# Destroy this context.
sub destroy {
    my $self = shift;

    # could be used to delete cookie files, but right now Perl does this itself
}

1;
