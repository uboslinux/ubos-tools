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
use IndieBox::Logging;
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

    return $self->{appConfigJson}->{context};
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
# Perform an HTTP GET request on the host on which the application is being tested.
# $relativeUrl: appended to the host's URL
# return: hash containing content and headers of the HTTP response
sub httpGetRelativeHost {
    my $self        = shift;
    my $relativeUrl = shift;

    my $url = 'http://' . $self->hostName . $relativeUrl;

    debug( 'Accessing url', $url );

    my $cmd = $self->{curl};
    $cmd .= " '$url'";
    
    my $stdout;
    my $stderr;
    if( IndieBox::Utils::myexec( $cmd, undef, \$stdout, \$stderr )) {
        $self->reportError( 'HTTP request failed:', $stderr );
    }

    return { 'content' => $stdout,
             'headers' => $stderr,
             'url'     => $url };
}

##
# Perform an HTTP GET request on the application being tested, appending to the context URL.
# $relativeUrl: appended to the application's context URL
# return: hash containing content and headers of the HTTP response
sub httpGetRelativeContext {
    my $self        = shift;
    my $relativeUrl = shift;

    return $self->httpGetRelativeHost( $self->context() . $relativeUrl );
}

##
# Perform an HTTP POST request on the host on which the application is being tested.
# $relativeUrl: appended to the host's URL
# $postPars: hash of posted parameters
# return: hash containing content and headers of the HTTP response
sub httpPostRelativeHost {
    my $self        = shift;
    my $relativeUrl = shift;
    my $postPars    = shift;

    my $url = 'http://' . $self->hostName . $relativeUrl;
    my $response;

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
        $self->reportError( 'HTTP request failed:', $stderr );
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
sub httpPostRelativeContext {
    my $self        = shift;
    my $relativeUrl = shift;
    my $postData    = shift;

    return $self->httpPostRelativeHost( $self->context() . $relativeUrl, $postData );
}
        
##
# Report an error.
# @args: error message
sub reportError {
    my $self = shift;
    my @args = @_;

    error( 'TestContext reports error:', @_ );

    push @{$self->{errors}}, join( ' ', @_ );
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
