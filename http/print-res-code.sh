#!/usr/bin/env bash

# Prints HTTP response code without downloading the entire resource
URL_FILE=$1

for URL in `cat $URL_FILE`
do
  echo "$(wget -S --spider "$URL" 2>&1 | grep "HTTP/" | awk '{print $2}') $URL" # print status code
done
