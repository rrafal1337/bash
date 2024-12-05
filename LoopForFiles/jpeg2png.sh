#!/bin/sh
# Converts png to jpeg replacing filename extension.
# Loop search for all png files in directory and runs imagemagick on each of them:
for i in *png
do echo "${i}"
    magick ${i} -quality 95% -resize 1280 "${i%.*}.jpeg"
done
