#!/bin/bash
LIST=(one two three)
for NUM in "${LIST[@]}"; do 
        COUNT="${NUM}"
	echo "Number is: $NUM"
	sleep .2 ;echo ""
done
