#TAR, Compress, split into 1 GB chunks, and upload to WallerGroup Team Drive
#Compress argument (either file or folder), send it to #WallerTeamDrive:/data/USERNAME/FILEORFOLDER_split
#0 arguments: compress current direcotry and send to default path in wallercloud
#1 argument: the path of file or directory to compress
#2 argspuments: path to crompress, custom path in wallercloud

if [ $# -eq 0 ]; then
    PATHTOCOMPRESS="$(pwd)"
else
	PATHTOCOMPRESS="$1"
fi
if [ $# -eq 2 ]; then
    CLOUDDIR="$2"
else
	CLOUDDIR="$USER"
fi

RELATIVENAME="$(basename "$PATHTOCOMPRESS")"

#Compress all files in foldername to here
COMPRESSEDFILEFULLPATH="$PATHTOCOMPRESS.tar.gz"

SPLITDIR="$PATHTOCOMPRESS"_split
mkdir "$SPLITDIR"

# tar and compress while showing progress
echo "Compressing, hashing, and splitting file"
#change directory so long paths dont appear in archive
DIRNAME="$(dirname "$PATHTOCOMPRESS")"/
RELATIVEPATH=${PATHTOCOMPRESS#"$DIRNAME"}
tar cf - -C "$DIRNAME" "$RELATIVEPATH" | pv -s $(du -sk "$PATHTOCOMPRESS" | awk '{print $1}')k | pigz -4 - | tee >(shasum > "${SPLITDIR}/${RELATIVENAME}_sha1.txt") | split -b 1024m - "${SPLITDIR}/${RELATIVENAME}_fragment"

#upload
CLOUDPATH="wallercloud:$CLOUDDIR/${RELATIVENAME}_split"
echo "Copying to: $CLOUDPATH"
rclone copy "$SPLITDIR" "$CLOUDPATH" -v

#Delete temp files--compressed file and split files
echo "Cleaning up..."
rm -rf "$COMPRESSEDFILEFULLPATH"
rm -rf "$SPLITDIR"
echo "Complete"