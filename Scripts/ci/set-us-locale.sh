#!/usr/bin/env bash
# Pin US locale on CI runners (belt-and-suspenders with locale-independent tests).
set -euo pipefail

export LANG="${LANG:-en_US.UTF-8}"
export LC_ALL="${LC_ALL:-en_US.UTF-8}"
export LC_CTYPE="${LC_CTYPE:-en_US.UTF-8}"

if [[ "$(uname -s)" == "Darwin" ]]; then
  defaults write NSGlobalDomain AppleLanguages -array "en-US"
  defaults write NSGlobalDomain AppleLocale "en_US"
  defaults write NSGlobalDomain AppleMeasurementUnits -string "Inches"
  defaults write NSGlobalDomain AppleMetricUnits -bool false
fi

echo "Locale: LANG=$LANG LC_ALL=$LC_ALL"
