#!/usr/bin/env bash

# set -x;
set -e;
set -u;

source helpers.sh

QC_GEN_CONFIG_PATH='json://'`pwd`'/etc/its-qcmn-cluster-track.json'
QC_FINAL_CONFIG_PATH='consul-json://{{ consul_endpoint }}/o2/components/qc/ANY/any/its-qcmn-cluster-track'
QC_CONFIG_PARAM='qc_config_uri'

cd ..

WF_NAME=its-qcmn-cluster-track-remote
export DPL_CONDITION_BACKEND="http://127.0.0.1:8084"
export DPL_CONDITION_QUERY_RATE="${GEN_TOPO_EPN_CCDB_QUERY_RATE:--1}"
DPL_PROCESSING_CONFIG_KEY_VALUES="NameConf.mCCDBServer=http://127.0.0.1:8084;"

o2-qc --config $QC_GEN_CONFIG_PATH --remote -b --o2-control $WF_NAME

# add the templated QC config file path
ESCAPED_QC_FINAL_CONFIG_PATH=$(printf '%s\n' "$QC_FINAL_CONFIG_PATH" | sed -e 's/[\/&]/\\&/g')
sed -i /defaults:/\ a\\\ \\\ "${QC_CONFIG_PARAM}":\ \""${ESCAPED_QC_FINAL_CONFIG_PATH}"\" workflows/${WF_NAME}.yaml

# find and replace all usages of the QC config path which was used to generate the workflow
ESCAPED_QC_GEN_CONFIG_PATH=$(printf '%s\n' "$QC_GEN_CONFIG_PATH" | sed -e 's/[]\/$*.^[]/\\&/g');
sed -i "s/""${ESCAPED_QC_GEN_CONFIG_PATH}""/{{ ""${QC_CONFIG_PARAM}"" }}/g" workflows/${WF_NAME}.yaml tasks/${WF_NAME}-*

