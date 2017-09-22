#!/usr/bin/perl
#
# Factors out operations common to many kinds of TestPlans.
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
