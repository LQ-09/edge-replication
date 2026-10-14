#!/bin/bash
#$ -j y

if [[ "$1" =~ ^(master|taqs|taqms|nbbo)$ ]]; then

    echo Running $1...

else

    echo Option '$1' is invalid. Valid options are: 'master', 'taqs', 'taqms', 'nbbo'
    exit

fi

if [[ $1 = "master" ]]; then

    sas master.sas -log master.log
    chmod 644 master.csv.gz

else

    mkdir -p $1

    if [[ $1 = "taqs" ]]; then 

        sasdata=$(find /wrds/nyse/sasdata/taqs/ -regex '.*/ct\_[0-9]+\.sas7bdat$')
        prefix=3
    
    else

        sasdata=$(find /wrds/nyse/sasdata/taqms/ct/ -regex '.*/ctm\_[0-9]+\.sas7bdat$')
        prefix=4
    
    fi

    for trades in $sasdata; do
        
        filename=$(basename $trades .sas7bdat)
        yyyymmdd=${filename:prefix}
        outfile="$1/$yyyymmdd.csv.gz"

        if [[ ! -s $outfile ]]; then

            if [[ $1 = "nbbo" ]]; then 

                quotes="/wrds/nyse/sasdata/wrds_taqms_nbbo/complete_nbbo_${yyyymmdd}.sas7bdat"
                sas quotes.sas -set quotes $quotes -set trades $trades -set outfile $outfile -log $outfile.log

            else

                sas trades.sas -set trades $trades -set freq $2 -set outfile $outfile -log $outfile.log

            fi

        fi

        if [[ -s $outfile ]]; then 

            echo $(date): $outfile [OK]
            rm -f $outfile.log

        else 

            echo $(date): $outfile [FAIL]

        fi

    done

    first=1
    for f in $1/*.csv.gz; do

        if [ "$first" ]; then

            zcat "$f"; first=
        
        else

            zcat "$f" | tail -n +2
        
        fi

    done | gzip --stdout > $1.csv.gz

fi

echo done!
