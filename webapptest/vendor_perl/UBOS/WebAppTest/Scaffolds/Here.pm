#!/usr/bin/perl
#
# A trivial scaffold for running tests on the local machine without
# any insulation.
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

package UBOS::WebAppTest::Scaffolds::Here;

use base qw( UBOS::WebAppTest::AbstractScaffold );
use fields;
use UBOS::Logging;

##
# Instantiate the Scaffold.
# $options: hash of options
sub setup {
    my $self    = shift;
    my $options = shift;

    unless( ref $self ) {
        $self = fields::new( $self );
    }
    $self->SUPER::setup( $options );

    info( 'Creating Scaffold Here' );

    $self->{isOk} = $self->handleImpersonateDepot( $options, '127.0.0.1' );

    return $self;
}

##
# Backup a site to a local file on the local machine.
# $site: $site JSON
# $filename: the local backup file name
# return: if successful, $filename
sub backupToLocal {
    my $self     = shift;
    my $site     = shift;
    my $filename = shift;

    my $cmd = 'sudo ubos-admin backup';
    $cmd .= ( ' --verbose' x $self->{verbose} );
    $cmd .= ' --siteid ' . $site->{siteid} . ' --out ' . $filename;

    my $exit = UBOS::Utils::myexec( $cmd );
    if( !$exit ) {
        UBOS::Utils::myexec( 'sudo chown $(id -un):$(id -gn) ' . $filename );
        return $filename;
    } else {
        error( 'Backup failed, exit', $exit );
        return 0;
    }
} 

##
# Restore a site from a local file on the local machine
# $site: $site JSON
# $filename: the local backup file name
# return: if successful, $filename
sub restoreFromLocal {
    my $self     = shift;
    my $site     = shift;
    my $filename = shift;

    my $cmd = 'sudo ubos-admin listsites';
    $cmd .= ( ' --verbose' x $self->{verbose} );
    $cmd .= ' --brief --backupfile ' . $filename;

    my $siteIdInBackup;
    my $exit = UBOS::Utils::myexec( $cmd, undef, \$siteIdInBackup );
    if( $exit ) {
        error( 'Cannot listsites in backup file, exit', $exit );
        return 0;
    }
    $siteIdInBackup =~ s!^\s+!!g;
    $siteIdInBackup =~ s!\s+$!!g;

    $cmd = 'sudo ubos-admin restore';
    $cmd .= ( ' --verbose' x $self->{verbose} );
    $cmd .= ' --siteid '     . $siteIdInBackup;
    $cmd .= ' --hostname '   . $site->{hostname};
    $cmd .= ' --newsiteid '  . $site->{siteid};
    $cmd .= ' --in '         . $filename;

    $exit = UBOS::Utils::myexec( $cmd );
    
    if( !$exit ) {
        return 1;
    } else {
        error( 'Restore failed, exit', $exit );
        return 0;
    }
}

##
# Teardown this Scaffold.
sub teardown {
    my $self = shift;

    info( 'Tearing down Scaffold Here' );

    return 1;
}

##
# Helper method to invoke a command on the target. This must be overridden by subclasses.
# $cmd: command
# $stdin: content to pipe into stdin
# $stdout: content captured from stdout
# $stderr: content captured from stderr
sub invokeOnTarget {
    my $self   = shift;
    my $cmd    = shift;
    my $stdin  = shift;
    my $stdout = shift;
    my $stderr = shift;

    return UBOS::Utils::myexec( $cmd, $stdin, $stdout, $stderr );
}

##
# Obtain the IP address of the target.
# return: IP address
sub getTargetIp {
    my $self = shift;

    return '127.0.0.1';
}

##
# Obtain information about a file on the target. This must be overridden by
# subclasses.
# $fileName: full path name of the file on the target
# $makeContentAvailable: if true, also make the content available locally
# return( $uname, $gname, $mode, $localContent ): localContent is the name
#        if a locally available file with the same content, except that
#        if the file turns out to be a symlink, it is the target of the symlink
sub getFileInfo {
    my $self                 = shift;
    my $fileName             = shift;
    my $makeContentAvailable = shift;

    my( $dev, $ino, $mode, $nlink, $uid, $gid, $rdev, $size, $atime, $mtime, $ctime, $blksize, $blocks )
            = lstat( $fileName );

    unless( $dev ) {
        return undef;
    }
    my $uname = UBOS::Utils::getUname( $uid );
    my $gname = UBOS::Utils::getGname( $gid );

    if( $makeContentAvailable ) {
        if( Fcntl::S_ISLNK( $mode )) {
            return( $uname, $gname, $mode, readlink( $fileName ));
        } else {
            return( $uname, $gname, $mode, $fileName );
        }
    } else {
        return( $uname, $gname, $mode );
    }
}

##
# Return help text.
# return: help text
sub help {
    return 'A trivial scaffold that runs tests on the local machine without any insulation.';
}

1;
