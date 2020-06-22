#!/bin/bash
# Media categories will likely need to be modified for your application

# Command line args
ATTACHMENT_IDS_FILE=$1 # File containing attachment IDs that need to be assigned the media category
IMPORT_TYPE=$2 # The media category to assign; one of: sa, si, b, va
DRY_RUN=$3  # whether to actually do the WP import commands

getMediaCategory() {
  if [[ $1 == "sa" ]]; then
    echo "sermon-audio"
  elif [[ $1 == "si" ]]; then
    echo "sermon-images"
  elif [[ $1 == "b" ]]; then
    echo "bulletins"
  elif [[ $1 == "va" ]]; then
    echo "video-announcements"
  elif [[ $1 == "n" ]]; then
    echo "sermon-notes"
  else
    echo ""
  fi
}

TERM_SLUG=$(getMediaCategory $IMPORT_TYPE)
FAILED_FILE_IMPORTS=() # array of file names for failed imports
FAILED_TERM_ADDS=()

echo "Using the term slug '$TERM_SLUG'"

# For each file in the search directory that matches the regex, attempt the WP import commands
for ATTACH_ID in `cat $ATTACHMENT_IDS_FILE`
do
  if [[ $DRY_RUN == "false" ]]; then
    (wp post term add $ATTACH_ID media_category $TERM_SLUG --path=./public_html && echo "from attach ID $ATTACH_ID" ) ||
FAILED_TERM_ADDS+=($ATTACH_ID)
  else # Debugging output
    echo "Dry run found $ATTACH_ID"
  fi
done

# Report
echo " "
echo "======== REPORT ========"

if [[ $FAILED_TERM_ADDS ]]; then
  echo " "
  echo " "
  echo "ERROR: the following attachments were imported but did not get terms added:"
  for i in "${FAILED_TERM_ADDS[@]}"; do
    echo $i
  done
fi
