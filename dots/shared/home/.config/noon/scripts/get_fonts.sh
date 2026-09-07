#!/bin/bash
fc-list : family | tr ',' '\n' | sed 's/^[ \t]*//' | sort -u | jq -R . | jq -s .
