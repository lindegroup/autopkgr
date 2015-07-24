#!/bin/bash

###
#
#            Name:  filename_metadata_checker.sh
#     Description:  Checks Obj-C source files to make sure the filename in the
#                   metadata matches the actual filename.
#          Author:  Elliot Jordan <elliot@lindegroup.com>
#         Created:  2015-07-03
#   Last Modified:  2015-07-24
#         Version:  1.1
#
###

PROJ_ROOT=".."

find "$PROJ_ROOT" ! -ipath "*/Pods/*" -and -iname "*.m" -or ! -ipath "*/Pods/*" -and -iname "*.h" | while read fname; do
    IDEAL="//
//  $(basename "$fname")"
    ACTUAL=$(head -2 "$fname")
    if [[ "$ACTUAL" != "$IDEAL" ]]; then
        echo "$fname"
        echo "$ACTUAL"
        echo
        open -a "Atom" "$fname"
    fi
    grep -q "Apache License, Version 2.0" "$fname"
    if [[ $? -ne 0 ]]; then
        echo "No license found in $fname."
        open -a "Atom" "$fname"
    fi
done

exit 0
