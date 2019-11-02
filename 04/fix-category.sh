#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

publication_file="data/publication.csv"
category_file="data/categories.csv"
pub_cat_file="data/publication_with_category.csv"

publication_cats="<article|<inproceedings|<proceedings|<book|<incollection|<phdthesis|<mastersthesis|<www|<person|<data"

n_lines=$(cat "$publication_file" | wc -l)
n_publications=$((n_lines-1))

echo 'category' > "$category_file"
grep -o -m "$n_publications" -E "$publication_cats" "data/dblp.xml" | tqdm --total "$n_publications" | tr -d '<' >> "$category_file"

sed -i '' -E 's/^/"/; s/$/"/' "$category_file"


paste -d ',' "$publication_file" "$category_file" | tqdm --total "$n_publications" > "$pub_cat_file"


rm "$category_file"
rm "$publication_file"
mv "$pub_cat_file" "$publication_file"
