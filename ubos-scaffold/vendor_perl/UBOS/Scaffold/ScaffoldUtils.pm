#!/usr/bin/perl
#
# Collection of utility methods for UBOS scaffolds
#
# Copyright (C) 2017 and later, Indie Computing Corp. All rights reserved. License: see package.
#

use strict;
use warnings;

package UBOS::Scaffold::ScaffoldUtils;

use Cwd;
use UBOS::Logging;
use UBOS::Utils;

####
# Find available commands.
# return: hash of command name to full package name
sub findCommands {
    my $ret = UBOS::Utils::findPerlShortModuleNamesInPackage( 'UBOS::Scaffold::Commands' );

    return $ret;
}

####
# Find available test scaffolds.
# return: hash of scaffold name to full package name
sub findScaffolds {
    my $ret = UBOS::Utils::findPerlShortModuleNamesInPackage( 'UBOS::Scaffold::Scaffolds' );
    return $ret;
}

####
# Find a named scaffold
# $name: name of the scaffold
# return: scaffold package, or undef
sub findScaffold {
    my $name = shift;

    my $scaffolds = findScaffolds();
    my $ret       = $scaffolds->{$name};

    return $ret;
}

####
# Ask the user for parameter values.
# $description: the description of the parameter
sub ask {
    my $description = shift;

    $description =~ s!^\s+!!m;
    $description =~ s!\s+$!!m;
    $description =~ s!\s+! !m;

    my $fullQuestion = $description . ': ';
    my $userinput;

    while( 1 ) {
        print STDERR $fullQuestion;

        $userinput = <STDIN>;
        $userinput =~ s!^\s+!!;
        $userinput =~ s!\s+$!!;

        if( $userinput ) {
            last;
        }
    }

    return $userinput;
}

1;
