#!/usr/bin/perl
#
# Command that lists all available test plans.
#
# Copyright (C) 2014 and later, Indie Computing Corp. All rights reserved. License: see package.
#

use strict;
use warnings;

package UBOS::WebAppTest::Commands::Listtestplans;

use UBOS::Utils;

##
# Execute this command.
# @args: arguments to this command
# return: desired exit code
sub run {
    my @args = @_;
    if( @args ) {
        fatal( 'No arguments are recognized for this command' );
    }

    my $testPlans = UBOS::WebAppTest::TestingUtils::findTestPlans();

    print UBOS::Utils::hashAsColumns( $testPlans, sub { UBOS::Utils::invokeMethod( shift . '::help' ); } );

    1;
}

##
# Return help text for this command.
# return: hash of synopsis to help text
sub synopsisHelp {
    return {
        '' => <<HHH
    Lists all available test plans. For example, some test plans may only
    perform short, brief smoke tests, while others may perform exhaustive tests.
HHH
    };
}

1;
