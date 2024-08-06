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
        read publishDate;
        read title;
        read content;
        read rawCategories;
    } <<< $(echo ${post} | jq -r -c '.id, .name, .publishDate, .title, .content, .category.results')

    # Convert fields
    name=$(echo "$name" | tr [:upper:] [:lower:])
    name=${name//[^a-z0-9_\-]/-}
    publishDate=$(date -d"$publishDate" "+%d %B %Y")
    content=$(transform_prosemirror "$content")

    category_ids=$(echo $rawCategories | jq -r '.[].id')
    category_names=""
    for category_id in $category_ids
    do
        case $category_id in
            taxonomy_blogPostCategory_auriga)
                category_names="${category_names}<li>Auriga</li>"
                ;;
            taxonomy_blogPostCategory_expressSantorini)
                category_names="${category_names}<li>Express Santorini</li>"
                ;;
            taxonomy_blogPostCategory_panorea)
                category_names="${category_names}<li>Panorea</li>"
                ;;
        esac
    done
    category_names="<ul>${category_names}</ul>"

    # Write file
    html=$(cat template.html)
    html="${html//'[[id]]'/$id}"
    html="${html//'[[title]]'/$title}"
    html="${html//'[[content]]'/$content}"
    html="${html//'[[date]]'/$publishDate}"
    html="${html//'[[category_names]]'/$category_names}"

    echo "Writing file: output/$name.html"
    echo "$html" > output/$name.html
done
