/**
 * This file is part of pacmanpkgmavenplugin.
 * 
 * (C) 2012-2016 Indie Computing Corp.
 * 
 * pacmanpkgmavenplugin is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 * 
 * pacmanpkgmavenplugin is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with pacmanpkgmavenplugin.  If not, see <http://www.gnu.org/licenses/>.
 * 
 */

package net.ubos.tools.pacmanpkgmavenplugin;

import java.io.File;
import java.io.IOException;
import java.io.PrintWriter;
import java.util.ArrayList;
import java.util.Set;
import org.apache.maven.artifact.Artifact;
import org.apache.maven.plugin.AbstractMojo;
import org.apache.maven.plugin.MojoExecutionException;
import org.apache.maven.plugins.annotations.Mojo;
import org.apache.maven.plugins.annotations.Parameter;
import org.apache.maven.project.MavenProject;

/**
 * A maven plugin that generates PKGBUILD files suitable for pacman.
 */
@Mojo( name = "pacmanpkg")
public class PacmanPkgMavenPlugin
    extends
        AbstractMojo
{

    /**
     * {@inheritDoc}
     * 
     * @throws MojoExecutionException
     */
    @Override
    public void execute()
        throws
            MojoExecutionException
    {
        MavenProject project   = (MavenProject) getPluginContext().get( "project" );
        String       packaging = project.getPackaging();
        
        if( !"jar".equals( packaging ) && !"ear".equals( packaging ) && !"war".equals( packaging )) {
            return;
        }

        getLog().info( "Generating PKGBUILD @ " + project.getName() );

        // pull stuff out of MavenProject
        String        artifactId   = project.getArtifactId();
        String        version      = project.getVersion();
        String        url          = project.getUrl();
        String        description  = project.getDescription();
        Set<Artifact> dependencies = project.getDependencyArtifacts();
        File          artifactFile = project.getArtifact().getFile();

        if( artifactFile == null || !artifactFile.exists() ) {
            throw new MojoExecutionException(
                    "pacmanpkg must be executed as part of a build, not standalone,"
                    + " otherwise it can't find the main JAR file" );
        }
        // translate to PKGBUILD fields
        String pkgname = artifactId;
        String pkgver  = version.replaceAll( "-SNAPSHOT", "a" ); // alpha
        String pkgdesc = "A Java package available on UBOS";
        if( description != null ) {
            if( description.length() > 64 ) {
                pkgdesc = description.substring( 0, 64 ) + "...";
            } else {
                pkgdesc = description;
            }
        }

        ArrayList<String> depends = new ArrayList<>( dependencies.size() );
        for( Artifact a : dependencies ) {
            if( !"test".equals( a.getScope())) {
                depends.add( a.getArtifactId() );
            }
        }
        // write to PKGBUILD
        try {
            File        baseDir  = project.getBasedir();
            File        pkgBuild = new File( baseDir, "target/PKGBUILD" );
            PrintWriter out      = new PrintWriter( pkgBuild );

            getLog().debug( "Writing PKGBUILD to " + pkgBuild.getAbsolutePath() );

            out.println( "#" );
            out.println( " * Automatically generated by pacman-pkg-maven-plugin; do not modify." );
            out.println( "#" );

            out.println();

            out.println( "pkgname="  + pkgname );
            out.println( "pkgver="   + pkgver );
            out.println( "pkgrel="   + pkgrel );
            out.println( "pkgdesc='" + pkgdesc + "'" );
            out.println( "arch=('any')" );
            out.println( "url='"  + url + "'" );
            out.println( "license=('"  + license + "')" );

            out.print( "depends=(" );
            String sep = "";
            for( String d : depends ) {
                out.print( sep );
                sep = ",";
                out.print( "'" );
                out.print( d );
                out.print( "'" );
            }
            out.println( ")" );

            out.println();

            out.println( "package() (" );
            out.println( "   mkdir -p ${pkgdir}/usr/share/java" );
            out.println( "   install -m644 ${startdir}/" + artifactFile.getName() + " ${pkgdir}/usr/share/java/" );
            out.println( ")" );

            out.close();

        } catch( IOException ex ) {
            throw new MojoExecutionException( "Failed to write target/PKGBUILD", ex );
        }
    }

    /**
     * Allow to set PKGBUILD pkgrel, with default.
     */
    @Parameter
    private Integer pkgrel = 1;
    
    /**
     * Allow to set PKGBUILD license, with default.
     */
    @Parameter
    private String license = "custom";
}