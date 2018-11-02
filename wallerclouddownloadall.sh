#Download and reconstruct a bunch of seperately split files/sirectories

DIRPATH="$1"
#remove trailing slash if presetn
length=${#DIRPATH}
last_char=${DIRPATH:length-1:1}
[[ $last_char == "/" ]] && DIRPATH=${DIRPATH:0:length-1}; :


RELATIVENAME="$(basename "$DIRPATH")"

mkdir "$RELATIVENAME"
cd "$RELATIVENAME"

#dont split on whitespace
IFS=$'\n'
for file in $(rclone lsf "$DIRPATH"); do
  echo "Processing:   $DIRPATH/$file"
  wallerclouddownload.sh "$DIRPATH/$file" 
done
unset IFS
