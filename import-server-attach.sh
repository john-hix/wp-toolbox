#!/usr/bin/env bash

# Author: John Hicks
# This script takes a list files living on the server and imports them to a WP
# installation as attachments, using the file's timestamp as the WP attachment's
# date. The file to be imported are supplied via a file with one file path per line

OLD_FOLDER=$1  # The basepath to prepend to all files imported
FILE_LIST=$2   # A file containing a list of files
WP_PATH=$3     # Optional argument to specify location of WP installation for wp cli

# Handle WP installation option if supplied
if [[ -n "$WP_PATH" ]]; then
  WP_PATH="--path=$WP_PATH"
fi

FAILED_FILE_IMPORTS=() # array of file names for failed imports

# Read in file
FILE_NAMES_ARR=(`cat "$FILE_LIST"`)

# For each line
for (( i = 0; i < ${#FILE_NAMES_ARR[@]}; i++ )); do
  FILE=${FILE_NAMES_ARR[i]}
  echo "Looking for for $OLD_FOLDER/$FILE"
  # Search for attachment file in old folder
  if [[ ! -e "$OLD_FOLDER/$FILE" ]]; then
    echo -e "\e[1m\e[31mFile not found:\e[0m $OLD_FOLDER/$FILE"
    FAILED_FILE_IMPORTS+=("$FILE")
  else  # if attachment file was found
    # Create a media attachment
    ID=$(wp media import "$OLD_FOLDER/$FILE" --preserve-filetime --porcelain "$WP_PATH")
    echo "$ID $FILE"
  fi
done # file input loop

if [[ $FAILED_FILE_IMPORTS ]]; then
  echo " "
  echo " "
  echo "ERROR: these files failed to import."
  for i in "${FAILED_FILE_IMPORTS[@]}"; do
    echo $i
  done
fi
