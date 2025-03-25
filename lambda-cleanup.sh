#!/usr/bin/env bash
set -e

# Check required environment variables
if [[ -z "$STACK_NAMES" ]]; then
  echo "Error: STACK_NAMES environment variable is not set"
  exit 1
fi

if [[ -z "$VERSIONS_TO_KEEP" ]]; then
  echo "Error: VERSIONS_TO_KEEP environment variable is not set"
  exit 1
fi

# Validate VERSIONS_TO_KEEP is a positive integer
if ! [[ "$VERSIONS_TO_KEEP" =~ ^[0-9]+$ ]] || [[ "$VERSIONS_TO_KEEP" -lt 1 ]]; then
  echo "Error: VERSIONS_TO_KEEP must be a positive integer"
  exit 1
fi

# Get all Lambda functions from the stacks
echo "Getting Lambda functions from stacks: $STACK_NAMES"
IFS=',' read -ra STACKS <<< "$STACK_NAMES"

function_arns=()
for stack in "${STACKS[@]}"; do
  echo "Processing stack: $stack"

  stack_resources=$(aws cloudformation list-stack-resources --stack-name "$stack")

  # Extract Lambda function ARNs
  lambda_resources=$(echo "$stack_resources" | jq -r '.StackResourceSummaries[] | select(.ResourceType=="AWS::Lambda::Function") | .PhysicalResourceId')

  for fn in $lambda_resources; do
    function_arns+=("$fn")
  done
done

echo "Found ${#function_arns[@]} Lambda functions"

# Process each function
for fn_name in "${function_arns[@]}"; do
  echo "Processing function: $fn_name"

  # List all versions for this function
  versions=$(aws lambda list-versions-by-function --function-name "$fn_name" --output json | jq -r '.Versions[] | select(.Version != "$LATEST") | .Version')
  echo "Raw versions: $versions"

  # Create array with space-separated values
  version_array=($versions)
  echo "Created array with ${#version_array[@]} elements"

  # Skip if there are no versions or fewer versions than we want to keep
  if [[ ${#version_array[@]} -le $VERSIONS_TO_KEEP ]]; then
   echo "Function $fn_name has ${#version_array[@]} versions, which is less than or equal to $VERSIONS_TO_KEEP. Skipping."
   continue
  fi

  # Calculate how many versions to delete
  versions_to_delete=$((${#version_array[@]} - VERSIONS_TO_KEEP))
  echo "Function $fn_name has ${#version_array[@]} versions. Keeping $VERSIONS_TO_KEEP newest versions, deleting $versions_to_delete versions."

  # Delete all but the newest VERSIONS_TO_KEEP versions
  for ((i=0; i<$versions_to_delete; i++)); do
   version=${version_array[$i]}
   echo "Deleting $fn_name:$version"
   # aws lambda delete-function-version --function-name "$fn_name" --qualifier "$version"
  done
done

echo "Lambda function version cleanup complete"