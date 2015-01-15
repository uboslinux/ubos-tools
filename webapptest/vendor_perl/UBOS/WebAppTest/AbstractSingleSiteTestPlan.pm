#!/usr/bin/perl
#
# Factors out operations common to many kinds of TestPlans that use a single site.
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

package UBOS::WebAppTest::AbstractSingleSiteTestPlan;

use base   qw( UBOS::WebAppTest::AbstractTestPlan );
use fields qw( hostname context siteId appConfigId );

use UBOS::Host;
use UBOS::Logging;

##
# Instantiate the TestPlan.
# $options: options for the test plan
sub new {
    my $self    = shift;
    my $options = shift;

    unless( ref $self ) {
        $self = fields::new( $self );
    }
    $self->SUPER::new( $options );

    if( exists( $options->{hostname} )) {
        $self->{hostname} = $options->{hostname};
        delete $options->{hostname};
    }
    if( exists( $options->{context} )) {
        $self->{context} = $options->{context};
        delete $options->{context};
    }

    # generate random identifiers, so multiple tests can run at the same time
    $self->{siteId}      = UBOS::Host::createNewSiteId();
    $self->{appConfigId} = UBOS::Host::createNewAppConfigId();

    return $self;
}

##
# Run this TestPlan
# $scaffold: the Scaffold to use
# $test: the AppTest to run
sub run {
    my $self     = shift;
    my $scaffold = shift;
    my $test     = shift;
    
    error( 'Must override AbstractTestPlan::run' );
    return 0;
}

##
# Obtain the desired hostname at which to test.
# return: hostname
sub hostname {
    my $self = shift;

    return $self->{hostname};
}

##
# Obtain the site JSON for this test. In the second return value, point to
# the AppConfiguration in the JSON that is being tested
# $test: the AppTest
sub getSiteAndAppConfigJson {
    my $self = shift;
    my $test = shift;

    my $appConfigJson = $self->_createAppConfigurationJson( $test );
    my $siteJson      = $self->_createSiteJson( $test, $appConfigJson );
    
    return( $siteJson, $appConfigJson );
}

##
# Helper to create the AppConfiguration JSON fragment for this test
# $test: the AppTest
# return: the AppConfiguration JSON fragment
sub _createAppConfigurationJson {
    my $self = shift;
    my $test = shift;

    my $testContext = $test->getTestContext(); # if there is any
    unless( defined( $testContext )) {
        $testContext = 'ctxt-' . UBOS::Utils::randomHex( 8 );    
    }

    my $appconfig = {
        'context'     => $testContext,
        'appconfigid' => $self->{appConfigId},
        'appid'       => $test->packageName()
    };

    my $custPointValues = $test->getCustomizationPointValues();
    if( $custPointValues ) {
        my $jsonHash = {};
        $appconfig->{customizationpoints}->{$test->{packageName}} = $jsonHash;

        foreach my $name ( keys %$custPointValues ) {
            my $value = $custPointValues->{$name};

            $jsonHash->{$name}->{value} = $value;
        }
    }
    return $appconfig;
}

##
# Helper to create the Site JSON for this test.
# $test: the AppTest
# $appConfigJson: the AppConfiguration JSON fragment for this test
# return: the site JSON
sub _createSiteJson {
    my $self          = shift;
    my $test          = shift;
    my $appConfigJson = shift;

    my $hostname = $self->hostname();
    unless( $hostname ) {
        $hostname = ref $self;
        $hostname =~ s!^.*::!!;
        $hostname = 'testhost-' . lc( $hostname ) . UBOS::Utils::randomHex( 8 );    
    }

    my $admin = $self->getAdminData();
    unless( $admin ) {
        fatal( ref( $self ), 'method getAdminData() returned undef value' );
    }
    foreach my $field ( qw( userid username credential email )) {
        unless( defined( $admin->{$field} )) {
            fatal( ref( $self ), 'method getAdminData() returned hash that does not contain field', $field );
        }
    }
    
    my $site = {
        'siteid'     => $self->{siteId},
        'hostname'   => $hostname,
        'admin'      => $admin,
        'appconfigs' => [ $appConfigJson ]
    };

    return $site;
}

##
# Overridable method that returns the desired admin information for the Site JSON.
# This needs to be a hash containing userid, username, credential and email.
sub getAdminData {
    my $self = shift;

    return {
        'userid'     => 'testuser',
        'username'   => 'Test User',
        'credential' => 's3cr3t', # This is of course not secure, but we're trying
                                  # to be memorable here so the user can easily log
                                  # on in interactive mode. To be secure, override
                                  # this method in your test.
        'email'      => 'testing@ignore.ubos.net',
    };
}


1;
