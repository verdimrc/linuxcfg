#!/bin/bash

awk -F '= ' '/^apikey = / {print $2; exit}' ~/.ngc/config
