#!/bin/bash
# Download student submissions from a Canvas Course.
#
# Syntax:
#       gradeStatus.sh [-v] [-h] CourseCode AssignmentID
# 
#
#
# Description
# Checks the status for each student.
# Status can be, graded, ungraded+submitted, not-submitted.
#
# Options;
# --late | -l    Late submissions, right now does not do anything.
#                Might change in later versions. 
# --missing | -m Deal with missing submissions.
#                It just prints those that did not submit.
# --verbose | -v Verbose output, enables also late + missing. 
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



VERBOSE=false
MISSING=false
LATE=false
created=0
added=0
DRYRUN=0

if [[ $(uname) == *"Linux" ]];then 
    MD5TOOL='md5sum '
fi
if [[ $(uname) == *"Darwin" ]];then 
    MD5TOOL='md5 -q'
fi

while getopts dlmvhi:-: OPT; do
    if [ "$OPT" = "-" ]; then
	OPT="${OPTARG%%=*}"       # extract long option name
	OPTARG="${OPTARG#$OPT}"   # extract long option argument (may be empty)
	OPTARG="${OPTARG#=}"      # if long option argument, remove assigning `=`
    fi
    
    case "${OPT}" in
	m | missing)
	    MISSING=true
	    ;;
	d | dryrun)
	    DRYRUN=1
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
assignment=$2


if [ -z $TOKEN ]; then
    echo "Your missing the Canvas API token. Grab one from your Profile page."
    exit;
fi

if [ -z "$courseCode" ]; then
    echo "Your missing the course ID, find it from Canvas."
    exit;
fi

if [ -z "$assignment" ]; then
    echo "Your missing the assignment ID, find it from Canvas."
    exit;
fi

echo  "My input; '$courseCode' / $assignment "



#echo "curl -H \"Authorization: Bearer $TOKEN\" \"https://$site.instructure.com/api/v1/courses/$courseID/users\" "
if [ "$VERBOSE" = true ]; then
    echo "Collecting data from Canvas."
fi

#Trying to find ID
courseData=$(curl -H "Authorization: Bearer $TOKEN" -s  "https://$site.instructure.com/api/v1/courses?enrollment_type=teacher&state=available&per_page=$maxEntries" | jq -r '.[] | {name, id}' |  jq "[.[]] | @tsv" | sed 's/\\t/*/g' | tr -d '"' | grep "^$courseCode")
courseID=$(echo "$courseData" | awk -F'*' '{print $2}')
courseString=$(echo "$courseData" | awk -F'*' '{print $1}')


found=$(echo "$courseID" | wc -l | tr -d ' ')

echo "|$courseData|$courseID|$courseString|$found|"


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
assignmentData=$(curl -H "Authorization: Bearer $TOKEN" -s  "https://$site.instructure.com/api/v1/courses/$courseID/assignments?per_page=$maxEntries" | jq -r '.[] | {name, id}' |  jq "[.[]] | @tsv" | sed 's/\\t/*/g' | tr -d '"' | grep "^$assignment\*" )

if [ -z "$assignmentData" ]; then
    echo "Did not find the 'assignment_string', checking ID." 
    assignmentData=$(curl -H "Authorization: Bearer $TOKEN" -s  "https://$site.instructure.com/api/v1/courses/$courseID/assignments?per_page=$maxEntries" | jq -r '.[] | {name, id}' |  jq "[.[]] | @tsv" | sed 's/\\t/*/g' | tr -d '"' | grep "$assignment" )
    
    echo "$assignmentData"
    echo "--------------"
fi



assignmentID=$(echo "$assignmentData" | awk -F'*' '{print $2}')
assignmentString=$(echo "$assignmentData" | awk -F'*' '{print $1}')

found=$(echo "$assignmentID" | wc -l )
if [ "$VERBOSE" = true ]; then
    echo "found $found"
fi

if [[ "$found" -gt "1" ]]; then
    echo "Too many matches, narrow your assignment identifier."
    echo "Add semester, i.e. 'CourseCode HT22'"
    exit;
fi

if [ -z "$assignmentID" ]; then
    echo "Did not find the assignmen. Check your syntax,|$assignment|."
    exit;
fi


echo "Course ID: $courseID - $courseString  Assignment: $assignmentID - $assignmentString"

## Grab student id + names.
##PRODUCTION
data=$(curl -H "Authorization: Bearer $TOKEN" -s  "https://$site.instructure.com/api/v1/courses/$courseID/users?per_page=$maxEntries")

emails=$(echo "$data" | jq ".[].email" | tr -d '"')
names=$(echo "$data" | jq ".[].name" | tr -d '"')
studids=$(echo "$data" | jq ".[].name" | tr -d '"')


emname=$(echo "$data" | jq ".[] | {id,email,name}"  | jq "[.[]] | @csv" |  sed 's|\\\"||g' | sed 's|,|\",\"|g') # | tr -d '\\' | tr ',' ' ' )
#echo "$emname"
emStrip=$(echo "$emname" | awk -F',' '{print $1","$2","$3}' | tr -d '"')
#echo "$emname"

echo "$emStrip" > bobby
echo "$emname" > bob

cnt=$(echo "$emStrip" | wc -l | tr -d ' ') 

submissions=$(curl -H "Authorization: Bearer $TOKEN" -s  "https://$site.instructure.com/api/v1/courses/$courseID/assignments/$assignmentID/submissions?per_page=$maxEntries" | jq | grep 'submitted_at' | grep -v 'null' | wc -l | tr -d ' ')

studSubmitted=$(curl -H "Authorization: Bearer $TOKEN" -s  "https://$site.instructure.com/api/v1/courses/$courseID/assignments/$assignmentID/submissions?per_page=$maxEntries" | jq ".[] | {user_id} | to_entries|map(.value)|@csv" | sed 's|\\\"||g' | sed 's|,|\",\"|g')
#reqGrading=$(echo "$studReqGrading" | wc -l | tr -d ' ')

subStatus=$(curl -H "Authorization: Bearer $TOKEN" -s  "https://$site.instructure.com/api/v1/courses/$courseID/assignments/$assignmentID/submission_summary" | jq )
graded=$(echo "$subStatus" | grep 'graded' | grep -v 'ungraded' | awk -F':' '{print $2}')
ungraded=$(echo "$subStatus" | grep 'ungraded' |  awk -F':' '{print $2}')
notsubmitted=$(echo "$subStatus" | grep 'not_submitted' | awk -F':' '{print $2}')


#echo "We have $cnt students to check, $submissions submissions, and $reqGrading students needed to be graded."
#echo "We have $cnt students to check and $submissions submissions."
echo "We have $cnt students, $submissions submissions and $notsubmitted studets did not submit. Among the submissions there are $graded graded and $ungraded ungraded."


missingStudents=""
lateStudents=""

passedStudents="" #Graded and passed
gradedStudents="" #Graded, could be pass, fail or fx (or what ever system is used)
ungradedStudents="" #Submitted, but not graded.
notSubmittedStudents="" #Not submitted

hashtable=$(mktemp -d)
#echo "<<$hashtable>>"

while read line; do
    read -r data <<<"$(echo "$line")"
    ID=$(echo "$data" | awk -F',' '{print $1}')
    EMAIL=$(echo "$data" | awk -F',' '{print $2}')
    NAME=$(echo "$data" | awk -F',' '{print $3}')

    canvasDownloadName=$(echo "$NAME" | awk '{printf tolower($(NF)); for(c=1;c<NF;c++)printf tolower($c);}' )
    
    #check if student is among the submitted.
    here=$(echo "$studSubmitted" | grep -e "$ID")
    if [ -z "$here" ]; then
	if [[ "$ID" == "1" ]]; then # PAL=45
	    echo "$ID -- $NAME SPECIAL TEST CASE!!!"
	else
	    echo "$ID -- $NAME have not submitted this assignment for some reason."
	    continue;
	fi
    fi


    checkForErrorMessage=$(curl -H "Authorization: Bearer $TOKEN" -s  "https://$site.instructure.com/api/v1/courses/$courseID/assignments/$assignmentID/submissions/$ID" | jq | grep "The specified resource does not exist." )
    if [ ! -z "$checkForErrorMessage" ]; then
	if [[ "$ID" == "1" ]]; then #PAL = 45
	    echo "$ID -- $NAME SPECIAL TEST CASE!!!"
	else
	    echo "$ID -- $NAME should be ignornoSubmissioncheckForErrorMessage'"
	    continue;
	fi
    fi
    
    #Translate NAME to a FOLDER"  ie (replace ' '  with '_'
    studFolderName=$(echo "$NAME" | tr ' ' '_')
    noAttachements=$(echo "$aData" | wc -l | tr -d ' ')								     

    
    echo -n "$ID -- $NAME -- $EMAIL --- "

   
    noSubmission=$(curl -H "Authorization: Bearer $TOKEN" -s  "https://$site.instructure.com/api/v1/courses/$courseID/assignments/$assignmentID/submissions/$ID" | jq | grep workflow_state | grep unsubmitted)
    submissionGraded=$(curl -H "Authorization: Bearer $TOKEN" -s  "https://$site.instructure.com/api/v1/courses/$courseID/assignments/$assignmentID/submissions/$ID" | jq | grep workflow_state | grep graded)

#    echo -n "[sB=$submissionGraded|nO=$noSubmission]"
    if [[ -z "$submissionGraded" ]]; then
	##Not submitted.
	echo "Not submitted"
	echo "$NAME" >> "$hashtable/notsubmitted" 
    else
#	echo -n "Graded"

	metaData=$(curl -H "Authorization: Bearer $TOKEN" -s  "https://$site.instructure.com/api/v1/courses/$courseID/assignments/$assignmentID/submissions/$ID" | jq '{grade,graded_at,grader_id,seconds_late,submitted_at} | to_entries|map(.value)|@csv ')
	
	grade=$(echo "$metaData" | awk -F',' '{print $1}' | tr -d '"\')
	gradedat=$(echo "$metaData" | awk -F',' '{print $2}' | tr -d '"\')
	graderid=$(echo "$metaData" | awk -F',' '{print $3}' | tr -d '"\')
	lateSeconds=$(echo "$metaData" | awk -F',' '{print $4}' | tr -d '"\')
	submittedat=$(echo "$metaData" | awk -F',' '{print $5}' | tr -d '"\')
	
	echo -e "$grade $gradedat $graderid $submittedat"
	echo "$NAME" >> "$hashtable/$grade" 
    fi



done < <(echo "$emStrip" )
echo "Grade - N# students"
for grade in $hashtable/*;do
    echo $(basename $grade) "-" $(wc -l "$grade" | awk '{print $1}')         
done

rm -rf $hashtable
