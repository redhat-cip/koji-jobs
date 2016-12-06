#!/bin/bash

if ! which bash8; then
    sudo pip install bash8
fi

echo "Run bash8 on koji-jobs/* image/*"
exec bash8 koji-jobs/* image/*
