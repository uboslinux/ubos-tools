#!/bin/bash
#
# Show the number of commits since a particular date
#

since=$1
if [[ -z "${since}" ]]; then
    echo "ERROR: Provide git-acceptable date string as argument, e.g. 'March 13, 2015'" >&2
    exit 1
fi

total=0
for d in */.git; do
    d=$(dirname $d)
    n=$( ( cd $d; git log --since "${since}" | grep commit | wc -l ))
    echo "$d: $n commits"
    total=$(( $total + $n ))
done
echo "Total: $total"

