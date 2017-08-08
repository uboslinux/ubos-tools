#!/usr/bin/perl
#
# Command that generates a new package from a scaffold
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
    my $directory     = '.';
    my $scaffoldName  = 'default';

    my $parseOk = GetOptionsFromArray(
            \@args,
            'verbose+'       => \$verbose,
            'logConfig=s'    => \$logConfigFile,
            'directory=s'    => \$directory,
            'scaffold=s'     => \$scaffoldName );

    if(    !$parseOk
        || @args
        || !$scaffoldName )
    {
        fatal( 'Invalid command-line arguments, add --help' );
    }
    unless( -d $directory ) {
        fatal( 'Cannot find directory:', $directory );
    }

    UBOS::Logging::initialize( 'ubos-scaffold', 'generate', $verbose, $logConfigFile );

    foreach my $f ( qw( PKGBUILD ubos-manifest.json )) {
        if( -e "$directory/$f" ) {
            fatal( "$directory/$f exists: refusing to proceed\n" );
        }
    }

    my $scaffold = UBOS::Scaffold::ScaffoldUtils::findScaffold( $scaffoldName );
    unless( $scaffold ) {
        fatal( 'Cannot find scaffold', $scaffoldName );
    }

    my $pars      = UBOS::Utils::invokeMethod( $scaffold . '::pars' );
    my $parValues = {};

    print STDERR "To parameterize things properly, we need to know a few things.\n";

    if( $pars ) {
        foreach my $parPair ( @$pars ) {
            my $value = UBOS::Scaffold::ScaffoldUtils::ask( $parPair->{description} );
            $parValues->{$parPair->{name}} = $value;
        }
    }

    print STDERR "Generating UBOS files for package $parValues->{name} into directory $directory using scaffold $scaffold\n";

    UBOS::Utils::invokeMethod( $scaffold . '::generate', $parValues, $directory );

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
    <dir>      -- the directory into which to generate. Defaults to the current directory.
    <scaffold> -- the name of the scaffold to generate.
HHH
    };
}

1;
