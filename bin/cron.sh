#!/usr/bin/env bash

cd "$(dirname "$0")"/..
if [ "$(date -u '+%H')" = "00" ] && [ "$(date -u '+%M')" = "00" ]; then
    git pull --rebase
    cp "$PWD/data/sub.txt" "$PWD/data/share/log/sub$(date -u '+%Y%m%d').txt"
    echo "" > "$PWD/data/sub.txt"
    hash=$(ipfs add -r --nocopy -Q "$PWD/data/share/log")
    ipfspub $hash
fi
if [ "$(date -u '+%M')" = "00" ] || [ "$(date -u '+%M')" = "30" ]; then
ipfspub 'Ok!'
feedupdate
fi
