//
// Copyright (C) 2018 and later, Johannes Ernst. All rights reserved. License: see package.
//

package net.ubos.proxycord;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.io.PrintStream;
import java.text.DateFormat;
import java.text.SimpleDateFormat;
import java.util.Date;
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
                lineWords = inReader.readLine().trim().split( "\\s+" );

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
     * Print steps.
     * 
     * @param steps the steps to print
     */
    protected void printSteps(
            Step [] steps )
    {
        PrintStream o = System.out;

        for( int i=0 ; i<steps.length ; ++i ) {
            o.println( String.format(
                    "%3d (%s): %s",
                    i-steps.length,
                    DATE_FORMAT.format( new Date( steps[i].getTimeCreated() )),
                    steps[i].toString() ));
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
                "mark",
                ( CommandInterpreter interpreter, String ... args ) -> {
                    MarkStep step;
                    if( args.length == 2 ) {
                        step = MarkStep.create( args[1] );
                    } else {
                        step = MarkStep.create();
                    }
                    interpreter.theApp.logStep( step );
                    return true;
                } );
                
        theConsoleCommands.put(
                "drop",
                ( CommandInterpreter interpreter, String ... args ) -> {
                    int n = 1;
                    if( args.length == 2 ) {
                        n = Integer.parseInt( args[1] );
                    }
                    interpreter.theApp.dropMostRecentSteps( n );
                    return true;
                } );

        theConsoleCommands.put(
                "list",
                ( CommandInterpreter interpreter, String ... args ) -> {
                    Step [] steps;
                    if( args.length == 2 ) {
                        steps = interpreter.theApp.getSteps( Integer.parseInt( args[1] ));
                    } else {
                        steps = interpreter.theApp.getSteps();
                    }
                    interpreter.printSteps( steps );
                    return true;
                } );

        theConsoleCommands.put(
                "quit",
                ( CommandInterpreter interpreter, String ... args ) -> {
                    interpreter.consoleDone = true;
                    return true;
                } );

        theConsoleCommands.put(
                "help",
                ( CommandInterpreter interpreter, String ... args ) -> {
                    System.out.println( "Available commands are: " + String.join( ", ", theConsoleCommands.keySet()) );
                    return true;
                });
    }

    /**
     * Format for printing time stamps.
     */
    protected static final DateFormat DATE_FORMAT
            = new SimpleDateFormat( "yyyy/MM/dd-HH:mm:ss.SSS" );

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
