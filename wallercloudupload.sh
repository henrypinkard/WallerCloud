#TAR, Compress, split into 1 GB chunks, and upload to WallerGroup Team Drive
#Compress current working directory, send it to WallerCloud/data/USERNAME/PARENTDIRECTORY
#suggested use: the parent dir is the date folder

PATHTOCOMPRESS="$(pwd)"
#should be a date folder (i.e. 2018-8-3 Some data collection)
PARENTDIR="$(basename "$(dirname "$PATHTOCOMPRESS")")"
#folder corresponding to all data from a given experiment (i.e. experiment 1)
FOLDERNAME="$(basename "$PATHTOCOMPRESS")"
#Compress all files in foldername to here
COMPRESSEDFILEFULLPATH="$PATHTOCOMPRESS.tar.gz"

# tar and compress while showing progress
# date
echo "Compressing"
tar cf - "$PATHTOCOMPRESS" | pv -s $(du -sb "$PATHTOCOMPRESS" | awk '{print $1}') | pigz -4 -> "$COMPRESSEDFILEFULLPATH"

#split into 1 GB chunks for upload
# date
echo "Splitting file..."
SPLITDIR="$PATHTOCOMPRESS"_split
mkdir "$SPLITDIR"
split -b 1024m "$COMPRESSEDFILEFULLPATH" "${SPLITDIR}/${FOLDERNAME}_fragment"

#Hash
# date
echo "Computing SHA1..."
rclone sha1sum "$COMPRESSEDFILEFULLPATH" > "${SPLITDIR}/${FOLDERNAME}_sha1.txt"

#upload
# date
# echo "Copying to: $CLOUDPATH"
CLOUDPATH="wallercloud:$USER/${PARENTDIR}/${FOLDERNAME}_split"
rclone copy "$SPLITDIR" "$CLOUDPATH" -v

#Delete temp files--compressed file and split files
# date
echo "Cleaning up..."
rm -rf "$COMPRESSEDFILEFULLPATH"
rm -rf "$SPLITDIR"
echo "Complete"