#!/usr/bin/env bash
POST_IDS_FILE=$1 # file w/ list of attachments to delete

for POST_ID in `cat $POST_IDS_FILE`; do
  echo "Gonna delete $POST_ID"
  wp post delete $POST_ID --force # force used for attachments
done

echo "DONE"
