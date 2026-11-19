#!/usr/bin/env bash

find /usr/share/sounds ~/.local/share/sounds -mindepth 2 -maxdepth 2 -name "index.theme" 2>/dev/null -print0 |
  jq -Rn '[
    inputs | split("\u0000")[] | select(length > 0) |
    sub("/index\\.theme$"; "") |
    {
      name: (split("/")[-1]),
      path: .
    }
  ]'
