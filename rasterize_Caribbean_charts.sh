#!/bin/bash
set -eu                # Always put this in Bourne shell scripts
IFS=$(printf '\n\t')  # Always put this in Bourne shell scripts
shopt -s nullglob

#1. Get Caribbean charts from https://www.faa.gov/air_traffic/flight_info/aeronav/digital_products/ifr/#caribbean
#2. Unzip the PDFs
#       unzip "*.zip"

if [ "$#" -ne 3 ] ; then
  echo "Usage: $0 SOURCE_DIRECTORY destinationRoot chartType" >&2
  exit 1
fi

#Get command line parameters
originalRastersDirectory="$1"
destinationRoot="$2"
chartType="$3"

#For files that have a version in their name, this is where the links to the lastest version
#will be stored (step 1)
linkedRastersDirectory="$destinationRoot/sourceRasters/$chartType/"

#Where expanded rasters are stored (step 2)
expandedRastersDirectory="$destinationRoot/expandedRasters/$chartType/"

#Where clipped rasters are stored (step 3)
clippedRastersDirectory="$destinationRoot/clippedRasters/$chartType/"

# #Where the polygons for clipping are stored
# clippingShapesDirectory="$destinationRoot/clippingShapes/$chartType/"



if [ ! -d "$originalRastersDirectory" ]; then
    echo "$originalRastersDirectory doesn't exist"
    exit 1
fi

if [ ! -d "$linkedRastersDirectory" ]; then
    echo "$linkedRastersDirectory doesn't exist"
    exit 1
fi

if [ ! -d "$expandedRastersDirectory" ]; then
    echo "$expandedRastersDirectory doesn't exist"
    exit 1
fi

if [ ! -d "$clippedRastersDirectory" ]; then
    echo "$clippedRastersDirectory doesn't exist"
    exit 1
fi

#Get our initial directory as it is where memoize.py is located
pushd $(dirname "$0") > /dev/null
installedDirectory=$(pwd)
popd > /dev/null

echo "Change directory to $originalRastersDirectory"
cd "$originalRastersDirectory"
#Ignore unzipping errors
set +e
#Unzip the Caribbean PDFs
echo "Unzipping $chartType files for Caribbean"
unzip -qq -u -j "delcb*.zip" "*.pdf"
#Restore quit on error
set -e

#Convert them to .tiff
for f in ENR_C[AL]0[0-9].pdf
do
    if [ -f "$f.tif" ]
	then
            echo "Rasterized $f already exists"
            continue  
	fi
    echo "--------------------------------------------"
    echo "Converting $f to raster"
    echo "--------------------------------------------"
    #Needs to point to where memoize is
    $installedDirectory/memoize.py -t \
        gs \
            -q -dQUIET -dSAFER -dBATCH -dNOPAUSE -dNOPROMPT \
            -sDEVICE=tiff24nc                               \
            -sOutputFile="$f-untiled.tif"                             \
            -r300 \
            -dTextAlphaBits=4 \
            -dGraphicsAlphaBits=4 \
            "$f"

    echo "--------------------------------------------"
    echo "Tile $f"
    echo "--------------------------------------------"
    #Needs to point to where memoize is
    $installedDirectory/memoize.py -t \
        gdal_translate \
                    -strict \
                    -co TILED=YES \
                    -co COMPRESS=LZW \
                    "$f-untiled.tif" \
                    "$f.tif"
                
    echo "--------------------------------------------"
    echo "Overviews $f"
    echo "--------------------------------------------"
    #Needs to point to where memoize is
    $installedDirectory/memoize.py -t \
        gdaladdo \
                -ro \
                -r gauss \
                --config INTERLEAVE_OVERVIEW PIXEL \
                --config COMPRESS_OVERVIEW JPEG \
                --config BIGTIFF_OVERVIEW IF_NEEDED \
                "$f.tif" \
                2 4 8 16 32 64
    
    rm "$f-untiled.tif"
    
done

exit 0






