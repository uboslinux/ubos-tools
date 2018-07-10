#!/usr/bin/perl
#
# Command that generates a new package from a scaffold
#
# Copyright (C) 2017 and later, Indie Computing Corp. All rights reserved. License: see package.
#

use strict;
use warnings;

package UBOS::Scaffold::Commands::Generate;

use Getopt::Long qw( GetOptionsFromArray );
use UBOS::Logging;
use UBOS::Utils;

##
# Execute this command.
# @args: arguments to this command
# return: desired exit code
sub run {
    my @args = @_;

    my $verbose       = 0;
    my $logConfigFile = undef;
    my $directory     = undef;
    my $scaffoldName  = undef;
    my $jsonFile          = undef;

    my $parseOk = GetOptionsFromArray(
            \@args,
            'verbose+'    => \$verbose,
            'logConfig=s' => \$logConfigFile,
            'directory=s' => \$directory,
            'scaffold=s'  => \$scaffoldName,
            'json=s'      => \$jsonFile );

    if(    !$parseOk
        || @args
        || !$scaffoldName )
    {
        fatal( 'Invalid command-line arguments, add --help' );
    }

    UBOS::Logging::initialize( 'ubos-scaffold', 'generate', $verbose, $logConfigFile );

    my $scaffold = UBOS::Scaffold::ScaffoldUtils::findScaffold( $scaffoldName );
    unless( $scaffold ) {
        fatal( 'Cannot find scaffold', $scaffoldName );
    }

    my $instance = UBOS::Utils::invokeMethod( $scaffold . '->new' );

    my $parValues;
    if( $jsonFile ) {
        $parValues = UBOS::Utils::readJsonFromFile( $jsonFile );
        unless( $parValues ) {
            fatal( $@ );
        }

    } else {
        my $pars = $instance->pars();

        print STDERR "To parameterize things properly, we need to know a few things.\n";

        $parValues = {};
        if( $pars ) {
            foreach my $key ( sort { ( $pars->{$a}->{index} || $a ) <=> ( $pars->{$b}->{index} || $b ) } keys %$pars ) {
                my $value = UBOS::Scaffold::ScaffoldUtils::ask( $pars->{$key}->{description} );
                $parValues->{$key} = $value;
            }
        }
    }

    print STDERR "Generating UBOS files for package " . $parValues->{name} . " using scaffold $scaffoldName\n";

    $instance->generate( $parValues, $directory );

    print STDERR "Done.\n";

    1;
}

##
# Return help text for this command.
# return: hash of synopsis to help text
sub synopsisHelp {
    return {
        <<SSS => <<HHH
    [--verbose] [--directory <dir>] --scaffold <scaffold>
SSS
Generate a scaffold for a UBOS package, or list which scaffolds are
available.
    <dir>      -- the directory into which to generate. Defaults to a subdirectory of the current directory with the name of the package.
    <scaffold> -- the name of the scaffold to generate.
HHH
    };
}

1;
