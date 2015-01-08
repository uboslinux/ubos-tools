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

package UBOS::WebAppTest::Commands::Run;

use Cwd;
use Getopt::Long qw( GetOptionsFromArray );
use UBOS::Host;
use UBOS::Logging;
use UBOS::Utils;

##
# Execute this command.
# $testSuiteName: name of the test suite to run
# return: desired exit code
sub run {
    my @args = @_;

    my $interactive   = 0;
    my $verbose       = 0;
    my $logConfigFile = undef;
    my $scaffoldOpt;
    my @testPlanOpts;
    my $parseOk = GetOptionsFromArray(
            \@args,
            'interactive' => \$interactive,
            'verbose+'    => \$verbose,
            'logConfig=s' => \$logConfigFile,
            'scaffold=s'  => \$scaffoldOpt,
            'testplan=s'  => \@testPlanOpts );

    UBOS::Logging::initialize( 'webapptest', 'run', $verbose, $logConfigFile );

    unless( $parseOk ) {
        fatal( 'Invalid command-line arguments' );
    }
    unless( @args ) {
        fatal( 'Must provide name of at least one test suite.' );
    }

    unless( $scaffoldOpt ) {
        $scaffoldOpt = 'here';
    }

    my( $scaffoldName, $scaffoldOptions ) = decode( $scaffoldOpt );
    
    my $scaffoldPackageName = UBOS::WebAppTest::TestingUtils::findScaffold( $scaffoldName );
    unless( $scaffoldPackageName ) {
        fatal( 'Cannot find scaffold', $scaffoldName );
    }

    my %testPlanPackagesWithArgsToRun = ();
    if( @testPlanOpts ) {
        foreach my $testPlanOpt ( @testPlanOpts ) {
            my( $testPlanName, $testPlanOptions ) = decode( $testPlanOpt );
            my $testPlanPackage = UBOS::WebAppTest::TestingUtils::findTestPlan( $testPlanName );
            unless( $testPlanPackage ) {
                fatal( 'Cannot find test plan', $testPlanName );
            }
            if( defined( $testPlanPackagesWithArgsToRun{$testPlanPackage} )) {
                fatal( 'Cannot run the same test plan multiple times at this time' );
            }
            $testPlanPackagesWithArgsToRun{$testPlanPackage} = $testPlanOptions;
        }
    } else {
        %testPlanPackagesWithArgsToRun = ( UBOS::WebAppTest::TestingUtils::findTestPlan( 'default' ) => undef );
    }

    my @appTestsToRun = ();
    foreach my $appTestName ( @args ) {
        my $appTestToRun = UBOS::WebAppTest::TestingUtils::findAppTestInDirectory( getcwd(), $appTestName );
        unless( $appTestToRun ) {
            fatal( 'Cannot find app test', $appTestName );
        }
        unless( $appTestToRun->name ) {
            $appTestToRun->setName( $appTestName );
        }
        push @appTestsToRun, $appTestToRun;
    }
    
    my $ret = 1;


    my $scaffold = UBOS::Utils::invokeMethod( $scaffoldPackageName . '->setup', $scaffoldOptions );
    if( $scaffold && $scaffold->isOk ) {
        my $printTest     = @appTestsToRun > 1;
        my $printTestPlan = ( keys %testPlanPackagesWithArgsToRun ) > 1;

        foreach my $appTest ( @appTestsToRun ) {
            if( $printTest ) {
                print "Running AppTest " . $appTest->name . "\n";
            }
            foreach my $testPlanPackage ( keys %testPlanPackagesWithArgsToRun ) {
                my $testPlanOptions = $testPlanPackagesWithArgsToRun{$testPlanPackage};

                if( $printTestPlan ) {
                    print "Running TestPlan " . $testPlanPackage . "\n";
                }
                info( 'Running AppTest', $appTest->name, 'with test plan', $testPlanPackage );
                
                my $testPlan = UBOS::Utils::invokeMethod( $testPlanPackage . '->new', $testPlanOptions );

                my $status = $testPlan->run( $appTest, $scaffold, $interactive, $verbose );
                $ret &= $status;

                unless( $status ) {
                    error( 'Test', $appTest->name, 'failed.' );
                } elsif( $verbose > 0 ) {
                    print "Test passed.\n";
                }
            }
        }
    } else {
        error( 'Setting up scaffold failed.' );
        $ret = 0;
    }

    if( $scaffold ) {
        $scaffold->teardown();
    }

    return $ret;
}

##
# Return help text for this command.
# return: hash of synopsis to help text
sub synopsisHelp {
    return {
        <<SSS => <<HHH
    [--verbose | --logConfig <file>] [--interactive] [--scaffold <scaffold[:scaffoldoption]...>] [--testplan <testplan>] <apptest>...
SSS
    Run the test apptest.
    --interactive: stop at important points and wait for user input
    <scaffold>: use this named scaffold instead of the default. If given as
                "abc:def=ghi:jkl=mno", "abc" represents the name of the scaffold,
                and "def" and "jkl" are scaffold-specific options
    <testplan>: use this named testplan instead of the default. If given as
                "abc:def=ghi:jkl=mno", "abc" represents the name of the testplan,
                and "def" and "jkl" are scaffold-specific options
HHH
    };
}

##
# Decode a structured argument
sub decode {
    my $string = shift;

    my @parts = split( ':', $string );

    my $name    = shift @parts;
    my $options = {};

    foreach my $part ( @parts ) {
        if( $part ) {
            # sometimes we encounter :: in the argument list
            if( $part =~ m!^(.*?)=(.*)$! ) {
                $options->{lc( $1 )} = $2;
            } else {
                $options->{lc( $part )} = lc( $part );
            }
        }
    }

    return( $name, $options );
}

1;

