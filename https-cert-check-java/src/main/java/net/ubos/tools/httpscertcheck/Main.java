/*
 * Very simple utility to access a URL, and print any exceptions that might occur,
 * such as SSL/TLS exceptions.
 */
package net.ubos.tools.httpscertcheck;

import java.io.IOException;
import java.io.InputStream;
import java.net.URL;
import java.net.URLConnection;

/**
 *
 */
public class Main
{
    public static void main(
            String [] args )
        throws
            Exception
    {
        if( args.length != 1 ) {
            synopsis();
            return;
        }
        try {
            run( new URL( args[0] ));

        } catch( Throwable t ) {

            System.err.println( "Exceptions:" );
            while( t != null ) {
                System.err.println( t.getMessage());

                t = t.getCause();
            }
        }
    }

    static void run(
            URL url )
        throws
            IOException
    {
        URLConnection conn = url.openConnection();
        InputStream   in   = conn.getInputStream();

        byte [] buf  = new byte[ 16384 ];
        int     count = 0;
        int     read;
        while( ( read = in.read( buf )) > 0 ) {
            count += read;
        }
        in.close();

        System.out.printf( "Successfully read %d bytes from %s\n", count, url.toExternalForm() );
    }

    static void synopsis()
    {
        System.err.println( "Arguments: <url to access>" );
    }

}
