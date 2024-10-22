#!/bin/sh

sha256sum cjdns.sh > ./manifest.txt

ls ./binaries | while read -r dir; do
    cd "binaries/$dir" || exit 100
    (
        ls | while read -r file; do
            if ! [ "$file" = "manifest.txt" ] ; then
                sha256sum "$file"
            fi
        done 
    ) > ./manifest.txt
done