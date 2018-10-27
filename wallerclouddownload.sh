#script for downloading a bunch of partial files from waller lab team drive, recombining them, and checking 
#their hash to make sure it worked correctly

#Full path in wallercloud (from root that rclone sees) e.g. 2018-6-6 Experiment folder/experiment name
DIRFULLPATH=$1
#remove gdrive if there
DIRFULLPATH="${DIRFULLPATH#"wallercloud:"}"
#name of dirctory that holds split files
DIRNAME="$(basename "$DIRFULLPATH")"
# download and reconstruct raw magellan
# experiment name
PREFIX="${DIRNAME%_split}"
FILENAME="${PREFIX}.tar.gz"
#create experiment date folder
echo "Checking size..."
SIZE=$(rclone size "wallercloud:$DIRFULLPATH" | awk 'FNR == 2 {print $5}' | cut -d'(' -f 2)
echo "Downloading..."
#download and concatenate into single compressed file
rclone --include "*_fragment*" cat "wallercloud:$DIRFULLPATH" | pv -s $SIZE > "${FILENAME}"
#download hash of file
rclone --include "*sha1.txt" copy "wallercloud:$DIRFULLPATH" "."
#compute hash on reconstructed file
echo "Computing hash on reconstructed file"
pv "${FILENAME}" | shasum > "${PREFIX}_sha1_reconstructed.txt"
#check if hashed are equal, if so clean up
if cmp -n 40 -s "${PREFIX}_sha1_reconstructed.txt" "${PREFIX}_sha1.txt" ; then
	echo "SHAs match, cleaning up..."
	#delete hash file
	rm "${PREFIX}_sha1_reconstructed.txt"
	rm "${PREFIX}_sha1.txt"
	#unzip and untar file, showing progress
	echo "Decompressing..."
	# pv "${FILENAME}" | pigz -dc - | tar -xf - -C "${PARENTDIRNAME}/"
	pv "${FILENAME}" | pigz -dc - | tar -xf - 

	#delete the compressed version
	echo "Deleting compressed version..."
	rm "${FILENAME}"
	echo "Finished"
else
	echo "Error: SHA1s don't match"
fi	


