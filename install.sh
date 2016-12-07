#!/usr/bin/bash

INSTALL_DIR=/var/lib/koji-jobs/

if [ ! -d $INSTALL_DIR ]; then
    mkdir $INSTALL_DIR
fi
cp -av koji-jobs/* $INSTALL_DIR/
