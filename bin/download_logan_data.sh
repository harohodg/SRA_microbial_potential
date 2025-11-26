#!/usr/bin/env bash

remote_file="$1"

aws s3 cp --no-sign-request ${remote_file} -