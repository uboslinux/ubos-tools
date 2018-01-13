#!/usr/bin/perl
#
# Deploys the app, redeploys at same host, then at wildcard, and back.
#
# Copyright (C) 2014 and later, Indie Computing Corp. All rights reserved. License: see package.
#

use strict;
use warnings;

package UBOS::WebAppTest::TestPlans::Redeploy;

use base qw( UBOS::WebAppTest::AbstractSingleSiteTestPlan );
use fields;

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
        fatal( 'Unknown option(s) for TestPlan Redeploy:', join( ', ', keys %$options ));
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

    info( 'Running testplan redeploy' );

    my $siteJson           = $self->getSiteJson();
    my $siteJsonAtWildcard = {};

    foreach my $key ( keys %$siteJson ) {
        if( 'hostname' eq $key ) {
            $siteJsonAtWildcard->{$key} = '*';
        } else {
            $siteJsonAtWildcard->{$key} = $siteJson->{$key};
        }
    }

    my $ret = 1;
    my $success;
    my $repeat;
    my $abort;
    my $quit;

    # deploy and check regular site
    do {
        info( 'Deploying' );

        $success = $scaffold->deploy( $siteJson );

        ( $repeat, $abort, $quit ) = UBOS::WebAppTest::TestingUtils::askUser( 'Performed deployment', $interactive, $success, $ret );

    } while( $repeat );
    $ret &= $success;

    my $c = undef;
    if( !$abort && !$quit ) {
        $c = new UBOS::WebAppTest::TestContext( $scaffold, $self, $verbose );

        my $currentState = $self->getTest()->getVirginStateTest();

        info( 'Checking StateCheck', $currentState->getName() );

        do {
            $success = $currentState->check( $c );

            ( $repeat, $abort, $quit ) = UBOS::WebAppTest::TestingUtils::askUser( 'Performed StateCheck ' . $currentState->getName(), $interactive, $success, $ret );

        } while( $repeat );
        $ret &= $success;
    }

    # redeploy and check regular site
    if( !$abort && !$quit ) {
        do {
            info( 'Re-deploying' );

            $success = $scaffold->deploy( $siteJson );

            ( $repeat, $abort, $quit ) = UBOS::WebAppTest::TestingUtils::askUser( 'Performed re-deployment', $interactive, $success, $ret );

        } while( $repeat );
        $ret &= $success;
    }

    if( !$abort && !$quit ) {
        my $currentState = $self->getTest()->getVirginStateTest();

        info( 'Checking StateCheck', $currentState->getName() );

        do {
            $success = $currentState->check( $c );

            ( $repeat, $abort, $quit ) = UBOS::WebAppTest::TestingUtils::askUser( 'Performed StateCheck ' . $currentState->getName(), $interactive, $success, $ret );

        } while( $repeat );
        $ret &= $success;
    }

    # deploy and check wildcard site
    if( !$abort && !$quit ) {
        $self->setSiteJson( $siteJsonAtWildcard );
        do {
            info( 'Deploying to wildcard host' );

            $success = $scaffold->deploy( $siteJsonAtWildcard );

            ( $repeat, $abort, $quit ) = UBOS::WebAppTest::TestingUtils::askUser( 'Performed wildcard deployment', $interactive, $success, $ret );

        } while( $repeat );
        $ret &= $success;
    }

    if( !$abort && !$quit ) {
        my $currentState = $self->getTest()->getVirginStateTest();

        info( 'Checking StateCheck', $currentState->getName() );

        do {
            $success = $currentState->check( $c );

            ( $repeat, $abort, $quit ) = UBOS::WebAppTest::TestingUtils::askUser( 'Performed StateCheck ' . $currentState->getName(), $interactive, $success, $ret );

        } while( $repeat );
        $ret &= $success;
    }

    # redeploy and check wildcard site
    if( !$abort && !$quit ) {
        do {
            info( 'Re-deploying to wildcard host' );

            $success = $scaffold->deploy( $siteJsonAtWildcard );

            ( $repeat, $abort, $quit ) = UBOS::WebAppTest::TestingUtils::askUser( 'Performed wildcard re-deployment', $interactive, $success, $ret );

        } while( $repeat );
        $ret &= $success;
    }

    if( !$abort && !$quit ) {
        my $currentState = $self->getTest()->getVirginStateTest();

        info( 'Checking StateCheck', $currentState->getName() );

        do {
            $success = $currentState->check( $c );

            ( $repeat, $abort, $quit ) = UBOS::WebAppTest::TestingUtils::askUser( 'Performed StateCheck ' . $currentState->getName(), $interactive, $success, $ret );

        } while( $repeat );
        $ret &= $success;
    }

    # redeploy and check regular site
    if( !$abort && !$quit ) {
        $self->setSiteJson( $siteJson );
        do {
            info( 'Re-deploying' );

            $success = $scaffold->deploy( $siteJson );

            ( $repeat, $abort, $quit ) = UBOS::WebAppTest::TestingUtils::askUser( 'Performed re-deployment', $interactive, $success, $ret );

        } while( $repeat );
        $ret &= $success;
    }

    if( !$abort && !$quit ) {
        my $currentState = $self->getTest()->getVirginStateTest();

        info( 'Checking StateCheck', $currentState->getName() );

        do {
            $success = $currentState->check( $c );

            ( $repeat, $abort, $quit ) = UBOS::WebAppTest::TestingUtils::askUser( 'Performed StateCheck ' . $currentState->getName(), $interactive, $success, $ret );

        } while( $repeat );
        $ret &= $success;
    }

    if( defined( $c )) {
        $c->destroy();
    }

    unless( $abort ) {
        $scaffold->undeploy( $siteJson );
    }
    
    info( 'End running TestPlan Redeploy' );

    return $ret;
}

##
# Return help text.
# return: help text
sub help {
    return 'Tests that the application can be re-deployed after install at different hostnames.';
}

##
# Return allowed arguments for this command.
# return: allowed arguments, as string
sub helpArguments {
    return undef;
}

1;
