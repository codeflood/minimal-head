#!/usr/bin/env bash
# API_TOKEN must be set as an environment variable before executing this script.

# Exit on error
set -eu

. ./transforms.sh

function filename_for_index {
    filename=index
    [ $1 -gt 1 ] && filename="${filename}${1}"
    echo "${filename}.html"
}

# Clear the output directory
if [ -d "output" ]; then
    rm -rf output
fi
mkdir output

# Get page data from CH ONE
query=$(cat query.graphql)
query="$(echo $query)"
has_more=true
end_cursor=""
page_number=0

while $has_more
do
    page_number=$((page_number+1))
    index_filename=$(filename_for_index "$page_number")

    page_data=$(\
        curl -X POST https://edge.sitecorecloud.io/api/graphql/v1 \
            -H "Content-Type: application/json" \
            -H "X-GQL-Token: ${API_TOKEN}" \
            -d "{\"query\":\"${query}\",\"variables\":{\"cursor\":\"$end_cursor\"}}" \
            --fail-with-body
    )

    # Extract paging fields
    {
        read has_more;
        read end_cursor;
    } <<< $(echo "${page_data}" | jq -r -c '.data.allBlogPost.pageInfo.hasNext, .data.allBlogPost.pageInfo.endCursor')

    index=""

    while read -r post
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

        categoryIds=$(echo $rawCategories | jq -r '.[].id')
        categoryNames=""
        for categoryId in $categoryIds
        do
            case $categoryId in
                taxonomy_blogPostCategory_auriga)
                    categoryNames="${categoryNames}<li>Auriga</li>"
                    ;;
                taxonomy_blogPostCategory_expressSantorini)
                    categoryNames="${categoryNames}<li>Express Santorini</li>"
                    ;;
                taxonomy_blogPostCategory_panorea)
                    categoryNames="${categoryNames}<li>Panorea</li>"
                    ;;
            esac
        done
        categoryNames="<ul>${categoryNames}</ul>"

        # Write file
        html=$(cat templates/blog-post.html)
        html="${html//'[[id]]'/$id}"
        html="${html//'[[title]]'/$title}"
        html="${html//'[[content]]'/$content}"
        html="${html//'[[date]]'/$publishDate}"
        html="${html//'[[categoryNames]]'/$categoryNames}"
        html="${html//'[[indexUrl]]'/$index_filename}"

        echo "Writing file: output/$name.html"
        echo "$html" > output/$name.html

        # Generate summary specific fields
        url=$name.html
        abstract=$(echo "$content" | sed 's|<[^>]*>||g')
        [ "${#abstract}" -gt 120 ] && abstract="${abstract:0:120}..."

        # Process summary component
        html=$(cat templates/components/blog-post-summary.html)
        html="${html//'[[id]]'/$id}"
        html="${html//'[[url]]'/$url}"
        html="${html//'[[title]]'/$title}"
        html="${html//'[[date]]'/$publishDate}"
        html="${html//'[[categoryNames]]'/$categoryNames}"
        html="${html//'[[abstract]]'/$abstract}"

        # Add summary to index
        index="${index}${html}"

    done <<< $(echo "${page_data}" | jq '.data.allBlogPost.results[]' -c)

    # Write index file
    html=$(cat templates/blog-index.html)
    html="${html//'[[posts]]'/$index}"

    echo "Writing index file: output/${index_filename}"
    echo "${html}" > output/${index_filename}
done

# Add pager to index files
echo "Adding pagers"
for i in $(seq $page_number);
do
    links=""
    for j in $(seq $page_number);
    do
        if [ $i -eq $j ]; then
            links="${links}<li>${j}</li>"
        else
            filename=$(filename_for_index "$j")
            links="${links}<li><a href="${filename}">${j}</a></li>"
        fi
    done

    links="<ul>${links}</ul>"
    filename=$(filename_for_index "$i")
    html=$(cat output/${filename})
    html="${html//'[[pager]]'/$links}"
    echo "${html}" > output/${filename}
done
