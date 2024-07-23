#!/usr/bin/env bash
# API_TOKEN must be set as an environment variable before executing this script.

# Exit on error
set -e

. ./transforms.sh

# Clear the output directory
if [ -d "output" ]; then
    rm -rf output
fi
mkdir output

# Get page data from CH ONE
query=$(cat query.graphql)
query="$(echo $query)"

page_data=$(\
    curl -X POST https://edge.sitecorecloud.io/api/graphql/v1 \
        -H "Content-Type: application/json" \
        -H "X-GQL-Token: ${API_TOKEN}" \
        -d "{\"query\":\"${query}\",\"variables\":{\"id\":\"W-ogYlX0z0W79idySURpiA\"}}" \
        --fail-with-body
)

# Extract individual fields
{
    read id;
    read title;
    read content;
} <<< $(echo ${page_data} | jq -r -c '.data.blogPost | .id, .title, .content')

# Convert fields
content=$(transform_prosemirror "$content")

# Write file
html=$(cat template.html)
html="${html//'[[id]]'/$id}"
html="${html//'[[title]]'/$title}"
html="${html//'[[content]]'/$content}"
echo "$html" > output/page.html
