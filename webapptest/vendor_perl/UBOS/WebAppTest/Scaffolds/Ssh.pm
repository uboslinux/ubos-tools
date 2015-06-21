#!/usr/bin/perl
#
# A scaffold for running tests on a remote machine accessible via ssh.
# This test neither sets up, nor tears down, the remote machine.
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

package UBOS::WebAppTest::Scaffolds::Ssh;

use base qw( UBOS::WebAppTest::AbstractRemoteScaffold );
use fields qw();

use File::Temp;
use Socket;
use Sys::Hostname;
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

    $self->{isOk} = 0; # until we decide otherwise

    unless( exists( $options->{host} )) {
        fatal( 'No value provided for host' );
    }
    unless( $options->{host} =~ m!^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$! ) {
        fatal( 'Not a valid IP address:', $options->{host} );
    }
    $self->{sshHost} = $options->{host};
    delete $options->{'host'};

    if( exists( $options->{'shepherd'} )) {
        unless( $options->{'shepherd'} ) {
            fatal( 'Value for shepherd cannot be empty' );
        }
        $self->{sshUser} = $options->{'shepherd'};
        delete $options->{'shepherd'};
    } else {
        $self->{sshUser} = 'shepherd';
    }

    if( exists( $options->{'shepherd-private-key-file'} )) {
        unless( -r $options->{'shepherd-private-key-file'} ) {
            fatal( 'Cannot read file', $options->{'shepherd-private-key-file'} );
        }
        $self->{sshPrivateKeyFile} = $options->{'shepherd-private-key-file'};
        delete $options->{'shepherd-private-key-file'};
    }

    my $impersonateDepot = delete $options->{impersonatedepot};

    if( defined( $options ) && %$options ) {
        fatal( 'Unknown option(s) for Scaffold ssh:', join( ', ', keys %$options ));
    }

    info( 'Creating Scaffold ssh' );
    
    $self->{isOk} = $self->handleImpersonateDepot( $impersonateDepot );

    return $self;
}

##
# Teardown this Scaffold.
sub teardown {
    my $self = shift;

    info( 'Tearing down Scaffold Ssh' );

    return 1;
}

##
# Return help text.
# return: help text
sub help {
    return <<TXT;
A scaffold that runs tests on the remote machine that is already set up, and accessible via ssh.
Options:
    host                      (required) -- hostname or IP address of the remote machine on which tests are run
    shepherd                  (optional) -- name of the user on the remote machine that can execute ubos-admin over ssh
    shepherd-private-key-file (optional) -- name of the file that contains the private key for  ubos-adminssh access
TXT
}

1;
