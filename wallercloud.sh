#!/bin/bash

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


POSITIONAL=()
while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    -d|--download)
    ./wallerclouddownload.sh "$2"
    shift # past argument
    shift # past value
    ;;
    -a|--downloadall)
    ./wallerclouddownloadall.sh "$2"
    shift # past argument
    shift # past value
    ;;
    -u|--upload)
    ./wallercloudupload.sh "$2"
    shift # past argument
    shift # past value
    ;;
    -l|--uploadall)
    ./wallerclouduploadal.sh "$2"
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
