#!/usr/bin/env bash
#
# MIT License
#
# Copyright (c) 2025 Michael Dalrymple <mike@mousedown.com>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

set -euo pipefail

STACK_NAMES=""
VERSIONS_TO_KEEP=""
DRY_RUN=false

print_usage() {
  echo "Usage: $0 --stacks stack1,stack2,stack3 --keep N [--dry-run]"
  echo "  --stacks   Comma-separated list of CloudFormation stack names"
  echo "  --keep     Number of Lambda function versions to keep (positive integer)"
  echo "  --dry-run  Identify versions to delete without actually deleting them"
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --stacks)
      STACK_NAMES="$2"
      shift 2
      ;;
    --keep)
      VERSIONS_TO_KEEP="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=true
      shift 1
      ;;
    *)
      echo "Unknown option: $1"
      print_usage
      ;;
  esac
done

if [[ -z "$STACK_NAMES" ]]; then
  echo "Error: --stacks argument is required"
  print_usage
fi

if [[ -z "$VERSIONS_TO_KEEP" ]]; then
  echo "Error: --keep argument is required"
  print_usage
fi

if ! [[ "$VERSIONS_TO_KEEP" =~ ^[0-9]+$ ]] || [[ "$VERSIONS_TO_KEEP" -lt 2 ]]; then
  echo "Error: --keep must be an integer of 2 or greater"
  print_usage
fi

if $DRY_RUN; then
  echo "DRY RUN: No changes will be made"
fi

IFS=',' read -ra STACKS <<< "$STACK_NAMES"

function_arns=()
for stack in "${STACKS[@]}"; do
  stack_resources=$(aws cloudformation list-stack-resources --stack-name "$stack")
  # Extract Lambda function ARNs
  lambda_resources=$(echo "$stack_resources" | jq -r '.StackResourceSummaries[] | select(.ResourceType=="AWS::Lambda::Function") | .PhysicalResourceId')
  for fn in $lambda_resources; do
    function_arns+=("$fn")
  done
done

echo "FOUND ${#function_arns[@]} Lambda functions"
# Process each function
for fn_name in "${function_arns[@]}"; do
  echo "PROCESSING $fn_name"

  # List all versions for this function
  readarray -t version_array < <(aws lambda list-versions-by-function --function-name "$fn_name" --output json | jq -r '.Versions[] | select(.Version != "$LATEST") | .Version')
  if [[ ${#version_array[@]} -le $VERSIONS_TO_KEEP ]]; then
    echo "SKIPPING $fn_name has ${#version_array[@]} versions"
    continue
  fi

  versions_to_delete=$((${#version_array[@]} - VERSIONS_TO_KEEP))
  for ((i=0; i<"$versions_to_delete"; i++)); do
    version=${version_array[$i]}
    if $DRY_RUN; then
      echo "DELETE SKIPPED (DRY RUN) $fn_name:$version"
    else
      if aws lambda delete-function --function-name "$fn_name" --qualifier "$version" &> /dev/null; then
        echo "DELETED $fn_name:$version"
      else
        echo "ERROR deleting $fn_name:$version"
      fi
    fi
  done
done

echo "COMPLETE"