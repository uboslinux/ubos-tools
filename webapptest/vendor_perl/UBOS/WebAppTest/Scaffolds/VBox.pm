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
# * ubos-admin-private-key-file and ubos-admin-public-key-file (required):
#   private and public ssh key for the ubos-admin user on the guest, so the
#   scaffold can create an ubos-admin user and invoke 'sudo ubos-admin' on
#   the guest
# * vncsecret (optional): if provided, the guest will be instantiated
#   with its display available via VNC, and this password
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

package UBOS::WebAppTest::Scaffolds::VBox;

use base qw( UBOS::WebAppTest::AbstractRemoteScaffold );
use fields qw( vmdkTemplate vmdkFile sshPublicKeyFile vmName configVmdkFile );

use File::Temp;
use UBOS::Logging;
use UBOS::Utils;

# name of the hostonly interface
my $hostonlyInterface = 'vboxnet0';

# how many seconds until we give up waiting for boot
my $bootMaxSeconds = 240;
# how many seconds until we give up that pacman keys have been initialized
my $keysMaxSeconds = 60;

# how many seconds until we give up waiting for shutdown
my $shutdownMaxSeconds = 120;

##
# Instantiate the Scaffold.
# $options: hash of options
sub setup {
    my $self    = shift;
    my $options = shift;

    unless( ref $self ) {
        $self = fields::new( $self );
    }
    $self->SUPER::setup( $options );

    $self->{isOk} = 0; # until we decide otherwise

    my $vmName = 'webapptest-' . UBOS::Utils::time2string( time() );
    $self->{vmName} = $vmName;

    debug( 'Creating VBox VM', $vmName );

    unless( exists( $options->{vmdktemplate} )) {
        fatal( 'No value provided for vmdktemplate' );
    }
    unless( $options->{vmdktemplate} =~ m!\.vmdk$! ) {
        fatal( 'Vmdktemplate file must have extension .vmdk, is:', $options->{vmdktemplate} );
    }
    unless( -r $options->{vmdktemplate} ) {
        fatal( 'Vmdktemplate file does not exist or cannot be read:', $options->{vmdktemplate} );
    }

    unless( exists( $options->{vmdkfile} )) {
        $options->{vmdkfile} = "$vmName.vmdk";
    }
    unless( $options->{vmdkfile} =~ m!\.vmdk$! ) {
        fatal( 'Vmdkfile file must have extension .vmdk, is:', $options->{vmdkfile} );
    }
    if( -e $options->{vmdkfile} ) {
        fatal( 'Vmdkfile file exists already:', $options->{vmdkfile} );
    }

    if( exists( $options->{'shepherd'} )) {
        unless( $options->{'shepherd'} ) {
            fatal( 'Value for shepherd cannot be empty' );
        }
        $self->{sshUser} = $options->{'shepherd'};
    } else {
        $self->{sshUser} = 'shepherd';
    }

    unless( exists( $options->{'shepherd-public-key-file'} ) && $options->{'shepherd-public-key-file'} ) {
        fatal( 'No value provided for shepherd-public-key-file' );
    }
    unless( -r $options->{'shepherd-public-key-file'} ) {
        fatal( 'Cannot find or read file', $options->{'shepherd-public-key-file'} );
    }
    unless( exists( $options->{'shepherd-private-key-file'} ) && $options->{'shepherd-private-key-file'} ) {
        fatal( 'No value provided for shepherd-private-key-file' );
    }
    unless( -r $options->{'shepherd-private-key-file'} ) {
        fatal( 'Cannot find or read file', $options->{'shepherd-private-key-file'} );
    }

    if( exists( $options->{ram} ) && $options->{ram} !~ m!^\d+$! ) {
        fatal( 'Option ram must be an integer' );
    }

    if( exists( $options->{vncsecret} ) && !$options->{vncsecret} ) {
        fatal( 'Vncsecret cannot be empty' );
    }

    $self->{vmdkTemplate}      = $options->{vmdktemplate};
    $self->{vmdkFile}          = $options->{vmdkfile};
    $self->{sshPublicKeyFile}  = $options->{'shepherd-public-key-file'};
    $self->{sshPrivateKeyFile} = $options->{'shepherd-private-key-file'};
    my $ram                    = $options->{ram} || 512;
    my $vncSecret              = $options->{vncsecret};

    info( 'Creating Scaffold VBox' );

    my $out;
    my $err;
    
    debug( 'Copying VMDK file to', $self->{vmdkFile} );
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

    debug( 'Configuring hostonly if' );
    # VBoxManage hostonlyif remove vboxnet0 manages to hang the machine! So we try not to do that any more.
    
    UBOS::Utils::myexec( "ip link show vboxnet0 > /dev/null || VBoxManage hostonlyif create" );
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
    # generate random uuid
    if( UBOS::Utils::myexec( "VBoxManage storageattach '$vmName' --storagectl '$vmName' --setuuid '' --port 1 --type hdd --medium " . $self->{vmdkFile} )) {
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

    debug( 'Creating ubos-staff config disk' );
    $self->{configVmdkFile} = $options->{vmdkfile} . '-config.vmdk';
    $self->createConfigDisk( $self->{configVmdkFile} );

    if( UBOS::Utils::myexec( "VBoxManage storageattach '$vmName' --storagectl '$vmName' --port 2 --type hdd --medium " . $self->{configVmdkFile} )) {
        fatal( 'VBoxManage storageattach failed' );
    }

    debug( 'Starting vm', $vmName );
    if( UBOS::Utils::myexec( "VBoxManage startvm '$vmName' --type headless", undef, \$out, \$err )) {
        # This starts the VM in the background (unlike VBoxHeadless)
        fatal( 'VBoxManage startvm failed' );
    }

    info( 'Waiting until target is ready' );
    if( $self->waitUntilTargetReady() ) {
        $self->{isOk} = 1;

        $self->{isOk} &= $self->handleImpersonateDepot( $options, '192.168.56.1' ); # FIXME get IP address by lookup
        $self->{isOk} &= ( $self->invokeOnTarget( "sudo ubos-admin update" ) == 0 );

    } else {
        error( 'Virtual machine failed to start up in time' );
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
        error( 'VBoxManage controlvm failed' );
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
    if( -e $self->{configVmdkFile} ) {
        UBOS::Utils::deleteFile( $self->{configVmdkFile} );
    }

    return 1;
}

##
# Wait until target is ready.
sub waitUntilTargetReady {
    my $self = shift;

    # first we wait for an IP address, then we make sure pacman keys have been
    # initialized

    my $vmName = $self->{vmName};
    my $ret    = 0;
    for( my $count = 0 ; $count < $bootMaxSeconds ; $count += 5 ) {
        # This is on the hostonly interface
        my $out;
        if( UBOS::Utils::myexec( "VBoxManage guestproperty get '$vmName' /VirtualBox/GuestInfo/Net/1/V4/IP", undef, \$out )) {
            error( 'VBoxManage guestproperty failed' );
        }
        # $out is something like "Value: 192.168.56.103"
        if( $out =~ m!Value: (\d+\.\d+\.\d+\.\d+)! ) {
            $self->{sshHost} = $1;
            info( 'The virtual machine is accessible, from this host only, at', $self->{sshHost} );
            $ret = 1;
            last;
        }
        sleep 5;
    }
    unless( $ret ) {
        return $ret;
    }
    for( my $count = 0 ; $count < $keysMaxSeconds ; $count += 5  ) {
        my $out;
        $self->invokeOnTarget( 'ls -l /etc/pacman.d/gnupg/pubring.gpg', undef, \$out );
        # format: -rw-r--r-- 1 root root 450806 Aug 31 20:26 /etc/pacman.d/gnupg/pubring.gpg

        if( $out =~ m!^(?:\S{10})\s+(?:\S+)\s+(?:\S+)\s+(?:\S+)\s+(\d+)\s+! ) {
            my $size = $1;
            if( $size > 10000 ) {
                # rather arbitrary cutoff, but seems to do the job
                $ret = 1;
                return $ret;
            }
        }
        sleep 5;
    }
    debug( 'Pacman keys file not populated in time' );

    return $ret;
}

##
# Create a cloud-init config disk in VMDK format
# $vmdkImage: name of the vmdk image file to be created
sub createConfigDisk {
    my $self       = shift;
    my $configFile = shift;

    my $image = "$configFile.img";
    my $mount = "$configFile.mount";

    my $out;
    my $err;
    if( UBOS::Utils::myexec( "dd if=/dev/zero 'of=$image' bs=1 count=0 seek=2M", undef, \$out, \$err )) {
        fatal( 'dd failed', $err );
    }
    if( UBOS::Utils::myexec( "mkfs.vfat -n UBOS-STAFF $image", undef, \$out, \$err )) {
        fatal( 'mkfs.vfat failed', $err );
    }
    UBOS::Utils::mkdir( $mount );
    if( UBOS::Utils::myexec( "sudo mount '$image' '$mount'", undef, \$out, \$err )) {
        fatal( 'mount failed', $err );
    }

    my $vmName    = $self->{vmName};
    my $sshPubKey = UBOS::Utils::slurpFile( $self->{sshPublicKeyFile} );
    $sshPubKey =~ s!^\s+!!;
    $sshPubKey =~ s!\s+$!!;

    UBOS::Utils::mkdirDashP( "$mount/shepherd/ssh/" );

    UBOS::Utils::saveFile( "$mount/shepherd/ssh/id_rsa.pub", $sshPubKey, 0640, 'root', 'root' );

    if( UBOS::Utils::myexec( "sudo umount '$mount'", undef, \$out, \$err )) {
        fatal( 'umount failed', $err );
    }
    if( UBOS::Utils::myexec( "VBoxManage convertfromraw '$image' '$configFile' --format VMDK", undef, \$out, \$err )) {
        fatal( 'VBoxManage convertfromraw failed', $err );
    }
    UBOS::Utils::deleteFile( $image );
    UBOS::Utils::deleteRecursively( $mount );
}

##
# Return help text.
# return: help text
sub help {
    return <<TXT;
A scaffold that runs tests on the local machine in a VirtualBox virtual machine.
Options:
    vmdktemplate              (required) -- template for the VMDK file
    vmdkfile                  (optional) -- local copy of the VMDK file on which tests is performed
    shepherd                  (optional) -- name of the user on the virtual machine that can execute ubos-admin over ssh
    shepherd-public-key-file  (required) -- name of the file that contains the public key for ubos-admin ssh access
    shepherd-private-key-file (required) -- name of the file that contains the private key for ubos-admin ssh access
    ram                       (optional) -- RAM in MB
    vncsecret                 (optional) -- if given, the virtual machine will be accessible over VNC with this password
TXT
}
                    
1;
