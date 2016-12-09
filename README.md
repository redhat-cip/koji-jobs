Software Factory scripts to interact with Koji or CBS
=====================================================

The repository contains scripts to interact with the Koji Build system
via the koji or the cbs client tool. The scripts take in
account a Zuul workspace by taking care of the environment
variables set by the Zuul scheduler but also use the zuul-cloner
tool to fetch sources.

Mainly this repository contains two scripts to be used in
CI jobs to interact with Koji:

- pkg-validate.sh
- pkg-export.sh

These scripts could be used standalone but are mainly designed
to run within Software Factory.

pkg-validate.sh
---------------

For each repository mentionned in the ZUUL_CHANGES environment
variable the script:

- clones the repository
- expects to find a .spec file
- builds the SRPM
- requests a scratch build on Koji
- waits for the task completion
- fetches the built rpms locally
- create a temporary repository locally with the built packages
- create a temporary release package that install
  a new yum repo targeting the temporary release repository and
  the build target repository

Once this script return success you can run any king of tests
with the built packages.

As the script supports the ZUUL_CHANGES variables and uses
zuul-cloner then if dependencies are specified via the Zuul
"depends-on" marker they are handled and the temporary repository
will contains all built packages according to the Zuul context.

Unfortunatly if the ZUUL_CHANGES contains dependencies such
as a RPM Build-Requirement it won't works as only scratch build
are use on Koji at this level.

This script is mainly designed to be called in the check pipeline
of Zuul within Software Factory.

pkg-export.sh
-------------

For the repository mentionned in the ZUUL_PROJECT variable the
script will:

- clones the repository
- expects to find a .spec file
- detects if the package NVR changed between HEAD and HEAD^1
  and return if not the case.
- builds the SRPM
- requests a non-scratch build on Koji

This script is mainly designed to be called in the gate pipeline
of Zuul within Software Factory. If the non-scratch build
failed then the job script return an error preventing the Git
change to land in the Git repository.

The Zuul context of the change queue in the Gate pipeline is not
taking in account by default. Nevertheless there is a script
available Software Factory slave node called *wait_for_other_jobs.py*
that can be used to for the script to wait for the current change
to be tested on top of the Gate pipeline change queue. This can be
useful if you run functional tests between packages in the gate
pipeline and be sure your test job will be able to find the expected
and already validated packages in the targeted Koji repository.
Please have a look to the pkg-export.sh scripts comment for more
informations.
