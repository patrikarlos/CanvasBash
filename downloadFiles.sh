#!/bin/bash
# Download student submissions from a Canvas Course.
#
# Syntax:
#      downloadFiles.sh [-v] [-h] CourseCode FolderName
# 
#
#
# Description
#
#
## Requires a CANVAS token in TOKEN
## Requires Openstack credentials to be sourced.



##
## Hard settings..
#What's the educational institutes name(site) at Instructure?
site=bth
##Change this to a larger number, if you have many students/courses.
##Used due to Canvas pagination, normally canvas returns the equivalent of 10.
##This changes it to maxEntries. However, be carefull. 
maxEntries=10000;

die() { echo "$*" >&2; exit 2; }  # complain to STDERR and exit with error
needs_arg() { if [ -z "$OPTARG" ]; then die "No arg for --$OPT option"; fi; }


if [[ $(uname) == "Linux" ]]; then
    HASHALGO=md5sum
    HASHARG=
elif [[ $(uname) == "Darwin" ]]; then
    HASHALGO=md5
    HASHARG=-q
else
    HASHALGO=md5sum
    HASHARG=--quiet
fi
    
VERBOSE=false
MISSING=false
LATE=false
created=0
added=0
DLGRADED=0;

PASSWDFILE=$(mktemp)

while getopts glmvhi:-: OPT; do
    if [ "$OPT" = "-" ]; then
	OPT="${OPTARG%%=*}"       # extract long option name
	OPTARG="${OPTARG#$OPT}"   # extract long option argument (may be empty)
	OPTARG="${OPTARG#=}"      # if long option argument, remove assigning `=`
    fi
    
    case "${OPT}" in
	m | missing)
	    MISSING=true
	    ;;
	g | graded)
	    DLGRADED=1
	    ;;
	l | late)
	    LATE=true
	    ;;	
        h)
            echo "usage: $0 [-v] [--late] [--missing] <COURSECODE> <ASSIGNMENT>" >&2
            exit 2
            ;;

        v) 
	    VERBOSE=true
	    LATE=true
	    MISSING=true
            ;;
        *)
            if [ "$OPTERR" != 1 ] || [ "${optspec:0:1}" = ":" ]; then
                echo "Non-option argument: '-${OPTARG}'" >&2
            fi
            ;;
    esac
done



shift $((OPTIND-1)) # remove parsed options and args from $@ list

courseCode=$1
folder=$2
location=$3

if [ -z $TOKEN ]; then
    echo "Your missing the Canvas API token. Grab one from your Profile page."
    exit;
fi

if [ -z "$courseCode" ]; then
    echo "Your missing the course ID, find it from Canvas."
    exit;
fi

if [ -z "$folder name" ]; then
    echo "Your missing the folder name find it from Canvas."
    exit;
fi

if [ -z "$location" ]; then
    echo "Your missing the location where to store the downloaded data."
    exit;
fi

echo  "My input; '$courseCode' / $folder / $location "



#echo "curl -H \"Authorization: Bearer $TOKEN\" \"https://$site.instructure.com/api/v1/courses/$courseID/users\" "
if [ "$VERBOSE" = true ]; then
    echo "Collecting data from Canvas."
fi

#Trying to find ID
courseData=$(curl -H "Authorization: Bearer $TOKEN" -s  "https://$site.instructure.com/api/v1/courses?enrollment_type=teacher&state=available&per_page=$maxEntries" | jq -r '.[] | {name, id}' |  jq "[.[]] | @tsv" | sed 's/\\t/*/g' | tr -d '"' | grep "^$courseCode")
courseID=$(echo "$courseData" | awk -F'*' '{print $2}')
courseString=$(echo "$courseData" | awk -F'*' '{print $1}')


found=$(echo "$courseID" | wc -l | tr -d ' ')

#echo "|$courseData|$courseID|$courseString|$found|"


if [ "$VERBOSE" = true ]; then
    echo "found $found"
fi

if [[ "$found" -gt "1" ]]; then
    echo "Too many matches, narrow your Course code."
    echo "Add semester, i.e. 'CourseCode HT22'"
    exit;
fi

if [ -z "$courseID" ]; then
    echo "Did not find a course. Check your syntax (code),|$courseCode|."
    echo "Did not find a course. Check your syntax (ID),|$courseID|."
    
    exit;
fi

#echo "Course ID: $courseID - $courseString "


data1=$(curl -H "Authorization: Bearer $TOKEN" -s  "https://$site.instructure.com/api/v1/courses/$courseID")
name=$(echo $data1 | jq '.name')
if [ "$VERBOSE" = true ]; then
    echo "Course: $name"
fi

#TEST

foldersData=$(curl -H "Authorization: Bearer $TOKEN" -s  "https://$site.instructure.com/api/v1/courses/$courseID/folders?per_page=$maxEntries" | jq -r '.[] | {full_name, id}' |  jq "[.[]] | @tsv" | sed 's/\\t/*/g' | tr -d '"')
folderData=$(echo "$foldersData" | grep "$folder")


folderID=$(echo "$folderData" | awk -F'*' '{print $2}')
folderString=$(echo "$folderData" | awk -F'*' '{print $1}')

found=$(echo "$folderID" | wc -l )
if [ "$VERBOSE" = true ]; then
    echo "found $found"
fi

if [[ "$found" -gt "1" ]]; then
    echo "Too many matches, narrow your folder identifier."
    echo "These were found based on '$folder'"
    echo "---------------------"
    echo "$folderData"
    echo "---------------------"
    
    exit;
fi

if [ -z "$folderID" ]; then
    echo "Did not find the assignment, check your syntax,|$assignment|."
    echo "You need the full name, probably within quotes."
    echo "These are the assignments for this class."
    echo "Working Org; |$foldersData|"
    echo "Working grep; |$folderData|"

    exit;
fi


echo "Course ID: $courseID - $courseString"
echo "Folder: $folderID - $folderString"



##PRODUCTION
filelist=$(curl -H "Authorization: Bearer $TOKEN" -s  "https://$site.instructure.com/api/v1/folders/$folderID/files?per_page=$maxEntries" | jq -r '.[] | {filename, id, url, size, updated_at}' |  jq "[.[]] | @tsv" | sed 's/\\t/*/g' | tr -d '"' )

while read line; do
    read -r data <<<"$(echo "$line")"

#    echo ">$data<"
    FILENAME=$(echo "$data" | awk -F'*' '{print $1}')
    FILEID=$(echo "$data" | awk -F'*' '{print $2}')
    URL=$(echo "$data" | awk -F'*' '{print $3}')
    SIZE=$(echo "$data" | awk -F'*' '{print $4}')
    UPDATEDAT=$(echo "$data" | awk -F'*' '{print $5}')

    echo "$FILENAME, $SIZE bytes, $UPDATEDAT"
    curl --location --silent --output "$location/$FILENAME" "$URL"
    
done < <(echo "$filelist") # | head -10 )


#echo "$emStrip"




