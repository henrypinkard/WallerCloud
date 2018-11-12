#!/bin/bash
#
# function setup() {
#
# }

# Set split size to 100mb (100,000,000 bytes)
FILE_SPLIT_THRESHOLD=100000000

function uploadFile() {

  # Get local directory
  LOCAL_FILE="$1"

  # Expand ~ character
  LOCAL_FILE="${LOCAL_FILE/#\~/$HOME}"

  # Get basename
  LOCAL_FILE_BASENAME="$(basename "$LOCAL_FILE")"

  # Get remote directory
  if [ $# -eq 2 ]; then
      CLOUD_DIR="wallercloud:$3"
  else
  	CLOUD_DIR="wallercloud:$WALLER_CLOUD_USERNAME"
  fi

  # Clean up tmp directory and make
  rm -rf /tmp/wallercloud/
  mkdir -p /tmp/wallercloud/

  #Compress all files in foldername to here
  COMPRESSED_FILE_PATH="/tmp/wallercloud/$LOCAL_FILE_BASENAME.tar.gz"

  # Make a temporary directory for split files
  SPLIT_DIR="/tmp/wallercloud/$LOCAL_FILE_BASENAME"_split
  rm -rf "$SPLIT_DIR"
  mkdir "$SPLIT_DIR"

  # Check size
  echo $LOCAL_FILE
  if [[ $(find "$LOCAL_FILE" -type f -size +"$FILE_SPLIT_THRESHOLD"c 2>/dev/null) ]]; then

    # tar and compress while showing progress
    echo "Compressing, hashing, and splitting file"

    #change directory so long paths dont appear in archive
    REMOTE_FILENAME="$(REMOTE_FILENAME "$LOCAL_FILE")"/
    RELATIVEPATH=${LOCAL_FILE#"$REMOTE_FILENAME"}
    tar cf - -C "$REMOTE_FILENAME" "$RELATIVEPATH" | pv -s $(du -sk "$LOCAL_FILE" | awk '{print $1}')k | pigz -4 - | tee >(shasum > "${SPLIT_DIR}/${RELATIVE_NAME}_sha1.txt") | split -b 1024m - "${SPLIT_DIR}/${RELATIVE_NAME}_fragment"

    #upload
    CLOUD_PATH="$CLOUD_DIR/${LOCAL_FILE_BASENAME}_split"
    echo "Copying to: $CLOUD_PATH"
    rclone copy "$SPLIT_DIR" "$CLOUD_PATH" -v
  else
    # Upload file without chunking
    CLOUD_PATH="$CLOUD_DIR/${LOCAL_FILE_BASENAME}"
    echo "Copying $LOCAL_FILE_BASENAME to: $CLOUD_PATH"
    rclone copy "$LOCAL_FILE" "$CLOUD_PATH" -v
  fi

  #Delete temp files--compressed file and split files
  echo "Cleaning up..."
  rm -rf "$COMPRESSED_FILE_FULL_PATH"
  rm -rf "$SPLIT_DIR"
  echo "Complete."
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
  REMOTE_FILENAME="$(basename "$DIRPATH")"

  for file in "$DIRPATH"/*; do
    echo "Processing:   $file"
    uploadFile "$file" "$WALLER_CLOUD_USERNAME/$REMOTE_FILENAME"
  done
}

function downloadFile() {

  # Remote path (relative to user folder)
  REMOTE_PATH=$1

  # Get download folder
  WALLER_CLOUD_DOWNLOAD_FOLDER=$2

  # Check if download location is set or if downlaod directory is provided
  if [ -z ${WALLER_CLOUD_DOWNLOAD_FOLDER} ];
    then echo "Download folder is unset in bash_profile!\n
               You can make this go away by adding the line:

               export WALLER_CLOUD_DOWNLOAD_FOLDER=~/Downloads

               to your ~/.bash_profile variable (on OSX) or ~/.bashrc on Linux.

               You can also specifiy the download folder as a second argument:

               wallercloud -d data/data.tiff ~/Downloads

               Where ~/Downloads is the output directory.

               For now, please provide a download folder:";

               echo -n "Enter local download folder: "
               read WALLER_CLOUD_DOWNLOAD_FOLDER

    else echo "Downloading to folder: '$WALLER_CLOUD_DOWNLOAD_FOLDER'"; fi

  # Generate correct full path
  REMOTE_PATH_FULL="wallercloud:$WALLER_CLOUD_USERNAME/$REMOTE_PATH"}"

  # Define temp directory to hold split files
  REMOTE_FILENAME="$(basename "$REMOTE_PATH")"

  # Determine if file exists as a split file or a normal (unsplit) file

  # download and reconstruct raw magellan

  # experiment name
  PREFIX="${REMOTE_FILENAME%_split}"
  FILENAME="${PREFIX}.tar.gz"

  #create experiment date folder
  echo "Checking size..."
  SIZE=$(rclone size "wallercloud:$REMOTE_PATH" | awk 'FNR == 2 {print $5}' | cut -d'(' -f 2)
  echo "Downloading..."
  #download and concatenate into single compressed file
  rclone --include "*_fragment*" cat "wallercloud:$REMOTE_PATH" | pv -s $SIZE > "${FILENAME}"
  #download hash of file
  rclone --include "*sha1.txt" copy "wallercloud:$REMOTE_PATH" "."
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
  	# rm "${FILENAME}"
  	echo "Finished"
  else
  	echo "Error: SHA1s don't match"
  fi
}

function downloadDirectory() {

  # Build directory path
  DIRPATH="wallercloud:$WALLER_CLOUD_USERNAME/$1"

  # Remove trailing slash if present
  length=${#DIRPATH}
  last_char=${DIRPATH:length-1:1}
  [[ $last_char == "/" ]] && DIRPATH=${DIRPATH:0:length-1}; :

  # Build relative path
  RELATIVE_NAME="$(basename "$DIRPATH")"

  # Ensure relative path doesn't already exist
  if [ -d "$RELATIVE_NAME" ]; then
    echo
    echo Path $RELATIVE_NAME exists, exiting.
    exit 0
  fi

  # Make directory
  mkdir "$RELATIVE_NAME"
  cd "$RELATIVE_NAME"

  # Dont split on whitespace
  IFS=$'\n'
  for file in $(rclone lsf "$DIRPATH"); do
    echo "Processing:   $DIRPATH/$file"
    downloadFile "$DIRPATH/$file"
  done
  unset IFS
}

function check_username() {
  # Check if username is set
  if [ -z ${WALLER_CLOUD_USERNAME+x} ];
    then echo "WALLER_CLOUD_USERNAME is unset in bash_profile!\n
               You can make this go away by adding the line:

               export WALLER_CLOUD_USERNAME=Oski

               to your ~/.bash_profile variable (on OSX) or ~/.bashrc on Linux.
               (If you're using zsh, add it to ~/.zshrc instead.)

               For now, please provide your username (the name of the folder we'll upload data to by default):";

               echo -n "Enter remote username / foldername for uploads: "
               read WALLER_CLOUD_USERNAME

    else echo "Using remote username '$WALLER_CLOUD_USERNAME'"; fi
}

function show_help() {
  echo "USAGE:"
  echo "   wallercloud --ls [dir]  :   Lists all files in a remote dir."
  echo "   wallercloud --download (-d) :   Downloads a path/file the remote server."
  echo "   wallercloud --upload (-u) :   Downloads a path/file the remote server."
}

# List directories on remote
function list_dir() {
  rclone lsd wallercloud:${WALLER_CLOUD_USERNAME}/$1
}

# Show help if command is passed with no arguments
if [[ $# -eq 0 ]] ; then
    show_help
    exit 0
fi

POSITIONAL=()
while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    -d|--download)
    # Check username
    check_username

    downloadDirectory $2
    # if [[ -d $2 ]]; then
    #     downloadDirectory $2
    # elif [[ -f $2 ]]; then
    #     downloadFile $2
    # else
    #     echo "$2 is not a valid path to a file or directory!"
    #     exit 1
    # fi
    shift # past argument
    shift # past value
    ;;
    -u|--upload)
    # Check username
    check_username

    if [[ -d $2 ]]; then
        echo HERE1
        uploadDirectory $2
    elif [[ -f $2 ]]; then
        uploadFile $2
    else
        echo "$2 is not a valid path to a file or directory!"
        exit 1
    fi
    shift # past argument
    shift # past value
    ;;
    -h|--help)
    show_help
    shift # past argument
    shift # past value
    ;;
    -s|--setup)
    setup
    shift # past argument
    shift # past value
    ;;
    ls|--ls)
    # Check username
    check_username

    list_dir $2
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



if [[ -n $1 ]]; then
    echo "Last line of file specified as non-opt/last argument:"
    tail -1 "$1"
fi
