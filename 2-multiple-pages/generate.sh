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
        -d "{\"query\":\"${query}\"}" \
        --fail-with-body
)

echo "${page_data}" | jq '.data.allBlogPost.results[]' -c | while read -r post
do
    # Extract individual fields
    {
        read id;
        read name;
        read title;
        read content;
    } <<< $(echo ${post} | jq -r -c '.id, .name, .title, .content')

    # Convert fields
    name=$(echo "$name" | tr [:upper:] [:lower:])
    name=${name//[^a-z0-9_\-]/-}
    content=$(transform_prosemirror "$content")

    # Write file
    html=$(cat template.html)
    html="${html//'[[id]]'/$id}"
    html="${html//'[[title]]'/$title}"
    html="${html//'[[content]]'/$content}"

    echo "Writing file: output/$name.html"
    echo "$html" > output/$name.html
done
