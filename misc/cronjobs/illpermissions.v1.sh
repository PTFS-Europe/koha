:
IFS='
'
 rm illperms.txt
 rm illperms.sql
echo "select borrowernumber from borrowers WHERE categorycode IN ('REAYSTA','REAYSTU','REAYPVT','REAYOTH','LIB', 'LEWSTA', 'OXSTA', 'QEHSTA', 'PRUHSTA', 'PRUHPVT', 'PRUHSTU', 'PRUHOTH', 'STENSTA', 'STENSTU', 'STENPVT', 'STENOTH');" | mysql -N -u koha_slhl -p0Klul6zq9o koha_slhl >illperms.txt
 for userdetails in `cat illperms.txt`
 do
    borrowernumber=`echo ${userdetails} | cut -f1`
 echo "INSERT INTO user_permissions (borrowernumber, module_bit, code) VALUES ('${borrowernumber}', '21', 'place');" >>illperms.sql
 done
 cat illperms.sql | mysql -u koha_slhl -p0Klul6zq9o koha_slhl
