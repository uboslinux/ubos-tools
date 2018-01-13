#!/usr/bin/perl
#
# Factors out operations common to many kinds of TestPlans.
#
# Copyright (C) 2014 and later, Indie Computing Corp. All rights reserved. License: see package.
#

use strict;
use warnings;

package UBOS::WebAppTest::AbstractTestPlan;

use fields qw( test );

use UBOS::Logging;

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
    unless( $test ) {
        fatal( 'Must provide test' );
    }
    $self->{test} = $test;

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

    fatal( 'Must override UBOS::WebAppTest::AbstractTestPlan::run' );
}

##
# Obtain the test run by this TestPlan.
# return: the test
sub getTest {
    my $self = shift;

    return $self->{test};
}

1;
