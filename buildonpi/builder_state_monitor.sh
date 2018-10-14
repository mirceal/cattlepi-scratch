#!/bin/bash
export SDROOT=/sd

function update_current_time() {
    CURRENT_TIME=$(date +%s)
    export CURRENT_TIME
}
update_current_time

function time_diff() {
    update_current_time
    let TIME_DELTA=$(($CURRENT_TIME - $1))
    export TIME_DELTA
}
time_diff $CURRENT_TIME

function load_builder_state() {
    BUILDERID=$1
    unset BUILDER_STATE
    unset BUILDER_LAST_CHECKED
    unset BUILDER_LAST_ACTION
    unset BUILDER_TIME_SINCE_LAST_ACTION
    unset BUILDER_TASK
    source ${SDROOT}/builders/${BUILDERID}/state
    BUILDER_STATE=${BUILDER_STATE:-unknown}
    export BUILDER_STATE
    BUILDER_LAST_CHECKED=${BUILDER_LAST_CHECKED:-0}
    export BUILDER_LAST_CHECKED
    BUILDER_LAST_ACTION=${BUILDER_LAST_ACTION:-0}
    export BUILDER_LAST_ACTION
    BUILDER_TASK=${BUILDER_TASK:-unknown}
    export BUILDER_TASK
    time_diff ${BUILDER_LAST_ACTION}
    BUILDER_TIME_SINCE_LAST_ACTION=$TIME_DELTA
    export BUILDER_TIME_SINCE_LAST_ACTION
}

function persist_builder_state() {
    BUILDERID=$1
    TMP_STATE=${SDROOT}/builders/${BUILDERID}/state.TMP_STATE
    echo "BUILDER_STATE=${BUILDER_STATE}" > "${TMP_STATE}"
    echo "BUILDER_LAST_CHECKED=${BUILDER_LAST_CHECKED}" >> "${TMP_STATE}"
    echo "BUILDER_LAST_ACTION=${BUILDER_LAST_ACTION}" >> "${TMP_STATE}"
    echo "BUILDER_TASK=${BUILDER_TASK}" >> "${TMP_STATE}"
    mv "${TMP_STATE}" ${SDROOT}/builders/${BUILDERID}/state
}

function check_builder_alive() {
    BUILDERID=$1
    BUILDER_ALIVE=1
    ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o ConnectTimeout=5 pi@${BUILDERID} whoami 2>/dev/null || BUILDER_ALIVE=0
    export BUILDER_ALIVE
}

function check_builder_on_stock() {
    BUILDERID=$1
    BUILDER_ON_STACK=1
    [ $(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o ConnectTimeout=5 pi@${BUILDERID} /etc/cattlepi/release.sh 2>/dev/null) == 'raspbian_stock' ] || BUILDER_ON_STACK=0
    export BUILDER_ON_STACK
}

function reset_builder_to_stock() {
    BUILDERID=$1
    ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o ConnectTimeout=5 pi@${BUILDERID} sudo /etc/cattlepi/restore_cattlepi.sh
}

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