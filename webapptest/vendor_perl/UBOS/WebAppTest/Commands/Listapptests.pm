#!/usr/bin/perl
#
# Command that lists all available tests in the current directory.
#
# This file is part of webapptest.
# (C) 2012-2014 Indie Computing Corp.
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

package UBOS::WebAppTest::Commands::Listapptests;

use Cwd;
use UBOS::Logging;
use UBOS::Host;
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
                while( my( $name, $value ) = each %$appTests ) {
                    $allAppTests->{$name} = $value;
                }
            }
        }
            
    } else {
        $allAppTests = UBOS::WebAppTest::TestingUtils::findAppTestsInDirectory( getcwd() );
    }

    UBOS::Utils::printHashAsColumns( $allAppTests, sub { shift->description(); } );

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
