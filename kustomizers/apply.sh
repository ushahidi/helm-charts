#!/bin/bash

# Applies a string of customizations
#
# Invoke with environment variable K set to list of kustomizers to apply in order.
# Usually invoked as a post renderer to helm, i.e.:
#
#   K="deployment-keel-tag ingress-ssl-redirect" \
#   helm template platform-api --post-renderer './kustomizers/apply.sh'
#

kbase=`dirname $0`

# work on temporary folder
_tmp=$(mktemp -d 2>/dev/null || mktemp -d -t 'krender')
if [[ ! "$_tmp" || ! -d "$_tmp" ]]; then
  echo "Could not create temp dir"
  exit 1
fi

function _cleanup {
  rm -fr "$_tmp"
}

trap _cleanup EXIT

## Prepare kustomization sequence
# base level: helm output
mkdir "$_tmp/base"
echo "resources: [ helm.yaml ]" > "$_tmp/base/kustomization.yaml"
cat <&0 > "$_tmp/base/helm.yaml"
_base="../base"

# additional folders per customization
_i=1
for k in $K; do
    _current=`printf %03d $_i`
    echo "current: $_current" >&2
    mkdir -p "$_tmp/$_current"
    cp -a $kbase/$k/ "$_tmp/$_current"
    echo -e "\nbases: [ $_base ]\n" >> "$_tmp/$_current/kustomization.yaml"
    #
    _base=../$_current
    _i=$(($_i + 1))
done

kustomize build $_tmp/`basename $_base`
