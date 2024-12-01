#!/usr/bin/env bash
# API_TOKEN must be set as an environment variable before executing this script.

# Exit on error
set -eu

# Clear the output directory
if [ -d "output" ]; then
    rm -rf output
fi
mkdir output

./generate-blog-posts.sh &
./generate-recipes.sh &

# Copy main page
echo "Writing main page"
cp templates/index.html output

wait
