#!/usr/bin/perl
#
# Only deploys the app and tests the virgin state.
#
# Copyright (C) 2014 and later, Indie Computing Corp. All rights reserved. License: see package.
#

use strict;
use warnings;

package UBOS::WebAppTest::TestPlans::DeployOnly;

use base qw( UBOS::WebAppTest::AbstractSingleSiteTestPlan );

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

    if( defined( $options ) && %$options ) {
        fatal( 'Unknown option(s) for TestPlan DeployOnly:', join( ', ', keys %$options ));
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

    info( 'Running testplan deploy-only' );

    my $siteJson = $self->getSiteJson();

    my $ret = 1;
    my $success;
    my $repeat;
    my $abort;
    my $quit;

    do {
        $success = $scaffold->deploy( $siteJson );

        ( $repeat, $abort, $quit ) = UBOS::WebAppTest::TestingUtils::askUser( 'Performed deployment', $interactive, $success, $ret );

    } while( $repeat );
    $ret &= $success;

    if( !$abort && !$quit ) {
        my $c = new UBOS::WebAppTest::TestContext( $scaffold, $self, $verbose );

        my $currentState = $self->getTest()->getVirginStateTest();

        info( 'Checking StateCheck', $currentState->getName() );

        do {
            $success = $currentState->check( $c );

            ( $repeat, $abort, $quit ) = UBOS::WebAppTest::TestingUtils::askUser( 'Performed StateCheck ' . $currentState->getName(), $interactive, $success, $ret );

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
