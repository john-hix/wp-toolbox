#!/usr/bin/env bash
# This script assumes wp cli will be able to find the correct configuration info
# for the site you are working on. Be sure that is true!

# Strips the leading and trailing quotes on a string
# Thank-you: https://stackoverflow.com/a/9733456
strip_quotes() {
  temp="${1%\"}"
  temp="${temp#\"}"
  echo "$temp"
}

LIST_FILE=$1 # CSV with ID, the current _wp_attached_file path, and the destination path
UPLOADS_DIR=$2 # Usually wp-content/uploads
WP_CONFIG_PATH=$3 # Directory containing WordPress files for use with wp cli --path option
FAILED_IMPORTS=()

if [[ ! $LIST_FILE || ! $UPLOADS_DIR ]]; then
  echo "Did not supply enough arguments to the script" 1>&2
  echo "LIST_FILE: $LIST_FILE, UPLOADS_DIR: $UPLOADS_DIR" 1>&2
  exit 1
fi

# Assign a non-whitespace value to WP_CONFIG_PATH if user passed one
if [[ -n "$WP_CONFIG_PATH" ]]; then
  WP_CONFIG_PATH="--path=$WP_CONFIG_PATH"
fi

# Parse CSV (thanks: www.cyberciti.biz/faq/linux-unix-appleosx-bsd-shell-parse-text-file/)
# Set "," as the field separator using $IFS
# and read line by line using while read combo
while IFS=',' read -r ID DATE CURR_PATH DEST_PATH
do
  # echo "$ID $CURR_PATH $DEST_PATH"
  ID=$(strip_quotes $ID)
  DATE=$(strip_quotes $DATE)
  CURR_PATH=$(strip_quotes $CURR_PATH)
  DEST_PATH=$(strip_quotes $DEST_PATH)

  if [[ ! -e "$UPLOADS_DIR/$CURR_PATH" ]]; then # if file doesn't exist
    echo "$ID: $UPLOADS_DIR/$CURR_PATH does not exist" 1>&2
    FAILED_IMPORTS+="$ID: $UPLOADS_DIR/$CURR_PATH does not exist\n" # log and continue
  else
    FAILED="0" # Used to determine whether the file move or db update for this record fails

    # Create destination directory if needed
    DEST_BASE=${DEST_PATH##*/}
    if [[ ! -e "$UPLOADS_DIR/${DEST_PATH%$DEST_BASE}" ]]; then
      mkdir -p "$UPLOADS_DIR/${DEST_PATH%$DEST_BASE}"
    fi
    # attempt to move file to new location
    mv "$UPLOADS_DIR/$CURR_PATH" "$UPLOADS_DIR/$DEST_PATH" || FAILED="1"

    # Move thumbnails to avoid need for regenerating them later
    if [[ "$FAILED" == "0" ]]; then
      for FILE_W_PATH in `find $UPLOADS_DIR -type f -regextype posix-extended \
        -iregex ".*$CURR_PATH-[0-9]{1,4}x[0-9]{1,4}\.[a-z]{1,4}$"`; # regex to match thumbnails for the current file
      do
        echo $FILE_W_PATH
        BASE=${FILE_W_PATH##*/}   #=> "foo.jpg" (basepath)
        # mv $FILE_W_PATH ${FILE_W_PATH%$BASE} || echo "Failed to move thumbnail $FILE_W_PATH" 1>&2
      done
    fi

    if [[ "$FAILED" == "1" ]]; then # check if mv command failed
      echo "$ID: Failed to move $UPLOADS_DIR/$CURR_PATH to $UPLOADS_DIR/$DEST_PATH" 1>&2 # log and continue
      FAILED_IMPORTS+="$ID: Failed to move $UPLOADS_DIR/$CURR_PATH to $UPLOADS_DIR/$DEST_PATH"
    else # Otherwise, update the database with the new location
      echo "Doing search-replace for $ID"
      # update db file location (includes GUID)
      wp search-replace $CURR_PATH $DEST_PATH --recurse-objects --all-tables $WP_CONFIG_PATH --format=count --dry-run || FAILED="1"
      # Check for failure, log and continue if failed
      if [[ "$FAILED" == "1" ]]; then
        echo "$ID: Failed to update database" 1>&2
        FAILED_IMPORTS+="$ID: failed to update database\n"
      fi
    fi
  fi
done < "$LIST_FILE"
