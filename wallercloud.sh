#!/bin/bash

function uploadFile() {
  if [ $# -eq 0 ]; then
      PATHTOCOMPRESS="$(pwd)"
  else
  	PATHTOCOMPRESS="$2"
  fi
  if [ $# -eq 2 ]; then
      CLOUDDIR="$3"
  else
  	CLOUDDIR="$WALLER_CLOUD_USERNAME"
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
}

function uploadDirectory() {
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
    wallercloudupload.sh "$file" "$WALLER_CLOUD_USERNAME/$DIRNAME"
  done
}

function downloadFile() {
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
  	pv "${FILENAME}" | pigz -dc - | tar -xf -

  	#delete the compressed version
  	echo "Deleting compressed version..."
  	rm "${FILENAME}"
  	echo "Finished"
  else
  	echo "Error: SHA1s don't match"
  fi
}

function downloadDirectory() {
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
}

function show_help() {
  echo "USAGE:"
  echo "   wallercloud --ls [dir]  :   Lists all files in a remote dir."
  echo "   wallercloud --ping (-p) :   Pings the remote server."
  echo "   wallercloud --download (-d) :   Downloads a path/file the remote server."
  echo "   wallercloud --upload (-u) :   Downloads a path/file the remote server."
}

function list_dir() {
  rclone lsd wallercloud:
}

# Check if username is set
if [ -z ${WALLER_CLOUD_USERNAME+x} ];
  then echo "Waller is unset in bash_profile!\n
             You can make this go away by adding the line:

             export WALLER_CLOUD_USERNAME=Oski

             to your ~/.bash_profile variable (on OSX) or ~/.bashrc on Linux.

             For now, please provide your username (the name of the folder we'll upload data to by default):";

             echo -n "Enter Username / foldername for uploads: "
             read WALLER_CLOUD_USERNAME

  else echo "Using remote username '$WALLER_CLOUD_USERNAME'"; fi


POSITIONAL=()
while [[ $# -gt 0 ]]
do
key="$1"


case $key in
    -d|--download)
    downloadFile
    shift # past argument
    shift # past value
    ;;
    -r|--downloaddir)
    downloadDirectory
    shift # past argument
    shift # past value
    ;;
    -u|--upload)
    uploadFile
    shift # past argument
    shift # past value
    ;;
    -l|--uploadall)
    uploadDirectory
    shift # past argument
    shift # past value
    ;;
    -h|--help)
    show_help
    shift # past argument
    shift # past value
    ;;
    ls|--list)
    list_dir
    shift # past argument
    shift # past value
    ;;
    --default)
    DEFAULT=YES
    shift # past argument
    ;;
    *)    # unknown option
    POSITIONAL+=("$1") # save it in an array for later
    shift # past argument
    ;;
esac
done
set -- "${POSITIONAL[@]}" # restore positional parameters

# echo FILE EXTENSION  = "${EXTENSION}"
# echo SEARCH PATH     = "${SEARCHPATH}"
# echo LIBRARY PATH    = "${LIBPATH}"
# echo DEFAULT         = "${DEFAULT}"
# echo "Number files in SEARCH PATH with EXTENSION:" $(ls -1 "${SEARCHPATH}"/*."${EXTENSION}" | wc -l)

if [[ -n $1 ]]; then
    echo "Last line of file specified as non-opt/last argument:"
    tail -1 "$1"
fi
