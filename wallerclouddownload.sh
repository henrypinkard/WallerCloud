 #script for downloading a bunch of partial files from google drive, recombining them, and checking their
#hash to make sure it worked correctly
#This script should be run from the master data folder. It will create an experiment name folder if 
#needed, and place the HDF file in there

#Full path inclding gdrive (from root that rclone sees) e.g. gdrive:Leukosight/2018-6-6 Experiment folder/experiment name
DIRFULLPATH=$1
#remove gdrive if there
DIRFULLPATH="${DIRFULLPATH#"gdrive:"}"
#name of dirctory that holds split files
DIRNAME="$(basename "$DIRFULLPATH")"
#path (relative to Data on Google drive) of parent dir
PARENTDIRNAME="$(basename "$(dirname "$DIRFULLPATH")")"

#check if its and HDF file or a raw magellan file
if [[ "$DIRNAME" == *magellan_split ]]
  	then  
  	# download and reconstruct raw magellan
	# experiment name
	PREFIX="${DIRNAME%_magellan_split}"
	FILENAME="${PREFIX}.tar.gz"
	#create experiment date folder
	mkdir "$PARENTDIRNAME"
	echo "Checking size..."
	SIZE=$(rclone size "gdrive:$DIRFULLPATH" | awk 'FNR == 2 {print $5}' | cut -d'(' -f 2)
	echo "Downloading..."
	#download and concatenate into single compressed file
	rclone --include "*_fragment_*" cat "gdrive:$DIRFULLPATH" | pv -s $SIZE > "${PARENTDIRNAME}/${FILENAME}"
	#download hash of file
	rclone --include "*sha1.txt" copy "gdrive:$DIRFULLPATH" "./${PARENTDIRNAME}"
	#compute hash on reconstructed file
	echo "Computing hash on reconstructed file"
	#alias this because they have different names on linux and mac
	alias sha1sum=shasum
	pv "${PARENTDIRNAME}/${FILENAME}" | sha1sum > "${PARENTDIRNAME}/${PREFIX}_sha1_reconstructed.txt"
	#check if hashed are equal, if so clean up
	if cmp -n 40 -s "${PARENTDIRNAME}/${PREFIX}_sha1_reconstructed.txt" "${PARENTDIRNAME}/${PREFIX}_sha1.txt" ;
	then
		echo "SHAs match, cleaning up..."
		#delete hash file
		rm "${PARENTDIRNAME}/${PREFIX}_sha1_reconstructed.txt"
		rm "${PARENTDIRNAME}/${PREFIX}_sha1.txt"
		#unzip and untar file, showing progress
		# echo "Decompressing..."
		# pv "${PARENTDIRNAME}/${FILENAME}" | pigz -dc - | tar -xf - -C "${PARENTDIRNAME}/"
		# #delete the compressed version
		# echo "Deleting compressed version..."
		# rm "${PARENTDIRNAME}/${FILENAME}"
		# echo "Finished"
	else
		echo "Error: SHA1s don't match"
	fi	

elif [[ "$DIRNAME" == *split ]]
	then
	# download and reconstruct hdf file
	#experiment name
	PREFIX="${DIRNAME%_split}"
	#HDF filename
	FILENAME="${PREFIX}.hdf"
	#Download all to current folder
	rclone copy "gdrive:$DIRFULLPATH" "./${PARENTDIRNAME}/tmp" -v
	echo "Reconstructing fragments"
	#reconstruct
	cat "${PARENTDIRNAME}/tmp/${PREFIX}_fragment_"* > "${PARENTDIRNAME}/${FILENAME}"
	#compute hash on reconstructed file
	echo "Computing hash on reconstructed file"
	rclone sha1sum "${PARENTDIRNAME}/${FILENAME}" > "${PARENTDIRNAME}/${PREFIX}_sha1_reconstructed.txt"
	#check if hashed are equal, if so clean up
	if cmp -s "${PARENTDIRNAME}/${PREFIX}_sha1_reconstructed.txt" "${PARENTDIRNAME}/tmp/${PREFIX}_sha1.txt" ;
	then
		echo "SHAs match, cleaning up"
		#delete hash file
		rm "${PARENTDIRNAME}/${PREFIX}_sha1_reconstructed.txt"
		#delete partial file and the directory that held them
		rm -rf "./${PARENTDIRNAME}/tmp"
	else
		echo "Error: SHA1s don't match"
	fi
else
	echo "Unexpected folder suffix, should be _split or _magellan_split"
fi

