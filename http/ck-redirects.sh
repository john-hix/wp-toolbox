#!/usr/bin/env bash
URL_FILE=$1

echo "This just tells you where each URL gets redirected; check manually that it's correct."

for URL in `cat $URL_FILE`
do
  echo "$URL => $(curl -Ls -o /dev/null -w %{url_effective} $URL)"
done

echo "DONE"
