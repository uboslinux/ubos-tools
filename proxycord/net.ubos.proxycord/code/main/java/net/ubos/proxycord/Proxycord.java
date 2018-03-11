//
// Copyright (C) 2018 and later, Johannes Ernst. All rights reserved. License: see package.
//

package net.ubos.proxycord;

import com.google.gson.Gson;
import com.google.gson.GsonBuilder;
import com.google.gson.JsonArray;
import com.google.gson.JsonObject;
import java.io.FileOutputStream;
import java.io.IOException;
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
     * @param localHost local IP address to bind to
     * @param localPort local port to open
     * @param remoteHost remote host to connect to
     * @param remotePort remote port to connect to
     * @return exit code
     * @throws IOException an I/O problem occurred
     * @throws InterruptedException should not happen
     */
    public int run(
            String    localHost,
            int       localPort,
            String    remoteHost,
            int       remotePort )
        throws
            IOException,
            InterruptedException
    {
        theHandler = new HttpConnectionHandler(
                this,
                localHost,
                localPort,
                remoteHost,
                remotePort );

        theConnectionAcceptThread = new Thread( theHandler );
        theConnectionAcceptThread.start();

        System.out.println(
                "Proxying to http://"
                + remoteHost
                + ":"
                + remotePort
                + "/. You can now connect to http://"
                + ( "0.0.0.0".equals( localHost ) ? "localhost" : localHost )
                + ":"
                + localPort
                + "/" );

        CommandInterpreter interpreter = CommandInterpreter.create( this );
        interpreter.run();

        theHandler.setInactive();
        theConnectionAcceptThread.interrupt();

        theConnectionAcceptThread.join();
        
        return 0;
    }
    
    /**
     * Obtain the steps recorded so far.
     * 
     * @return the Steps
     */
    public Step [] getSteps()
    {
        return getSteps( Integer.MAX_VALUE );
    }

    /**
     * Obtain the steps recorded so far, but no more than n
     * 
     * @param n maximum number of steps to return
     * @return the Steps
     */
    public Step [] getSteps(
            int n )
    {
        if( n >= theSteps.size() ) {
            return theSteps.toArray( new Step[ theSteps.size() ] );
        } else {
            Step [] ret = new Step[ n ];
            System.arraycopy( theSteps.toArray(), theSteps.size()-n, ret, 0, n );
            
            return ret;
        }
    }

    /**
     * Output the recorded steps.
     * 
     * @param out the name of the output file, or null if stdout
     * @throws IOException if an i/o problem occurred
     */
    public void writeJsonOutput(
            String out )
        throws
            IOException
    {
        Gson       gson      = new GsonBuilder().setPrettyPrinting().disableHtmlEscaping().create();
        JsonObject jsonRet   = new JsonObject();
        JsonArray  jsonSteps = new JsonArray();
        jsonRet.add( "steps", jsonSteps );
        
        for( Step s : theSteps ) {
            jsonSteps.add( s.asJson() );
        }
        
        String jsonString = gson.toJson( jsonRet );

        PrintStream outStream;
        if( out != null ) {
            outStream = new PrintStream( new FileOutputStream( out ), false, "UTF-8" );
        } else {
            outStream = System.out;
        }
        outStream.print( jsonString );
        
        outStream.flush();
        outStream.close();
    }

    /**
     * Finish and clean up.
     */
    public void end()
    {
        if( theHandler != null ) {
            theHandler.setInactive(); // do again in case an exception occurred earlier
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
     * A new Step needs to be logged.
     * 
     * @param step the Step to be logged
     */
    public void logStep(
            Step step )
    {
        theSteps.add( step );
    }

    /**
     * Drop the n most recent steps from the log.
     * 
     * @param n the number of Steps to drop
     */
    public void dropMostRecentSteps(
            int n )
    {
        for( int i = theSteps.size()-1 ; n > 0 && i >= 0 ; --i, --n ) {
            theSteps.remove( i );
        }
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
     * The Steps recorded so far.
     */
    protected List<Step> theSteps = new ArrayList<>();

    /**
     * Worker threads.
     */
    protected final ExecutorService theWorkerThreads = Executors.newFixedThreadPool( 20 );
}
