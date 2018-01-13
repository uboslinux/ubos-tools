#!/usr/bin/perl
#
# Walks through the states and transitions in sequence, and restores from
# a backup file for each of them if there is one. Those backup files were
# typically created by BackupAllStates.pm.
#
# Copyright (C) 2014 and later, Indie Computing Corp. All rights reserved. License: see package.
#

use strict;
use warnings;

package UBOS::WebAppTest::TestPlans::RestoreAllStates;

use base qw( UBOS::WebAppTest::AbstractSingleSiteTestPlan );
use fields qw( backupFilePrefix );

use UBOS::Logging;
use UBOS::Utils;
use UBOS::WebAppTest::TestContext;
use UBOS::WebAppTest::TestingUtils;

##
# Instantiate the TestPlan.
# $options: options for the test plan
# $test: the test to run
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

    if( !exists( $options->{backupfileprefix} ) || !$options->{backupfileprefix} ) {
        fatal( 'Must provide option backupfileprefix' );
    }
    $self->{backupFilePrefix} = $options->{backupfileprefix};
    delete $options->{backupfileprefix};

    if( defined( $options ) && %$options ) {
        fatal( 'Unknown option(s) for TestPlan RestoreAllStates:', join( ', ', keys %$options ));
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

    info( 'Running testplan restore-all-states' );

    my $siteJson = $self->getSiteJson();

    my $ret = 1;
    my $success;
    my $repeat;
    my $abort;
    my $quit;
    my $numberRestored = 0;

    my $c = new UBOS::WebAppTest::TestContext( $scaffold, $self, $verbose );

    my $currentState = $self->getTest()->getVirginStateTest();
    while( 1 ) {
        my $backupFile = $self->{backupFilePrefix} . $currentState->getName() . '.ubos-backup';
        if( -r $backupFile ) {
            info( 'Checking StateCheck', $currentState->getName() );
            ++$numberRestored;

            do {
                $success = $scaffold->restoreFromLocal( $siteJson, $backupFile );
                ( $repeat, $abort, $quit ) = UBOS::WebAppTest::TestingUtils::askUser( 'Restored backup for ' . $currentState->getName(), $interactive, $success, $ret );

            } while( $repeat );
            $ret &= $success;

            if( $abort || $quit ) {
                last;
            }

            do {
                $success = $currentState->check( $c );

                ( $repeat, $abort, $quit ) = UBOS::WebAppTest::TestingUtils::askUser( 'Performed StateCheck ' . $currentState->getName(), $interactive, $success, $ret );

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

        my( $transition, $nextState ) = $self->getTest()->getTransitionFrom( $currentState );
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

    info( 'End running TestPlan RestoreAllStates' );

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
