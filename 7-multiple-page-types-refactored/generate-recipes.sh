#!/usr/bin/env bash
# API_TOKEN must be set as an environment variable before executing this script.

# Exit on error
set -eu

. ./transforms.sh
. ./substitute-placeholders.sh
. ./naming.sh
. ./data.sh

outDir=output/recipe
mkdir $outDir

# Get recipe page data from CH ONE
query=$(cat query/getRecipes.graphql)
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
        mh_name=$(url_for_name "$mh_name")
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

        echo "Writing file: $outDir/$mh_name.html"
        echo "$html" > $outDir/$mh_name.html

        # Generate summary specific fields
        mh_url=$mh_name.html
        mh_abstract=$(generate_abstract "$mh_description")

        # Process summary component
        html=$(substitute_placeholders templates/components/recipe-summary.html)

        # Add summary to index
        mh_index="${mh_index}${html}"

    done <<< $(echo "${page_data}" | jq '.data.allRecipe.results[]' -c)

    # Write index file
    html=$(substitute_placeholders templates/recipe-index.html)

    echo "Writing index file: $outDir/${index_filename}"
    echo "${html}" > $outDir/${index_filename}
done

# Add pager to recipe index files
echo "Adding recipe pagers"
substitute_pagers $page_number
