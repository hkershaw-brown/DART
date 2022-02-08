#!/bin/tcsh


cat << EndOfText >! print_files
#!/bin/tcsh

ls *inflution* >& /dev/null
if (\$status != 0) then
   echo "WARNING, no inflution files"
endif

EndOfText
chmod 0755 print_files

./print_files

exit
