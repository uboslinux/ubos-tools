//
// Copyright (C) 2018 and later, Johannes Ernst. All rights reserved. License: see package.
//

package net.ubos.proxycord;

import com.google.gson.JsonArray;
import com.google.gson.JsonElement;
import com.google.gson.JsonObject;
import com.google.gson.JsonPrimitive;
import java.nio.charset.Charset;
import java.util.Base64;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * A recorded Step that is a completed HTTP exchange.
 */
public class HttpRequestResponseStep
    extends
        Step
{
    /**
     * Constructor.
     * 
     * @param request the received request
     * @param response the received response
     */
    public HttpRequestResponseStep(
            HttpRequest  request,
            HttpResponse response )
    {
        theRequest  = request;
        theResponse = response;
    }

    @Override
    public JsonElement asJson()
    {
        JsonObject jsonRequest  = new JsonObject();
        jsonRequest.add( "verb",    new JsonPrimitive( theRequest.getVerb() ));
        jsonRequest.add( "path",    new JsonPrimitive( theRequest.getPath() ));
        jsonRequest.add( "version", new JsonPrimitive( theRequest.getVersion() ));
        
        JsonObject jsonRequestHeaders = new JsonObject();
        Map<String,String[]> requestHeaders = theRequest.getHeaders();
        for( Map.Entry<String,String[]> entry : requestHeaders.entrySet() ) {
            JsonArray jsonValues = new JsonArray();
            for( String value : entry.getValue() ) {
                jsonValues.add( value );
            }
            jsonRequestHeaders.add( entry.getKey(), jsonValues );
        }
        jsonRequest.add( "headers", jsonRequestHeaders );

        byte [] requestContent = theRequest.getContent();
        if( requestContent != null ) {
            addContentToJson( jsonRequest, requestContent, requestHeaders.get( HttpMessage.HTTP_CONTENT_TYPE_HEADER ) );
        }
        
        JsonObject jsonResponse = new JsonObject();
        jsonResponse.add( "status",  new JsonPrimitive( theResponse.getStatus() ));
        jsonResponse.add( "version", new JsonPrimitive( theResponse.getVersion() ));
        
        JsonObject jsonResponseHeaders = new JsonObject();
        Map<String,String[]> responseHeaders = theResponse.getHeaders();
        for( Map.Entry<String,String[]> entry : responseHeaders.entrySet() ) {
            JsonArray jsonValues = new JsonArray();
            for( String value : entry.getValue() ) {
                jsonValues.add( value );
            }
            jsonResponseHeaders.add( entry.getKey(), jsonValues );
        }
        jsonResponse.add( "headers", jsonResponseHeaders );

        byte [] responseContent = theResponse.getContent();
        if( responseContent != null ) {
            addContentToJson( jsonResponse, responseContent, responseHeaders.get( HttpMessage.HTTP_CONTENT_TYPE_HEADER ) );
        }

        JsonObject jsonRet = new JsonObject();
        jsonRet.add( "type",     new JsonPrimitive( "HttpRequestResponse" ));
        jsonRet.add( "request",  jsonRequest );
        jsonRet.add( "response", jsonResponse );
        return jsonRet;
    }
    
    /**
     * Factored out helper to insert content into the JSON.
     * 
     * @param obj the JSON Object to add the content to
     * @param data the content
     * @param contentType the value(s) of the HTTP Content-Type header
     */
    protected void addContentToJson(
            JsonObject obj,
            byte []    data,
            String []  contentType )
    {
        obj.add( "rawcontentlength", new JsonPrimitive( data.length ));
        obj.add( "rawcontentbase64", new JsonPrimitive( Base64.getEncoder().encodeToString( data ) ));

        if( contentType != null && contentType.length > 0 ) {
            String [] split = contentType[0].split( ";", 2 );
            if( split.length == 2 ) {
                String mime  = split[0];
                if( TEXT_MIME_TYPES.contains( mime )) {
                    Matcher m = CHARSET_PATTERN.matcher( split[1] );
                    if( m.find() ) {
                        String charsetName = m.group( 1 );
                        
                        Charset charset = Charset.forName( charsetName );
                        
                        String dataAsString = new String( data, charset );
                        
                        obj.add( "contentastext", new JsonPrimitive( dataAsString ));
                    }
                }
            }
        }
    }

    /**
     * Convert to String, for output on the console.
     * 
     * @return as String
     */
    @Override
    public String toString()
    {
        byte [] responseContent = theResponse.getContent();

        return    theRequest.getVerb()
                + " "
                + theRequest.getPath()
                + " => status "
                + theResponse.getStatus()
                + ", "
                + ( responseContent != null ? responseContent.length : "0" )
                + " bytes";
    }

    /**
     * The received request.
     */
    protected HttpRequest theRequest;
    
    /**
     * The received response.
     */
    protected HttpResponse theResponse;

    /**
     * Set of known text mime types which can be inlined into JSON without
     * encoding.
     */
    protected static final Set<String> TEXT_MIME_TYPES = new HashSet<>();
    static {
        TEXT_MIME_TYPES.add( "text/css" );
        TEXT_MIME_TYPES.add( "text/html" );
        TEXT_MIME_TYPES.add( "text/csv" );
        TEXT_MIME_TYPES.add( "text/plain" );

        TEXT_MIME_TYPES.add( "application/javascript" );
        TEXT_MIME_TYPES.add( "application/json" );
        TEXT_MIME_TYPES.add( "application/x-www-form-urlencoded" );
        TEXT_MIME_TYPES.add( "application/xml" );
        TEXT_MIME_TYPES.add( "application/sql" );
        TEXT_MIME_TYPES.add( "application/graphql" );
        TEXT_MIME_TYPES.add( "application/ld+json" );
    }
    
    /**
     * Regex matching the charset parameter to a mime type
     */
    protected static final Pattern CHARSET_PATTERN = Pattern.compile( "charset=(\\S+)");
}
