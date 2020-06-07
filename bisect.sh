
# config
declare -a indirs=("draft" "raw")
declare -a scales=("95%" "90%" "85%" "80%" "75%" "70%" "65%" "60%" "55%" "50%" "45%" "40%")
limit=5242880

# get directory of the script as default working directory
currdir=$(dirname "${BASH_SOURCE[0]}")

# set working directory to argument 1 if it exists
if [[ "$#" -gt 0 ]] ; then
    currdir="$1"

    # set crop mode
    if [[ ! -z "$2" ]]; then
        arg_crop="-crop 100%x100%+0-${2}"
    fi
fi

# validate working directory
if [[ ! -e "$currdir" ]] ; then
    printf "working directory '%s' not exists\n" "$currdir"
    exit 1
elif [[ ! -d "$currdir" ]] ; then
    printf "working directory '%s' exists but is not a directory\n" "$currdir"
    exit 2
else
    printf "set working directory to '%s'\n" "$currdir"
fi

# find the valid input directory
indir=""
for dir in "${indirs[@]}"
do
    indir="$currdir"/"$dir"
    if [[ -d "$indir" ]] ; then
        break
    else
        indir=""
    fi
done

if [[ -z "$indir" ]]; then
    printf "failed to find any input directory\n"
    exit 3
fi
printf "set input directory to '%s'\n" "$indir"

# create output directory
outdir="$currdir"/submit
if [[ ! -e "$outdir" ]] ; then
    if [[ ! -z "$outdir" ]] ; then
        mkdir -p "$outdir"
    fi
elif [[ ! -d "$outdir" ]] ; then
    printf "output directory '%s' exists but is not a directory\n" "$outdir"
    exit 4
fi
printf "set output directory to '%s'\n" "$outdir"

# attempt to convert images into smaller ones
for infile in "$indir"/*.jpg
do
    outfile="$outdir"/"${infile##*/}"
    insize=$(stat -f%z "$infile")
    if [ "$insize" -le "$limit" ]; then
        if [[ -z "$arg_crop" ]]; then
            cp "$infile" "$outfile"
            printf "copy as %s\n" "$outfile"
        else
            convert "$infile" $arg_crop "$outfile"
            printf "crop as %s\n" "$outfile"
        fi
    else
        for scale in "${scales[@]}"
        do
            convert "$infile" $arg_crop -scale "$scale" "$outfile"
            outsize=$(stat -f%z "$outfile")
            if [ "$outsize" -le "$limit" ]; then
                printf "best compression rate is %s for %s\n" "$scale" "$outfile"
                break
            fi
        done
    fi
done
