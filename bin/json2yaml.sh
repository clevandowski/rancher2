#!/bin/bash

python -c 'import sys, yaml, json; print yaml.dump(yaml.load(sys.stdin), default_flow_style=False)' 2>/dev/null
