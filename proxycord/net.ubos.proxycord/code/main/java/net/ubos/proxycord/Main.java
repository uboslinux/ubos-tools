//
// Copyright (C) 2018 and later, Johannes Ernst. All rights reserved. License: see package.
//

package net.ubos.proxycord;

import com.beust.jcommander.JCommander;
import com.beust.jcommander.ParameterException;
import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.util.logging.LogManager;
import java.util.logging.Logger;

/**
 * Main program
 */
public class Main
{
    private final static Logger LOG = Logger.getLogger( Main.class.getName() );

    /**
     * Main program.
     *
     * @param argv the command-line arguments
     */
    public static void main(
            String [] argv )
    {
        Args args = parseCommandLine( argv );

        if( args.logConfig != null ) {
            File logConfig = new File( args.logConfig );
            if( logConfig.canRead() ) {
                try {
                    LogManager.getLogManager().readConfiguration( new FileInputStream( logConfig ));
                } catch( IOException ex ) {
                    LOG.severe( ex.getMessage() );
                    System.exit( 1 );
                }
            }
        }
                
        Proxycord app = Proxycord.create();

        int status = 1;
        try {
            status = app.run(
                    args.localHost,
                    args.localPort,
                    args.remoteHost,
                    args.remotePort );

            if( args.out != null ) {
                app.writeJsonOutput( args.out );
            }

        } catch( Throwable t ) {
            t.printStackTrace();

        } finally {
            app.end();
        }
        System.exit( status );
    }
    
    /**
     * Parse the command-line arguments or quit.
     * 
     * @param argv the command-line arguments
     * @return the parsed arguments
     */
    protected static Args parseCommandLine(
            String [] argv )
    {
        Args args = new Args();
        JCommander commander = JCommander.newBuilder().addObject( args ).build();

        try {
            commander.parse( argv );
        } catch( ParameterException ex ) {
            commander.usage( ex.getMessage() );
            System.exit( 0 );
        }
        
        if( args.help ) {
            commander.usage();
            System.exit( 0 );
        }
        if( args.remoteHost == null ) {
            commander.usage();
            System.exit( 0 );
        }
        
        return args;
    }
}
