#!/usr/bin/perl
#
# Wellknown test plan: this degenerate test plan pays little attention
# to the app being tested, but instead checks that the well-known
# site fields (robotstxt, sitemapxml and faviconicobase64) are
# served correctly in the virgin state.
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

package UBOS::WebAppTest::TestPlans::WellKnown;

use base qw( UBOS::WebAppTest::AbstractSingleSiteTestPlan );
use fields;
use UBOS::Logging;
use UBOS::WebAppTest::TestContext;
use UBOS::Utils;

##
# Instantiate the TestPlan.
# $test: the test to run
# $options: options for the test plan
sub new {
    my $self    = shift;
    my $test    = shift;
    my $options = shift;

    unless( ref $self ) {
        $self = fields::new( $self );
    }
    $self = $self->SUPER::new( $test, $options );

    if( defined( $options ) && %$options ) {
        fatal( 'Unknown option(s) for TestPlan Wellknown:', join( ', ', keys %$options ));
    }

    return $self;
}

##
# Run this TestPlan
# $scaffold: the Scaffold to use
# $interactive: if 1, ask the user what to do after each error
# $verbose: verbosity level from 0 (not verbose) upwards
sub run {
    my $self        = shift;
    my $scaffold    = shift;
    my $interactive = shift;
    my $verbose     = shift;

    info( 'Running TestPlan Wellknown' );

    my $siteJson = $self->getSiteJson();

    my $siteJsonWithWellKnown = { %$siteJson };
    $siteJsonWithWellKnown->{wellknown}->{robotstxt} = <<ROBOTS; # from robotstxt.org
User-agent: *
Disallow: /
ROBOTS
    $siteJsonWithWellKnown->{wellknown}->{sitemapxml} = <<SITEMAP; # from sitemaps.org
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
   <url>
      <loc>http://www.example.com/</loc>
      <lastmod>2005-01-01</lastmod>
      <changefreq>monthly</changefreq>
      <priority>0.8</priority>
   </url>
</urlset>
SITEMAP
    $siteJsonWithWellKnown->{wellknown}->{faviconicobase64} = <<ICO; # ubos.ico
AAABAAEAEBAAAAAAIABoBAAAFgAAACgAAAAQAAAAIAAAAAEAIAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAABcvnP/Xb90/12+c/9dvnT/XL5z/1y+c/9dv3T/Xb5z/12+
dP9cvnP/XL5z/12/dP9dvnP/Xb50/1y+c/9cvnP/XL9z/12/dP9cvnP/XL90/1y+
c/9cvnP/Xb90/1y+c/9cv3T/XL5z/1y+c/9dv3T/XL5z/1y/dP9cvnP/XL5z/1y/
dP9dv3T/Xb90/12/dP9cv3T/XL90/12/dP9dv3T/Xb90/1y/dP9cv3T/Xb90/12/
dP9dv3T/XL9z/1y+dP9cv3P/Xb90/12+c/9dv3T/Xb5z/1y+c/9dv3T/Xb5z/12/
dP9dvnP/XL5z/12/dP9dvnP/Xb90/12+c/9dvnP/XL5z/1y+c/9dv3T/Xb90/12/
dP9dv3T/Xb90/12/dP9cvnP/Xb90/12/dP9cvnP/Xb90/12/dP9dv3T/XL5z/1y+
c/9dwHT/XL1y/1y9cv9dwHT/XL1y/1u8cv9dv3T/XsF1/1y+c/9bvHL/XcF1/13A
dP9aunH/Xb90/12/dP9dwHX/VK1p/zx8S/88fUz/VK1p/z+CT/8+f03/QIRQ/1Su
af8/gk//PH1M/1GnZf9Hk1n/QIRQ/0GGUf9cvXP/XsJ2/0OKVP9NoGH/TZ9g/0aR
WP9DilT/RpBY/zx7S/84dUf/TJxg/1i2b/84dEb/UKRj/0qZXf83ckX/W7xy/17C
dv9DilT/T6Jj/0+iYv9GkFf/Q4pU/0GHU/83c0b/QINQ/0uaXv9YtW//OndI/z5/
Tf9Fjlb/TqJi/1y9c/9dv3T/P4NP/0qYXP9KmFz/P4JP/z6BTv89fUz/Q4pU/1ez
bf8/g0//PH1M/1KqZ/9KmFz/P4JP/0OKVP9cvXP/XL5z/1y9c/9cvXP/XL1z/1y9
c/9cvXP/XL1y/13AdP9dwHT/Xb90/1y9cv9dwHX/XcB1/1u8cv9dwHT/Xb90/12/
dP9dv3T/Xb90/12/dP9dv3T/Xb90/12/dP9dv3T/XL5z/12/dP9dv3T/XL5z/12/
dP9dv3T/Xb90/1y+c/9cv3T/Xb90/12/dP9dv3T/XL90/1y/dP9dv3T/Xb90/12/
dP9cv3T/XL90/12/dP9dv3T/Xb90/1y/c/9cvnT/XL9z/12/dP9dvnP/Xb90/12+
c/9cvnP/Xb90/12+c/9dv3T/Xb5z/1y+c/9dv3T/Xb5z/12/dP9dvnP/Xb5z/12/
dP9dv3T/Xb90/12/dP9dv3T/Xb90/12/dP9dv3T/Xb90/12/dP9dv3T/Xb90/12/
dP9dv3T/Xb90/12/dP9cv3T/Xb90/1y/dP9cv3T/XL90/1y/dP9dv3T/XL90/1y/
dP9cv3T/XL90/12/dP9cv3T/XL90/1y/c/9cvnT/3/q9/z8OH4Y/Gh+GV7hChf//
//////////////////8HOeuF/v///2/r2v9fTp3/vxofhle4QoX/////AAAAAA==
ICO

    my $ret = 1;
    my $repeat;
    my $abort;
    my $quit;

    foreach my $thisSiteJson ( $siteJsonWithWellKnown, $siteJson ) {
        my $success;
        my $currentState = $self->getTest()->getVirginStateTest();

        do {
            $success = $scaffold->deploy( $thisSiteJson );

            ( $repeat, $abort, $quit ) = $self->askUser(
                    'Performed deployment ' . ( $thisSiteJson == $siteJsonWithWellKnown ? 'with' : 'without' ) . ' well-known site fields',
                    $interactive, $success, $ret );
        } while( $repeat );
        $ret &= $success;

        if( !$abort && !$quit ) {
            my $c = new UBOS::WebAppTest::TestContext( $scaffold, $self, $verbose );

            my $currentState = $self->getTest()->getVirginStateTest();

            info( 'Checking well-known site fields in', $currentState->getName() );

            do {
                $success = $currentState->checkWellKnown( $c, $thisSiteJson );

                ( $repeat, $abort, $quit ) = $self->askUser(
                    'Performed check ' . ( $thisSiteJson == $siteJsonWithWellKnown ? 'with' : 'without' ) . ' well-known site fields',
                    $interactive, $success, $ret );

            } while( $repeat );
            $ret &= $success;

            $c->destroy();
        }
        if( $abort || $quit ) {
            last;
        }
    }

    unless( $abort ) {
        $scaffold->undeploy( $siteJson );
    }

    info( 'End running TestPlan Wellknown' );

    return $ret;
}

##
# Return help text.
# return: help text
sub help {
    return 'Walks twice through all States and Transitions in sequence, checking well-known site fields only.';
}

##
# Return allowed arguments for this command.
# return: allowed arguments, as string
sub helpArguments {
    return undef;
}

1;
