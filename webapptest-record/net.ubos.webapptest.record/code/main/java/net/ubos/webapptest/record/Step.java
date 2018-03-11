//
// Copyright (C) 1998 and later, Johannes Ernst. All rights reserved. License: see package.
//

package net.ubos.webapptest.record;

import com.google.gson.JsonElement;

/**
 *
 */
public abstract class Step
{
    /**
     * Private constructor, use factory method.
     */
    protected Step()
    {
    }
    
    /**
     * Convert to JSON.
     * 
     * @return JSON object
     */
    public abstract JsonElement asJson();
    
    /**
     * Creation time of the step.
     */
    protected long theTimeCreated = System.currentTimeMillis();
}
