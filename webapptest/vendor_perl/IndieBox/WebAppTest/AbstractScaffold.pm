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

package IndieBox::WebAppTest::AbstractScaffold;

use fields;
use IndieBox::Logging;
use IndieBox::Utils;

##
# Instantiate the Scaffold. This may take a long time.
# This method must be overridden by subclasses.
sub setup {
    my $self = shift;

    unless( ref $self ) {
        fatal( 'Must override Scaffold' );
    }

    return $self;
}

##
# Deploy a site
# $site: site JSON
sub deploy {
    my $self = shift;
    my $site = shift;

    my $jsonString = IndieBox::Utils::writeJsonToString( $site );
    debug( 'Site JSON:', $jsonString );

    my $exit = $self->invokeOnTarget( 'sudo indiebox-admin deploy', $jsonString );
    return !$exit;
}

##
# Undeploy a site
# $site: site JSON
sub undeploy {
    my $self = shift;
    my $site = shift;

    my $exit = $self->invokeOnTarget( 'sudo indiebox-admin undeploy --siteid ' . $site->{siteid} );
    return !$exit;
}

##
# Update all code on the target.
sub update {
    my $self = shift;

    my $exit = $self->invokeOnTarget( 'sudo indiebox-admin update' );
    return !$exit;
}

##
# Backup a site.
# $site: site JSON
# return: identifier of the backup, e.g. filename
sub backup {
    my $self = shift;
    my $site = shift;

    my $file;
    
    my $exit = $self->invokeOnTarget( 'F=$(mktemp webapptest-XXXXX.indie-backup); sudo indiebox-admin backup --siteid ' . $site->{siteid} . ' --out $F; echo $F', undef, \$file );
    if( !$exit ) {
        return $file;
    } else {
        return 0;
    }
}

##
# Restore a site
# $site: site JSON
# $identifier: identifier of the backupobtained earlier via backup
sub restore {
    my $self       = shift;
    my $site       = shift;
    my $identifier = shift;

    my $exit = $self->invokeOnTarget( 'sudo indiebox-admin restore --siteid ' . $site->{siteid} . ' --in ' . $identifier );
    return !$exit;
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
sub invokeOnTarget {
    my $self  = shift;
    my $cmd   = shift;
    my $stdin = shift;

    error( 'Must override Scaffold::invokeOnTarget' );

    return 0;
}

##
# Obtain the IP address of the target.  This must be overridden by subclasses.
# return: target IP
sub getTargetIp {
    my $self  = shift;

    error( 'Must override Scaffold::getTargetIp' );

    return undef;
}
    
1;
