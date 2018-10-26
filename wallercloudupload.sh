#TAR, Compress, split into 1 GB chunks, and upload to WallerGroup Team Drive
#Compress argument (either file or folder), send it to #WallerTeamDrive:/data/USERNAME/FILEORFOLDER_split

if [ $# -eq 0 ]; then
    PATHTOCOMPRESS="$(pwd)"
else
	PATHTOCOMPRESS="$1"
fi
RELATIVENAME="$(basename "$PATHTOCOMPRESS")"


#Compress all files in foldername to here
COMPRESSEDFILEFULLPATH="$PATHTOCOMPRESS.tar.gz"

# tar and compress while showing progress
# date
echo "Compressing"
tar cf - "$PATHTOCOMPRESS" | pv -s $(du -sb "$PATHTOCOMPRESS" | awk '{print $1}') | pigz -4 -> "$COMPRESSEDFILEFULLPATH"

# #split into 1 GB chunks for upload
# # date
# echo "Splitting file..."
SPLITDIR="$PATHTOCOMPRESS"_split
mkdir "$SPLITDIR"
split -b 1024m "$COMPRESSEDFILEFULLPATH" "${SPLITDIR}/${RELATIVENAME}_fragment"

#Hash
# date
echo "Computing SHA1..."
rclone sha1sum "$COMPRESSEDFILEFULLPATH" > "${SPLITDIR}/${RELATIVENAME}_sha1.txt"

#upload
# date
# echo "Copying to: $CLOUDPATH"
CLOUDPATH="wallercloud:$USER/${RELATIVENAME}_split"
rclone copy "$SPLITDIR" "$CLOUDPATH" -v

#Delete temp files--compressed file and split files
# date
echo "Cleaning up..."
rm -rf "$COMPRESSEDFILEFULLPATH"
rm -rf "$SPLITDIR"
echo "Complete"