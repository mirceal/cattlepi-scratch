#!/bin/bash
export SDROOT=/sd
source ${SDROOT}/functions.sh

update_current_time
time_diff $CURRENT_TIME

for BUILDERI in $(ls -1 ${SDROOT}/builders)
do
    echo "found builder ${BUILDERI}"
    load_builder_state $BUILDERI
    update_current_time
    BUILDER_LAST_CHECKED=${CURRENT_TIME}
    echo "make some decisions in between"
    persist_builder_state $BUILDERI
    echo "---------------------------"
    cat ${SDROOT}/builders/${BUILDERID}/state
    echo "---------------------------"
done