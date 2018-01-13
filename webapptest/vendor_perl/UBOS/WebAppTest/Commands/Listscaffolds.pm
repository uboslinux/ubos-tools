#!/usr/bin/perl
#
# Command that lists all available Scaffolds.
#
# Copyright (C) 2014 and later, Indie Computing Corp. All rights reserved. License: see package.
#

use strict;
use warnings;

package UBOS::WebAppTest::Commands::Listscaffolds;

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

    my $scaffolds = UBOS::WebAppTest::TestingUtils::findScaffolds();

    print UBOS::Utils::hashAsColumns( $scaffolds, sub { UBOS::Utils::invokeMethod( shift . '::help' ); } );

    1;
}

##
# Return help text for this command.
# return: hash of synopsis to help text
sub synopsisHelp {
    return {
        '' => <<HHH
    Lists all available web app test scaffolds.
HHH
    };
}

1;
