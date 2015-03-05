#!/usr/bin/perl
#
# Abstract superclass for all Scaffold implementations.
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

package UBOS::WebAppTest::AbstractScaffold;

use fields qw( isOk verbose );
use UBOS::Logging;
use UBOS::Utils;

##
# Instantiate the Scaffold. This may take a long time.
# This method must be overridden by subclasses.
# $options: hash of options
sub setup {
    my $self    = shift;
    my $options = shift;

    unless( ref $self ) {
        fatal( 'Must override Scaffold' );
    }

    if( exists( $options->{verbose} )) {
        $self->{verbose} = $options->{verbose} || 0;
    } else {
        $self->{verbose} = 0;
    }        

    return $self;
}

##
# Determine whether this Scaffold has successfully initialized
# return: true or false
sub isOk {
    my $self = shift;

    return $self->{isOk};
}

##
# Deploy a site
# $site: site JSON
sub deploy {
    my $self = shift;
    my $site = shift;

    my $jsonString = UBOS::Utils::writeJsonToString( $site );
    debug( 'Site JSON:', $jsonString );

    my $cmd = 'sudo ubos-admin deploy --stdin';
    $cmd .= ( ' --verbose' x $self->{verbose} );

    my $exit = $self->invokeOnTarget( $cmd, $jsonString );
    return !$exit;
}

##
# Undeploy a site
# $site: site JSON
sub undeploy {
    my $self = shift;
    my $site = shift;

    my $cmd = 'sudo ubos-admin undeploy';
    $cmd .= ( ' --verbose' x $self->{verbose} );
    $cmd .= ' --siteid ' . $site->{siteid};

    my $exit = $self->invokeOnTarget( $cmd );
    return !$exit;
}

##
# Update all code on the target.
sub update {
    my $self = shift;

    my $cmd = 'sudo ubos-admin update';
    $cmd .= ( ' --verbose' x $self->{verbose} );
    
    my $exit = $self->invokeOnTarget( $cmd );
    return !$exit;
}

##
# Backup a site. This does not move the backup from the target to
# the local machine if the target is remote.
# $site: site JSON
# return: identifier of the backup, e.g. filename
sub backup {
    my $self = shift;
    my $site = shift;

    my $file;

    my $cmd = 'F=$(mktemp webapptest-XXXXX.ubos-backup);';
    $cmd .= ' sudo ubos-admin backup';
    $cmd .= ( ' --verbose' x $self->{verbose} );
    $cmd .= ' --siteid ' . $site->{siteid} . ' --out $F;';
    $cmd .= ' echo $F';

    my $exit = $self->invokeOnTarget( $cmd, undef, \$file );
    if( !$exit ) {
        $file =~ s!^\s+!!;
        $file =~ s!\s+$!!;
        return $file;
    } else {
        error( 'Backup failed' );
        return 0;
    }
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

    error( 'Must override Scaffold::backupToLocal' );

    return undef;
}    

##
# Restore a site
# $site: site JSON
# $identifier: identifier of the backupobtained earlier via backup
sub restore {
    my $self       = shift;
    my $site       = shift;
    my $identifier = shift;

    my $cmd = 'sudo ubos-admin restore';
    $cmd .= ( ' --verbose' x $self->{verbose} );
    $cmd .= ' --siteid ' . $site->{siteid} . ' --in ' . $identifier;

    my $exit = $self->invokeOnTarget( $cmd );
    return !$exit;
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

    error( 'Must override Scaffold::restoreFromLocal' );

    return undef;
}

##
# Destroy a previously created backup
sub destroyBackup {
    my $self       = shift;
    my $site       = shift;
    my $identifier = shift;

    my $exit = $self->invokeOnTarget( 'rm ' . $identifier );
    return !$exit;
}

##
# Teardown this Scaffold.
# This method must be overridden by subclasses.
sub teardown {
    my $self = shift;

    return 0;
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

    error( 'Must override Scaffold::invokeOnTarget' );

    return 0;
}

##
# Obtain the IP address of the target. This must be overridden by subclasses.
# return: IP address
sub getTargetIp {
    my $self = shift;

    error( 'Must override Scaffold::getTargetIp' );

    return undef;
}

##
# Obtain information about a file on the target. This must be overridden by
# subclasses.
# $fileName: full path name of the file on the target
# $makeContentAvailable: if true, also make the content available locally.
# return( $uname, $gname, $mode, $localContent ): localContent is the name
#        if a locally available file with the same content, except that
#        if the file turns out to be a symlink, it is the target of the symlink
sub getFileInfo {
    my $self                 = shift;
    my $fileName             = shift;
    my $makeContentAvailable = shift;

    error( 'Must override Scaffold::getFileInfo' );

    return undef;
}

##
# Handle the impersonatedepot option, if given
# $options: the scaffold options
# $ip: the IP address to use for depot.ubos.net
sub handleImpersonateDepot {
    my $self    = shift;
    my $options = shift;
    my $ip      = shift;

    my $on;
    if( exists( $options->{impersonatedepot} )) {
        $on = 1;
    } else {
        $on = 0;
    }

    my $cmd = <<CMD;
use strict;
use warnings;

use UBOS::Utils;

my \$ip = '$ip';
my \$on = $on;

unless( -r '/etc/hosts' ) {
    print STDERR "Cannot read /etc/hosts on target $ip\\n";
    exit 1;
}
CMD
    $cmd .= <<'CMD';

my $etchosts = UBOS::Utils::slurpFile( '/etc/hosts' );
if( $etchosts ) {
    if( $on ) {
        unless( $etchosts =~ m!depot\.ubos\.net! ) {
            $etchosts .= <<ADD;
# webapptest added
$ip depot.ubos.net
ADD
            UBOS::Utils::saveFile( '/etc/hosts', $etchosts, 0644, 'root', 'root' );
        }
    } else {
        my $changed = 0;
        if( $etchosts =~ s!# webapptest added\s*!! ) {
            $changed = 1;
        }
        my $ipEsc = quotemeta( $ip );
        if( $etchosts =~ s!$ipEsc\s+depot\.ubos\.net!! ) {
            $changed = 1;
        }
        if( $changed ) {
            UBOS::Utils::saveFile( '/etc/hosts', $etchosts, 0644, 'root', 'root' );
        }
    }
    exit 0;

} else {
    print STDERR "/etc/hosts is empty on $ip. Not changing\n";
    exit 1;
}
1;
CMD
    my $out;
    my $err;
    if( $self->invokeOnTarget( 'sudo /bin/bash -c /usr/bin/perl', $cmd, \$out, \$err )) {
        error( "Failed to edit /etc/hosts file to add depot.ubos.net:", $out, $err );
        return 0;

    } elsif( $err =~ /Respect the privacy of others/ ) {
        error( "Failed to edit /etc/hosts file to add depot.ubos.net. sudo problem:", $out, $err );
        return 0;
    }
    return 1;
}

1;
