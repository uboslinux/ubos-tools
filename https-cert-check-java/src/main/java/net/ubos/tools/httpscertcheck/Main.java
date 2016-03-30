/*
 * To change this license header, choose License Headers in Project Properties.
 * To change this template file, choose Tools | Templates
 * and open the template in the editor.
 */
package net.ubos.tools.httpscertcheck;

import java.io.InputStream;
import java.net.URL;
import java.net.URLConnection;


/**
 *
 * @author jernst
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
        URL           url  = new URL( args[0] );
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
