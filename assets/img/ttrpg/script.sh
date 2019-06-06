for file in *.jpg; do
    echo "converting $file"
    convert "$file" -resize 30% "$file"
done
