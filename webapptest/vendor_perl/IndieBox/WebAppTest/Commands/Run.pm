#!/usr/bin/perl
#
# Command that runs a TestSuite.
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

package IndieBox::WebAppTest::Commands::Run;

use Cwd;
use Getopt::Long qw( GetOptionsFromArray );
use IndieBox::Host;
use IndieBox::Logging;
use IndieBox::Utils;

##
# Execute this command.
# $testSuiteName: name of the test suite to run
# return: desired exit code
sub run {
    my @args = @_;

    my $interactive = 0;
    my $verbose = 0;
    my $scaffoldName;
    my $testPlanName;
    my $parseOk = GetOptionsFromArray(
            \@args,
            'interactive' => \$interactive,
            'verbose+'    => \$verbose,
            'scaffold=s'  => \$scaffoldName,
            'testplan=s'  => \$testPlanName );
    unless( $parseOk ) {
        fatal( 'Invalid command-line arguments' );
    }
    unless( @args ) {
        fatal( 'Must provide name of at least one test suite.' );
    }

    if( $verbose ) {
        IndieBox::Logging::setVerbose( $verbose );
    }

    unless( $scaffoldName ) {
        $scaffoldName  = 'here';
    }
    my $scaffoldOptions;
    if( $scaffoldName =~ m!^(.*):(.*)$! ) {
        $scaffoldName    = $1;
        $scaffoldOptions = $2;
    }
    my $scaffoldPackageName = IndieBox::WebAppTest::TestingUtils::findScaffold( $scaffoldName );
    unless( $scaffoldPackageName ) {
        fatal( 'Cannot find scaffold', $scaffoldName );
    }

    unless( $testPlanName ) {
        $testPlanName  = 'default';
    }
    my $testPlanPackage = IndieBox::WebAppTest::TestingUtils::findTestPlan( $testPlanName );
    unless( $testPlanPackage ) {
        fatal( 'Cannot find test plan', $testPlanName );
    }

    my @appTestsToRun = ();
    foreach my $appTestName ( @args ) {
        my $appTestToRun = IndieBox::WebAppTest::TestingUtils::findAppTestInDirectory( getcwd(), $appTestName );
        unless( $appTestToRun ) {
            fatal( 'Cannot find app test', $appTestName );
        }
        push @appTestsToRun, $appTestToRun;
    }
    
    my $ret = 1;

    my $testPlan = IndieBox::Utils::invokeMethod( $testPlanPackage     . '->new' );

    my $scaffold = IndieBox::Utils::invokeMethod( $scaffoldPackageName . '->setup', $scaffoldOptions );
    foreach my $appTest ( @appTestsToRun ) {
        if( @appTestsToRun > 1 ) {
            print "Running AppTest " . $appTest->name . "\n";
        }
        info( 'Running AppTest', $appTest->name );

        my $status = $testPlan->run( $appTest, $scaffold, $interactive );
        $ret &= $status;

        unless( $ret ) {
            error( 'Test', $appTest->name, 'failed.' );
        } else {
            print "Test passed.\n";
        }
    }

    $scaffold->teardown();

    return $ret;
}

##
# Return help text for this command.
# return: hash of synopsis to help text
sub synopsisHelp {
    return {
        <<SSS => <<HHH
    [--interactive] [--verbose] [--scaffold <scaffold[:scaffoldoption]...>] [--testplan <testplan>] <apptest>...
SSS
    Run the test apptest.
    --interactive: stop at important points and wait for user input
    --verbose: print more information about how the test progresses
    <scaffold>: use this named scaffold instead of the default. If given as
                "abc:def:ghi", "abc" represents the name of the scaffold, and
                "def" and "ghi" are scaffold-specific options
    <testplan>: use this named testplan instead of the default
HHH
    };
}

1;
