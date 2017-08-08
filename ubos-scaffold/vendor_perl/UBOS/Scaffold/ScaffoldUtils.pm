#!/usr/bin/perl
#
# Collection of utility methods for UBOS scaffolds
#
# This file is part of ubos-scaffold.
# (C) 2017 Indie Computing Corp.
#
# ubos-scaffold is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# ubos-scaffold is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with ubos-scaffold.  If not, see <http://www.gnu.org/licenses/>.
#

use strict;
use warnings;

package UBOS::Scaffold::ScaffoldUtils;

use Cwd;
use UBOS::Logging;
use UBOS::Utils;

##
# Find available commands.
# return: hash of command name to full package name
sub findCommands {
    my $ret = UBOS::Utils::findPerlShortModuleNamesInPackage( 'UBOS::Scaffold::Commands' );

    return $ret;
}

##
# Find available test scaffolds.
# return: hash of scaffold name to full package name
sub findScaffolds {
    my $ret = UBOS::Utils::findPerlShortModuleNamesInPackage( 'UBOS::Scaffold::Scaffolds' );
    return $ret;
}

##
# Find a named scaffold
# $name: name of the scaffold
# return: scaffold package, or undef
sub findScaffold {
    my $name = shift;

    my $scaffolds = findScaffolds();
    my $ret       = $scaffolds->{$name};

    return $ret;
}

##
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

##
# Copy the default icons
# $dir: destination directory
sub copyIcons {
    my $dir = shift;

    for my $f ( '72x72.png', '144x144.png' ) {
        UBOS::Utils::myexec( "cp /usr/share/ubos-scaffold/default-appicons/$f", $dir );
    }
    1;
}

1;
