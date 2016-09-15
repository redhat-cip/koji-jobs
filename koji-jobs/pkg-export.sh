#!/bin/bash

# Copyright (C) 2016 Red Hat, Inc
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License. You may obtain
# a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.

# Run it standalone
# DEBUG=1 WORKSPACE=/tmp/workspace_sim ZUUL_CHANGES=aodh-distgit:xyz \
# ZUUL_BRANCH=rdo-liberty ZUUL_URL=http://rpmfactory.beta.rdoproject.org/zuul/p ZUUL_REF="" \
# ZUUL_PROJECT=aodh-distgit pkg-export.sh

source ./rpm-koji-gating-lib.common


# The wait_for_other_jobs.py is deactivated atm as the gating
# does not run any functionnal testing code. This should be
# activated if we intend to run real validation jobs in order to be sure
# the CBS non-scratch build starts after the ends of the other
# validation jobs.

#echo "\n\n=== Wait for other belonging jobs for this change to finish ==="
#
## Wait for other job to finish
## We want to make sure all jobs belonging to this change
## finish prior to run the "non scratch" build on Koji
## Furthermore we want to wait for the change to be on top
## of the shared queue before we start the build on koji
## wait_for_other_jobs.py handles the condition of releasing
## the wait.
#[ -x /usr/local/bin/wait_for_other_jobs.py ] && /usr/local/bin/wait_for_other_jobs.py

# We are there so all voting jobs finished with success


echo "\n===  Clone project ${ZUUL_PROJECT} ==="

# Clean previous run
sanitize

# Fetch all involved projects
echo -e "\n--- Fetch $ZUUL_PROJECT at the right revision ---"
zuul-cloner --workspace $workdir $rpmfactory_clone_url $ZUUL_PROJECT


echo "\n===  Check project NVR change ==="

pushd ${workdir}/$ZUUL_PROJECT > /dev/null
spec=$(ls *.spec)
git --no-pager show HEAD^1:$spec > /tmp/${spec}_prev
set +e
rpmdev-vercmp $(rpm -q --specfile $spec) $(rpm -q --specfile /tmp/${spec}_prev)
status_code="$?"
case $status_code in
    0)
        echo "No NVR change detected. Nothing to do ! Exit 0"
        ;;
    1[12])
        echo "NVR has changed. Start CBS non-scratch build ..."
        ;;
    *)
        echo "Error in NVR change checking"
        ;;
esac
set -e
popd > /dev/null

echo "\n===  Start publish RPMS for project ${ZUUL_PROJECT} ==="

# Build all SRPMS
echo -e "\n--- Build SRPM for $ZUUL_PROJECT ---"
pushd ${workdir}/$ZUUL_PROJECT > /dev/null
git log --simplify-merges -n1
build_srpm
fpname=$(echo $rpmbuild_output | awk -F'/' '{print $NF}')
pname=$(python -c "import sys; from rpmUtils.miscutils import splitFilename; print splitFilename(sys.argv[1])[0]" $fpname)
srpm=$(ls ${rpmbuild}/SRPMS/${pname}*.src.rpm)
popd > /dev/null

# Start builds on koji
echo -e "\n--- Start koji build for $ZUUL_PROJECT ---"
start_build_on_koji $srpm $ZUUL_PROJECT ""

# Check build status koji side
while check_build_on_koji $ZUUL_PROJECT; do
  echo -e "\n--- Check koji build for $ZUUL_PROJECT ---"
  if [ ! -f "$workdir/${ZUUL_PROJECT}_meta/built" ]; then
    if [ -f "$workdir/${ZUUL_PROJECT}_meta/failed" ]; then
      echo -e "\n Build failed. Package not exported. Exit 1 !"
      exit 1
    fi
  else
    break
  fi
  echo "Waiting ..."
  sleep 30
done

echo -e "\n Build succeed. Package exported."
