#!/usr/bin/env bash

# This plugin assumes the use of the Enhanced Media Library plugin
# @link https://wordpress.org/plugins/enhanced-media-library/
#
# Logic to accompany some SQL queries for finding attachments with duplicate titles.
# For this script's application it mattered who the author was, so there is additional
# logic for that. Use the SQL query to get the inputs for this script.
#
# This script takes a list of attachment names and a parallel list of the number
# of duplicates each attachment name has (both lists in files, one per line),
# selects which attachment to keep by
# giving preference the "oldest" attachment by finding the attachment with the lowest
# id in a given set of duplicates, then tags the other dupes for deletion via post
# meta. This script does not perform the deletion; it marks the posts for deletion
# within the database with the meta key `jh_delete_duplicate`.
#
# For debugging, you can uncomment the lines which add the meta `jh_save`
# to attachments selected to be saved. The relevant line is:
# `wp post term add $KEPT_POST_ID media_category jh_save`

# Command line args
POST_NAMES_FILE=$1 # File containing the post titles for the duplicate posts
NUM_DUPES_FILE=$2  # File containing the number of duplicates for each post
TARGET_AUTHOR=0    # The author that must own a post in order for it to be saved
DRY_RUN=$4 # Assumed true, meaning no deletions are made, unless passed "false"

# Get the duplicates out of the files
POST_NAMES_ARR=(`cat "$POST_NAMES_FILE"`) # NOTE: Assumes no spaces in post names
# Get the number of duplicates for each post title
NUM_DUPES_ARR=(`cat "$NUM_DUPES_FILE"`)
# Reporting array to hold the names of posts that returned too many results to safely delete the dupes automatically
TOO_MANY_SEARCH_RESULTS=()
# Reporting array to hold the names of posts that didn't have the targeted author
INCORRECT_AUTHOR=()

# Check if POST_NAMES_ARR and NUM_DUPES_ARR found the same number of items
if [[ ${#POST_NAMES_ARR[@]} -ne ${#NUM_DUPES_ARR[@]} ]]; then
  echo "Unequal number of elements in $POST_NAMES_FILE and $NUM_DUPES_FILE:"
  echo "${#POST_NAMES_ARR[@]} and ${#NUM_DUPES_ARR[@]} respectively"
  echo "Quitting."
  exit 2
fi


# Loop through file input
for (( i = 0; i < ${#POST_NAMES_ARR[@]}; i++ )); do

  # Define post name and number of dupes for this record
  THIS_POST_NAME=${POST_NAMES_ARR[i]}
  THIS_NUM_DUPES=${NUM_DUPES_ARR[i]}

  # Get posts from WP for POST_TITLE
  echo "Searching for attachment posts with the name '$THIS_POST_NAME'"
  POST_IDS=$(wp post list --post_type=attachment --s="$THIS_POST_NAME" --exact=true --format=ids)
  DUPES=($POST_IDS)

  # Check if number of posts returned matches number of dupes from NUM_DUPES_ARR
  # If it doesn't, skip deletion and report that this one could not be safely deleted
  if [[ ${#DUPES[@]} -ne $THIS_NUM_DUPES ]]; then
    echo "  Search returned ${#DUPES[@]}, expected $THIS_NUM_DUPES. Skipping this post."
    TOO_MANY_SEARCH_RESULTS+=($THIS_POST_NAME)
  else
    # Loop and find any/all posts with author 0
    echo "  Checking for posts with author $TARGET_AUTHOR:"
    POSTS_WITH_CORRECT_AUTHOR=()
    for ID in "${DUPES[@]}"; do
      echo "    $ID"
      # Look post author ID via post ID
      AUTHOR_ID=$(wp post get $ID --field=author)
      # If this was added via CLI, implied by author of 0, then add to POSTS_WITH_CORRECT_AUTHOR array
      if [[ $AUTHOR_ID == $TARGET_AUTHOR ]]; then
        POSTS_WITH_CORRECT_AUTHOR+=("$ID")
      fi
    done # DUPES traversal

    if [[ $POSTS_WITH_CORRECT_AUTHOR ]]; then
      echo "  These had author $TARGET_AUTHOR: ${POSTS_WITH_CORRECT_AUTHOR[@]}"
    else
      echo "  Could not find any posts with author $TARGET_AUTHOR, so falling back to author 2"
      for ID in "${DUPES[@]}"; do
        # Look post author ID via post ID
        AUTHOR_ID=$(wp post get $ID --field=author)
        # If this was added via CLI, implied by author of 0, then add to POSTS_WITH_CORRECT_AUTHOR array
        if [[ $AUTHOR_ID == 2 ]]; then
          POSTS_WITH_CORRECT_AUTHOR+=("$ID")
        fi
      done
      if [[ $POSTS_WITH_CORRECT_AUTHOR ]]; then
        echo "  These had author 2: ${POSTS_WITH_CORRECT_AUTHOR[@]}"
      fi
    fi

    # Check if any of the posts had the target author before continuing
    if [[ ! $POSTS_WITH_CORRECT_AUTHOR ]]; then
      # Flag for review and continue
      echo "  No posts with author $TARGET_AUTHOR or 2 found, flagging for review and moving on."
      INCORRECT_AUTHOR+=($THIS_POST_NAME)
    else # We DID find at least one with the correct author or a fallback
      # Pick the post with the lowest ID and remove it from the author_0 array
      LOWEST_ID=${POSTS_WITH_CORRECT_AUTHOR[0]}
      for (( j = 1; j < ${#POSTS_WITH_CORRECT_AUTHOR[@]}; j++ )); do
        echo "     ${POSTS_WITH_CORRECT_AUTHOR[j]}, $LOWEST_ID"
        if [[ ${POSTS_WITH_CORRECT_AUTHOR[j]} -lt $LOWEST_ID ]]; then
          LOWEST_ID=${POSTS_WITH_CORRECT_AUTHOR[j]}
        fi
      done
      echo "  This is the lowest ID from that list: $LOWEST_ID"
      # Remove the one to keep
      KEPT_POST_ID=$LOWEST_ID
      # Remove all instances of the ID of the post to keep from the dupes array, as its contents will be deleted
      for (( D = 0; D < ${#DUPES[@]}; D++ )); do
        if [[ $KEPT_POST_ID -eq ${DUPES[D]} ]]; then
          unset DUPES[D] # Remove matching ID from DUPES array
        fi
      done
      echo "  This is the DUPES array after removing the ID to keep: ${DUPES[@]}"

      # echo "Adding $KEPT_POST_ID to the jh_save category"
      # wp post term add $KEPT_POST_ID media_category jh_save # debugging

      # Delete the rest via wp cli
      if [[ $DRY_RUN == "false"  ]]; then
        # do deletion
        for P_ID in ${DUPES[@]}; do
          echo "    Flagging $P_ID as duplicate"
          wp post term add $P_ID media_category jh_delete_duplicate
        done

      fi

    fi
  fi
done # file input loop


# Report
echo " "
echo "======== REPORT ========"


if [[ $TOO_MANY_SEARCH_RESULTS ]]; then
  echo " "
  echo " "
  echo "ERROR: the following posts did not return the expected number of posts from search:"
  for i in "${TOO_MANY_SEARCH_RESULTS[@]}"; do
    echo $i
  done
fi

if [[ $INCORRECT_AUTHOR ]]; then
  echo " "
  echo " "
  echo "ERROR: These posts didn't have the targeted author:"
  for i in "${INCORRECT_AUTHOR[@]}"; do
    echo $i
  done
fi
