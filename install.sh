#/bin/bash

for file in ./*.sh
do
    if [[ -f $file ]]; then
      filename=$(basename -- "$file")
      cp $file /usr/local/bin/${filename%.*}
    fi
done
