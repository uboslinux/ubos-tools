//
// Copyright (C) 2018 and later, Johannes Ernst. All rights reserved. License: see package.
//

package net.ubos.proxycord;

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
 * Represents the application.
 */
public class Proxycord
{
    /**
     * Factory method.
     *
     * @return the created instance
     */
    public static Proxycord create()
    {
        return new Proxycord();
    }

    /**
     * Private constructor, use factory method.
     */
    protected Proxycord()
    {
    }

    /**
     * Main functionality without exception handling and cleanup
     * 
     * @param args the parsed command-line arguments
     * @return exit code
     * @throws IOException an I/O problem occurred
     * @throws InterruptedException should not happen
     */
    public int run(
            Args args )
        throws
            IOException,
            InterruptedException
    {
        theHandler = new HttpConnectionHandler(
                this,
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

            Command cmd = theConsoleCommands.get( lineWords[0] );
            if( cmd == null ) {
                cmd = theConsoleCommands.get( "help" );
            }
            cmd.run( this, lineWords );
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
     * Finish and clean up.
     */
    public void end()
    {
        if( theHandler != null ) {
            theHandler.setInactive();
        }
        theWorkerThreads.shutdownNow();
    }

    /**
     * There is a new task that needs to be run.
     * 
     * @param r the Runnable
     */
    public void submitTask(
            Runnable r )
    {
        theWorkerThreads.submit( r );
    }

    /**
     * A full request-response pair has been found.
     * 
     * @param request the found request
     * @param response the found response
     */
    public void logExchange(
            HttpRequest  request,
            HttpResponse response )
    {
        theSteps.add( new HttpRequestResponseStep( request, response ));
    }

    /**
     * The Thread that accepts incoming connections.
     */
    protected Thread theConnectionAcceptThread;
    
    /**
     * Handles an incoming connection.
     */
    protected HttpConnectionHandler theHandler;
    
    /**
     * Flag that indicates whether the main console loop should continue to run.
     */
    protected boolean consoleDone = false;

    /**
     * The Steps recorded so far.
     */
    protected List<Step> theSteps = new ArrayList<>();

    /**
     * Worker threads.
     */
    protected final ExecutorService theWorkerThreads = Executors.newFixedThreadPool( 20 );

    /**
     * The available console commands.
     */
    protected static final Map<String,Command> theConsoleCommands = new HashMap<>();
    static {
        theConsoleCommands.put(
                "help",
                ( Proxycord app, String ... args ) -> {
                    System.out.println( "Available commands are: " + String.join( ", ", theConsoleCommands.keySet()) );
                    return true;
                });
        theConsoleCommands.put(
                "quit",
                ( Proxycord app, String ... args ) -> {
                    app.consoleDone = true;
                    return true;
                } );                
    }
}
