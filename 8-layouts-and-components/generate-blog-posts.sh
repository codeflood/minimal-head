#!/usr/bin/env bash
# API_TOKEN must be set as an environment variable before executing this script.

# Exit on error
set -eu

. ./transforms.sh
. ./substitute-placeholders.sh
. ./naming.sh
. ./data.sh

outDir=output/blog
mkdir $outDir

# Get blog post page data from CH ONE
query=$(cat query/getBlogPosts.graphql)
query="$(echo $query)"
has_more=true
end_cursor=""
page_number=0

while $has_more
do
    page_number=$((page_number+1))
    index_filename=$(filename_for_index "$page_number")
    page_data=$(execute_graphql "${query}" "${end_cursor}")

    # Extract paging fields
    {
        read has_more;
        read end_cursor;
    } <<< $(echo "${page_data}" | jq -r -c '.data.allBlogPost.pageInfo.hasNext, .data.allBlogPost.pageInfo.endCursor')

    mh_index=""

    while read -r post
    do
        # Extract individual fields
        {
            read mh_id;
            read mh_name;
            read mh_publish_date;
            read mh_title;
            read mh_content;
            read mh_raw_categories;
        } <<< $(echo ${post} | jq -r -c '.id, .name, .publishDate, .title, .content, .category.results')

        # Convert fields
        mh_name=$(url_for_name "$mh_name")
        mh_publish_date=$(date -d"$mh_publish_date" "+%d %B %Y")
        mh_content=$(transform_prosemirror "$mh_content")

        mh_category_ids=$(echo $mh_raw_categories | jq -r '.[].id')
        mh_category_names=""
        for category_id in $mh_category_ids
        do
            case $category_id in
                taxonomy_blogPostCategory_auriga)
                    mh_category_names="${mh_category_names}<li>Auriga</li>"
                    ;;
                taxonomy_blogPostCategory_expressSantorini)
                    mh_category_names="${mh_category_names}<li>Express Santorini</li>"
                    ;;
                taxonomy_blogPostCategory_panorea)
                    mh_category_names="${mh_category_names}<li>Panorea</li>"
                    ;;
            esac
        done
        mh_category_names="<ul>${mh_category_names}</ul>"

        # Write file
        mh_index_url=$index_filename
        mh_body=$(substitute_placeholders templates/blog-post.html)
        html=$(substitute_placeholders templates/page.html)

        echo "Writing file: $outDir/$mh_name.html"
        echo "$html" > $outDir/$mh_name.html

        # Generate summary specific fields
        mh_url=$mh_name.html
        mh_abstract=$(generate_abstract "$mh_content")

        # Process summary component
        html=$(substitute_placeholders templates/components/blog-post-summary.html)

        # Add summary to index
        mh_index="${mh_index}${html}"

    done <<< $(echo "${page_data}" | jq '.data.allBlogPost.results[]' -c)

    # Write index file
    mh_body=$(substitute_placeholders templates/blog-index.html)
    mh_title="Blog Posts"
    html=$(substitute_placeholders templates/page.html)

    echo "Writing index file: $outDir/${index_filename}"
    echo "${html}" > $outDir/${index_filename}
done

# Add pager to blog index files
echo "Adding blog pagers"
substitute_pagers $page_number
