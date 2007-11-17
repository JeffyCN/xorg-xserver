#!/bin/sh
PATH=/usr/bin:/usr/sbin:/bin:/sbin:/usr/local/bin
export PATH

verbose_msgs="false"
DEFAULT_SPOOLDIR=`perl -e '@x = getpwuid($>); print $x[7]'`/Xprintjobs

usage()
{
    printf "Usage: ${0}: [options]\n"
    printf "-v\tbe verbose\n"
    printf "-d dirname\tdefine spool dir\n"
    printf "-p string\tname of printer selected by user\n"
    printf "-c integer\tnumber of copies\n"
    printf "-t string\tjob title\n"
    printf "-s string\tfile name suffix\n"
    printf "-o string\tspooler options\n"
    printf "-u mask\tpermission mask for new files (see umask)\n"
    exit 2
}

verbose()
{
    if ${verbose_msgs} ; then
        echo "$1"
    fi
}

spooldir="${DEFAULT_SPOOLDIR}"
printername=
num_job_copies=
job_title=
filename_suffix=
spooler_options=
permmask=
while getopts va:b:d:p:c:t:s:o:u: i
do
    case $i in
        v)  
            verbose_msgs="true"
            ;;
        d)  
            spooldir="$OPTARG"
            ;;
        p)  
            printername="$OPTARG"
            ;;
        c)  
            num_job_copies="$OPTARG"
            ;;
        t)  
            job_title="$OPTARG"
            ;;
        s)  
            filename_suffix="$OPTARG"
            ;;
        o)  
            spooler_options="$OPTARG"
            ;;
        u)  
            permmask="$OPTARG"
            ;;
        ?)  usage
            ;;
    esac
done

verbose "# spooldir=\"$spooldir\""
verbose "# printername=\"$printername\""
verbose "# num_job_copies=\"$num_job_copies\""
verbose "# job_title=\"$job_title\""
verbose "# spooler_options=\"$spooler_options\""
verbose "# umask=\"$permmask\""

if [ ! -d "${DEFAULT_SPOOLDIR}" ] ; then 
  mkdir "${DEFAULT_SPOOLDIR}"
fi

if [ "${permmask}" != "" ] ; then
    umask ${permmask}
fi

if [ ! -d "$spooldir" ] ; then
    echo "$0: spooldir \"$spooldir\" does not exits." >&2
    exit 1
fi
if [ ! -w "$spooldir" ] ; then
    echo "$0: Cannot write to spooldir \"$spooldir\"." >&2
    exit 1
fi

# Create first part of the output file name (prefix and an "unique"
# id(=date and time))...
filename="Xpjob_`date +%Y%m%d%H%M%S`"

# ... then add options ...
if [ "${printername}" != "" ] ; then
    filename="${filename}_${printername}"
fi
if [ "${num_job_copies}" != "" -a "${num_job_copies}" != "1" ] ; then
    filename="${filename}_copies_${num_job_copies}"
fi
if [ "${job_title}" != "" ] ; then
    filename="${filename}_title_${job_title}"
fi

# ... mangle output file name and filter chars (like whitespaces)
# which may screw-up further processing by other shell scripts ...
filename="`echo \"${filename}\" | tr '[:blank:]' '_' | tr -c -d '[:alnum:]_.-'`"

# consider that the end name might be too long:
# 1. Calculate the length of the suffix (I think we need to count in bytes)
filename_length="`echo \"${filename_suffix}\" | wc -c`"
# 2. remove this length from 256
filename_length="`echo \"256-${filename_length}\" | bc`"
# 3. and keep only the first 256 - suffix_length bytes from the name.
filename="`echo \"${filename}\" | cut -b-${filename_length}`"

# ... add path and suffix ...
# ... should be unique, but check anyway
if [ -e "${spooldir}/${filename}" ]; then
  filename="`tempfile -d "${spooldir}" -s "_${filename}${filename_suffix}"`"
else
  filename="${spooldir}/${filename}${filename_suffix}"
fi

verbose "# File name is \"$filename\"."

# ... and finally capture stdin to the file (we are using "gs" directly to
# avoid the problem that "ps2pdf" is not available in all Linux
# distributions by default).
#ps2pdf - - | cat >"${filename}"
gs -q -dNOPAUSE -dBATCH -sDEVICE=pdfwrite "-sOutputFile=-" -dCompatibilityLevel=1.2 -c .setpdfwrite -f - | cat >"${filename}"

if ${verbose_msgs} ; then
    printf "# File is " ; ls -l "${filename}"
fi

verbose "# Done."

exit 0
# EOF.
