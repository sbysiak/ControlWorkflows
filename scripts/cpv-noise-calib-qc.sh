#!/usr/bin/env bash

# set -x;
set -e;
set -u;

WF_NAME=cpv-noise-calib-qc
export DPL_CONDITION_BACKEND="http://127.0.0.1:8084"
export DPL_CONDITION_QUERY_RATE="${GEN_TOPO_EPN_CCDB_QUERY_RATE:--1}"
DPL_PROCESSING_CONFIG_KEY_VALUES="NameConf.mCCDBServer=http://127.0.0.1:8084;"

# check
QC_GEN_CONFIG_PATH='json://'`pwd`'/etc/cpv-noise-calib-qc.json'
QC_FINAL_CONFIG_PATH='consul-json://{{ consul_endpoint }}/o2/components/qc/ANY/any/cpv-noise-calib-qc'
QC_CONFIG_PARAM='qc_config_uri'

cd ..

# DPL command to generate the AliECS dump
o2-dpl-raw-proxy -b --session default --dataspec 'x0:CPV/RAWDATA;dd:FLP/DISTSUBTIMEFRAME/0' --readout-proxy '--channel-config "name=readout-proxy,type=pull,method=connect,address=ipc:///tmp/stf-builder-dpl-pipe-0,transport=shmem,rateLogging=1"' \
    | o2-cpv-reco-workflow -b --session default --input-type raw --output-type digits --disable-root-input --disable-root-output --disable-mc --no-gain-calibration --no-bad-channel-map --condition-tf-per-query 0 --configKeyValues "${DPL_PROCESSING_CONFIG_KEY_VALUES}" \
    | o2-calibration-cpv-calib-workflow --noise --tf-per-slot 100 --max-delay 0 --configKeyValues "${DPL_PROCESSING_CONFIG_KEY_VALUES}" \
    | o2-calibration-ccdb-populator-workflow --ccdb-path http://o2-ccdb.internal --configKeyValues "${DPL_PROCESSING_CONFIG_KEY_VALUES}" \
    | o2-dpl-output-proxy --environment "DPL_OUTPUT_PROXY_ORDERED=1" -b --session default --dataspec 'x0:CPV/RAWDATA;DIG:CPV/DIGITS/0;DTR:CPV/DIGITTRIGREC/0;ERR:CPV/RAWHWERRORS/0;dd:FLP/DISTSUBTIMEFRAME/0' --dpl-output-proxy '--channel-config "name=downstream,type=push,method=bind,address=ipc:///tmp/stf-pipe-0,rateLogging=1,transport=shmem"' \
    | o2-qc -b --config ${QC_GEN_CONFIG_PATH} --o2-control $WF_NAME

# add the templated QC config file path
ESCAPED_QC_FINAL_CONFIG_PATH=$(printf '%s\n' "$QC_FINAL_CONFIG_PATH" | sed -e 's/[\/&]/\\&/g')
sed -i /defaults:/\ a\\\ \\\ "${QC_CONFIG_PARAM}":\ \""${ESCAPED_QC_FINAL_CONFIG_PATH}"\" workflows/${WF_NAME}.yaml

sed -i /defaults:/\ a\\\ \\\ "tf_per_slot: 100" workflows/${WF_NAME}.yaml

sed -i '/--tf-per-slot/{n;s/.*/    - "{{ tf_per_slot }}"/}' tasks/${WF_NAME}-*


# find and replace all usages of the QC config path which was used to generate the workflow
ESCAPED_QC_GEN_CONFIG_PATH=$(printf '%s\n' "$QC_GEN_CONFIG_PATH" | sed -e 's/[]\/$*.^[]/\\&/g');
sed -i "s/""${ESCAPED_QC_GEN_CONFIG_PATH}""/{{ ""${QC_CONFIG_PARAM}"" }}/g" workflows/${WF_NAME}.yaml tasks/${WF_NAME}-*
