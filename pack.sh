#!/usr/bin/env bash
#
# pack powerup files for a release
#
# usage:
#  ./pack.sh DIRECTORY
#

function usage {
    cat <<EOF
usage:
    $0 [-o DIRECTORY]

    -o  output directory (defaults to /tmp)

EOF
}

RELDIR=/tmp
opt_pack_assembly=
while getopts ":o:h" o; do
  case $o in
    o)
        RELDIR=$OPTARG
        ;;
    h)
        usage
        exit 0
        ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      exit 1
      ;;
    esac
done
shift $((OPTIND-1))

# RELDIR=$1
# if [ -z "$RELDIR" ]; then
#     RELDIR=/tmp
# fi

if [ ! -d .git ]; then
    echo "*** No .git dir found. Halt!"
    exit 1
fi

RELVER=$(cat BASEDIR | sed 's/\r//')
DATEYMD=$(date "+%Y%m%d")

# Paths to files
PATH_MANIFEST=./share/MANIFEST
PATH_SKIPLIST=./skiplist
# PATH_RELZIP=$RELDIR/powerup-${DATEYMD}-${RELVER}.zip
PATH_RELZIP=$RELDIR/powerup.zip
PATH_RELPPM=$RELDIR/powerup.ppm
egrep '\/$' .gitignore | egrep -v '^\s*#' > $PATH_SKIPLIST

# Download conditionally
# cat REDIST_PSMOD.url | egrep -v '\s*#' | sed 's/\r$//' | while read fn url; do
#     if [ ! -f "share/redist/lib/PSModules/$fn" ]; then
#         echo $url
#         curl -L -o "share/redist/lib/PSModules/$fn" $url
#     fi
# done

# Generate MANIFEST
echo "" > $PATH_MANIFEST
echo BASEDIR >> $PATH_MANIFEST
echo StartHere.cmd >> $PATH_MANIFEST
find chores -type f >> $PATH_MANIFEST
find config -type f >> $PATH_MANIFEST
find share -type f >> $PATH_MANIFEST
find invoke -type f >> $PATH_MANIFEST

# # filter for redist
# if [ -z "$opt_pack_assembly" ]; then
#     find share -type f | grep -v PSAssemblies >> $PATH_MANIFEST
# else
#     find share -type f >> $PATH_MANIFEST
# fi

find lib -type f | grep -vFf $PATH_SKIPLIST >> $PATH_MANIFEST
echo 'share/MANIFEST' >> $PATH_MANIFEST
unix2dos $PATH_MANIFEST > /dev/null

# convert to dos
find lib/PSModules -name "*psm1" -o -name "*psd1" | xargs unix2dos > /dev/null
find share/samples -type f | xargs unix2dos >/dev/null
find share/examples -type f | xargs unix2dos >/dev/null
find share/templates -name "*ps1" | xargs unix2dos >/dev/null
find chores -name "*psm1" -o -name "*ps1" | xargs unix2dos >/dev/null
find config -name "*cfg" | xargs unix2dos >/dev/null
find invoke -name "*ps1" | xargs unix2dos >/dev/null
unix2dos StartHere.cmd >/dev/null

# Pack zip file
if [ -f $PATH_RELZIP ]; then
    rm -f $PATH_RELZIP
    rm -f $PATH_RELPPM >/dev/null 2>&1
fi
zip -q $PATH_RELZIP -@ < $PATH_MANIFEST
echo "*" $(cat $PATH_MANIFEST | wc -l) files in MANIFEST
echo "* release: $PATH_RELZIP"

# create ppm
cat >$PATH_RELPPM <<EOF
PACKAGE_NAME,PARAMETER,VALUE
powerup,version,$RELVER
powerup,archive_container_type,zip
powerup,repository_dir,
powerup,archive_filename,powerup.zip
powerup,archive_subdir,
powerup,package_install_dir,
EOF

# Cleanup
rm $PATH_SKIPLIST
