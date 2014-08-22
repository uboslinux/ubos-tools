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
# The following options can be provied:
# * vmdktemplate (required): name of a VMDK file containing a VirtualBox
#   virtual Indie Box. This file will only be copied as a template, and
#   not modified by tests
# * vmdkfile (optional): name of the copy of the VMDK template file
# * ram (optional): amount of RAM to allocate to the guest
# * ubos-admin-keyfile (required): private ssh key for the
#   ubos-admin user on the guest, so the scaffold can invoke
#   'sudo ubos-admin' on the guest
# * vncsecret (optional): if provided, the guest will be instantiated
#   with its display available via VNC, and this password
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

package UBOS::WebAppTest::Scaffolds::VBox;

use base qw( UBOS::WebAppTest::AbstractScaffold );
use fields qw( vmdkTemplate vmdkFile ubosAdminKeyfile vmName hostOnlyIp );
use UBOS::Logging;
use UBOS::Utils;

# name of the hostonly interface
my $hostonlyInterface = 'vboxnet0';

# how many seconds until we give up waiting for boot
my $bootMaxSeconds = 120;
# how many seconds until we give up waiting for shutdown
my $shutdownMaxSeconds = 30;

##
# Instantiate the Scaffold.
# $options: array of options
sub setup {
    my $self    = shift;
    my $options = shift;

    unless( ref $self ) {
        $self = fields::new( $self );
    }
    $self->SUPER::setup();

    my $vncSecret = undef;
    my $ram       = 512; # default
    my $vram      =  16; # default

    if( defined( $options ) && @$options ) {
        foreach my $pair ( @$options ) {
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
                        $ram = $value;
                    }
    
                } elsif( 'ubos-admin-keyfile' eq $key ) {
                    if( !$value ) {
                        fatal( 'No value provided for ubos-admin-keyfile' );
                    } else {
                        $self->{ubosAdminKeyfile} = $value;
                    }
    
                } elsif( 'vncsecret' eq $key ) {
                    if( !$value ) {
                        fatal( 'No value provided for vncsecret' );
                    } else {
                        $vncSecret = $value;
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

    unless( defined( $self->{ubosAdminKeyfile} )) {
        fatal( 'Must provide option ubos-admin-keyfile pointing to private ssh key for ubos-admin on guest' );
    }
    unless( -r $self->{ubosAdminKeyfile} ) {
        fatal( 'Cannot find or read file', $self->{ubosAdminKeyfile} );
    }

    my $vmName = 'webapptest-' . UBOS::Utils::time2string( time() );
    $self->{vmName} = $vmName;

    unless( $self->{vmdkFile} ) {
        $self->{vmdkFile} = "$vmName.vmdk";
    }

    info( 'Creating Scaffold VBox' );

    my $out;
    my $err;
    
    debug( 'Copying VMDK file' );
    if( UBOS::Utils::myexec( 'cp ' . $self->{vmdkTemplate} . ' ' . $self->{vmdkFile} )) {
        fatal( 'Copying VMDK file failed' );
    }

    debug( 'Defining VM' );
    if( UBOS::Utils::myexec( "VBoxManage createvm -name '$vmName' -ostype Linux_64 -register", undef, \$out, \$err )) {
        fatal( 'VBoxManage createvm failed:', $err );
    }

    debug( 'Setting RAM' );
    if( UBOS::Utils::myexec( "VBoxManage modifyvm '$vmName' --memory $ram" )) {
        fatal( 'VBoxManage modifyvm failed' );
    }

    debug( 'Setting video RAM' );
    if( UBOS::Utils::myexec( "VBoxManage hostonlyif ipconfig $hostonlyInterface --ip 192.168.56.1" )) {
        fatal( 'VBoxManage modifyvm failed' );
    }

    debug( 'Adding NIC1 in nat mode' );
    if( UBOS::Utils::myexec( "VBoxManage modifyvm '$vmName' --nic1 nat" )) {
        fatal( 'VBoxManage modifyvm failed' );
    }
    
    debug( 'Adding NIC2 in hostonly mode' );
    if( UBOS::Utils::myexec( "VBoxManage modifyvm '$vmName' --nic2 hostonly" )) {
        fatal( 'VBoxManage modifyvm failed' );
    }
    
    debug( 'Attaching storage controller, drive and making it the boot drive' );
    # Storage controller with same name as the vm
    if( UBOS::Utils::myexec( "VBoxManage storagectl '$vmName' --name '$vmName' --add sata --bootable on" )) {
        fatal( 'VBoxManage storagectl failed' );
    }
    if( UBOS::Utils::myexec( "VBoxManage storageattach '$vmName' --storagectl '$vmName' --port 1 --type hdd --medium " . $self->{vmdkFile} )) {
        fatal( 'VBoxManage storageattach failed' );
    }
    if( UBOS::Utils::myexec( "VBoxManage modifyvm '$vmName' --boot1 disk --boot2 none --boot3 none --boot4 none" )) {
        fatal( 'VBoxManage modifyvm failed' );
    }

    debug( 'Setting up host-only networking' );
    if( UBOS::Utils::myexec( "ip link show dev $hostonlyInterface", undef, \$out, \$err )) {
        # doesn't exist
        if( UBOS::Utils::myexec( "VBoxManage hostonlyif create" )) {
            error( 'VBoxManage hostonlyif create failed' );
        }
        if( UBOS::Utils::myexec( "VBoxManage hostonlyif ipconfig $hostonlyInterface --ip 192.168.56.1" )) {
            error( 'VBoxManage hostonlyif ipconfig failed' );
        }
    }
    if( UBOS::Utils::myexec( "VBoxManage modifyvm '$vmName' --hostonlyadapter2 $hostonlyInterface" )) {
        fatal( 'VBoxManage modifyvm failed' );
    }

    if( $vncSecret ) {
        if( UBOS::Utils::myexec( "VBoxManage setproperty vrdeextpack VNC" )) {
            error( 'VBoxManage setproperty vrdeextpack failed' );
        }
        if( UBOS::Utils::myexec( "VBoxManage modifyvm '$vmName' --vrde on" )) { 
            error( 'VBoxManage modifyvm (enabling vrde) failed. You may not be able to connect via VNC.' );
        }
        if( UBOS::Utils::myexec( "VBoxManage modifyvm '$vmName' --vrdeproperty 'VNCPassword=$vncSecret'" )) { 
            error( 'VBoxManage modifyvm (setting VNC password) failed. You may not be able to connect via VNC.' );
        }
        if( UBOS::Utils::myexec( "VBoxManage modifyvm '$vmName' --vrdeauthlibrary null" )) {
            error( 'VBoxManage modifyvm --vrdeauthlibrary failed' );
        }
        if( UBOS::Utils::myexec( "VBoxManage modifyvm '$vmName' --vrdeport 1501" )) {
            error( 'VBoxManage modifyvm --vrdeport failed' );
        } else {
            info( 'You can access the VM via VNC at port 1501' );
        }
    }

    debug( 'Starting vm', $vmName );
    if( UBOS::Utils::myexec( "VBoxManage startvm '$vmName' --type headless", undef, \$out, \$err )) {
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
    if( UBOS::Utils::myexec( "VBoxManage controlvm '$vmName' acpipowerbutton" )) {
        error( 'VBoxManage unregistervm failed' );
    }

    my $out;
    my $err;
    for( my $count = 0 ; $count < $shutdownMaxSeconds ; ++$count ) {
        if( UBOS::Utils::myexec( "VBoxManage showvminfo '$vmName' --machinereadable", undef, \$out )) {
            error( 'VBoxManage showvminfo failed' );
        }
        if( $out =~ m!VMState="poweroff"! ) {
            debug( 'VM state is poweroff' );
            last;
        }
        sleep 1;
    }

    if( UBOS::Utils::myexec( "VBoxManage unregistervm '$vmName' --delete", undef, \$out, \$err )) {
        error( 'VBoxManage unregistervm failed', $err );
    }
    if( -e $self->{vmdkFile} ) {
        UBOS::Utils::deleteFile( $self->{vmdkFile} );
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
    $sshCmd .= ' -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=error';
            # don't put into known_hosts file, and don't print resulting warnings
    $sshCmd .= ' ubos-admin@' . $ip;
    $sshCmd .= ' -i ' . $self->{ubosAdminKeyfile};
    $sshCmd .= " '$cmd'";
    debug( 'ssh command:', $sshCmd );

    return UBOS::Utils::myexec( $sshCmd, $stdin, $stdout, $stderr );
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
        if( UBOS::Utils::myexec( "VBoxManage guestproperty get '$vmName' /VirtualBox/GuestInfo/Net/1/V4/IP", undef, \$out )) {
            error( 'VBoxManage guestproperty failed' );
        }
        # $out is something like "Value: 192.168.56.103"
        my $ret;
        if( $out =~ m!Value: (\d+\.\d+\.\d+\.\d+)! ) {
            $self->{hostOnlyIp} = $1;
            info( 'The virtual machine is accessible, from this host only, at', $self->{hostOnlyIp} );
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
