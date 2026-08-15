#!/usr/bin/env bash


model_names=$(ollama list | tail -n +2 | awk '{print $1}')


json_array="["
for name in $model_names; do
    json_array+="\"$name\","
done


json_array="${json_array%,}]"


echo "$json_array"
