#For every file in the directory supplied as an argument, or the current working direcory if none supplied
#TAR, Compress, split into 1 GB chunks, and upload to WallerGroup Team Drive
#WallerTeamDrive:/data/USERNAME/DIRNAME/FILEORFOLDER_split
#suggested use: the parent dir is the date folder (i.e. 2018-6-8 some data collection)
#subdirectories are folders or files to be sent to cloud

if [ $# -eq 0 ]; then
    DIRPATH="$(pwd)"
else
	DIRPATH="$1"
	#add trainling slash if needed
	[[ "${DIRPATH}" != */ ]] && DIRPATH="${DIRPATH}/"
fi

#just the folder name, not absolute path
DIRNAME="$(basename "$DIRPATH")"

for file in "$DIRPATH"/*; do
  echo "Processing:   $file"
  wallercloudupload.sh "$file" "$USER/$DIRNAME"
done
