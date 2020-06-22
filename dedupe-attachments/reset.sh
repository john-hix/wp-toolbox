#!/usr/bin/env bash
# Unmarks a list of attachments which were marked via the dedupte script

for ID in `cat reset.txt`; do
  wp post term remove $ID media_category jh_save
  wp post term remove $ID media_category jh_delete_duplicate
done
