#!/usr/bin/env bash

# Exit on error
set -e

# args: 1 = ProseMirror JSON to transform.
function transform_prosemirror {
    local type=$(echo $1 | jq .type -r)

    case $type in
        
        paragraph)
            echo "<p>"
            process_content "$1"
            echo "</p>"
            ;;
        
        text)
            echo $(echo "$1" | jq .text -r)
            ;;

        *)
            process_content "$1"
            ;;
    esac
}

function process_content {
    echo "$1" | jq .content[] -c | while read -r item
    do
        transform_prosemirror "$item"
    done
}

# Clear the output directory
if [ -d "output" ]; then
    rm -rf output
fi
mkdir output

# Get page data from CH ONE
page_data=$(\
    curl -X POST https://edge.sitecorecloud.io/api/graphql/v1 \
        -H "Content-Type: application/json" \
        -H "X-GQL-Token: ${API_TOKEN}" \
        -d '{"query":"query getBlogPost($id: String!) {blogPost(id: $id) { id, title, content }}","variables":{"id":"W-ogYlX0z0W79idySURpiA"}}' \
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
cat << END > output/page.html
<!DOCTYPE html>
<html>
    <head>
        <title>${title}</title>
    </head>
    <body>
        <h1>${title}</h1>
        <p>ID: ${id}</p>
        <main>
            ${content}
        </main>
    </body>
</html>
END
