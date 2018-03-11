//
// Copyright (C) 2018 and later, Johannes Ernst. All rights reserved. License: see package.
//

package net.ubos.proxycord;

import com.google.gson.JsonElement;

/**
 * A recorded step.
 */
public abstract class Step
{
    /**
     * Convert to JSON.
     * 
     * @return JSON object
     */
    public abstract JsonElement asJson();

    /**
     * Obtain the time this step was created.
     * 
     * @return the time, in System.currentTimeMillis() format
     */
    public final long getTimeCreated()
    {
        return theTimeCreated;
    }

    /**
     * Creation time of the step.
     */
    protected final long theTimeCreated = System.currentTimeMillis();
}
