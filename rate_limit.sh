#!/bin/bash
pv -q -L $RATE_LIMIT | "$@"
