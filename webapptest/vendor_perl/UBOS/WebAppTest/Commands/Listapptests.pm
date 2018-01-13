#!/usr/bin/perl
#
# Command that lists all available tests in the current directory.
#
# Copyright (C) 2014 and later, Indie Computing Corp. All rights reserved. License: see package.
#

use strict;
use warnings;

package UBOS::WebAppTest::Commands::Listapptests;

use Cwd;
use UBOS::WebAppTest::TestingUtils;
use UBOS::Utils;

##
# Execute this command.
# @args: arguments to this command
# return: desired exit code
sub run {
    my @args = @_;

    my $allAppTests;
    if( @args ) {
        foreach my $dir ( @args ) {
            my $appTests = UBOS::WebAppTest::TestingUtils::findAppTestsInDirectory( $dir );
            if( !defined( $allAppTests )) {
                $allAppTests = $appTests;
            } else {
                foreach my $name ( keys %$appTests ) {
                    my $value = $appTests->{$name};

                    $allAppTests->{$name} = $value;
                }
            }
        }
            
    } else {
        $allAppTests = UBOS::WebAppTest::TestingUtils::findAppTestsInDirectory( getcwd() );
    }

    print UBOS::Utils::hashAsColumns( $allAppTests, sub { shift->description() || '(no description)'; } );

    1;
}

##
# Return help text for this command.
# return: hash of synopsis to help text
sub synopsisHelp {
    return {
        '[ <dir> ]...' => <<HHH
    Lists the available app tests in the specified directories.
    If no directory is given, lists the available app tests in
    the current directory.
HHH
    };
}

1;
