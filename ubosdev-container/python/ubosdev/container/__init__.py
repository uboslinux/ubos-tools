#!/usr/bin/python
#
# Copyright (C) 2022 and later, Indie Computing Corp. All rights reserved. License: see package.
#

import argparse
import atexit
import os
import os.path
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import traceback
import ubos.logging
import ubos.utils
import ubosdev.container.utils
import sys


def run() :
    """
    main program
    """
    cmds = ubosdev.container.utils.findCommands()

    parser = argparse.ArgumentParser( description='Run commands on UBOS development containers.'
            + ' After you have run sub-command "setup" with your desired release channel,'
            + ' run "list-templates" to determine which container templates are available,'
            + ' and then "create" to instantiate one, and "run" to run it.' )
    parser.add_argument('-v', '--verbose', action='count',       default=0,  help='Display extra output. May be repeated for even more output.')
    parser.add_argument('--logConfig',                                       help='Use an alternate log configuration file for this command.')
    parser.add_argument('--debug',         action='store_const', const=True, help='Suspend execution at certain points for debugging' )
    cmdParsers = parser.add_subparsers( dest='command', required=True )

    for cmdName, cmd in cmds.items():
        cmd.addSubParser( cmdParsers, cmdName )

    args,remaining = parser.parse_known_args(sys.argv[1:])
    cmdName = args.command

    ubos.logging.initialize('ubosdev-container', cmdName, args.verbose, args.logConfig, args.debug)

    if len(remaining)>0 :
        parser.print_help()
        exit(0)

    if cmdName in cmds:
        try :
            ret = cmds[cmdName].run(args)
            exit( ret )

        except Exception as e:
            if args.verbose > 1:
                traceback.print_exc( e )
            ubos.logging.fatal( str(type(e)), '--', e )

    else:
        ubos.logging.fatal('Sub-command not found:', cmdName, '. Add --help for help.' )


def determineChannel( arg ) :
    if arg is None :
        arg = 'yellow'
    else :
        if not arg in [ 'dev', 'red', 'yellow', 'green' ] :
            ubos.logging.fatal( 'Invalid channel:', arg )
    return arg


def determineArch( arg ) :
    if arg is None:
        result = ubos.utils.myexec( 'uname -m', captureStdout=True )
        arg = result[1].strip().decode( 'UTF-8' )
    return arg


def determineContainerDir( arg ) :
    if arg is None:
        arg = f"{os.environ['HOME']}/ubos-containers/ubosdev"
    return arg


def determineNamedContainerRootDir( containerDir, containerName ) :
    return f"{containerDir}/{containerName}"


def determineImagesDir( arg ) :
    if arg is None:
        arg = f"{os.environ['HOME']}/ubos-containers/images"
    return arg


def determineNamedTemplateRootDir( imagesDir, templateName ) :
    return f"{imagesDir}/{templateName}"


def ensurePackage( name ) :
    """
    Ensure that a package is installed
    """

    cmd = f"pacman -Q '{name}' 2> /dev/null || sudo pacman -S --noconfirm '{name}'"
    ret = ubos.utils.myexec( cmd )
    return ret


def ensureDirectory( name ) :
    """
    Ensure this directory and its parents exist
    """
    os.makedirs( name, exist_ok=True )


def ensureSubvol( name ) :
    """
    Ensure this subvolume and its parents exist

    return: true if it was newly made
    """
    os.makedirs( Path( name ).parent, exist_ok=True )
    if not os.path.exists( name ) :
        ubos.utils.myexec( f"sudo btrfs subvol create '{name}'" )
        return True
    else :
        return False


def deleteSubvol( name ) :
    """
    Delete this subvolume
    """

    ubos.utils.myexec( f"sudo btrfs subvol delete '{name}'" )


def copyRecursively( fromDir, toDir ) :
    """
    Copy a directory hierarchy that happens to be subvols on both sides
    """
    ubos.utils.myexec( f"sudo btrfs subvol snapshot '{fromDir}' '{toDir}' 2>/dev/null" )


# -- commands --


def listContainerTemplates( args ) :
    """
    List the available templates
    """

    imagesDir = determineImagesDir( args.imagesdirectory )

    osRelease = '/etc/os-release' # look for this file, so we know it's a valid container system
    for found in Path( imagesDir ).glob( '*' + osRelease ) :
        dir = str( found )
        dir = dir[ len(imagesDir)+1 : -len( osRelease ) ]
        print( dir )


def listContainers( args ) :
    """
    List the available containers
    """

    containerDir = determineContainerDir( args.containerdirectory )

    osRelease = '/etc/os-release' # look for this file, so we know it's a valid container system
    for found in Path( containerDir ).glob( '*' + osRelease ) :
        dir = str( found )
        dir = dir[ len(containerDir)+1 : -len( osRelease ) ]
        print( dir )


def setup( args ) :
    """
    Setup for a particular release channel
    """

    channel         = determineChannel( args.channel )
    arch            = determineArch( args.arch )
    containerDir    = determineContainerDir( args.containerdirectory )
    imagesDir       = determineImagesDir( args.imagesdirectory )
    depotUrl        = args.depoturl or 'https://depot.ubosfiles.net'

    print( '*** Upgrading system.' )
    ubos.utils.myexec( 'sudo pacman -Syu' )

    print( '*** Ensuring all needed packages.' )
    ensurePackage( 'gnu-free-fonts' )
    ensurePackage( 'ttf-liberation' )
    ensurePackage( 'firefox' )
    ensurePackage( 'snapper' )
    ensurePackage( 'geany' )
    ensurePackage( 'geany-plugins' )
    ensurePackage( 'java-environment' )
    ensurePackage( 'netbeans' )

    print( '*** Running iptables.' )
    for f in [ '/etc/iptables/iptables.rules', '/etc/iptables/ip6tables.rules' ] :
        if not os.path.exists( f ) :
            ubos.utils.myexec( f"sudo cp /etc/iptables/empty.rules {f}" )
    ubos.utils.myexec( 'sudo systemctl enable --now iptables ip6tables' )

    ensureDirectory( containerDir )
    ensureDirectory( imagesDir )

    print( f"*** Setting up for release channel {channel} on arch {arch}." )

    imageName   = f"ubos-develop_{channel}_{arch}-container_LATEST.tar.xz"
    templateDir = f"{imagesDir}/ubos-develop-{channel}"

    if os.path.exists( f"{imagesDir}/{imageName}" ) :
        print( '*** Have image already, not downloading nor checking for updates.' )
    else :
        print( '*** Downloading a UBOS Linux container image. This may take a while.' )
        ubos.utils.myexec( f"curl -o {imagesDir}/{imageName} {depotUrl}/{channel}/{arch}/images/{imageName}" )

    if ensureSubvol( templateDir ) :
        print( f"*** Unpacking image into {templateDir}." )
        ubos.utils.myexec( f"sudo tar -C {templateDir} -x -J -f {imagesDir}/{imageName}" )


def createContainer( args ) :
    """
    Create a container from a template
    """

    containerName   = args.name
    templateName    = args.templatename
    containerDir    = determineContainerDir( args.containerdirectory )
    siteTemplateUrl = args.sitetemplate
    imagesDir       = determineImagesDir( args.imagesdirectory )
    isMesh          = args.flavor == 'mesh'

    if containerName is None or not containerName:
        ubos.logging.fatal( 'Must specify a name for the container with --name' )

    if templateName is None or not templateName:
        ubos.logging.fatal( 'Must specify a name for the template with --templatename' )

    if siteTemplateUrl is None :
        if isMesh:
            siteTemplateUrl = '/usr/share/ubosdev-container/site-templates/mesh-default-site-development-debug.json'

    def cleanup() :
        if 0 == ubos.utils.myexec( f"machinectl show {containerName} > /dev/null 2>&1" ) :
            print( '*** Shutting down container' )
            ubos.utils.myexec( f"sudo machinectl poweroff {containerName} > /dev/null 2>&1" )

    atexit.register( cleanup )

    namedContainerRootDir = determineNamedContainerRootDir( containerDir, containerName )
    namedTemplateRootDir  = determineNamedTemplateRootDir(  imagesDir,    templateName )

    if os.path.exists( namedContainerRootDir ) :
        ubos.logging.fatal( f"*** Cannot create container, container directory exists already: {namedContainerRootDir}" )

    if not os.path.exists( namedTemplateRootDir ) :
        ubos.logging.fatal( f"*** Cannot create container, template directory does not exist: {namedTemplateRootDir}" )

    print( '*** Copying from template' )
    copyRecursively( namedTemplateRootDir, namedContainerRootDir )


    if isMesh :
        print( 'Ensuring container has ubos-mesh packages' )
        temp = tempfile.NamedTemporaryFile( delete=False )
        temp.write( b"[mesh]\nServer = https://depot.ubosfiles.net/$channel/$arch/mesh\n" )
        temp.close()
        ubos.utils.myexec( f"sudo mv {temp.name} {namedContainerRootDir}/etc/pacman.d/repositories.d/mesh" )

        print( 'Opening up default debug ports 7777 and 7778' )
        temp = tempfile.NamedTemporaryFile( delete=False )
        temp.write( b"7777/tcp\n7778/tcp\n" )
        temp.close()
        ubos.utils.myexec( f"sudo mv {temp.name} {namedContainerRootDir}/etc/ubos/open-ports.d/java-debugging" )


    print( '*** Temporarily starting container for updates' )
    cmd = f"systemd-nspawn -n -b -D {namedContainerRootDir} -M {containerName}"
    if siteTemplateUrl is not None and not siteTemplateUrl.startswith( 'http:' ) and not siteTemplateUrl.startswith( 'https:' ) :
        if os.path.exists( siteTemplateUrl ) :
            cmd += f" --bind {siteTemplateUrl}"
        else :
            ubos.logging.warning( 'Site template file does not exist, skipping:', siteTemplateUrl )
            timeTemplateUrl = None
    ubos.utils.myexec( f"sudo {cmd} > /dev/null 2>&1 &" ) # in the background

    # wait until the container is running
    while True :
        time.sleep( 5 )
        if 0 == ubos.utils.myexec( f"sudo systemctl -M {containerName} is-system-running > /dev/null" ) :
            break

    print( '*** Updating container' )
    containerCmd = 'ubos-admin update -v --nokeyrefresh'
    containerCmd += ' && pacman -S --noconfirm ubos-mesh-devtools'
    containerCmd += ' && snapper create-config .'
    containerCmd += ' && snapper create -d after-first-update'
    ubos.utils.myexec( f"sudo machinectl shell {containerName} /bin/bash -c '{containerCmd}'" )

    if isMesh:
        print( '*** Setting PACKAGE_RESOURCES_PARENT_DIR to use assets from the source tree, not package' )
        temp = tempfile.NamedTemporaryFile( delete=False )
        tmp.write(  b"\n" )
        tmp.write(  b"# Take web app assets from the source tree, not the package; makes development faster\n" )
        temp.write( b"PACKAGE_RESOURCES_PARENT_DIR=/home/ubosdev/git/gitlab.com/ubos/ubos-datapalace:/home/ubosdev/git/gitlab.com/ubos/ubos-mesh-underbars-ui:/home/jernst/git/gitlab.com/ubos/ubos-mesh-underbars-ui-experimental:/home/ubosdev/git/gitlab.com/ubos/ubos-mesh\n" )
        temp.close()
        ubos.utils.myexec( f"sudo cat {temp.name} >> {namedContainerRootDir}/etc/diet4j/diet4j-jsvc-defaults.conf" )

    if siteTemplateUrl and len( siteTemplateUrl ) > 0 :
        print( '*** Deploying site to container' )
        containerCmd = f"ubos-admin createsite --from-template {siteTemplateUrl} && snapper create -d after-first-site-deploy"
        ubos.utils.myexec( f"sudo machinectl shell {containerName} /bin/bash -c '{containerCmd}'" )

    # we registered a handler earlier that will shut down the container again


def runContainer( args ) :
    """
    Run a container
    """
    containerName   = args.name
    containerDir    = determineContainerDir( args.containerdirectory )
    siteTemplateUrl = args.sitetemplate
    networkZone     = args.network_zone

    namedContainerRootDir = determineNamedContainerRootDir( containerDir, containerName )

    if not os.path.exists( namedContainerRootDir ) :
        ubos.logging.fatal( 'Container not found:', namedContainerRootDir )

    print( '*** Starting container' )
    cmd = f"systemd-nspawn -n -b -D {namedContainerRootDir} -M {containerName}"
    if networkZone :
        cmd += f" --network-zone {networkZone}"
    cmd += f" --bind $HOME --bind /dev/fuse"
    if siteTemplateUrl is not None and not siteTemplateUrl.startswith( 'http:' ) and not siteTemplateUrl.startswith( 'https:' ) :
        cmd += f" --bind {siteTemplateUrl}"

    ubos.utils.myexec( f"sudo {cmd}" )


def deleteContainer( args ) :
    """
    Delete a container
    """
    containerName   = args.name
    containerDir    = determineContainerDir( args.containerdirectory )

    namedContainerRootDir = determineNamedContainerRootDir( containerDir, containerName )

    if not os.path.exists( namedContainerRootDir ) :
        ubos.logging.fatal( 'Container not found:', namedContainerRootDir )

    deleteSubvol( namedContainerRootDir )

