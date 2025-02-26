#!/usr/bin/env bash
# API_TOKEN must be set as an environment variable before executing this script.

# Exit on error
set -eu

. ./transforms.sh
. ./substitute-placeholders.sh
. ./naming.sh
. ./data.sh

outDir=output

# Clear the output directory
if [ -d $outDir ]; then
    rm -rf $outDir
fi
mkdir $outDir

# Generate sidebar
export mh_sidebar=$(cat templates/components/site-links.html)
query=$(cat query/getLatestBlogPosts.graphql)
query="$(echo $query)"
page_data=$(execute_graphql "${query}" "")
mh_posts=""

while read -r post
do
    # Extract individual fields
    {
        read mh_name;
        read mh_publish_date;
        read mh_title;
        read mh_content;
        read mh_raw_categories;
    } <<< $(echo ${post} | jq -r -c '.name, .publishDate, .title, .content, .category.results')

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

    # Generate summary specific fields
    mh_url="/blog/$mh_name.html"
    mh_abstract=$(generate_abstract "$mh_content")

    # Process summary component
    html=$(substitute_placeholders templates/components/latest-blog-post-summary.html)

    # Add summary to index
    mh_posts="${mh_posts}${html}"

done <<< $(echo "${page_data}" | jq '.data.allBlogPost.results[]' -c)

mh_latest_posts=$(substitute_placeholders templates/components/latest-blog-posts.html)
mh_sidebar="${mh_sidebar}${mh_latest_posts}"

# Generate pages
./generate-blog-posts.sh &
./generate-recipes.sh &

# Generate main page
echo "Generating index page"
mh_title="Index"
mh_body=$(cat templates/index.html)
html=$(substitute_placeholders templates/page.html)
echo "${html}" > $outDir/index.html

#echo "Writing main page"
#cp templates/index.html output

# Copy includes
echo "Copy includes"
cp -r include output

wait
