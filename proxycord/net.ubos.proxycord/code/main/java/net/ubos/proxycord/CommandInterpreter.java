//
// Copyright (C) 2018 and later, Johannes Ernst. All rights reserved. License: see package.
//

package net.ubos.proxycord;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.util.HashMap;
import java.util.Map;

/**
 * Knows how to interpret commands entered on the keyboard.
 */
public class CommandInterpreter
{
    /**
     * Factory method.
     *
     * @param app the application
     * @return the created instance
     */
    public static CommandInterpreter create(
            Proxycord app )
    {
        return new CommandInterpreter( app );
    }

    /**
     * Private constructor, use factory method.
     * 
     * @param app the application
     */
    protected CommandInterpreter(
            Proxycord app )
    {
        theApp = app;
    }
    
    /**
     * Run the interpreter. Returns when the user wanted to quit.
     */
    public void run()
    {
        BufferedReader inReader = new BufferedReader( new InputStreamReader( System.in ));
        
        while( !consoleDone ) {
            System.out.print( "Enter a command> " );
            System.out.flush();

            String [] lineWords;
            try {
                lineWords = inReader.readLine().trim().split( "\\s+ " );

            } catch( IOException ex ) {
                ex.printStackTrace();
                continue;
            }

            Command cmd = theConsoleCommands.get( lineWords[0] );
            if( cmd == null ) {
                cmd = theConsoleCommands.get( "help" );
            }
            cmd.run( this, lineWords );
        }
    }
    
    /**
     * The application.
     */
    protected Proxycord theApp;

    /**
     * Flag that indicates whether the main console loop should continue to run.
     */
    protected boolean consoleDone = false;

    /**
     * The available console commands.
     */
    protected static final Map<String,Command> theConsoleCommands = new HashMap<>();
    static {
        theConsoleCommands.put(
                "help",
                ( CommandInterpreter interpreter, String ... args ) -> {
                    System.out.println( "Available commands are: " + String.join( ", ", theConsoleCommands.keySet()) );
                    return true;
                });
        theConsoleCommands.put(
                "quit",
                ( CommandInterpreter interpreter, String ... args ) -> {
                    interpreter.consoleDone = true;
                    return true;
                } );                
    }

    /**
     * A command that can be executed from the terminal.
     */
    public static interface Command
    {
        /**
         * Run the command.
         * 
         * @param interpreter the interpreter for the command
         * @param args command-line arguments, with args[0] being the name of the command
         * @return true if the command was successful
         */
        public boolean run(
                CommandInterpreter interpreter,
                String ...         args );
    }
}
