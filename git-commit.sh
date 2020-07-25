#!/bin/bash

quote="'"
message=$quote$1$quote

echo 'Git message: ' $message

git add --all .
git commit -m "$@"
git push -u origin master
