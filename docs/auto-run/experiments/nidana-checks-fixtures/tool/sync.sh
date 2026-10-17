#!/usr/bin/env bash
# Copies the repository's nidana-checks fixtures (and the fixture-wide
# analysis options) into this experiment at the same relative paths.
cd "$(dirname "$0")/.." || exit 1
REPO=../../../..
F=hsdd/contract/fixture
rm -rf hsdd && mkdir -p $F
cp $REPO/$F/analysis_options.yaml $F/
cp -R $REPO/$F/nidana-checks $F/
