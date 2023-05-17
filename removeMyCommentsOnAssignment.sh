#!/bin/bash
# Download student submissions from a Canvas Course.
#
# Syntax:
#      removeMyCommentsOnAssignments.sh [-v] [-h] CourseCode AssignmentID
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
DATUM=0;
DATUMFROM=0
DATUMTO=0


PASSWDFILE=$(mktemp)

while getopts glmvhf:t:d:u:i:-: OPT; do
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
	u | userid)
	    userid=${OPTARG}
	    ;;
	d | date)
	    DATUM=${OPTARG}
	    ;;
	f | from)
	    DATUMFROM=$(date -d ${OPTARG} +%s)
	    ;;
	t | too)
	    DATUMTO=$(date -d ${OPTARG} +%s)
	    ;;
        h)
            echo "usage: $0 [-v] [--userid=nr] [--missing] [--graded] <COURSECODE> <ASSIGNMENT>" >&2
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
#location=$3

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


if [[ -z "$userid" ]]; then
    ## Trying to identify my ID.
    myCanvasID=$(curl -H "Authorization: Bearer $TOKEN" -s  "https://$site.instructure.com/api/v1/courses" | jq -r '.[] | .enrollments[].user_id'  | uniq)
    myCanvasIDcount=$(echo "$myCanvasID" | wc -l)
    if [[ "$myCanvasIDcount" -gt 1 ]]; then
	echo "You have more than ONE id, thats confusing. "
	echo "Provide what ID to use, via argument (not implemented)."
	echo "$myCanvasID"
	exit;
    fi
else
    echo "User id was provided."
    myCanvasID="$userid"
fi

echo "USERID=$myCanvasID"

#Trying to find ID
courseData=$(curl -H "Authorization: Bearer $TOKEN" -s  "https://$site.instructure.com/api/v1/courses?enrollment_type=teacher&state=available&per_page=$maxEntries" | jq -r '.[] | {name, id}' |  jq "[.[]] | @tsv" | sed 's/\\t/*/g' | tr -d '"' | grep "^$courseCode")
courseID=$(echo "$courseData" | awk -F'*' '{print $2}')
courseString=$(echo "$courseData" | awk -F'*' '{print $1}')


found=$(echo "$courseID" | wc -l | tr -d ' ')

echo "|$courseData|$courseID|$courseString|$found|"

echo "DATUM=|$DATUM|"
echo "DATUMFROM=|$DATUMFROM|"
echo "DATUMTO=|$DATUMTO|"


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
assignmentsData=$(curl -H "Authorization: Bearer $TOKEN" -s  "https://$site.instructure.com/api/v1/courses/$courseID/assignments?per_page=$maxEntries" | jq -r '.[] | {name, id}' |  jq "[.[]] | @tsv" | sed 's/\\t/*/g' | tr -d '"')
assignmentData=$(echo "$assignmentsData" | grep "$assignment\*")

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
    echo "Did not find the assignment, check your syntax,|$assignment|."
    echo "You need the full name, probably within quotes."
    echo "These are the assignments for this class."
    echo "Working with; |$assignmentsData|"

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
ungraded=$(echo "$subStatus" | grep -v 'ungraded' | grep 'graded' | awk -F':' '{print $2}')
notsubmitted=$(echo "$subStatus" | grep 'not_submitted' | awk -F':' '{print $2}')


#echo "We have $cnt students to check, $submissions submissions, and $reqGrading students needed to be graded."
echo "We have $cnt students to check and $submissions submissions."
echo "We have $cnt students, and there are $graded graded, $ungraded ungraded, and $notsubmitted assignments."

missingStudents=""
lateStudents=""

while read line; do
    read -r data <<<"$(echo "$line")"
    ID=$(echo "$data" | awk -F',' '{print $1}')
    EMAIL=$(echo "$data" | awk -F',' '{print $2}')
    NAME=$(echo "$data" | awk -F',' '{print $3}')

    canvasDownloadName=$(echo "$NAME" | awk '{printf tolower($(NF)); for(c=1;c<NF;c++)printf tolower($c);}' )
    
    #check if student is among the submitted.
    here=$(echo "$studSubmitted" | grep -e "$ID")
    if [ -z "$here" ]; then
	echo "$ID -- $NAME have not submitted this assignment for some reason."
	continue;
    fi


    checkForErrorMessage=$(curl -H "Authorization: Bearer $TOKEN" -s  "https://$site.instructure.com/api/v1/courses/$courseID/assignments/$assignmentID/submissions/$ID" | jq | grep "The specified resource does not exist." )
    if [ ! -z "$checkForErrorMessage" ]; then
	echo "$ID -- $NAME should be ignornoSubmissioncheckForErrorMessage'"
	continue;
    fi

    
    
    #Translate NAME to a FOLDER"  ie (replace ' '  with '_'
    studFolderName=$(echo "$NAME" | tr ' ' '_')
    noAttachements=$(echo "$aData" | wc -l | tr -d ' ')								     
#    echo " $noAttachements"


    
    echo -n "$ID -- $NAME -- $EMAIL -> "


    
    noSubmission=$(curl -H "Authorization: Bearer $TOKEN" -s  "https://$site.instructure.com/api/v1/courses/$courseID/assignments/$assignmentID/submissions/$ID" | jq | grep workflow_state | grep unsubmitted)
    submissionGraded=$(curl -H "Authorization: Bearer $TOKEN" -s  "https://$site.instructure.com/api/v1/courses/$courseID/assignments/$assignmentID/submissions/$ID" | jq | grep workflow_state | grep graded)
    
    ## Add logic to check if its a 'new' or old (reviewed) submission. If old, and already reviewed do not work with it.
    OVERRIDE=0
    if [[ "$submissionGraded" && "$DLGRADED" -eq "1" ]]; then
	submissionGraded=""
	OVERRIDE=1
    fi

    echo -n "$noSubmission - $submissionGraded | "
    if [[ -z "$noSubmission"  && -z "$submissionGraded" ]]; then

	echo -n " submitted"
	if [ "$OVERRIDE" -eq "1" ]; then
	    echo " (forced retreival, already graded)."
	else
	    echo "."
	fi
	
	metaData=$(curl -H "Authorization: Bearer $TOKEN" -s  "https://$site.instructure.com/api/v1/courses/$courseID/assignments/$assignmentID/submissions/$ID" | jq '{grade,graded_at,grader_id,seconds_late,submitted_at} | to_entries|map(.value)|@csv ')

	grade=$(echo "$metaData" | awk -F',' '{print $1}' | tr -d '"\\')
	gradedat=$(echo "$metaData" | awk -F',' '{print $2}' | tr -d '"\\')
	graderid=$(echo "$metaData" | awk -F',' '{print $3}' | tr -d '"\\')
	lateSeconds=$(echo "$metaData" | awk -F',' '{print $4}' | tr -d '"\\')
	submittedat=$(echo "$metaData" | awk -F',' '{print $5}' | tr -d '"\\')

	lateDays=$(echo "scale=0; $lateSeconds/86400"|bc )
	lateHours=$(echo "scale=0; $lateSeconds/3600"|bc )

	graderName=$(echo "$emname" | tr -d '"' | grep "^$graderid," | awk -F',' '{print $3}' )
	
	if [ -z "$submittedat" ]; then
	    echo "Not submitted."
	    continue;
	fi
	
	if [ "$lateDays" -ne "0" ]; then
	    lateTime="$lateDays days"
	else
	    lateTime="$lateHours hours"
	fi

	if [ "$lateSeconds" -eq "0" ]; then
	    lateTime="Not late"
	else
	    if [ -z "$lateStudents" ]; then
		lateStudents="$ID -- $NAME -- $EMAIL -- $lateTime ($lateSeconds)"
	    else
		lateStudents="$lateStudents\n$ID -- $NAME -- $EMAIL -- $lateTime ($lateSeconds)"
	    fi
	fi


	##Grab comments
	comments=$(curl -H "Authorization: Bearer $TOKEN" -s  "https://$site.instructure.com/api/v1/courses/$courseID/assignments/$assignmentID/submissions/$ID?include[]=submission_comments" | jq '.submission_comments[]' )
	if [ -z "$comments" ]; then
	    echo -e "\tNo comments found in submission."
	else
	    
	    comments=$(curl -H "Authorization: Bearer $TOKEN" -s  "https://$site.instructure.com/api/v1/courses/$courseID/assignments/$assignmentID/submissions/$ID?include[]=submission_comments" | jq '.submission_comments[] | {id, author_id, created_at, comment}'| jq "[.[]] | @csv" ) 
	    commentCNT=$(echo "$comments" | wc -l | tr -d ' ')

	    userComments=$(echo "$comments" | grep ",$myCanvasID," )
	    ucCNT=$(echo "$userComments" | wc -l | tr -d ' ')
	    echo -e "\tThere are $commentCNT comments in total, of these user $myCanvasID has $ucCNT comments."
	    remCNT=0
	    while read thecommentLine; do
		commentID=$(echo "$thecommentLine" | awk -F',' '{print $1}' | tr -d '\"' )
		createdAT=$(echo "$thecommentLine" | awk -F',' '{print $3}' | tr -d '\"' )

		## Time to remove, if conditions are met.
		removeTHIS=0;
		condition=""
		createdATseconds=$(date -d ${createdAT} +%s)
#		echo "createdATseconds=$createdATseconds"
		
		if [[ "$DATUM" -ne 0 ]]; then
		    if [[ $(echo "$createdAT" | grep "$DATUM" ) ]]; then
			##This is explicit.
			condition="DATUM match "
			removeTHIS=1;
		    fi ## Eventually add support for other 'filters'.
		fi

		if [[ "$DATUMFROM" -ne 0 ||  "$DATUMTO" -ne 0 ]]; then
		    if [[ "$DATUMFROM" -ne 0 &&  "$DATUMTO" -eq 0 ]]; then
			if [[ "$createdATseconds" -ge "$DATUMFROM" ]]; then
			    condition=" ctAT>=DATUMFROM"
			    removeTHIS=1;
			fi
		    elif [[ "$DATUMTO" -ne 0 &&  "$DATUMFROM" -eq 0 ]]; then
			if [[ "$createdATseconds" -le "$DATUMTO" ]]; then
			    condition=" ctAT>=DATUMFROM"
			    removeTHIS=1;
			fi
		    else 
			if [[ "$createdATseconds" -ge "$DATUMFROM" && "$createdATseconds" -le "$DATUMTO" ]]; then
			    condition=" DATUMFROM <= ctAT <= DATUMTO "
			    removeTHIS=1;
			fi
		    fi
		fi
		

		if [[ "$removeTHIS" -eq 1 ]]; then
#		    echo "curl -H \"Authorization: Bearer $TOKEN\" -X DELETE -s \"https://$site.instructure.com/api/v1/courses/$courseID/assignments/$assignmentID/submissions/$ID/comments/$commentID\" "
		    removeComment=$(curl -H "Authorization: Bearer $TOKEN" -X DELETE -s "https://$site.instructure.com/api/v1/courses/$courseID/assignments/$assignmentID/submissions/$ID/comments/$commentID" | jq .id)
		    if [[ "$removeComment" == "$commentID" ]]; then
			echo "Removed $commentID, $createdAT * $condition "
			((remCNT++))
		    else
			echo "Response was"
			echo "|$removeComment|"
		    fi
		fi
	    done < <(echo "$userComments") 
	    echo -e "\tRemoved $remCNT comments."
	fi
	
    else
	echo "Not touching."
	
    fi

    

done < <(echo "$emStrip") 


#echo "$emStrip"




