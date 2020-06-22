#!/usr/bin/env bash

SS_LIST_FILE=$1   # A file containing a list of sermon series data
WP_PATH=$2        # Optional argument to specify location of WP installation for wp cli

# Handle WP installation option if supplied
if [[ -n "$WP_PATH" ]]; then
  WP_PATH="--path=$WP_PATH"
fi

# Iterate over CSV rows, add SS and its date, print redirect data
# Parse CSV (thanks: www.cyberciti.biz/faq/linux-unix-appleosx-bsd-shell-parse-text-file/)
IFS=','
while read -r ORIG_POST_ID REDIR_FROM DATE TITLE DESC
do
  echo "$ORIG_POST_ID"
  echo "$REDIR_FROM"
  echo "$DATE"
  echo "$TITLE"
  echo "$DESC"
  echo "$@"
  # Create sermon series
  ID=$(wp term create "sermon-series" "$TITLE" --porcelain)
  if [[ "$ID" ]]; then
    # Serialize the date for the database
    SDATE=$(php serialize.php "$DATE")
    # Update default value given to tbcf_sermon_tax_start_date
    wp term meta update "$ID" tbcf_sermon_tax_start_date "$SDATE" "$WP_PATH" #
    # Print out for redirects
    SLUG=$(wp term get sermon-series "101" --field=slug "$WP_PATH")
    echo "$ORIG_POST_ID  -->  $SLUG"
  else
    echo "\e[1m\e[31mFailed:\e[0m $ORIG_POST_ID"
  fi
done < "$SS_LIST_FILE"
