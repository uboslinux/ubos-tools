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

package UBOS::WebAppTest::TestContext;

use fields qw( siteJson appConfigJson scaffold appTest testPlan ip curl cookieFile errors );

use Fcntl;
use UBOS::Logging qw( debug );
use UBOS::WebAppTest::TestingUtils;
use UBOS::Utils;

#
# This file is organized as follows:
# (1) Constructor
# (2) General methods
# (3) HTTP testing methods
# (4) File testing methods
# (5) Utility methods
# Sorry, it's long, but that makes the API a lot easier for the test developer

##### (1) Constructor #####

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

##### (2) General methods #####

##
# Determine the hostname of the application being tested
# return: hostname
sub hostName {
    my $self = shift;

    return $self->{siteJson}->{hostname};
}

##
# Determine the test being run.
# return: the test
sub getTest {
    my $self = shift;
    
    return $self->{appTest};
}

##
# Determine the context path of the application being tested
# return: context, e.g. /foo
sub context {
    my $self = shift;

    return $self->{appTest}->getTestContext();
}

##
# Determine the full context path of the application being tested
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

##### (3) HTTP testing methods #####

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
            return {
                'error' => $self->error( 'Cannot access URL without protocol or leading slash:', $url )
            };
        }
        $url = 'http://' . $self->hostName . $url;
    }

    debug( 'Accessing url', $url );

    my $cmd = $self->{curl};
    $cmd .= " '$url'";
    
    my $stdout;
    my $stderr;
    my $ret = {};
    
    if( UBOS::Utils::myexec( $cmd, undef, \$stdout, \$stderr )) {
        $ret->{error} = $self->error( 'HTTP request failed:', $stderr );
    }
    $ret->{content} = $stdout;
    $ret->{headers} = $stderr;
    $ret->{url}     = $url;

    return $ret;
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
            map { UBOS::Utils::uri_escape( $_ ) . '=' . UBOS::Utils::uri_escape( $postPars->{$_} ) } keys %$postPars );
    
    my $cmd = $self->{curl};
    $cmd .= " -d '$postData'";
    $cmd .= " '$url'";
    
    my $stdout;
    my $stderr;
    my $ret = {};

    if( UBOS::Utils::myexec( $cmd, undef, \$stdout, \$stderr )) {
        $ret->{error} = $self->error( 'HTTP request failed:', $stderr );
    }
    $ret->{content}     = $stdout;
    $ret->{headers}     = $stderr;
    $ret->{url}         = $url;
    $ret->{postpars}    = $postPars;
    $ret->{postcontent} = $postData;

    return $ret;
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
# $errorMsg: if the test fails, report this error message
sub getMustContain {
    my $self        = shift;
    my $relativeUrl = shift;
    my $content     = shift;
    my $status      = shift;
    my $errorMsg    = shift;

    my $response = $self->get( $relativeUrl );
    my $ret      = $self->mustContain( $response, $content, $errorMsg );
 
    if( defined( $status )) {
        my $tmp = $self->mustStatus( $response, $status, $errorMsg );
        if( defined( $tmp->{error} )) {
            appendError( $ret, $tmp->{error} );
        }
    }
    return $ret;
}

##
# Test that an HTTP GET on a relative URL returns a page that does not
# contain certain content.
# Convenience method to make tests more concise.
# $relativeUrl: appended to the application's context URL
# $content: the content to look for in the response
# $status: optional HTTP status to look for
# $errorMsg: if the test fails, report this error message
sub getMustNotContain {
    my $self        = shift;
    my $relativeUrl = shift;
    my $content     = shift;
    my $status      = shift;
    my $errorMsg    = shift;

    my $response = $self->get( $relativeUrl );
    my $ret      = $self->mustNotContain( $response, $content, $errorMsg );
    if( defined( $status )) {
        my $tmp = $self->mustStatus( $response, $status, $errorMsg );
        if( defined( $tmp->{error} )) {
            appendError( $ret, $tmp->{error} );
        }
    }
    return $ret;
}

##
# Test that an HTTP GET on a relative URL returns a page that matches a regular expression.
# Convenience method to make tests more concise.
# $relativeUrl: appended to the application's context URL
# $regex: the regex for the content to look for in the response
# $status: optional HTTP status to look for
# $errorMsg: if the test fails, report this error message
sub getMustMatch {
    my $self        = shift;
    my $relativeUrl = shift;
    my $regex       = shift;
    my $status      = shift;
    my $errorMsg    = shift;

    my $response = $self->get( $relativeUrl );
    my $ret      = $self->mustMatch( $response, $regex, $errorMsg );
    if( defined( $status )) {
        my $tmp = $self->mustStatus( $response, $status, $errorMsg );
        if( defined( $tmp->{error} )) {
            appendError( $ret, $tmp->{error} );
        }
    }
    return $ret;
}

##
# Test that an HTTP GET on a relative URL returns a page that does not
# match a regular expression.
# Convenience method to make tests more concise.
# $relativeUrl: appended to the application's context URL
# $regex: the regex for the content to look for in the response
# $status: optional HTTP status to look for
# $errorMsg: if the test fails, report this error message
sub getMustNotMatch {
    my $self        = shift;
    my $relativeUrl = shift;
    my $regex       = shift;
    my $status      = shift;
    my $errorMsg    = shift;

    my $response = $self->get( $relativeUrl );
    my $ret      = $self->mustNotMatch( $response, $regex, $errorMsg );
    if( defined( $status )) {
        my $tmp = $self->mustStatus( $response, $status, $errorMsg );
        if( defined( $tmp->{error} )) {
            appendError( $ret, $tmp->{error} );
        }
    }
    return $ret;
}

##
# Test that an HTTP GET on a relative URL redirects to a certain other URL.
# Convenience method to make tests more concise.
# $relativeUrl: appended to the application's context URL
# $target: the destination URL
# $status: optional HTTP status to look for
# $errorMsg: if the test fails, report this error message
sub getMustRedirect {
    my $self        = shift;
    my $relativeUrl = shift;
    my $target      = shift;
    my $status      = shift;
    my $errorMsg    = shift;

    my $response = $self->get( $relativeUrl );
    my $ret      = $self->mustRedirect( $response, $target, $errorMsg );
    if( defined( $status )) {
        my $tmp = $self->mustStatus( $response, $status, $errorMsg );
        if( defined( $tmp->{error} )) {
            appendError( $ret, $tmp->{error} );
        }
    }
    return $ret;
}

##
# Test that an HTTP GET on a relative URL does not redirect to a certain
# other URL.
# Convenience method to make tests more concise.
# $relativeUrl: appended to the application's context URL
# $target: the destination URL
# $status: optional HTTP status to look for
# $errorMsg: if the test fails, report this error message
sub getMustNotRedirect {
    my $self        = shift;
    my $relativeUrl = shift;
    my $target      = shift;
    my $status      = shift;
    my $errorMsg    = shift;

    my $response = $self->get( $relativeUrl );
    my $ret      = $self->mustNotRedirect( $response, $target, $errorMsg );
    if( defined( $status )) {
        my $tmp = $self->mustNotStatus( $response, $status, $errorMsg );
        if( defined( $tmp->{error} )) {
            appendError( $ret, $tmp->{error} );
        }
    }
    return $ret;
}

##
# Look for a certain status code in a response.
# $response: the response
# $status: HTTP status to look for
# $errorMsg: if the test fails, report this error message
sub getMustStatus {
    my $self        = shift;
    my $relativeUrl = shift;
    my $status      = shift;
    my $errorMsg    = shift;

    my $response = $self->get( $relativeUrl );
    my $ret      = $self->mustStatus( $response, $status, $errorMsg );
    
    return $ret;
}

##
# Look for certain content in a response.
# $response: the response
# $content: the content to look for in the response
# $errorMsg: if the test fails, report this error message
sub mustContain {
    my $self     = shift;
    my $response = shift;
    my $content  = shift;
    my $errorMsg = shift;

    my %ret = %$response; # make copy
    unless( $self->contains( $response, $content )) {
        debugResponse( $response );
        $ret{error} = $self->error( $errorMsg, 'Response content does not contain', $content );
    }
    return \%ret;
}

##
# Look for the lack of a certain content in a response.
# $response: the response
# $content: the content to look for in the response
# $errorMsg: if the test fails, report this error message
sub mustNotContain {
    my $self     = shift;
    my $response = shift;
    my $content  = shift;
    my $errorMsg = shift;

    my %ret = %$response; # make copy
    unless( $self->notContains( $response, $content )) {
        debugResponse( $response );
        $ret{error} = $self->error( $errorMsg, 'Response content contains', $content );
    }
    return \%ret;
}

##
# Look for a regular expression match on the content in a response
# $response: the response
# $regex: the regex for the content to look for in the response
# $errorMsg: if the test fails, report this error message
sub mustMatch {
    my $self     = shift;
    my $response = shift;
    my $regex    = shift;
    my $errorMsg = shift;
    
    my %ret = %$response; # make copy
    unless( $self->matches( $response, $regex )) {
        debugResponse( $response );
        $ret{error} = $self->error( $errorMsg, 'Response content does not match regex', $regex );
    }
    return \%ret;
}

##
# Look for a regular expression non-match on the content in a response
# $response: the response
# $regex: the regex for the content to look for in the response
# $errorMsg: if the test fails, report this error message
sub mustNotMatch {
    my $self     = shift;
    my $response = shift;
    my $regex    = shift;
    my $errorMsg = shift;
    
    my %ret = %$response; # make copy
    unless( $self->notMatches( $response, $regex )) {
        debugResponse( $response );
        $ret{error} = $self->error( $errorMsg, 'Response content does not match regex', $regex );
    }
    return \%ret;
}

##
# Look for a redirect to a certain URL in the response
# $response: the response
# $target: the redirect target
# $errorMsg: if the test fails, report this error message
sub mustRedirect {
    my $self     = shift;
    my $response = shift;
    my $target   = shift;
    my $errorMsg = shift;

    my %ret = %$response; # make copy
    unless( $self->redirects( $response, $target )) {
        debugResponse( $response );
        $ret{error} = $self->error( $errorMsg, 'Response is not redirecting to', $target );
    }
    return \%ret;
}

##
# Look for the lack of a redirect to a certain URL in the response
# $response: the response
# $target: the redirect target
# $errorMsg: if the test fails, report this error message
sub mustNotRedirect {
    my $self     = shift;
    my $response = shift;
    my $target   = shift;
    my $errorMsg = shift;

    my %ret = %$response; # make copy
    unless( $self->notRedirects( $response, $target )) {
        debugResponse( $response );
        $ret{error} = $self->error( $errorMsg, 'Response is redirecting to', $target );
    }
    return \%ret;
}

##
# Look for an HTTP status in the response
# $response: the response
# $status: the HTTP status
# $errorMsg: if the test fails, report this error message
sub mustStatus {
    my $self     = shift;
    my $response = shift;
    my $status   = shift;
    my $errorMsg = shift;

    my %ret = %$response; # make copy
    unless( $self->status( $response, $status )) {
        debugResponse( $response );
        $ret{error} = $self->error( $errorMsg, 'Response does not have HTTP status', $status );
    }
    return \%ret;
}

##
# Look for an HTTP status other than the provided one in the response
# $response: the response
# $status: the HTTP status
# $errorMsg: if the test fails, report this error message
sub mustNotStatus {
    my $self     = shift;
    my $response = shift;
    my $status   = shift;
    my $errorMsg = shift;

    my %ret = %$response; # make copy
    unless( $self->notStatus( $response, $status )) {
        debugResponse( $response );
        $ret{error} = $self->error( $errorMsg, 'Response has HTTP status',  $status );
    }
    return \%ret;
}

##
# Look for certain content in a response.
# $response: the response
# $content: the content to look for in the response
# $errorMsg: if the test fails, report this error message
sub contains {
    my $self     = shift;
    my $response = shift;
    my $content  = shift;

    if( $response->{content} !~ m!\Q$content\E! ) {
        return 0;
    }
    return 1;
}

##
# Look for the lack of a certain content in a response.
# $response: the response
# $content: the content to look for in the response
sub notContains {
    my $self     = shift;
    my $response = shift;
    my $content  = shift;

    if( $response->{content} =~ m!\Q$content\E! ) {
        return 0;
    }
    return 1;
}

##
# Look for a regular expression match on the content in a response
# $response: the response
# $regex: the regex for the content to look for in the response
sub matches {
    my $self     = shift;
    my $response = shift;
    my $regex    = shift;
    
    if( $response->{content} !~ m!$regex! ) {
        return 0;
    }
    return 1;
}

##
# Look for a regular expression non-match on the content in a response
# $response: the response
# $regex: the regex for the content to look for in the response
sub notMatches {
    my $self     = shift;
    my $response = shift;
    my $regex    = shift;

    if( $response->{content} =~ m!$regex! ) {
        return 0;
    }
    return 1;
}

##
# Look for a redirect to a certain URL in the response
# $response: the response
# $target: the redirect target
sub redirects {
    my $self     = shift;
    my $response = shift;
    my $target   = shift;

    if( $target !~ m!^https?://! ) {
        if( $target !~ m!^/! ) {
            $self->error( 'Cannot look for target URL without protocol or leading slash', $target );
            return 0;
        }
        $target = $self->fullContext() . $target;
    }

    if( $response->{headers} !~ m!Location: $target! ) {
        return 0;
    }
    return 1;
}

##
# Look for the lack of a redirect to a certain URL in the response
# $response: the response
# $target: the redirect target
sub notRedirects {
    my $self     = shift;
    my $response = shift;
    my $target   = shift;

    if( $target !~ m!^https?://! ) {
        if( $target !~ m!^/! ) {
            $self->error( 'Cannot look for target URL without protocol or leading slash', $target );
            return 0;
        }
        $target = $self->fullContext() . $target;
    }

    if( $response->{headers} =~ m!Location: $target! ) {
        return 0;
    }
    return 1;
}

##
# Look for an HTTP status in the response
# $response: the response
# $status: the HTTP status
sub status {
    my $self     = shift;
    my $response = shift;
    my $status   = shift;

    if( $response->{headers} !~ m!HTTP/1\.[01] $status! ) {
        return 0;
    }
    return 1;
}

##
# Look for an HTTP status other than the provided one in the response
# $response: the response
# $status: the HTTP status
sub notStatus {
    my $self     = shift;
    my $response = shift;
    my $status   = shift;

    if( $response->{headers} =~ m!HTTP/1\.1 $status! ) {
        return 0;
    }
    return 1;
}

##### (4) File testing methods #####

##
# Test that a file exists and has certain content and properties
# $fileName: name of the file
# $fileUname: name of the file's owner, or undef if not to be checked
# $fileGname: name of the file's group, or undef if not to be checked
# $fileMode: number (per chmod) for file permissions, or undef if not the be checked
# $testMethod: a method to invoke which will return 1 (ok) or 0 (fail), or undef
#              if not to be checked. Parameters: 1: this TestContext, 2: fileName
sub checkFile {
    my $self       = shift;
    my $fileName   = shift;
    my $fileUname  = shift;
    my $fileGname  = shift;
    my $fileMode   = shift;
    my $testMethod = shift;

    my( $dev, $ino, $mode, $nlink, $uid, $gid, $rdev, $size, $atime, $mtime, $ctime, $blksize, $blocks )
            = lstat( $fileName);

    unless( $dev ) {
        $self->error( 'File does not exist:', $fileName );
        return 0;
    }

    my $ret = 1;

    unless( Fcntl::S_ISREG( $mode )) {
        $self->error( 'Not a regular file:', $fileName );
        $ret = 0;
    }
    
    if( defined( $fileMode )) {
        my $realFileMode = oct( $fileMode );
        my $realMode     = $mode & 07777; # ignore special file bits
        if( $realFileMode != $realMode ) {
            $self->error( 'File', $fileName, 'has wrong permissions:', sprintf( '%o vs %o', $realFileMode, $realMode ));
            $ret = 0;
        }
    }

    if( defined( $fileUname )) {
        my $fileUid = UBOS::Utils::getUid( $fileUname );
        if( $fileUid != $uid ) {
            $self->error( 'File', $fileName, 'has wrong owner:', $fileUid, 'vs.', $uid );
            $ret = 0;
        }
    }
    if( defined( $fileGname )) {
        my $fileGid = UBOS::Utils::getGid( $fileGname );
        if( $fileGid != $gid ) {
            $self->error( 'File', $fileName, 'has wrong group:', $fileGid, 'vs.', $gid );
            $ret = 0;
        }
    }
    if( defined( $testMethod )) {
        $ret &= $testMethod->( $self, $fileName );
    }

    return $ret;
}

##
# Test that a directory exists and has certain content and properties
# $dirName: name of the directory
# $dirUname: name of the directory's owner, or undef if not to be checked
# $dirGname: name of the directory's group, or undef if not to be checked
# $dirMode: number (per chmod) for directory permissions, or undef if not the be checked
sub checkDir {
    my $self      = shift;
    my $dirName   = shift;
    my $dirUname  = shift;
    my $dirGname  = shift;
    my $dirMode   = shift;

    my( $dev, $ino, $mode, $nlink, $uid, $gid, $rdev, $size, $atime, $mtime, $ctime, $blksize, $blocks )
            = lstat( $dirName);

    unless( $dev ) {
        $self->error( 'Directory does not exist:', $dirName );
        return 0;
    }

    my $ret = 1;

    unless( Fcntl::S_ISDIR( $mode )) {
        $self->error( 'Not a directory:', $dirName );
        $ret = 0;
    }

    if( defined( $dirMode )) {
        my $realDirMode = oct( $dirMode );
        my $realMode    = $mode & 07777; # ignore special file bits
        if( $realDirMode != $realMode ) {
            $self->error( 'Directory', $dirName, 'has wrong permissions:', sprintf( '%o vs %o', $realDirMode, $realMode ));
            $ret = 0;
        }
    }

    if( defined( $dirUname )) {
        my $dirUid = UBOS::Utils::getUid( $dirUname );
        if( $dirUid != $uid ) {
            $self->error( 'Directory', $dirName, 'has wrong owner:', $dirUid, 'vs.', $uid );
            $ret = 0;
        }
    }
    if( defined( $dirGname )) {
        my $dirGid = UBOS::Utils::getGid( $dirGname );
        if( $dirGid != $gid ) {
            $self->error( 'Directory', $dirName, 'has wrong group:', $dirGid, 'vs.', $gid );
            $ret = 0;
        }
    }

    return $ret;
}

##
# Tests that a symbolic link exists and points to a certain destination.
# Think "ln -s $target $link"
# $target: the destination of the symlink
# $link: the symlink itself
sub checkSymlink {
    my $self   = shift;
    my $target = shift;
    my $link   = shift;

    my( $dev, $ino, $mode, $nlink, $uid, $gid, $rdev, $size, $atime, $mtime, $ctime, $blksize, $blocks )
            = lstat( $link);

    unless( $dev ) {
        $self->error( 'Symbolic link does not exist:', $link );
        return 0;
    }

    my $ret = 1;
    unless( Fcntl::S_ISLNK( $mode )) {
        $self->error( 'Not a symlink:', $link );
        $ret = 0;
    }
    my $content = readlink( $link );
    if( $target ne $content ) {
        $self->error( 'Wrong target for symbolic link:', $target, 'vs.', $content );
        $ret = 0;
    }
    return $ret;
}

##### (5) Utility methods #####

##
# Emit a response in the debug level of the log
# $response: the response
sub debugResponse {
    my $response = shift;

    my $msg = "Response:\n";
    $msg .= UBOS::Utils::printHashAsColumns( $response );

    debug( $msg );
}

##
# Report an error.
# @args: error message
sub error {
    my $self = shift;
    my @args = @_;

    my $msg = join( ' ', grep { !/^\s*$/ } @_ );

    UBOS::Logging::error( $msg );

    push @{$self->{errors}}, $msg;
    
    return $msg;
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
# Append an error message to the error messages that may already be
# contained in this response hash
# $hash: the response hash
# $newError: the error message
sub appendError {
    my $hash     = shift;
    my $newError = shift;

    my $error = $hash->{error};
    if( $error ) {
        my $index = 0;
        foreach my $line ( split( "\n", $error ) ) {
            if( $line =~ m!^\s*(\d+):! ) {
                $index = $1;
            }
        }
        if( $index ) {
            $error .= ++$index . ": " . $newError;
        } else {
            $error = "1: $error$newError";
        }
        
    } else {
        $hash->{error} = $error;
    }
    return $hash;
}

##
# Destroy this context.
sub destroy {
    my $self = shift;

    # could be used to delete cookie files, but right now Perl does this itself
}

1;
