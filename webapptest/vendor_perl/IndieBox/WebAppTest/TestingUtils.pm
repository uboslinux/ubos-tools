#!/usr/bin/perl
#
# Collection of utility methods for web app testing.
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

package IndieBox::WebAppTest::TestingUtils;

use Cwd;
use IndieBox::Logging;
use IndieBox::Utils;

##
# Find all AppTests in a directory.
# $dir: directory to look in
# return: hash of file name to AppTest object
sub findAppTestsInDirectory {
    my $dir = shift;
    
    my $appTestCandidates = IndieBox::Utils::readFilesInDirectory( $dir, 'Test\.pm$' );
    my $appTests = {};
    
    while( my( $fileName, $content ) = each %$appTestCandidates ) {
        my $appTest = eval $content;

        if( defined( $appTest ) && ref( $appTest ) eq 'IndieBox::WebAppTest' ) {
            $appTests->{$fileName} = $appTest;

        } elsif( $@ ) {
            error( 'Failed to parse', $fileName, ':', $@ );
            
        } else {
            info( 'Skipping', $fileName, '-- not an AppTest' );
        }
    }
    return $appTests;
}

##
# Find available commands.
# return: hash of command name to full package name
sub findCommands {
    my $ret = IndieBox::Utils::findPerlShortModuleNamesInPackage( 'IndieBox::WebAppTest::Commands' );

    return $ret;
}

##
# Find available test plans
# return: hash of test plan name to full package name
sub findTestPlans {
    my $ret = IndieBox::Utils::findPerlShortModuleNamesInPackage( 'IndieBox::WebAppTest::TestPlans' );

    return $ret;
}

##
# Find a named test plan
# $name: name of the test plan
# return: test plan template, or undef
sub findTestPlan {
    my $name = shift;

    my $plans = findTestPlans();
    my $ret   = $plans->{$name};

    return $ret;
}

##
# Find available test scaffolds.
# return: hash of scaffold name to full package name
sub findScaffolds {
    my $ret = IndieBox::Utils::findPerlShortModuleNamesInPackage( 'IndieBox::WebAppTest::Scaffolds' );
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
# Find a named AppTest in a directory.
# $dir: directory to look in
# $name: name of the test
# return: the AppTest object, or undef
sub findAppTestInDirectory {
    my $dir  = shift;
    my $name = shift;

    my $fileName;
    if( $name =~ m!^/! ) {
        $fileName = $name;
    } else {
        $fileName = getcwd() . "/$name";
    }

    if( !-r $fileName && $fileName !~ m!\.pm$! ) {
        $fileName = "$fileName.pm";
    }
    if( -r $fileName ) {
        my $content = IndieBox::Utils::slurpFile( $fileName );
        
        my $appTest = eval $content;

        if( defined( $appTest ) && ref( $appTest ) eq 'IndieBox::WebAppTest' ) {
            return $appTest;

        } elsif( $@ ) {
            error( 'Failed to parse', $fileName, ':', $@ );
            
        } else {
            error( 'Not a IndieBox::WebAppTest:', $fileName );
        }
    }        
    return undef;
}

1;
