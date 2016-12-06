#!/bin/bash

sudo pip install bash8

echo "Run bash8 on koji-jobs/* image/*"
exec bash8 koji-jobs/* image/*
