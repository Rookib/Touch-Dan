#!/bin/sh
# Simulator deployment is deliberately separate from builds.
printf '%s\n' 'Touch-Dan does not install into or restart the Simulator during a build.'
printf '%s\n' 'Use a dedicated test environment for SpringBoard injection; see README.md.'
exit 1
