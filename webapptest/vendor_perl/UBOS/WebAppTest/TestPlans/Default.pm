#!/usr/bin/perl
#
# Default test plan: walks through the states and transitions, and attempts to restore.
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

package UBOS::WebAppTest::TestPlans::Default;

use base qw( UBOS::WebAppTest::AbstractSingleSiteTestPlan );
use fields;
use UBOS::Logging;
use UBOS::WebAppTest::TestContext;
use UBOS::Utils;

##
# Instantiate the TestPlan.
# $test: the test to run
# $options: options for the test plan
sub new {
    my $self    = shift;
    my $test    = shift;
    my $options = shift;

    unless( ref $self ) {
        $self = fields::new( $self );
    }
    $self = $self->SUPER::new( $test, $options );

    if( defined( $options ) && %$options ) {
        fatal( 'Unknown option(s) for TestPlan Default:', join( ', ', keys %$options ));
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

    info( 'Running TestPlan Default' );

    my $siteJson = $self->getSiteJson();

    my $ret = 1;
    my $success;
    my $repeat;
    my $abort;
    my $quit;
    my $deployed = 1;

    do {
        $success = $scaffold->deploy( $siteJson );

        ( $repeat, $abort, $quit ) = $self->askUser( 'Performed deployment', $interactive, $success, $ret );

    } while( $repeat );
    $ret      &= $success;
    $deployed =  $success;

    my @statesBackupsReverse = ();

    if( !$abort && !$quit ) {
        my $c = new UBOS::WebAppTest::TestContext( $scaffold, $self, $verbose );

        my $currentState = $self->getTest()->getVirginStateTest();

        # March forward, and create backups
        my $done = 0;
        while( !$done ) {
            info( 'Checking StateCheck', $currentState->getName() );

            do {
                $success = $currentState->check( $c );

                ( $repeat, $abort, $quit ) = $self->askUser( 'Performed StateCheck ' . $currentState->getName(), $interactive, $success, $ret );

            } while( $repeat );
            $ret &= $success;

            if( $abort || $quit ) {
                last;
            }

            my $backup = $scaffold->backup( $siteJson );
            unshift @statesBackupsReverse, [ $currentState, $backup ]; # insert at the beginning

            my( $transition, $nextState ) = $self->getTest()->getTransitionFrom( $currentState );
            if( $transition ) {

                info( 'Taking StateTransition', $transition->getName() );

                do {
                    $success = $transition->execute( $c );

                    ( $repeat, $abort, $quit ) = $self->askUser( 'Performed StateTransition ' . $transition->getName(), $interactive, $success, $ret );

                } while( $repeat );
                $ret &= $success;

                if( $abort || $quit ) {
                    $done = 1;
                }
            } else {
                $done = 1;
            }

            if( !$done ) {
                $currentState = $nextState;
            }
        }

        # March backwards, restore from backups
        my @statesBackupsReverseMinusOne = @statesBackupsReverse;
        shift @statesBackupsReverseMinusOne;
        
        foreach my $stateBackup ( @statesBackupsReverseMinusOne ) {
            my( $currentState, $currentBackup ) = @$stateBackup;

            if( $currentBackup ) {
                info( 'Restoring state', $currentState->getName() );

                do {
                    $scaffold->undeploy( $siteJson );
                    $success = $scaffold->restore( $siteJson, $currentBackup );
                
                    ( $repeat, $abort, $quit ) = $self->askUser( 'Restored state ' . $currentState->getName(), $interactive, $success, $ret );

                } while( $repeat );
                $ret &= $success;

                if( $abort || $quit ) {
                    last;
                }

                info( 'Checking StateCheck', $currentState->getName() );
                do {
                    $success = $currentState->check( $c );

                    ( $repeat, $abort, $quit ) = $self->askUser( 'Performed StateCheck ' . $currentState->getName(), $interactive, $success, $ret );

                } while( $repeat );
                $ret &= $success;

                if( $abort || $quit ) {
                    last;
                }

            } else {
                debug( 'Skipping restoring and checking StateCheck', $currentState->getName() );
            }
        }

        # And then do the last one again, because it wasn't fair to restore the current state
        if( @statesBackupsReverse > 1 && !$abort && !$quit ) {
            my( $currentState, $currentBackup ) = @{$statesBackupsReverse[0]};
            if( $currentBackup ) {
                info( 'Restoring (one more time) StateCheck', $currentState->getName() );

                do {
                    $scaffold->undeploy( $siteJson );
                    $success = $scaffold->restore( $siteJson, $currentBackup );
                
                    ( $repeat, $abort, $quit ) = $self->askUser( 'Restored state ' . $currentState->getName(), $interactive, $success, $ret );

                } while( $repeat );
                $ret &= $success;

                if( !$abort && !$quit ) {
                    info( 'Checking StateCheck', $currentState->getName() );
                    do {
                        $success = $currentState->check( $c );

                        ( $repeat, $abort, $quit ) = $self->askUser( 'Performed StateCheck ' . $currentState->getName(), $interactive, $success, $ret );

                    } while( $repeat );
                    $ret &= $success;
                }

            } else {
                debug( 'Skipping restoring and checking StateCheck', $currentState->getName() );
            }
        }
        $c->destroy();
    }

    if( $deployed && !$abort ) {
        $scaffold->undeploy( $siteJson );
    }

    foreach my $stateBackup ( @statesBackupsReverse ) {
        my( $currentState, $currentBackup ) = @$stateBackup;

        if( $currentBackup ) {
            $scaffold->destroyBackup( $siteJson, $currentBackup );
        }
    }

    info( 'End running TestPlan Default' );

    return $ret;
}

##
# Return help text.
# return: help text
sub help {
    return 'Walks through all States and Transitions, and attempts to backup and restore each State.';
}

##
# Return allowed arguments for this command.
# return: allowed arguments, as string
sub helpArguments {
    return undef;
}

1;


