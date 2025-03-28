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


show_usage() {
  echo "Usage: source $(basename "${BASH_SOURCE[0]}") --account ACCOUNT --role ROLE_NAME [--session SESSION_NAME]"
  echo ""
  echo "Options:"
  echo "  --account  AWS account ID"
  echo "  --role     IAM role name (without the arn:aws:iam prefix)"
  echo "  --session  Session name for the assumed role (default: default-session)"
  echo "  --help     Show this help message"
}

# Ensure script is being sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "Error: This script must be sourced, not executed."
  show_usage
  exit 1
fi

set -euo pipefail

ACCOUNT=""
ROLE_NAME=""
SESSION_NAME="default-session"

while [[ $# -gt 0 ]]; do
  case $1 in
    --account)
      ACCOUNT="$2"
      shift 2
      ;;
    --role)
      ROLE_NAME="$2"
      shift 2
      ;;
    --session)
      SESSION_NAME="$2"
      shift 2
      ;;
    --help)
      show_usage
      return 0
      ;;
    *)
      echo "Unknown parameter: $1"
      echo "Use --help for usage information"
      return 1
      ;;
  esac
done

if [ -z "$ACCOUNT" ]; then
  echo "Error: Account ID is required"
  return 1
fi

if [ -z "$ROLE_NAME" ]; then
  echo "Error: Role name is required"
  return 1
fi

CREDENTIALS=$(aws sts assume-role \
  --role-arn "arn:aws:iam::${ACCOUNT}:role/${ROLE_NAME}" \
  --role-session-name "${SESSION_NAME}" \
  --output json)
AWS_ACCESS_KEY_ID=$(echo "$CREDENTIALS" | jq -r '.Credentials.AccessKeyId')
AWS_SECRET_ACCESS_KEY=$(echo "$CREDENTIALS" | jq -r '.Credentials.SecretAccessKey')
AWS_SESSION_TOKEN=$(echo "$CREDENTIALS" | jq -r '.Credentials.SessionToken')

export AWS_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY
export AWS_SESSION_TOKEN

echo "ASSUMED: arn:aws:iam::${ACCOUNT}:role/${ROLE_NAME}"