#!/bin/bash

set -eo pipefail

# config
declare -a indirs=("draft" "raw")
declare -a scales=("95%" "90%" "85%" "80%" "75%" "70%" "65%" "60%" "55%" "50%" "45%" "40%")
limit=5242880

# get directory of the script as default working directory
currdir=$(dirname "${BASH_SOURCE[0]}")

# set working directory to argument 1 if it exists
if [[ "$#" -gt 0 ]]; then
    currdir="$1"

    # set crop mode
    if [[ ! -z "$2" ]]; then
        arg_crop="-crop 100%x100%+0-${2}"
    fi
fi

# validate working directory
if [[ ! -e "$currdir" ]]; then
    printf "working directory '%s' not exists\n" "$currdir"
    exit 1
elif [[ ! -d "$currdir" ]]; then
    printf "working directory '%s' exists but is not a directory\n" "$currdir"
    exit 2
else
    printf "set working directory to '%s'\n" "$currdir"
fi

# find the valid input directory
indir=""
for dir in "${indirs[@]}"; do
    indir="$currdir"/"$dir"
    if [[ -d "$indir" ]]; then
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
if [[ ! -e "$outdir" ]]; then
    if [[ ! -z "$outdir" ]]; then
        mkdir -p "$outdir"
    fi
elif [[ ! -d "$outdir" ]]; then
    printf "output directory '%s' exists but is not a directory\n" "$outdir"
    exit 4
fi
printf "set output directory to '%s'\n" "$outdir"

# binary search for the right size
function resize() {
    local infile="$1"
    local outfile="$2"
    local scale="$3"
    convert "$infile" $arg_crop -scale "$scale%" "$outfile"
    local outsize=$(stat -f%z "$outfile")
    echo $outsize
}

function bisect_resize() {
    local infile="$1"
    local outfile="$2"
    local low=20
    local high=100

    # check low
    local size=$(resize "$infile" "$outfile" "$low")
    if [ "$size" -gt "$limit" ]; then
        printf "can't get smaller, lowest scale is %s%% (%d)\n" "$low" "$size"
        return
    fi
    # check high
    size=$(resize "$infile" "$outfile" "$high")
    if [ "$size" -le "$limit" ]; then
        printf "no need to resize, highest scale is %s%% (%d)\n" "$high" "$size"
        return
    fi

    while true; do
        if [ $low -ge $high ] || [ $((low + 1 - high)) -eq 0 ]; then
            size=$(resize "$infile" "$outfile" "$high")
            printf "reached final scale low=$low%%, high=$high%%, got size $size\n"
            break
        fi
        local mid=$(((low + high) / 2))
        size=$(resize "$infile" "$outfile" "$mid")
        printf "attempt to resize, current scale is $mid%% ($size) of [$low, $high], "
        if [ "$size" -le "$limit" ]; then
            echo "it's too small"
            low=$((mid + 0))
        else
            echo "it's too large"
            high=$((mid - 1))
        fi
    done

    if [ "$size" -gt "$limit" ]; then
        mid=$((high - 1))
        size=$(resize "$infile" "$outfile" "$mid")
        printf "last attempt to scale at $mid%%, got size $size\n"
    fi
}

# attempt to convert images into smaller ones
for infile in "$indir"/*.jpg; do
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
        printf "compress $infile of $insize\n"
        bisect_resize "$infile" "$outfile"
    fi
done
