#!/bin/bash

############################################
#
# Create OS.User mysql
# Create OS.Group mysql
#
###########################################

egrep "^mysql\:" /etc/group >& /dev/null
if [ $? -ne 0 ]
then
   groupadd mysql
fi

id mysql >& /dev/null
if [ $? -ne 0 ]
then
   useradd -r -g mysql -s /bin/false mysql
fi

