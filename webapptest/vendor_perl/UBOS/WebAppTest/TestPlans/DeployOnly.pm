#!/usr/bin/perl
#
# Only deploys the app and tests the virgin state.
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

package UBOS::WebAppTest::TestPlans::DeployOnly;

use base qw( UBOS::WebAppTest::AbstractSingleSiteTestPlan );
use fields;
use UBOS::Logging;
use UBOS::WebAppTest::TestContext;
use UBOS::Utils;

##
# Instantiate the TestPlan.
# $options: options for the test plan
sub new {
    my $self    = shift;
    my $options = shift;

    unless( ref $self ) {
        $self = fields::new( $self );
    }
    $self = $self->SUPER::new( $options );

    if( defined( $options ) && %$options ) {
        fatal( 'Unknown option(s) for TestPlan DeployOnly:', join( ', ', keys %$options ));
    }

    return $self;
}

##
# Run this TestPlan
# $test: the AppTest to run
# $scaffold: the Scaffold to use
# $interactive: if 1, ask the user what to do after each error
# $verbose: verbosity level from 0 (not verbose) upwards
sub run {
    my $self        = shift;
    my $test        = shift;
    my $scaffold    = shift;
    my $interactive = shift;
    my $verbose     = shift;

    info( 'Running TestPlan DeployOnly' );

    my( $siteJson, $appConfigJson ) = $self->getSiteAndAppConfigJson( $test );

    my $ret = 1;
    my $success;
    my $repeat;
    my $abort;
    my $quit;

    do {
        $success = $scaffold->deploy( $siteJson );

        ( $repeat, $abort, $quit ) = $self->askUser( 'Performed deployment', $interactive, $success, $ret );

    } while( $repeat );
    $ret &= $success;

    if( !$abort && !$quit ) {
        my $c = new UBOS::WebAppTest::TestContext( $siteJson, $appConfigJson, $scaffold, $test, $self, $scaffold->getTargetIp(), $verbose );

        my $currentState = $test->getVirginStateTest();

        info( 'Checking StateCheck', $currentState->getName() );

        do {
            $success = $currentState->check( $c );

            ( $repeat, $abort, $quit ) = $self->askUser( 'Performed StateCheck ' . $currentState->getName(), $interactive, $success, $ret );

        } while( $repeat );
        $ret &= $success;

        $c->destroy();
    }

    unless( $abort ) {
        $scaffold->undeploy( $siteJson );
    }
    
    info( 'End running TestPlan DeployOnly' );

    return $ret;
}

##
# Return help text.
# return: help text
sub help {
    return 'Only tests whether the application can be installed.';
}

##
# Return allowed arguments for this command.
# return: allowed arguments, as string
sub helpArguments {
    return undef;
}

1;
