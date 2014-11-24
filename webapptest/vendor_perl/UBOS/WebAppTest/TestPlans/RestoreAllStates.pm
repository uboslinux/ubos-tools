#!/usr/bin/perl
#
# Walks through the states and transitions in sequence, and restores from
# a backup file for each of them if there is one. Those backup files were
# typically created by BackupAllStates.pm.
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

package UBOS::WebAppTest::TestPlans::RestoreAllStates;

use base qw( UBOS::WebAppTest::AbstractSingleSiteTestPlan );
use fields qw( backupFilePrefix );
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
    $self = $self->SUPER::new();

    if( !exists( $options->{backupfileprefix} ) || !$options->{backupfileprefix} ) {
        fatal( 'Must provide backupfileprefix' );
    }
    $self->{backupFilePrefix} = $options->{backupfileprefix};

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

    info( 'Running TestPlan RestoreAllStates' );

    my( $siteJson, $appConfigJson ) = $test->getSiteAndAppConfigJson();

    my $ret = 1;
    my $success;
    my $repeat;
    my $abort;
    my $quit;
    my $numberRestored = 0;

    my $c = new UBOS::WebAppTest::TestContext( $siteJson, $appConfigJson, $scaffold, $test, $self, $scaffold->getTargetIp(), $verbose );

    my $currentState = $test->getVirginStateTest();
    while( 1 ) {
        my $backupFile = $self->{backupFilePrefix} . $currentState->getName() . '.ubos-backup';
        if( -r $backupFile ) {
            info( 'Checking StateCheck', $currentState->getName() );
            ++$numberRestored;

            do {
                $success = $scaffold->restoreFromLocal( $siteJson, $backupFile );
                ( $repeat, $abort, $quit ) = $self->askUser( 'Restored backup for ' . $currentState->getName(), $interactive, $success, $ret );

            } while( $repeat );
            $ret &= $success;

            if( $abort || $quit ) {
                last;
            }

            do {
                $success = $currentState->check( $c );

                ( $repeat, $abort, $quit ) = $self->askUser( 'Performed StateCheck ' . $currentState->getName(), $interactive, $success, $ret );

            } while( $repeat );
            $ret &= $success;

            if( $abort || $quit ) {
                last;
            }
        } else {
            info( 'Skipping StateCheck', $currentState->getName(), 'backup file not found' );
        }

        unless( $abort ) {
            $scaffold->undeploy( $siteJson );
        }

        my( $transition, $nextState ) = $test->getTransitionFrom( $currentState );
        unless( $transition ) {
            last;
        }

        # No point in taking the transition

        $currentState = $nextState;
    }
    $c->destroy();

    if( $numberRestored == 0 ) {
        error( "Not a single backup file found. Test run didn't do anything." );
        $ret =0;
    }

    info( 'End running TestPlan Simple' );

    return $ret;
}

##
# Return help text.
# return: help text
sub help {
    return 'Restores from a local backup file for each State, and tests upgrade.';
}

##
# Return allowed arguments for this command.
# return: allowed arguments, as string
sub helpArguments {
    return undef;
}

1;
