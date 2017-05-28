#!/usr/bin/perl
#
# Abstract superclass for Scaffold implementations that access a remote
# host via ssh.
#
# This file is part of webapptest.
# (C) 2012-2015 Indie Computing Corp.
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

package UBOS::WebAppTest::AbstractRemoteScaffold;

use base qw( UBOS::WebAppTest::AbstractScaffold );
use fields qw( sshHost sshUser sshPrivateKeyFile );

use File::Temp;
use UBOS::Logging;
use UBOS::Utils;

##
# Backup a site to a local file on the local machine.
# $site: $site JSON
# $filename: the local backup file name
# return: if successful, $filename
sub backupToLocal {
    my $self     = shift;
    my $site     = shift;
    my $filename = shift;

    my $cmd = 'F=$(mktemp webapptest-XXXXX.ubos-backup)';
    $cmd .= ' sudo ubos-admin backup';
    $cmd .= ( ' --verbose' x $self->{verbose} );
    $cmd .= ' --siteid ' . $site->{siteid} . ' --out $F;';
    $cmd .= ' echo $F';

    my $remoteFile;
    my $exit = $self->invokeOnTarget( $cmd, undef, \$remoteFile );
    if( $exit ) {
        error( 'Remote backup failed' );
        return undef;
    }
    $remoteFile =~ s!^\s+!!;
    $remoteFile =~ s!\s+$!!;

    $exit = $self->copyFromTarget( $remoteFile, $filename );
    if( $exit ) {
        error( 'Copying backup from remote to local failed' );
        return undef;
    }
    $self->destroyBackup( $remoteFile );

    return $filename;
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
    
    my $remoteFile;
    $exit = $self->invokeOnTarget( 'mktemp webapptest-XXXXX.ubos-backup', undef, \$remoteFile );
    if( $exit ) {
        error( 'Failed to create remote temp file' );
        return 0;
    }
    $remoteFile =~ s!^\s+!!;
    $remoteFile =~ s!\s+$!!;

    $exit = $self->copyToTarget( $filename, $remoteFile );
    if( $exit ) {
        error( 'Failed to copy backup from local to remote ' );
        return 0;
    }

    $cmd = 'sudo ubos-admin restore';
    $cmd .= ( ' --verbose' x $self->{verbose} );
    $cmd .= ' --siteid '     . $siteIdInBackup;
    $cmd .= ' --hostname '   . $site->{hostname};
    $cmd .= ' --newsiteid '  . $site->{siteid};
    $cmd .= ' --in '         . $filename;

    $exit = $self->invokeOnTarget( $cmd );

    if( !$exit ) {
        return 1;
    } else {
        error( 'Restore failed, exit', $exit );
        return 0;
    }
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

    my $sshCmd = 'ssh';
    $sshCmd .= ' -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=error';
            # don't put into known_hosts file, and don't print resulting warnings
    $sshCmd .= ' ' . $self->{sshUser} . '@' . $self->{sshHost};
    if( $self->{sshPrivateKeyFile} ) {
        $sshCmd .= ' -i ' . $self->{sshPrivateKeyFile};
    }
    $sshCmd .= " '$cmd'";

    my $ret = UBOS::Utils::myexec( $sshCmd, $stdin, $stdout, $stderr );

    if( $ret == 0 && $stderr ) {
        if( $$stderr =~ m!^(FATAL|ERROR|WARNING):! ) {
            # Guess the command was wrong, it didn't return an error code
            $ret = -999;
        } else {
            # If there are no errors, zap the log output
            $$stderr = '';
        }
    }
    return $ret;
}

##
# Obtain the IP address of the target.
# return: IP address
sub getTargetIp {
    my $self = shift;

    return $self->{sshHost};
}

##
# Copy a remote file to the local machine
# $remoteFile: the name of the file on the remote machine
# $localFile: the name of the file on the local machine
sub copyFromTarget {
    my $self       = shift;
    my $remoteFile = shift;
    my $localFile  = shift;

    my $scpCmd = 'scp -q';
    $scpCmd .= ' -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=error';
            # don't put into known_hosts file, and don't print resulting warnings
    if( $self->{sshPrivateKeyFile} ) {
        $scpCmd .= ' -i ' . $self->{sshPrivateKeyFile};
    }
    $scpCmd .= ' ' . $self->{sshUser} . '@' . $self->{sshHost} . ':' . $remoteFile;
    $scpCmd .= ' ' . $localFile;
    debug( 'scp command:', $scpCmd );

    my $ret = UBOS::Utils::myexec( $scpCmd );
    return $ret;
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

    # Perl inside Perl -- escaping is a bit tricky
    my $script = <<SCRIPT;
use strict;
use warnings;

if( -e '$fileName' ) {
    my \@found = lstat( '$fileName' );
    \$found[4] = getpwuid( \$found[4] );
    \$found[5] = getgrgid( \$found[5] );
    print( join( ',', \@found ) . "\\n" );
    if( -l '$fileName' ) {
        print readlink( '$fileName' ) . "\\n";
    }
} else {
    print( "---\\n" );
}
exit 0;
1;
SCRIPT

    my $out;
    my $err;
    if( $self->invokeOnTarget( 'perl', $script, \$out, \$err )) {
        error( 'Failed to invoke remote perl command', $err );
        return undef;
    }

    my @lines = split /\n/, $out;

    if( $lines[0] eq '---' ) {
        return undef;
    }
    my( $dev, $ino, $mode, $nlink, $uname, $gname, $rdev, $size, $atime, $mtime, $ctime, $blksize, $blocks )
            = split( /,/, $lines[0] );

    if( $makeContentAvailable ) {
        if( Fcntl::S_ISLNK( $mode )) {
            my $target = $lines[1];
            return( $uname, $gname, $mode, $target );

        } else {
            my $localFile = tmpnam();
            $self->copyFromTarget( $fileName, $localFile );
            chmod 0600, $localFile; # scp keeps permissions

            return( $uname, $gname, $mode, $localFile );
        }

    } else {
        return( $uname, $gname, $mode );
    }
}
               
1;
