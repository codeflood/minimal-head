#!/usr/bin/env bash
# API_TOKEN must be set as an environment variable before executing this script.

# Exit on error
set -eu

. ./transforms.sh
. ./substitute-placeholders.sh

outDirBlog=output/blog
outDirRecipe=output/recipe

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
mkdir $outDirBlog
mkdir $outDirRecipe

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
        mh_name=$(echo "$mh_name" | tr [:upper:] [:lower:])
        mh_name=${mh_name//[^a-z0-9_\-]/-}
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
        html=$(substitute_placeholders templates/blog-post.html)

        echo "Writing file: $outDirBlog/$mh_name.html"
        echo "$html" > $outDirBlog/$mh_name.html

        # Generate summary specific fields
        mh_url=$mh_name.html
        mh_abstract=$(echo "$mh_content" | sed 's|<[^>]*>||g')
        [ "${#mh_abstract}" -gt 120 ] && mh_abstract="${mh_abstract:0:120}..."

        # Process summary component
        html=$(substitute_placeholders templates/components/blog-post-summary.html)

        # Add summary to index
        mh_index="${mh_index}${html}"

    done <<< $(echo "${page_data}" | jq '.data.allBlogPost.results[]' -c)

    # Write index file
    html=$(substitute_placeholders templates/blog-index.html)

    echo "Writing index file: $outDirBlog/${index_filename}"
    echo "${html}" > $outDirBlog/${index_filename}
done

# Add pager to blog index files
echo "Adding blog pagers"
for i in $(seq $page_number);
do
    mh_pager=""
    for j in $(seq $page_number);
    do
        if [ $i -eq $j ]; then
            mh_pager="${mh_pager}<li>${j}</li>"
        else
            filename=$(filename_for_index "$j")
            mh_pager="${mh_pager}<li><a href="${filename}">${j}</a></li>"
        fi
    done

    mh_pager="<ul>${mh_pager}</ul>"
    filename=$(filename_for_index "$i")
    html=$(substitute_placeholders $outDirBlog/${filename})
    echo "${html}" > $outDirBlog/${filename}
done

# Get recipe page data from CH ONE
query=$(cat query/getRecipes.graphql)
query="$(echo $query)"
has_more=true
end_cursor=""
page_number=0
unset mh_pager

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
    } <<< $(echo "${page_data}" | jq -r -c '.data.allRecipe.pageInfo.hasNext, .data.allRecipe.pageInfo.endCursor')

    mh_index=""

    while read -r recipe
    do
        # Extract fields
        {
            read mh_id;
            read mh_name;
            read mh_title;
            read mh_description;
            read mh_prep_time;
            read mh_cook_time;
            read mh_method;
        } <<< $(echo ${recipe} | jq -r -c '.id, .name, .title, .description, .prepTime, .cookingTime, .method')
        mh_ingredients=$(echo "${recipe}" | jq -r .ingredients)
        mh_images=$(echo "${recipe}" | jq -r .images.results[].fileUrl)

        # Convert fields
        mh_name=$(echo "$mh_name" | tr [:upper:] [:lower:])
        mh_name=${mh_name//[^a-z0-9_\-]/-}
        mh_description=$(transform_prosemirror "$mh_description")
        mh_method=$(transform_prosemirror "$mh_method")

        ingredient_list=""

        while read -r item
        do
            ingredient_list="${ingredient_list}<li>${item}</li>"
        done <<< "$mh_ingredients"

        mh_ingredients="<ul>${ingredient_list}</ul>"

        image_tags=""

        while read -r image
        do
            image_tags="${image_tags}<li><img src=\"${image}\" width=\"400\"/></li>"
        done <<< "$mh_images"

        mh_images="<ul>${image_tags}</ul>"

        # Write file
        mh_index_url=$index_filename
        html=$(substitute_placeholders templates/recipe.html)

        echo "Writing file: $outDirRecipe/$mh_name.html"
        echo "$html" > $outDirRecipe/$mh_name.html

        # Generate summary specific fields
        mh_url=$mh_name.html
        mh_abstract=$(echo "$mh_description" | sed 's|<[^>]*>||g')
        [ "${#mh_abstract}" -gt 120 ] && mh_abstract="${mh_abstract:0:120}..."

        # Process summary component
        html=$(substitute_placeholders templates/components/recipe-summary.html)

        # Add summary to index
        mh_index="${mh_index}${html}"

    done <<< $(echo "${page_data}" | jq '.data.allRecipe.results[]' -c)

    # Write index file
    html=$(substitute_placeholders templates/recipe-index.html)

    echo "Writing index file: $outDirRecipe/${index_filename}"
    echo "${html}" > $outDirRecipe/${index_filename}
done

# Add pager to recipe index files
echo "Adding recipe pagers"
for i in $(seq $page_number);
do
    mh_pager=""
    for j in $(seq $page_number);
    do
        if [ $i -eq $j ]; then
            mh_pager="${mh_pager}<li>${j}</li>"
        else
            filename=$(filename_for_index "$j")
            mh_pager="${mh_pager}<li><a href="${filename}">${j}</a></li>"
        fi
    done

    mh_pager="<ul>${mh_pager}</ul>"
    filename=$(filename_for_index "$i")
    html=$(substitute_placeholders $outDirRecipe/${filename})
    echo "${html}" > $outDirRecipe/${filename}
done

# Copy main page
echo "Writing main page"
cp templates/index.html output
