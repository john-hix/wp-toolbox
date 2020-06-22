#!/bin/bash

# Note: confirmed: all media is stored in year-month folders since website's beginning

# Command line args
UPLOADS_DIR=$1 # location of the old uploads directory
IMPORT_TYPE=$2 # one of: sa, si, b, va
DRY_RUN=$3  # whether to actually do the WP import commands

# Takes the IMPORT_TYPE string and returns the appropriate regex to find files with
# Pre: arg1 is the IMPORT_TYPE
# Post: returns a regex that will match files for the given IMPORT_TYPE, including date
generateRegex() {
  if [[ $1 == "sa" ]]; then
    echo ".*\/[0-9]{1,2}[\.-_][0-9]{1,2}[\.-_][0-9]{2,4}.*?\.mp3"
  elif [[ $1 == "si" ]]; then
    echo ".*\/[0-9]{1,2}[\.-_][0-9]{1,2}[\.-_][0-9]{2,4}.*?\.(jpg|jpeg|png|bmp|gif)$"
  elif [[ $1 == "b" ]]; then
    echo ".*\/[0-9]{1,2}[\.-_][0-9]{1,2}[\.-_][0-9]{2,4}.*?bulletin.*\.pdf"
  elif [[ $1 == "va" ]]; then
    echo ".*announcement.*\.mp4"
  else
    echo ""
  fi
}

getMediaCategory() {
  if [[ $1 == "sa" ]]; then
    echo "sermon-audio"
  elif [[ $1 == "si" ]]; then
    echo "sermon-images"
  elif [[ $1 == "b" ]]; then
    echo "bulletins"
  elif [[ $1 == "va" ]]; then
    echo "video-announcements	"
  else
    echo ""
  fi
}

REGEX=$(generateRegex $IMPORT_TYPE) # The regex with which to match file names
TERM_SLUG=$(getMediaCategory $IMPORT_TYPE)
ATTACHMENT_IDS=() # array used to record the ids of the attachments added to the WP instance
FAILED_FILE_IMPORTS=() # array of file names for failed imports
FAILED_TERM_ADDS=()

# For each file in the search directory that matches the regex, attempt the WP import commands
for FILE in `find ${UPLOADS_DIR} -type f -regextype posix-extended -iregex "$REGEX"`
do
  if [[ $DRY_RUN == "false" ]]; then
    echo "Attempting to import $FILE"
    ATTACH_ID=$(wp media import $FILE --preserve-filetime --porcelain)
    # If successful, add to media category
    if [[ $ATTACH_ID ]]; then
      echo "Successfully imported media item as $ATTACH_ID"
      ATTACHMENT_IDS+=("$ATTACH_ID corresponds to $FILE") # record success
      # Add proper category to upload via post meta. If that fails, track it via FAILED_TERM_ADDS array
      wp post term add $ATTACH_ID media_category $TERM_SLUG || FAILED_TERM_ADDS+=($ATTACH_ID)
    else # handle error to import file file
      echo -e "\e[1m\e[31mFailed:\e[0m  $FILE"
      FAILED_FILE_IMPORTS+=($FILE)
    fi

  else # Debugging output
    echo "Dry run found $FILE"
  fi
done

# Report
echo " "
echo "======== REPORT ========"

if [[ $ATTACHMENT_IDS ]]; then
  echo " "
  echo " "
  echo "Sucessfully imported the following attachments (WP ID, filename)"
  for i in "${ATTACHMENT_IDS[@]}"; do
    echo $i
  done
fi

if [[ $FAILED_TERM_ADDS ]]; then
  echo " "
  echo " "
  echo "ERROR: the following attachments were imported but did not get terms added:"
  for i in "${FAILED_TERM_ADDS[@]}"; do
    echo $i
  done
fi

if [[ $FAILED_FILE_IMPORTS ]]; then
  echo " "
  echo " "
  echo "ERROR: these files failed to import."
  for i in "${FAILED_FILE_IMPORTS[@]}"; do
    echo $i
  done
fi
