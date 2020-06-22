#!/usr/bin/env bash

# Strips the leading and trailing quotes on a string
# Thank-you: https://stackoverflow.com/a/9733456
strip_quotes() {
  temp="${1%\"}"
  temp="${temp#\"}"
  echo "$temp"
}

# Start over with uploads folder
rm -r wp-content/uploads
mkdir wp-content/uploads

# Populate uploads folder with our misplaced files
# Parse CSV (thanks: www.cyberciti.biz/faq/linux-unix-appleosx-bsd-shell-parse-text-file/)
while IFS=',' read -r ID DATE CURR_PATH DEST_PATH
do
  # echo "$ID $CURR_PATH $DEST_PATH" # debug

  # Remove quotes from CSV
  CURR_PATH=$(strip_quotes "$CURR_PATH")

  # Separate directory path from file name
  FILENAME=${CURR_PATH##*/}
  DIRPATH=${CURR_PATH%$FILENAME}

  # Make the directory in the uploads directory
  mkdir -p "wp-content/uploads/$DIRPATH"
  # Make a dummy file with this name
  echo "This is a file!" > "wp-content/uploads/${CURR_PATH}" # make a dummy file
  echo "This is a file!" > "wp-content/uploads/${CURR_PATH}" # make a dummy file

done < "filepath-corrections.csv"
