# CanvasBash
Various tools to interact with Canvas, using Bash and Curl. 

Most // all require a CANVAS token to be in TOKEN. See Canvas API documentation how to generate a token.

Each script needs adaptations; site should be replaced with your site. 


listMyCourses
	Lists all courses you (TOKEN) has access to.

listAssignments
	Lists all assignments assoicated with a course.

downloadAssignments
	Downloads all submissions for a specified assignment in a particular course.




#In assignment group_category_id.

curl -s -H "Authorization: Bearer $TOKEN" "https://$site.instructure.com/api/v1/group_categories/GRPID:" | jq

List groups in Category
curl -s -H "Authorization: Bearer $TOKEN" "https://$site.instructure.com/api/v1/group_categories/GRPID:/groups" | jq

List users in Category
curl -s -H "Authorization: Bearer $TOKEN" "https://$site.instructure.com/api/v1/group_categories/GRPID:/users" | jq

Export users and group from category, in a CSV format.
curl -s -H "Authorization: Bearer $TOKEN" "https://$site.instructure.com/api/v1/group_categories/GRPID:/export"
