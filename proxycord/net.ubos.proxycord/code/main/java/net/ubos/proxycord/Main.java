//
// Copyright (C) 2018 and later, Johannes Ernst. All rights reserved. License: see package.
//

package net.ubos.proxycord;

import com.beust.jcommander.JCommander;
import com.beust.jcommander.ParameterException;

/**
 * Main program
 */
public class Main
{
    /**
     * Main program.
     *
     * @param argv the command-line arguments
     */
    public static void main(
            String [] argv )
    {
        Args args = parseCommandLine( argv );
        
        Proxycord app = Proxycord.create();
        int status = 1;
        try {
            status = app.run( args );

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
