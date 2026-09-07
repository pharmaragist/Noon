#!/bin/bash
opencode session list --format json \
  | jq -r '.[].id' \
  | xargs -r -n1 opencode session delete
