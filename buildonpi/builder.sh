#!/bin/bash
export SELFDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source ${SELFDIR}/functions.sh > /dev/null 2>&1
source $WORKDIR/cattlepi/tools/venv/bin/activate > /dev/null 2>&1

BUILDER=$1
BUILDLOCATION=$2
load_builder_state $BUILDER
JOBDIR=${WORKDIR}/jobs/${BUILDER_TASK}

github_status_update $BUILDER_TASK "pending"
echo "build in progress" > ${JOBDIR}/build_output
upload_logs_to_s3 $BUILDER_TASK

COMMITID=$(head -1 ${JOBDIR}/commit)
SQSQ=$(cat /tmp/current_config | jq -r '.config.buildcontrol.aws_sqs_queue')

update_current_time
BUILDER_LAST_ACTION=${CURRENT_TIME}
persist_builder_state $BUILDER
echo "running with builder ${BUILDER} in ${BUILDLOCATION}"
export BUILDER_NODE=${BUILDER}
cd ${BUILDLOCATION} && git clone https://github.com/cattlepi/cattlepi.git
cd ${BUILDLOCATION}/cattlepi && git fetch origin +refs/pull/*/merge:refs/remotes/origin/pr/* && git reset --hard ${COMMITID}
cd ${BUILDLOCATION}/cattlepi && make envsetup

# test
cd ${BUILDLOCATION}/cattlepi && make test_noop
BUILDRESULT=$?

### this is the actual build
# update_current_time
# BUILDER_LAST_ACTION=${CURRENT_TIME}
# persist_builder_state $BUILDER

# if [ $BUILDRESULT -eq 0 ]; then
#     cd ${BUILDLOCATION}/cattlepi && make raspbian_cattlepi
#     BUILDRESULT=$?
# fi

echo ""
echo "-------------------------"
if [ $BUILDRESULT -ne 0 ]; then
    github_status_update $BUILDER_TASK "failure"
    echo "failure" > ${JOBDIR}/build_result
    touch ${JOBDIR}/job_failure
else
    github_status_update $BUILDER_TASK "success"
    echo "success" > ${JOBDIR}/build_result
    touch ${JOBDIR}/job_success
fi

# ack the message in the queue
RECEIPT=$(head -1 ${JOBDIR}/handle)
aws sqs delete-message --queue-url "${SQSQ}" --receipt-handle "${RECEIPT}"
# upload the logs
cp ${BUILDLOCATION}/output ${JOBDIR}/build_output
upload_logs_to_s3 $BUILDER_TASK

# cleanup
clean_builder_state $BUILDER

# update the build state
update_current_time
BUILDER_LAST_ACTION=${CURRENT_TIME}
BUILDER_STATE="rebuild"
BUILDER_TASK=""
persist_builder_state $BUILDER
echo "-------------------------"