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
# $options: array of options
sub setup {
    my $self    = shift;
    my $options = shift;

    if( defined( $options ) && @$options ) {
        fatal( 'Scaffold', ref( $self ), 'does not support any options, got:', @$options );
    }

    unless( ref $self ) {
        $self = fields::new( $self );
    }
    $self->SUPER::setup();

    info( 'Creating Scaffold Here' );
    
    return $self;
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
# Obtain the IP address of the target.  This must be overridden by subclasses.
# return: target IP
sub getTargetIp {
    my $self  = shift;

    return '127.0.0.1';
}

##
# Return help text.
# return: help text
sub help {
    return 'A trivial scaffold that runs tests on the local machine without any insulation.';
}

1;
