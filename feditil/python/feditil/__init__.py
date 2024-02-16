"""
"""

from typing import Any
import json
import re
import urllib.parse
import urllib.request
import ubos.logging


def normalize_id(candidate: str) -> str | None:
    if candidate.startswith('http://') or candidate.startswith('https://'):
        ret = candidate

    elif candidate.startswith('acct:'):
        ret = candidate

    else:
        m = re.match( '^(@)?([^@]+)@([^@]+)$', candidate )
        if m:
            ret = 'acct:' + m.group(2) + '@' + m.group(3)
        else:
            ret = None

    ubos.logging.trace('Normalized', candidate, 'to', ret )
    return ret


def determine_webfinger_url(normalized_id: str ) -> str:
    at = normalized_id.index( '@', 1 )
    domain = normalized_id[at+1:]

    ret = f"https://{domain}/.well-known/webfinger?resource={ urllib.parse.quote(normalized_id) }"
    ubos.logging.trace('Webfinger Url for', normalized_id, 'is', ret )
    return ret

def perform_webfinger_query(normalized_id: str ) -> Any:
    wfUrl = determine_webfinger_url(normalized_id)

    wfContent = urllib.request.urlopen(wfUrl).read()
    wfJson = json.loads( wfContent )

    return wfJson


def determine_jrd_first_href_for(normalized_id: str, rel: str | None = None, type : str | None = None ) -> str | None:
    wfJson = perform_webfinger_query(normalized_id)

    ret = None
    if 'links' in wfJson:
        for linkJson in wfJson['links']:
            if rel and ( not 'rel' in linkJson or linkJson['rel'] != rel ):
                next

            if type and ( not 'type' in linkJson or linkJson['type'] != type ):
                next

            if 'href' in linkJson:
                ret = linkJson['href']
                break

    ubos.logging.trace('href for', normalized_id, 'with rel', rel, ' and type', type, 'is', ret )
    return ret


def perform_actor_query(normalized_id: str) -> Any:
    actorUrl = determine_jrd_first_href_for(normalized_id, rel='self', type='application/activity+json')

    actorJson = None
    if actorUrl:
        actorContent = urllib.request.urlopen( urllib.request.Request( actorUrl, headers={ 'Accept' : 'application/activity+json', 'User-Agent' : '' } )).read()
        actorJson = json.loads( actorContent )

    return actorJson
