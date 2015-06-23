#!/usr/bin/perl
#
# Walks through the states and transitions in sequence, and creates a
# backup file for each of them. This allows the RestoreAllStates
# TestPlan to test upgrades.
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

package UBOS::WebAppTest::TestPlans::BackupAllStates;

use base qw( UBOS::WebAppTest::AbstractSingleSiteTestPlan );
use fields qw( backupFilePrefix );

use UBOS::Logging;
use UBOS::Utils;
use UBOS::WebAppTest::TestContext;
use UBOS::WebAppTest::TestingUtils;

##
# Instantiate the TestPlan.
# $test: the test to run
# $options: options for the test plan
# $tlsData: if given, the TLS section of the Site JSON to use
sub new {
    my $self    = shift;
    my $test    = shift;
    my $options = shift;
    my $tlsData = shift;

    unless( ref $self ) {
        $self = fields::new( $self );
    }
    $self = $self->SUPER::new( $test, $options, $tlsData );
    
    if( exists( $options->{backupfileprefix} )) {
        unless( $options->{backupfileprefix} ) {
            fatal( 'option backupfileprefix cannot be empty' );
        }
        $self->{backupFilePrefix} = $options->{backupfileprefix};
        delete $options->{backupfileprefix};
    } # cannot calculcate the fallback yet for backupfileprefix

    if( defined( $options ) && %$options ) {
        fatal( 'Unknown option(s) for TestPlan BackupAllStates:', join( ', ', keys %$options ));
    }

    return $self;
}

##
# Run this TestPlan
# $scaffold: the Scaffold to use
# $interactive: if 1, ask the user what to do after each error
# $verbose: verbosity level from 0 (not verbose) upwards
sub run {
    my $self        = shift;
    my $scaffold    = shift;
    my $interactive = shift;
    my $verbose     = shift;

    info( 'Running testplan backup-all-states' );

    my $siteJson = $self->getSiteJson();

    my $ret = 1;
    my $success;
    my $repeat;
    my $abort;
    my $quit;

    do {
        $success = $scaffold->deploy( $siteJson );

        ( $repeat, $abort, $quit ) = UBOS::WebAppTest::TestingUtils::askUser( 'Performed deploy', $interactive, $success, $ret );

    } while( $repeat );
    $ret &= $success;

    if( !$abort && !$quit ) {
        my $c = new UBOS::WebAppTest::TestContext( $scaffold, $self, $verbose );

        my $currentState = $self->getTest()->getVirginStateTest();
        while( 1 ) {
            info( 'Checking StateCheck', $currentState->getName() );

            do {
                $success = $currentState->check( $c );

                ( $repeat, $abort, $quit ) = UBOS::WebAppTest::TestingUtils::askUser( 'Performed StateCheck ' . $currentState->getName(), $interactive, $success, $ret );

            } while( $repeat );
            $ret &= $success;

            if( $abort || $quit ) {
                last;
            }

            $scaffold->backupToLocal( $siteJson, $self->{backupFilePrefix} . $currentState->getName() . '.ubos-backup' );

            my( $transition, $nextState ) = $self->getTest()->getTransitionFrom( $currentState );
            unless( $transition ) {
                last;
            }
    
            info( 'Taking StateTransition', $transition->getName() );

            do {
                $success = $transition->execute( $c );

                ( $repeat, $abort, $quit ) = UBOS::WebAppTest::TestingUtils::askUser( 'Performed StateTransition ' . $transition->getName(), $interactive, $success, $ret );

            } while( $repeat );
            $ret &= $success;

            if( $abort || $quit ) {
                last;
            }

            $currentState = $nextState;
        }
        $c->destroy();
    }

    unless( $abort ) {
        $scaffold->undeploy( $siteJson );
    }
    
    info( 'End running TestPlan BackupAllStates' );

    return $ret;
}

##
# Return help text.
# return: help text
sub help {
    return 'Creates a local backup file for each State.';
}

##
# Return allowed arguments for this command.
# return: allowed arguments, as string
sub helpArguments {
    return undef;
}

1;
