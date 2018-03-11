//
// Copyright (C) 2018 and later, Johannes Ernst. All rights reserved. License: see package.
//

package net.ubos.webapptest.record;

import com.beust.jcommander.JCommander;
import com.beust.jcommander.ParameterException;
import com.google.gson.Gson;
import com.google.gson.GsonBuilder;
import com.google.gson.JsonArray;
import com.google.gson.JsonObject;
import java.io.BufferedReader;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStreamReader;
import java.io.PrintStream;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;


/**
 *
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
        
        int status = 1;
        try {
            status = main0( args );

        } catch( Throwable t ) {
            t.printStackTrace();

        } finally {
            if( theHandler != null ) {
                theHandler.setInactive();
            }
            theWorkerThreads.shutdownNow();
        }
        System.exit( status );
    }
    
    /**
     * Almost main program.
     * 
     * @param args the parsed command-line arguments
     * @return exit code
     */
    protected static int main0(
            Args args )
        throws
            IOException,
            InterruptedException
    {
        theHandler = new HttpConnectionHandler(
                args.localHost,
                args.localPort,
                args.remoteHost,
                args.remotePort );

        theConnectionAcceptThread = new Thread( theHandler );
        theConnectionAcceptThread.start();

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

            Runnable r = theConsoleCommands.get( lineWords[0] );
            if( r == null ) {
                r = theConsoleCommands.get( "help" );
            }
            r.run();
        }

        theHandler.setInactive();
        theConnectionAcceptThread.interrupt();

        theConnectionAcceptThread.join();
        
        Gson       gson      = new GsonBuilder().setPrettyPrinting().disableHtmlEscaping().create();
        JsonObject jsonRet   = new JsonObject();
        JsonArray  jsonSteps = new JsonArray();
        jsonRet.add( "steps", jsonSteps );
        
        for( Step s : theSteps ) {
            jsonSteps.add( s.asJson() );
        }
        
        String jsonString = gson.toJson( jsonRet );

        PrintStream outStream;
        if( args.out != null ) {
            outStream = new PrintStream( new FileOutputStream( args.out ), false, "UTF-8" );
        } else {
            outStream = System.out;
        }
        outStream.print( jsonString );
        
        outStream.flush();
        outStream.close();
        
        return 0;
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
    
    /**
     * A full request-response pair has been found.
     * 
     * @param request the found request
     * @param response the found response
     */
    public static void logExchange(
            HttpRequest  request,
            HttpResponse response )
    {
        theSteps.add( new HttpRequestResponseStep( request, response ));
    }

    /**
     * The Thread that accepts incoming connections.
     */
    protected static Thread theConnectionAcceptThread;
    
    /**
     * Handles an incoming connection.
     */
    protected static HttpConnectionHandler theHandler;
    
    /**
     * Flag that indicates whether the main console loop should continue to run.
     */
    protected static boolean consoleDone = false;

    /**
     * The Steps recorded so far.
     */
    protected static List<Step> theSteps = new ArrayList<>();

    /**
     * The available console commands.
     */
    protected static final Map<String,Runnable> theConsoleCommands = new HashMap<>();
    static {
        theConsoleCommands.put(
                "help",
                () -> System.out.println( "Available commands are: " + String.join( ", ", theConsoleCommands.keySet()) ));
        theConsoleCommands.put(
                "quit",
                () -> consoleDone = true );                
    }

    /**
     * Worker threads.
     */
    public static final ExecutorService theWorkerThreads = Executors.newFixedThreadPool( 20 );
}
