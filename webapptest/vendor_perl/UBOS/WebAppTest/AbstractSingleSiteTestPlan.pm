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

use base qw( UBOS::WebAppTest::AbstractTestPlan );
use fields;
use UBOS::Logging;

##
# Instantiate the TestPlan.
sub new {
    my $self = shift;

    unless( ref $self ) {
        $self = fields::new( $self );
    }
    $self->SUPER::new();

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

1;
