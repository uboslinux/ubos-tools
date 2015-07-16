#!/usr/bin/perl
#
# A scaffold for running tests on the local machine inside a
# Linux container.
#
# The container is configured with two network interfaces:
# 1: uses NAT networking, so it can access the public internet and
#    download new packages if the test requires that.
# 2: uses hostonly, so the host can do HTTP get on web apps
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

package UBOS::WebAppTest::Scaffolds::Container;

use base qw( UBOS::WebAppTest::AbstractRemoteScaffold );
use fields qw( directory name sshPublicKeyFile
               bootMaxSeconds shutdownMaxSeconds );

use File::Temp qw( tempdir );
use Socket;
use UBOS::Logging;
use UBOS::Utils;

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

    # make sure ip_forwarding is set on the host
    my $out;
    if( UBOS::Utils::myexec( 'sysctl net.ipv4.ip_forward', undef, \$out ) != 0 ) {
        fatal( 'sysctl call failed' );
    }
    unless( $out =~ m!\Qnet.ipv4.ip_forward\E\s*=\s*1\s*! ) {
        fatal( 'Cannot run Container scaffold without IPv4 forwarding:', $out );
    }

    $self->{isOk} = 0; # until we decide otherwise

    my $name;
    if( exists( $options->{name} )) {
        $self->{name} = $options->{name};
        delete $options->{name};
    } else {
        $self->{name} = 'webapptest-' . UBOS::Utils::time2string( time() );
    }

    if( exists( $options->{'shepherd'} )) {
        unless( $options->{'shepherd'} ) {
            fatal( 'Value for shepherd cannot be empty' );
        }
        $self->{sshUser} = $options->{'shepherd'};
        delete $options->{'shepherd'};
    } else {
        $self->{sshUser} = 'shepherd';
    }

    unless( exists( $options->{'shepherd-public-key-file'} ) && $options->{'shepherd-public-key-file'} ) {
        fatal( 'No value provided for shepherd-public-key-file' );
    }
    unless( -r $options->{'shepherd-public-key-file'} ) {
        fatal( 'Cannot find or read file', $options->{'shepherd-public-key-file'} );
    }
    unless( exists( $options->{'shepherd-private-key-file'} ) && $options->{'shepherd-private-key-file'} ) {
        fatal( 'No value provided for shepherd-private-key-file' );
    }
    unless( -r $options->{'shepherd-private-key-file'} ) {
        fatal( 'Cannot find or read file', $options->{'shepherd-private-key-file'} );
    }


    debug( 'Creating container', $self->{name} );

    unless( exists( $options->{directory} )) {
        fatal( 'No value provided for directory' );
    }
    unless( -d $options->{directory} ) {
        fatal( 'directory does not exist or cannot be read:', $options->{directory} );
    }

    if( exists( $options->{'boot-max-seconds'} )) {
        $self->{bootMaxSeconds} = $options->{'boot-max-seconds'};
        delete $options->{'boot-max-seconds'};
    } else {
        $self->{bootMaxSeconds} = 60;
    }

    if( exists( $options->{'shutdown-max-seconds'} )) {
        $self->{shutdownMaxSeconds} = $options->{'shutdown-max-seconds'};
        delete $options->{'shutdown-max-seconds'};
    } else {
        $self->{shutdownMaxSeconds} = 60;
    }

    $self->{directory}         = delete $options->{directory};
    $self->{sshPublicKeyFile}  = delete $options->{'shepherd-public-key-file'};
    $self->{sshPrivateKeyFile} = delete $options->{'shepherd-private-key-file'};
    my $impersonateDepot       = delete $options->{impersonatedepot};

    if( defined( $options ) && %$options ) {
        fatal( 'Unknown option(s) for Scaffold container:', join( ', ', keys %$options ));
    }

    debug( 'Creating ubos-staff config directory' );

    my $ubosStaffDir = tempdir( CLEANUP => 1 );
    $self->populateConfigDir( $ubosStaffDir );

    info( 'Creating Scaffold container' );

    my $outFile = File::Temp->new();

    debug( 'Starting container' );
    my $cmd = "sudo systemd-nspawn";
    $cmd .= " --boot";
    $cmd .= " --ephemeral";
    $cmd .= " --network-veth";
    $cmd .= " --machine=" . $self->{name};
    $cmd .= " --directory '" . $self->{directory} . "'";
    $cmd .= " --bind '" . $ubosStaffDir . ":/UBOS-STAFF'"; # UBOS staff 
    $cmd .= " > '" . $outFile->filename . "'";
    $cmd .= " 2>&1";
    $cmd .= " &";                                          # run in background; we don't want the login prompt

    if( UBOS::Utils::myexec( $cmd )) {
        fatal( 'systemd-nspawn failed', UBOS::Utils::slurpFile( $outFile->filename ));
    }

    info( 'Waiting until target is ready' );
    if( $self->waitUntilTargetReady() ) {
        $self->{isOk} = 1;

        $self->{isOk} &= $self->handleImpersonateDepot( $impersonateDepot );
        $self->{isOk} &= ( $self->invokeOnTarget( "sudo ubos-admin update" ) == 0 );

    } else {
        error( 'Container machine failed to start up in time' );
    }

    return $self;
}

##
# Teardown this Scaffold.
sub teardown {
    my $self = shift;

    info( 'Tearing down Scaffold Container' );

    my $containerName = $self->{name};
    
    if( UBOS::Utils::myexec( "sudo machinectl poweroff '$containerName'" )) {
        error( 'machinectl poweroff failed' );
    }
    my $out;
    my $err;
    for( my $count = 0 ; $count < $self->{shutdownMaxSeconds} ; ++$count ) {
        if( UBOS::Utils::myexec( "sudo machinectl show '$containerName' -p State", undef, \$out, \$err )) {
            last;
        }
        $out =~ s!\s+! !g;
        debug( 'Machine', $containerName, 'still has status', $out );
        sleep 1;
    }

    return 1;
}

##
# Wait until target is ready.
sub waitUntilTargetReady {
    my $self = shift;

    my $name = $self->{name};
    my $ret  = 0;
    my $out;
    my $err;
    for( my $count = 0 ; $count < $self->{bootMaxSeconds} ; $count += 5 ) {
        # systemctl -M $name is-system-running currently is not possible due to
        # https://github.com/uboslinux/ubos-admin/issues/110
        # So we look for success of ubos-httpd instead.
        
        my $result = UBOS::Utils::myexec( "sudo systemctl -M '$name' status ubos-httpd", undef, \$out, \$err );
        if( $result == 0 ) {

            my $h = gethostbyname( $name );
            if( defined( $h )) {
                $self->{sshHost} = inet_ntoa( $h );
            
                debug( 'target', $name, 'is ready at', $self->{sshHost} );

                $ret = 1;
                return $ret;
            }
        }
        sleep 5;
    }
    debug( 'system is-system-running not in time:', $out );

    return $ret;
}

##
# Populate a UBOS staff directory
# $dir: name of the directory
sub populateConfigDir {
    my $self = shift;
    my $dir  = shift;

    my $sshPubKey = UBOS::Utils::slurpFile( $self->{sshPublicKeyFile} );
    $sshPubKey =~ s!^\s+!!;
    $sshPubKey =~ s!\s+$!!;

    unless( -d "$dir/shepherd/ssh" ) {
        UBOS::Utils::myexec( "mkdir -p '$dir/shepherd/ssh'" );
    }

    UBOS::Utils::saveFile( "$dir/shepherd/ssh/id_rsa.pub", $sshPubKey );
}

##
# Return help text.
# return: help text
sub help {
    return <<TXT;
A scaffold that runs tests on the local machine in a Linux container.
Options:
    directory                 (required) -- directory containing UBOS that becomes the root directory for the container
    name                      (optional) -- name of the container to create
    shepherd                  (optional) -- name of the user on the virtual machine that can execute ubos-admin over ssh
    shepherd-public-key-file  (required) -- name of the file that contains the public key for ubos-admin ssh access
    shepherd-private-key-file (required) -- name of the file that contains the private key for ubos-admin ssh access
    boot-max-seconds          (optional) -- the maximum number of seconds to wait for the boot to complete
    keys-max-seconds          (optional) -- the maximum number of seconds to wait until keys have been generated
    shutdown-max-seconds      (optional) -- the maximum number of seconds to wait until shutdown is complete
TXT
}
                    
1;
