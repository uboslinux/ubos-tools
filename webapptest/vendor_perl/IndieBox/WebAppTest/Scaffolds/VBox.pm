#!/usr/bin/perl
#
# A scaffold for running tests on the local machine inside a
# VirtualBox virtual machine.
#
# The virtual machine is configured with two network interfaces:
# 1: uses NAT networking, so it can access the public internet and
#    download new packages if the test requires that.
# 2: uses hostonly, so the host can do HTTP get on web apps
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

package IndieBox::WebAppTest::Scaffolds::VBox;

use base qw( IndieBox::WebAppTest::AbstractScaffold );
use fields qw( vmdkTemplate vmdkFile ram vram indieboxAdminKeyfile vmName hostOnlyIp );
use IndieBox::Logging;
use IndieBox::Utils;

# name of the hostonly interface
my $hostonlyInterface = 'vboxnet0';

# how many seconds we try until we give up waiting for boot
my $bootMaxSeconds = 120;

# How to connect to the console: (example)
# VBoxManage setproperty vrdeextpack VNC
# VBoxManage modifyvm test1 --vrdeproperty VNCPassword=s3cr3t 
# VBoxManage modifyvm test1 --vrdeauthlibrary null

##
# Instantiate the Scaffold.
sub setup {
    my $self    = shift;
    my $options = shift;

    unless( ref $self ) {
        $self = fields::new( $self );
    }
    $self->SUPER::setup();

    $self->{ram}  = 512; # default
    $self->{vram} =  16; # default
    if( $options ) {
        foreach my $pair ( split /&/, $options ) {
            if( $pair =~ m!^(.*)(=(.*))$! ) {
                my $key   = $1;
                my $value = $3;
    
                if( 'vmdktemplate' eq $key ) {
                    if( !$value ) {
                        fatal( 'No value provided for vmdktemplate' );
                    } elsif( $value !~ m!\.vmdk$! ) {
                        fatal( 'Vmdktemplate file must have extension .vmdk, is:', $value );
                    } elsif( !-e $value ) {
                        fatal( 'Vmdktemplate file does not exist:', $value );
                    }
                    $self->{vmdkTemplate} = $value;
    
                } elsif( 'vmdkfile' eq $key ) {
                    if( !$value ) {
                        fatal( 'No value provided for vmdkfile' );
                    } elsif( $value !~ m!\.vmdk$! ) {
                        fatal( 'Vmdkfile must have extension .vmdk, is:', $value );
                    } elsif( -e $value ) {
                        fatal( 'Vmdkfile file exists already:', $value );
                    }
                    $self->{vmdkFile} = $value;
    
                } elsif( 'ram' eq $key ) {
                    if( !$value ) {
                        fatal( 'No value provided for ram' );
                    } else {
                        $self->{ram} = $value;
                    }
    
                } elsif( 'indiebox-admin-keyfile' eq $key ) {
                    if( !$value ) {
                        fatal( 'No value provided for indiebox-admin-keyfile' );
                    } else {
                        $self->{indieboxAdminKeyfile} = $value;
                    }
    
                } else {
                    fatal( 'Unknown VBox scaffold option', $key );
                }
            }
        }
    }
    unless( defined( $self->{vmdkTemplate} )) {
        fatal( 'Must provide option vmdktemplate pointing to template VMDK file to copy and use as guest drive' );
    }
    unless( -r $self->{vmdkTemplate} ) {
        fatal( 'Cannot find or read file', $self->{vmdkTemplate} );
    }

    unless( defined( $self->{indieboxAdminKeyfile} )) {
        fatal( 'Must provide option indiebox-admin-keyfile pointing to private ssh key for indiebox-admin on guest' );
    }
    unless( -r $self->{indieboxAdminKeyfile} ) {
        fatal( 'Cannot find or read file', $self->{indieboxAdminKeyfile} );
    }

    my $vmName = 'webapptest-' . IndieBox::Utils::randomHex( 16 );
    $self->{vmName} = $vmName;

    unless( $self->{vmdkFile} ) {
        $self->{vmdkFile} = "$vmName.vmdk";
    }

    info( 'Creating Scaffold VBox' );

    my $out;
    my $err;
    
    debug( 'Copying VMDK file' );
    if( IndieBox::Utils::myexec( 'cp ' . $self->{vmdkTemplate} . ' ' . $self->{vmdkFile} )) {
        fatal( 'Copying VMDK file failed' );
    }

    debug( 'Defining VM' );
    if( IndieBox::Utils::myexec( "VBoxManage createvm -name '$vmName' -ostype Linux_64 -register" )) {
        fatal( 'VBoxManage createvm failed' );
    }

    debug( 'Setting RAM' );
    if( IndieBox::Utils::myexec( "VBoxManage modifyvm '$vmName' --memory " . $self->{ram} )) {
        fatal( 'VBoxManage modifyvm failed' );
    }

    debug( 'Setting video RAM' );
        if( IndieBox::Utils::myexec( "VBoxManage hostonlyif ipconfig $hostonlyInterface --ip 192.168.56.1" )) {
        fatal( 'VBoxManage modifyvm failed' );
    }

    debug( 'Adding NIC1 in nat mode' );
    if( IndieBox::Utils::myexec( "VBoxManage modifyvm '$vmName' --nic1 nat" )) {
        fatal( 'VBoxManage modifyvm failed' );
    }
    
    debug( 'Adding NIC2 in hostonly mode' );
    if( IndieBox::Utils::myexec( "VBoxManage modifyvm '$vmName' --nic2 hostonly" )) {
        fatal( 'VBoxManage modifyvm failed' );
    }
    
    debug( 'Attaching storage controller, drive and making it the boot drive' );
    # Storage controller with same name as the vm
    if( IndieBox::Utils::myexec( "VBoxManage storagectl '$vmName' --name '$vmName' --add sata --bootable on" )) {
        fatal( 'VBoxManage storagectl failed' );
    }
    if( IndieBox::Utils::myexec( "VBoxManage storageattach '$vmName' --storagectl '$vmName' --port 1 --type hdd --medium " . $self->{vmdkFile} )) {
        fatal( 'VBoxManage storageattach failed' );
    }
    if( IndieBox::Utils::myexec( "VBoxManage modifyvm '$vmName' --boot1 disk --boot2 none --boot3 none --boot4 none" )) {
        fatal( 'VBoxManage modifyvm failed' );
    }

    debug( 'Setting up host-only networking' );
    if( IndieBox::Utils::myexec( "ip link show dev $hostonlyInterface", undef, \$out, \$err )) {
        # doesn't exist
        if( IndieBox::Utils::myexec( "VBoxManage hostonlyif create" )) {
            error( 'VBoxManage hostonlyif create failed' );
        }
        if( IndieBox::Utils::myexec( "VBoxManage hostonlyif ipconfig $hostonlyInterface --ip 192.168.56.1" )) {
            error( 'VBoxManage hostonlyif ipconfig failed' );
        }
    }
    if( IndieBox::Utils::myexec( "VBoxManage modifyvm '$vmName' --hostonlyadapter2 $hostonlyInterface" )) {
        fatal( 'VBoxManage modifyvm failed' );
    }
    if( IndieBox::Utils::myexec( "VBoxManage startvm '$vmName' --type headless" )) {
        # This starts the VM in the background (unless VBoxHeadless)
        fatal( 'VBoxManage startvm failed' );
    }
  
    return $self;
}

##
# Teardown this Scaffold.
sub teardown {
    my $self = shift;

    info( 'Tearing down Scaffold VBox' );

    my $vmName = $self->{vmName};
    
    debug( 'Shutting down vm, unregistering, and deleting image file' );
    if( IndieBox::Utils::myexec( "VBoxManage controlvm '$vmName' acpipowerbutton" )) {
        error( 'VBoxManage unregistervm failed' );
    }
    sleep 10;
    if( IndieBox::Utils::myexec( "VBoxManage unregistervm '$vmName' --delete" )) {
        error( 'VBoxManage unregistervm failed' );
    }
    if( -e $self->{vmdkFile} ) {
        IndieBox::Utils::deleteFile( $self->{vmdkFile} );
    }
        
    return 1;
}

##
# Helper method to invoke a command on the target. This must be overridden by subclasses.
# $cmd: command
# $stdin: content to pipe into stdin
# $stdout: content captured from stdout
# $stderr: content captured from stderr
sub invokeOnTarget {
    my $self   = shift;
    my $cmd    = shift;
    my $stdin  = shift;
    my $stdout = shift;
    my $stderr = shift;

    my $ip = $self->getTargetIp();
    
    my $sshCmd = 'ssh';
    $sshCmd .= ' -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null';
    $sshCmd .= ' indiebox-admin@' . $ip;
    $sshCmd .= ' -i ' . $self->{indieboxAdminKeyfile};
    $sshCmd .= " '$cmd'";
    debug( 'ssh command:', $sshCmd );

    return IndieBox::Utils::myexec( $sshCmd, $stdin, $stdout, $stderr );
}

##
# Obtain the IP address of the target.  This must be overridden by subclasses.
# return: target IP
sub getTargetIp {
    my $self  = shift;

    if( $self->{hostOnlyIp} ) {
        return $self->{hostOnlyIp};
    }

    my $vmName = $self->{vmName};
    for( my $count = 0 ; $count < $bootMaxSeconds ; ++$count ) {
        # This is on the hostonly interface
        my $out;
        if( IndieBox::Utils::myexec( "VBoxManage guestproperty get '$vmName' /VirtualBox/GuestInfo/Net/1/V4/IP", undef, \$out )) {
            error( 'VBoxManage guestproperty failed' );
        }
        # $out is something like "Value: 192.168.56.103"
        my $ret;
        if( $out =~ m!Value: (\d+\.\d+\.\d+\.\d+)! ) {
            $self->{hostOnlyIp} = $1;
            return $self->{hostOnlyIp};
        }
        sleep 1;
    }
    return undef;
}

##
# Return help text.
# return: help text
sub help {
    return <<TXT;
A scaffold that runs tests on the local machine in a VirtualBox virtual machine.
Options:
    vmdktemplate (required) -- template for the VMDK file
    vmdkfile     (required) -- local copy of the VMDK file on which tests is performed
    ram          (optional) -- RAM in MB
TXT
}

1;
