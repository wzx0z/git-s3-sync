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

aws s3api list-objects --bucket $s3bucket --output json --query "length(Contents[])" $cliparams || not_empty=true
# sync github to s3
if [ $not_empty ];then
  echo "Bucket not empty. Start incremental sync."
  sha_before=`aws s3 cp s3://$s3bucket/SYNCED_SHA - $cliparams | cat || ""`
  git diff-tree --no-commit-id --name-status -r $sha $sha_before | while read status filename; do
  if [ $status = "D" ]; then
    #echo "Delete $filename from S3"
    aws s3 rm "s3://$s3bucket/$filename" $cliparams
  else
    #echo "Copy $filename to S3"
    aws s3 cp "$filename" "s3://$s3bucket/$filename" --exclude ".git/*" --exclude ".ci/*" --recursive $cliparams || echo "Skip $filename."
  fi
  done
else
  echo "Bucket is empty. Start first sync."
  aws s3 sync . "s3://$s3bucket" --exclude ".git/*" --exclude ".ci/*" $cliparams
fi

# save synced sha
echo $sha > SYNCED_SHA
aws s3 cp SYNCED_SHA "s3://$s3bucket/" $cliparams

