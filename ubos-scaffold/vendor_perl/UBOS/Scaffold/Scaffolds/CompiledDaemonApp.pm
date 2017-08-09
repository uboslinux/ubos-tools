#!/usr/bin/perl
#
# A scaffold for app packages that need to start a compiled background daemon on UBOS.
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

package UBOS::Scaffold::Scaffolds::CompiledDaemonApp;

use UBOS::Scaffold::ScaffoldUtils;

##
# Declare which parameters should be provided for this scaffold.
sub pars {
    return [
        {
            'name'        => 'name',
            'description' => <<DESC
Name of the package
DESC
        },
        {
            'name'        => 'developer',
            'description' => <<DESC
URL of the developer, such as your company URL
DESC
        },
        {
            'name'        => 'url',
            'description' => <<DESC
URL of the package, such as a product information page on your company website
DESC
        },
        {
            'name'        => 'description',
            'description' => <<DESC
One-line description of your package, which will be shown to the user when
they ask pacman about your package (-i flag to pacman)
DESC
        },
        {
            'name'        => 'license',
            'description' => <<DESC
License of your package, such as GPL, Apache, or Proprietary
DESC
        }
    ];
}

##
# Do the generation
# $pars: the parameters to use
# $dir: the output directory
sub generate {
    my $pars = shift;
    my $dir  = shift;

    my $packageName = $pars->{name};
    unless( $dir ) {
        $dir = $packageName;
        UBOS::Scaffold::ScaffoldUtils::ensurePackageDirectory( $dir );
    }

    my $pkgBuild = <<END;
#
# PKGBUILD for package $pars->{name}, generated by ubos-scaffold.
# For the syntax of this file, please refer to the description on the
# Arch Linux wiki here: https://wiki.archlinux.org/index.php/PKGBUILD
#

developer='$pars->{developer}'
url='$pars->{url}'
maintainer='\${developer}'
pkgname='$packageName'
pkgver=0.1
pkgrel=1
pkgdesc='$pars->{description}'
arch=('any')
license=('$pars->{license}')
depends=(
    # Insert your UBOS package dependencies here as a bash array, like this:
    #     'perl-archive-zip' 'ubos-perl-utils'
)
backup=(
    # List any config files your package uses that should NOT be overridden
    # upon the next package update if the user has modified them.
)
source=(
    # Insert URLs to the source(s) of your code here, usually one or more tar files
    # or such, like this:
    #     "https://releases.mattermost.com/\${pkgver}/mattermost-team-\${pkgver}-linux-amd64.tar.gz"
)
sha512sums=(
    # List the checksums for one source at a time, same sequence as the in
    # the sources array, like this:
    #     '2391c2564d6cccbb3c925c3cd7c4d5fde6de144cc7960ec43cc903f222352eaa312f58925b32e6f7dd88338e9b2efee0d5e50c902f7aeb3bc5dbdebc3b70b379'
)

# If your package requires compilation, uncomment this build() function
# and insert your build code.
# build () {
#     echo -n 'Build starts in directory:'
#     pwd
# }

package() {
# Manifest
    mkdir -p \${pkgdir}/var/lib/ubos/manifests
    install -m0644 \${startdir}/ubos-manifest.json \${pkgdir}/var/lib/ubos/manifests/\${pkgname}.json

# Icons
    mkdir -p \${pkgdir}/srv/http/_appicons/\${pkgname}
    install -m644 \${startdir}/appicons/{72x72,144x144}.png \${pkgdir}/srv/http/_appicons/\${pkgname}/

# Place for instance-specific config files
    mkdir -p \${pkgdir}/etc/\${pkgname}

# Data
    mkdir -p \${pkgdir}/var/lib/\${pkgname}

# Code
    mkdir -p \${pkgdir}/usr/share/\${pkgname}
    # install your code here, such as:
    #     install -m0755 \${startdir}/my-\${pkgname}-script \${pkgdir}/usr/bin/

# Webserver configuration
    mkdir -p \${pkgdir}/usr/share/\${pkgname}/tmpl
    install -m644 \${startdir}/tmpl/htaccess.tmpl \${pkgdir}/usr/share/\${pkgname}/tmpl/

# Systemd
    mkdir -p \${pkgdir}/usr/lib/systemd/system
    cp \${startdir}/systemd/*.service \${pkgdir}/usr/lib/systemd/system/
}
END

    my $manifest = <<END;
{
    "type" : "app",

    "roles" : {
        "apache2" : {
            "defaultcontext" : "/$pars->{name}",
            "apache2modules" : [
                "proxy",
                "proxy_http",
                "headers",
                "proxy_wstunnel",
                "rewrite"
            ],
            "appconfigitems" : [
                {
                    "type"         : "tcpport",
                    "name"         : "mainport"
                },
                {
                    "type"  : "directory",
                    "name"  : "\${appconfig.datadir}"
                },
                {
                    "type"  : "directory",
                    "name"  : "\${appconfig.datadir}/data",
                    "retentionpolicy" : "keep",
                    "retentionbucket" : "datadir",
                    "dirpermissions"  : "0750",
                    "filepermissions" : "0640",
                    "uname"       : "\${apache2.uname}",
                    "gname"       : "\${apache2.gname}"
                },
                {
                    "type"         : "file",
                    "name"         : "\${appconfig.apache2.appconfigfragmentfile}",
                    "template"     : "tmpl/htaccess.tmpl",
                    "templatelang" : "varsubst"
                },
                {
                    "type"         : "file",
                    "name"         : "/etc/$pars->{name}/\${appconfig.appconfigid}.json",
                    "template"     : "tmpl/config.json.tmpl",
                    "templatelang" : "varsubst"
                },
                {
                    "type"         : "systemd-service",
                    "name"         : "$pars->{name}\@\${appconfig.appconfigid}",
                },
            ]
        },
        "mysql" : {
            "appconfigitems" : [
                {
                    "type"       : "database",
                    "name"       : "maindb",
                    "retentionpolicy"  : "keep",
                    "retentionbucket"  : "maindb",
                    "privileges" : "all privileges"
                }
            ]
        }
    }
}
END

    my $htAccessTmpl = <<END;
<Directory "\${appconfig.apache2.dir}">
  <IfModule php7_module>
    php_admin_value open_basedir        \${appconfig.apache2.dir}:/tmp/:/usr/share/:/dev:\${appconfig.datadir}
    php_value       post_max_size       1G
    php_value       upload_max_filesize 1G
  </IfModule>
</Directory>
<IfModule mod_headers.c>
  Header always set Strict-Transport-Security "max-age=15768000; includeSubDomains; preload"
</IfModule>

ProxyPass /robots.txt !
ProxyPass /favicon.ico !
ProxyPass /sitemap.xml !
ProxyPass /.well-known !
ProxyPass /_common !
ProxyPass /_errors !

ProxyPass \${appconfig.contextorslash} http://127.0.0.1:\${appconfig.tcpport.mainport}\${appconfig.contextorslash}
ProxyPassReverse \${appconfig.contextorslash} http://127.0.0.1:\${appconfig.tcpport.mainport}\${appconfig.contextorslash}
ProxyPassReverseCookieDomain 127.0.0.1 \${site.hostname}

ProxyPreserveHost On

RequestHeader set X-Forwarded-Proto "\${site.protocol}"
RequestHeader set X-Frame-Options SAMEORIGIN

END

    my $configTmpl = <<END;
{
    "some" : "thing"
}
END

    my $dotService = <<END;
\[Unit]
Description=$pars->{description}

[Service]
WorkingDirectory=/usr/share/$pars->{name}
ExecStart=/usr/share/$pars->{name}/bin/$pars->{name}d --config=/etc/$pars->{name}/%I.json
Restart=always

[Install]
WantedBy=multi-user.target
END

    UBOS::Utils::mkdir( "$dir/appicons" );
    UBOS::Utils::mkdir( "$dir/systemd" );
    UBOS::Utils::mkdir( "$dir/tmpl" );

    UBOS::Utils::saveFile( "$dir/PKGBUILD",                        $pkgBuild,     0644 );
    UBOS::Utils::saveFile( "$dir/ubos-manifest.json",              $manifest,     0644 );

    UBOS::Scaffold::ScaffoldUtils::copyIcons( "$dir/appicons" );

    UBOS::Utils::saveFile( "$dir/systemd/$pars->{name}\@.service", $dotService,   0644 );
    UBOS::Utils::saveFile( "$dir/tmpl/htaccess.tmpl",              $htAccessTmpl, 0644 );
    UBOS::Utils::saveFile( "$dir/tmpl/config.json.tmpl",           $configTmpl,   0644 );

}

##
# Return help text.
# return: help text
sub help {
    return 'a compiled daemon is run that speaks HTTP at a non-standard port';
}

1;
