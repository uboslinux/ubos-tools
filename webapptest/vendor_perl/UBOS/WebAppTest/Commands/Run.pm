#!/usr/bin/perl
#
# Command that runs a TestSuite.
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

package UBOS::WebAppTest::Commands::Run;

use Cwd;
use Getopt::Long qw( GetOptionsFromArray );
use UBOS::Logging;
use UBOS::Utils;
use UBOS::WebAppTest::TestingUtils;

##
# Execute this command.
# $testSuiteName: name of the test suite to run
# return: desired exit code
sub run {
    my @args = @_;

    my $configFile    = undef;
    my $interactive   = 0;
    my $verbose       = 0;
    my $logConfigFile = undef;
    my $scaffoldOpt;
    my @testPlanOpts;
    my $tlsKeyFile;
    my $tlsCrtFile;
    my $tlsCrtChainFile;
    my $tlsData = undef;

    my $parseOk = GetOptionsFromArray(
            \@args,
            'configfile=s'      => \$configFile,
            'interactive'       => \$interactive,
            'verbose+'          => \$verbose,
            'logConfig=s'       => \$logConfigFile,
            'scaffold=s'        => \$scaffoldOpt,
            'testplan=s'        => \@testPlanOpts,
            'tlskeyfile=s'      => \$tlsKeyFile,
            'tlscrtfile=s'      => \$tlsCrtFile,
            'tlscrtchainfile=s' => \$tlsCrtChainFile );
    
    UBOS::Logging::initialize( 'webapptest', 'run', $verbose, $logConfigFile );

    unless( $parseOk ) {
        fatal( 'Invalid command-line arguments' );
    }
    unless( @args ) {
        fatal( 'Must provide name of at least one test suite.' );
    }

    my $configData = undef;
    if( $configFile ) {
        unless( -r $configFile ) {
            fatal( 'Cannot read configfile', $configFile );
        }
        $configData = UBOS::Utils::readJsonFromFile( $configFile );

        if( !$interactive && exists( $configData->{interactive} )) {
            $interactive = $configData->{interactive};
        }
        if( !$verbose && exists( $configData->{verbose} )) {
            $verbose = $configData->{verbose};
        }
        if( !$logConfigFile && exists( $configData->{logConfig} )) {
            $logConfigFile = $configData->{logConfig};
        }

        if( !$tlsKeyFile && exists( $configData->{tlskeyfile} )) {
            $tlsKeyFile = $configData->{tlskeyfile};
        }
        if( !$tlsCrtFile && exists( $configData->{tlscrtfile} )) {
            $tlsCrtFile = $configData->{tlscrtfile};
        }
        if( !$tlsCrtChainFile && exists( $configData->{tlscrtchainfile} )) {
            $tlsCrtChainFile = $configData->{tlscrtchainfile};
        }
    }
    
    my $tlsCount = 0;
    foreach my $arg ( $tlsKeyFile, $tlsCrtFile, $tlsCrtChainFile ) {
        if( $arg ) {
            ++$tlsCount;
            unless( -r $arg ) {
                fatal( 'Cannot read file', $arg );
            }
        }
    }
    if( $tlsCount == 1 || $tlsCount == 2 ) {
        fatal( 'If providing TLS options, must provide all three options: tlskeyfile, tlscrtfile, tlscrtchainfile' );
    }
    if( $tlsKeyFile ) {
        $tlsData->{key} = UBOS::Utils::slurpFile( $tlsKeyFile );
    }
    if( $tlsCrtFile ) {
        $tlsData->{crt} = UBOS::Utils::slurpFile( $tlsCrtFile );
    }
    if( $tlsCrtChainFile ) {
        $tlsData->{crtchain} = UBOS::Utils::slurpFile( $tlsCrtChainFile );
    }

    my( $scaffoldName, $scaffoldOptions );
    if( $scaffoldOpt ) {
        ( $scaffoldName, $scaffoldOptions ) = decode( $scaffoldOpt );
    } elsif( $configData && exists( $configData->{scaffold} )) {
        foreach my $n ( keys %{$configData->{scaffold}} ) {
            ( $scaffoldName, $scaffoldOptions ) = ( $n, $configData->{scaffold}->{$n} );
            last; # for consistency, can be extended later
        }
    } else {
        $scaffoldName = 'here';
    }

    my $scaffoldPackageName = UBOS::WebAppTest::TestingUtils::findScaffold( $scaffoldName );
    unless( $scaffoldPackageName ) {
        fatal( 'Cannot find scaffold', $scaffoldName );
    }

    my %testPlanPackagesWithArgsToRun = ();
    if( @testPlanOpts ) {
        foreach my $testPlanOpt ( @testPlanOpts ) {
            my( $testPlanName, $testPlanOptions ) = decode( $testPlanOpt );
            unless( $testPlanName ) {
                $testPlanName = 'default';
            }
            my $testPlanPackage = UBOS::WebAppTest::TestingUtils::findTestPlan( $testPlanName );
            unless( $testPlanPackage ) {
                fatal( 'Cannot find test plan', $testPlanName );
            }
            if( defined( $testPlanPackagesWithArgsToRun{$testPlanPackage} )) {
                fatal( 'Cannot run the same test plan multiple times at this time' );
            }
            $testPlanPackagesWithArgsToRun{$testPlanPackage} = $testPlanOptions;
        }

    } elsif( $configData && exists( $configData->{testplan} )) {
        foreach my $testPlanName ( keys %{ $configData->{testplan} } ) {
            my $testPlanPackage = UBOS::WebAppTest::TestingUtils::findTestPlan( $testPlanName );
            unless( $testPlanPackage ) {
                fatal( 'Cannot find test plan', $testPlanName );
            }
            if( defined( $testPlanPackagesWithArgsToRun{$testPlanPackage} )) {
                fatal( 'Cannot run the same test plan multiple times at this time' );
            }
            $testPlanPackagesWithArgsToRun{$testPlanPackage} = $configData->{testplan}->{$testPlanName};
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
    my $success;
    my $repeat;
    my $abort;
    my $quit;
    my $scaffold;

    do {
        my $scaffoldOptionsCopy = { %$scaffoldOptions }; # scaffold deletes them, so repeat won't work without copying
        $scaffold = UBOS::Utils::invokeMethod( $scaffoldPackageName . '->setup', $scaffoldOptions );
        if( $scaffold && $scaffold->isOk ) {
            $success = 1;

        } else {
            $success = 0;

            error( 'Setting up scaffold failed.' );

        }
        ( $repeat, $abort, $quit ) = UBOS::WebAppTest::TestingUtils::askUser( 'Setting up scaffold', $interactive, $success, $ret );

    } while( $repeat );

    if( $success && !$abort && !$quit ) {
        my $printTest     = @appTestsToRun > 1;
        my $printTestPlan = ( keys %testPlanPackagesWithArgsToRun ) > 1;

        foreach my $appTest ( @appTestsToRun ) {
            if( $printTest ) {
                print "Running AppTest " . $appTest->name . "\n";
            }
            foreach my $testPlanPackage ( sort keys %testPlanPackagesWithArgsToRun ) { # consistent sequence
                my $testPlanOptions = $testPlanPackagesWithArgsToRun{$testPlanPackage};

                if( $printTestPlan ) {
                    print "Running TestPlan " . $testPlanPackage . "\n";
                }
                info( 'Running AppTest', $appTest->name, 'with test plan', $testPlanPackage );
                
                my $testPlan = UBOS::Utils::invokeMethod( $testPlanPackage . '->new', $appTest, $testPlanOptions, $tlsData );

                my $status = $testPlan->run( $scaffold, $interactive, $verbose );
                $ret &= $status;

                unless( $status ) {
                    error( 'Test', $appTest->name, 'failed.' );

                } elsif( $verbose > 0 ) {
                    print "Test passed.\n";
                }
            }
        }
    }
    $ret &= $success;

    if( $scaffold && !$abort ) {
        $scaffold->teardown();
    }

    return $ret;
}

##
# Return help text for this command.
# return: hash of synopsis to help text
sub synopsisHelp {
    return {
        <<SSS => <<HHH,
    [--verbose | --logConfig <file>] [--interactive] [--scaffold <scaffold>] [--testplan <testplan>] [--tlskeyfile <tlskeyfile> --tlscrtfile <tlscrtfile> --tlscrtchainfile <tlscrtchainfile> ] <apptest>...
SSS
    Run the test apptest.
    --interactive: stop at important points and wait for user input
    <scaffold>:   use this named scaffold instead of the default. If given as
                  "abc:def=ghi:jkl=mno", "abc" represents the name of the scaffold,
                  and "def" and "jkl" are scaffold-specific options
    <testplan>:   use this named testplan instead of the default. If given as
                  "abc:def=ghi:jkl=mno", "abc" represents the name of the testplan,
                  and "def" and "jkl" are scaffold-specific options
    <tlskeyfile>, <tlscrtfile>, <tlscrtchainfile>: files containing
                  TLS key, certificate, certicate chain, and client certificate chain
                  if test is supposed to be run with TLS
HHH
        <<SSS => <<HHH
    [--verbose | --logConfig <file>] --configfile <configfile> <apptest>...
SSS
    Run the test apptest.
    <configfile>: Read arguments from <configfile>, instead of from command-line
                  arguments. If arguments are provided on the command-line
                  anyway, they will override the values from the config file.
                  The config file must be a JSON file, in a hierarchical order
                  that corresponds to the command-line arguments and options for
                  scaffolds and testplans.
HHH
    };
}

##
# Decode a structured argument
sub decode {
    my $string = shift;

    my @parts = split( ':', $string );

    my $name    = shift @parts; # name may be empty, in which case the default kicks in later
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
