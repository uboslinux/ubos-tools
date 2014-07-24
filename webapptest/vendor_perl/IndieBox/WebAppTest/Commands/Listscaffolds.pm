#!/usr/bin/perl
#
# Command that lists all available Scaffolds.
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

package IndieBox::WebAppTest::Commands::Listscaffolds;

use IndieBox::Host;
use IndieBox::Utils;

##
# Execute this command.
# @args: arguments to this command
# return: desired exit code
sub run {
    my @args = @_;
    if( @args ) {
        fatal( 'No arguments are recognized for this command' );
    }

    my $scaffolds = IndieBox::WebAppTest::TestingUtils::findScaffolds();
    IndieBox::WebAppTest::TestingUtils::printHashAsColumns( $scaffolds, sub { IndieBox::Utils::invokeMethod( shift . '::help' ); } );

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
