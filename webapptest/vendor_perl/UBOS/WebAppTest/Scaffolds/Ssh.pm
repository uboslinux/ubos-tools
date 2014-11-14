#!/usr/bin/perl
#
# A scaffold for running tests on a remote machine accessible via ssh.
# This test neither sets up, nor tears down, the remote machine.
#
# The following options can be provied:
# * host (required): hostname or IP address of the machine that will run the tests
# * user (required): user name of the administrative user that will invoke
#   'sudo ubos-admin'
# * privatekeyfile (optional): name of a file that contains the private ssh key
#   to use
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

package UBOS::WebAppTest::Scaffolds::Ssh;

use base qw( UBOS::WebAppTest::AbstractRemoteScaffold );
use fields qw();

use File::Temp;
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
    $self->SUPER::setup();

    $self->{isOk} = 0; # until we decide otherwise

    unless( exists( $options->{host} )) {
        fatal( 'No value provided for host' );
    }
    unless( $options->{host} =~ m!^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$! ) {
        fatal( 'Not a valid IP address:', $options->{host} );
    }
    $self->{sshHost} = $options->{host};

    if( exists( $options->{'ubos-admin'} )) {
        unless( $options->{'ubos-admin'} ) {
            fatal( 'Value for ubos-admin cannot be empty' );
        }
        $self->{sshUser} = $options->{'ubos-admin'};
    } else {
        $self->{sshUser} = 'ubos-admin';
    }

    if( exists( $options->{'ubos-admin-private-key-file'} )) {
        unless( -r $options->{'ubos-admin-private-key-file'} ) {
            fatal( 'Cannot read file', $options->{'ubos-admin-private-key-file'} );
        }
        $self->{sshPrivateKeyFile} = $options->{'ubos-admin-private-key-file'};
    }

    info( 'Creating Scaffold Ssh' );

    $self->{isOk} = 1;

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
    host                        (required) -- hostname or IP address of the remote machine on which tests are run
    ubos-admin                  (optional) -- name of the user on the remote machine that can execute ubos-admin over ssh
    ubos-admin-private-key-file (optional) -- name of the file that contains the private key for  ubos-adminssh access
TXT
}

1;
