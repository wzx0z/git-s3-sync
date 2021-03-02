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

s3objects=`aws s3api list-objects --bucket $s3bucket --output json --query "length(Contents[])" $cliparams`
if [ "$s3objects" != "null" -a $s3objects > 0 ];then
  echo "Bucket not empty. Start incremental sync."
  git diff-tree --no-commit-id --name-status -r $sha | while read status filename; do
  if [ $status = "D" ]; then
    #echo "Delete $filename from S3"
    aws s3 rm "s3://$s3bucket/$filename" --exclude ".git/*" --exclude ".ci/*" $cliparams
  else
    #echo "Copy $filename to S3"
    aws s3 cp "$filename" "s3://$s3bucket/$filename" --exclude ".git/*" --exclude ".ci/*" --recursive $cliparams
  fi
  done
else
  echo "Bucket is empty. Start first sync."
  aws s3 sync . "s3://$s3bucket" --exclude ".git/*" --exclude ".ci/*" $cliparams
fi
