#!/bin/bash

set +x
cliparams=""
while getopts "r:b:s:c:" opt; do
  case $opt in
    r)
      sha=$OPTARG
      ;;
    b)
      s3bucket=$OPTARG
      ;;
    c)
      cliparams=$OPTARG
      ;;
    \?)
      echo "Invalid option: -$OPTARG" 
      ;;
  esac
done

sha_before=`aws s3 cp s3://$s3bucket/SYNCED_SHA - $cliparams | cat || ""`
# sync github to s3
if [ $sha_before ];then
  echo "Synced SHA found. Start incremental sync." 
  git diff-tree --no-commit-id --name-status -r $sha_before $sha | grep -vE '\.ci/.*' | while read status filename; do
  #echo "$status $filename"
  if [[ "$status" == "D" ]]; then
    #echo "Delete $filename from S3"
    aws s3 rm "s3://$s3bucket/$filename" $cliparams
  else
    #echo "Copy $filename to S3"
    aws s3 cp "$filename" "s3://$s3bucket/$filename" $cliparams
  fi
  done
else
  echo "Synced SHA not found. Start first full sync."
  aws s3 sync . "s3://$s3bucket" --exclude ".git/*" --exclude ".ci/*" $cliparams
fi

# save synced sha
echo $sha > SYNCED_SHA
aws s3 cp SYNCED_SHA "s3://$s3bucket/" $cliparams

