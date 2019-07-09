#!/bin/bash


function uploadPath() {

  # Get local directory
  LOCAL_PATH="$1"
  # Expand ~ character
  LOCAL_PATH="${LOCAL_PATH/#\~/$HOME}"
  # Get basename
  BASENAME="$(basename "$LOCAL_PATH")"

  # Get remote directory
  if [ $# -eq 2 ]; then
    #second argument, if provided, gives a relative path for upload
    REMOTE_PARENT_DIR="wallercloud:${WALLER_CLOUD_USERNAME}/$2/${BASENAME}_split"
  else
    REMOTE_PARENT_DIR="wallercloud:${WALLER_CLOUD_USERNAME}/${BASENAME}_split"
  fi
  echo "Uploading to:  $REMOTE_PARENT_DIR"

  #make temporary folder for upload and download
  TMPDIR="$(dirname "$LOCAL_PATH")/${BASENAME}_tmp"
  rm -rf "$TMPDIR"
  mkdir "$TMPDIR"

  #Compress all files in foldername to here
  LOCAL_COMPRESSED_FILE_PATH="$TMPDIR/$BASENAME.tar.gz"

  # Make a temporary directory for split files
  LOCAL_SPLIT_DIR="$TMPDIR/$BASENAME"_split
  mkdir -p "$LOCAL_SPLIT_DIR"

  # tar and compress while showing progress
  echo "Compressing, hashing, and splitting file"
  #change directory so long paths dont appear in archive
  LOCAL_PARENT_DIR="$(dirname "$LOCAL_PATH")"/
  LOCAL_RELATIVE_PATH=${LOCAL_PATH#"$LOCAL_PARENT_DIR"}
  #alias this because they have different names on linux and mac
  alias shasum=sha1sum
  tar cf - -C "$LOCAL_PARENT_DIR" "$LOCAL_RELATIVE_PATH"  | pv -s $(du -sk "$LOCAL_PATH" | awk '{print $1}')k | pigz -4 - | tee >(shasum > "${LOCAL_SPLIT_DIR}/${BASENAME}_sha1.txt") | split -b 1024m - "${LOCAL_SPLIT_DIR}/${BASENAME}_fragment"

  #delete tar gz file
  rm -rf "$LOCAL_COMPRESSED_FILE_PATH"

  #upload
  CLOUD_PATH="$REMOTE_PARENT_DIR/${BASENAME}_split"
  echo "Copying to: $REMOTE_PARENT_DIR"
  rclone copy "$LOCAL_SPLIT_DIR" "$REMOTE_PARENT_DIR" -v
  #Delete temp files--compressed file and split files
  echo "Cleaning up..."
  rm -rf "$TMPDIR"
  echo "Complete."
}

function uploadAll() {
  #Call uploadPath on all files in direcotry and supply a second argument to 
  #uoloadPath so that it puts each one into relative path determined by the 
  #first argument to this function
  if [ $# -eq 0 ]; then
      DIRPATH="$(pwd)"
  else
  	DIRPATH="$1"
  	#add trailing slash if needed
  	[[ "${DIRPATH}" != */ ]] && DIRPATH="${DIRPATH}/"
  fi

  #just the folder name, not absolute path
  REMOTE_DIR="$(basename "$DIRPATH")"

  for file in "$DIRPATH"*; do
    echo "Processing:   $file"
    uploadPath "$file" "$REMOTE_DIR"
  done
}

function downloadOnly() {
  # Remote path (relative to user folder)
  REMOTE_PATH="$1"

  # Get download folder
  WALLER_CLOUD_DOWNLOAD_FOLDER="$2"

  # Check if download location is set or if downlaod directory is provided
  if [ -z ${WALLER_CLOUD_DOWNLOAD_FOLDER} ];
    then echo "Download folder is unset in bash_profile!
               You can make this go away by adding the line:
               export WALLER_CLOUD_DOWNLOAD_FOLDER=~/Downloads
               to your ~/.bash_profile variable (on OSX) or ~/.bashrc on Linux.
               You can also specifiy the download folder as a second argument:
               wallercloud -d data/data.tiff ~/Downloads
               Where ~/Downloads is the output directory.
               For now, automatically downloading to current working direcotry:";
               WALLER_CLOUD_DOWNLOAD_FOLDER="$(pwd)"
               echo "Downloading to folder: '$WALLER_CLOUD_DOWNLOAD_FOLDER'"

  else echo "Downloading to folder: '$WALLER_CLOUD_DOWNLOAD_FOLDER'"; fi

  # Generate correct full path
  REMOTE_PATH_FULL="wallercloud:$WALLER_CLOUD_USERNAME/$REMOTE_PATH"

  # get basename that doesn't include _split suffix
  FOLDERNAME="$(basename "$REMOTE_PATH")"
  BASENAME="${FOLDERNAME%_split}"
  #download to tmp hidden folder
  TMP_DOWNLOAD_PATH="$WALLER_CLOUD_DOWNLOAD_FOLDER/${BASENAME}_tmp"
  # rm -rf "$TMP_DOWNLOAD_PATH"
  mkdir -p "$TMP_DOWNLOAD_PATH"

  TARGZ_FULLPATH="$TMP_DOWNLOAD_PATH/$BASENAME.tar.gz"
 
  #create experiment date folder
  echo "Checking size..."
  SIZE=$(rclone size "$REMOTE_PATH_FULL" | awk 'FNR == 2 {print $5}' | cut -d'(' -f 2)
  echo "Total size: "
  echo "$SIZE" | awk '{ foo = $1 / 1024 / 1024 / 1024; print foo "GB" }'
  echo "Downloading..."
  # download and concatenate into single compressed file

  # rclone --include "*_fragment*" cat "$REMOTE_PATH_FULL" | pv -s $SIZE > "$TARGZ_FULLPATH"
  rclone --include "*_fragment*" copy "$REMOTE_PATH_FULL" "$TMP_DOWNLOAD_PATH"
  #concatenate
  cat "$TMP_DOWNLOAD_PATH"/* > "$TARGZ_FULLPATH"
  #download hash of file
  rclone --include "*sha1.txt" copy "$REMOTE_PATH_FULL" "$TMP_DOWNLOAD_PATH"
}

function decompress() {
  # Remote path (relative to user folder)
  REMOTE_PATH="$1"

  # Get download folder
  WALLER_CLOUD_DOWNLOAD_FOLDER="$2"

  # Check if download location is set or if downlaod directory is provided
  if [ -z ${WALLER_CLOUD_DOWNLOAD_FOLDER} ];
    then echo "Download folder is unset in bash_profile!
               You can make this go away by adding the line:
               export WALLER_CLOUD_DOWNLOAD_FOLDER=~/Downloads
               to your ~/.bash_profile variable (on OSX) or ~/.bashrc on Linux.
               You can also specifiy the download folder as a second argument:
               wallercloud -d data/data.tiff ~/Downloads
               Where ~/Downloads is the output directory.
               For now, automatically downloading to current working direcotry:";
               WALLER_CLOUD_DOWNLOAD_FOLDER="$(pwd)"
               echo "Using data downloaded to folder: '$WALLER_CLOUD_DOWNLOAD_FOLDER'"

  else echo "Using data downloaded to folder: '$WALLER_CLOUD_DOWNLOAD_FOLDER'"; fi

  # get basename that doesn't include _split suffix
  FOLDERNAME="$(basename "$REMOTE_PATH")"
  BASENAME="${FOLDERNAME%_split}"

  #download to tmp hidden folder
  TMP_DOWNLOAD_PATH="$WALLER_CLOUD_DOWNLOAD_FOLDER/${BASENAME}_tmp"
  TARGZ_FULLPATH="$TMP_DOWNLOAD_PATH/$BASENAME.tar.gz"
 
  # compute hash on reconstructed file
  echo "Computing hash on reconstructed file"
  RECON_HASH_PATH="$TMP_DOWNLOAD_PATH/${BASENAME}_sha1_reconstructed.txt"
  # ORIG_HASH_PATH="$TMP_DOWNLOAD_PATH/${BASENAME}_sha1.txt"
  # use wildcard search to enable backwards compatibility with older versions
  ORIG_HASH_PATH="$(ls "$TMP_DOWNLOAD_PATH/"*"_sha1.txt")"
  #alias this because they have different names on linux and mac
  alias shasum=sha1sum
  # pv "${TARGZ_FULLPATH}" | shasum > "$RECON_HASH_PATH"
  shasum "${TARGZ_FULLPATH}" > "$RECON_HASH_PATH"
  #check if hashed are equal, if so clean up
  if cmp -n 40 -s "$RECON_HASH_PATH" "$ORIG_HASH_PATH" ; then
    echo "SHAs match, cleaning up..."
    #unzip and untar file, showing progress
    echo "Decompressing..."
    # pv "${TARGZ_FULLPATH}" | pigz -dc - | tar -xf -
    gzip -d < "${TARGZ_FULLPATH}" | tar xvf -
    #delete the compressed version
    echo "Deleting tmp files..."
    rm -rf "$TMP_DOWNLOAD_PATH"
    echo "Finished"
  else
    echo "Error: SHA1s don't match"
  fi
}

function download() {
  downloadOnly "$1" "$2"
  decompress "$1" "$2"
}

function downloadAll() {
  echo "$1"
  # Build directory path
  DIRPATH="$1"

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
  for file in $(rclone lsf "wallercloud:$WALLER_CLOUD_USERNAME/$DIRPATH"); do
    echo "Processing:   $DIRPATH/$file"
    download "$DIRPATH/$file"
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
  echo "   wallercloud --help   :   Shows this information."
  echo "   wallercloud --ls (-l) [dir]  :   Lists all files in a remote dir."
  echo "   wallercloud --download (-d) :   Downloads a path/file the remote server."
  echo "   wallercloud --upload (-u) [path to file or directory]:   Uploads a path/file"
  echo "   the remote server. Uses current working directory if none supplied"
  echo "   wallercloud --upload-all (-a) [path to file or directory]:   Uploads all"
  echo "   paths/files in directory the remote server. Uses current working directory if none supplied"
  echo "   wallercloud --download-only (-o) [path to file or directory]:  Only downloads and cats but doesnt check or deomcpress"
  echo "   wallercloud --decompress-extract (-x) [path to file or directory]:  used after download only"

}

# List directories on remote
function list_dir() {
  rclone lsf "wallercloud:${WALLER_CLOUD_USERNAME}/$1"
}

# Show help if command is passed with no arguments
if [[ $# -eq 0 ]] ; then
    show_help
    exit 0
fi

#loop through sets of arguments and take action
while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    -d|--download)
    # Check username
    check_username

    # Remove trailing slash if present
    ARG2="$2"
    length=${#ARG2}
    last_char=${ARG2:length-1:1}
    [[ $last_char == "/" ]] && ARG2=${ARG2:0:length-1}; :

    #assume its a directory
    if [[ "$ARG2" == *_split ]]; then
      download "$ARG2"
    else
      #its should be a directory containing a bunch of split directories
      downloadAll "$ARG2"
    fi    

    shift # past argument
    shift # past value
    ;;
    -o|--download-only)
    # Check username
    check_username

    # Remove trailing slash if present
    ARG2="$2"
    length=${#ARG2}
    last_char=${ARG2:length-1:1}
    [[ $last_char == "/" ]] && ARG2=${ARG2:0:length-1}; :

    #assume its a directory
    if [[ "$ARG2" == *_split ]]; then
      downloadOnly "$ARG2"
    else
      #its should be a directory containing a bunch of split directories
      echo "Error: download only is only implemented for split directories"
    fi    

    shift # past argument
    shift # past value
    ;;
    -x|--decompress-extract)
    # Check username
    check_username

    # Remove trailing slash if present
    ARG2="$2"
    length=${#ARG2}
    last_char=${ARG2:length-1:1}
    [[ $last_char == "/" ]] && ARG2=${ARG2:0:length-1}; :

    #assume its a directory
    if [[ "$ARG2" == *_split ]]; then
      decompress "$ARG2"
    else
      #its should be a directory containing a bunch of split directories
      echo "Error: decompress-extract is only implemented for split directories"
    fi    

    shift # past argument
    shift # past value
    ;;
    -u|--upload)
    # Check username
    check_username

    if [ $# -eq 1 ]; then
        #if no argument supplied use current working directory
        uploadPath "$(pwd)"
    elif [[ -d "$2" ]]; then 
        uploadPath "$2"
    elif [[ -f "$2" ]]; then
        uploadPath "$2"
    else
        echo "$2 is not a valid path to a file or directory!"
        exit 1
    fi
    shift # past argument
    shift # past value
    ;;
    -a|--upload-all)
    # Check username
    check_username

    if [ $# -eq 1 ]; then
        #if no argument supplied use current working directory
        uploadAll  "$(pwd)"
    elif [[ -d "$2" ]]; then 
        uploadAll "$2"
    else
        echo "$2 is not a valid path to a directory!"
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
    -l|--ls)
    # Check username
    check_username

    list_dir "$2"
    shift # past argument
    shift # past value
    ;;
esac
done


