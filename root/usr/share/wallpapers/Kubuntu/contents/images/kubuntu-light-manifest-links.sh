#!/bin/bash
# kubuntu-light-manifest-links.sh:
# This creates links to horizontal or vertical wallpapers for common sizes.
# Run it in this directory only, e.g.
#   ./kubuntu-light-manifest-links.shp
#

set -u;

_mainFn () {
  declare _hfile _vfile _size_table _line _bit_list \
    _expect_ratio _found_ratio _base_h_ratio _base_v_ratio \
    _base _file _suffix

  _hfile='7861x2545.svg';
  _vfile='2545x7861.svg';

  _size_table=(
    # 2:1 or 1:2
    '2|1|720|360'
    '2|1|1440|720'
    '2|1|2880|1440'
    '2|1|3840|1920'

    # 16:9 or 9:16
    '16|9|1920|1080'
    '16|9|3840|2160'

    # 16:10 or 10:16
    '16|10|1920|1200'
    '16|10|3840|2400'

    # 5:4 or 4:5
    '5|4|1280|1024'
    '5|4|2560|2048'
    '5|4|3000|2400'

    # 16|9 or 9|16
    '16|9|440|248'
    '16|9|640|360'
    '16|9|1024|576'
    '16|9|1280|720'
    '16|9|1366|768'
    '16|9|1600|900'
    '16|9|1680|945'
    '16|9|1920|1080'
    '16|9|2560|1440'
    '16|9|3200|1800'
    '16|9|5120|2880'

    # 16:10
    '16|10|640|400'
    '16|10|1280|800'
    '16|10|1440|900'
    '16|10|1680|1050'
    '16|10|1920|1200'
    '16|10|2560|1600'
    '16|10|3200|2000'
    '16|10|5120|3200'

    # 16:12 (4:3 or 3:4)
    '16|12|1024|768'
    '16|12|1600|1200'
    '16|12|2048|1536'
    '16|12|3200|2400'
  );

  for _line in "${_size_table[@]}"; do
    IFS='|' read -r -a _bit_list <<< "${_line}";
    _expect_ratio="$(bc <<< "scale=2; ${_bit_list[0]} / ${_bit_list[1]}" )";
    _found_ratio="$( bc <<< "scale=2; ${_bit_list[2]} / ${_bit_list[3]}" )";
    _base_h_str="${_bit_list[2]}x${_bit_list[3]}";
    _base_v_str="${_bit_list[3]}x${_bit_list[2]}";
    echo "|${_base_h_str}|${_base_v_str}|";
    if [ "${_expect_ratio}" != "${_found_ratio}" ]; then
      echo "Expected ratio does not match found: |${_expect_ratio} != ${_found_ratio}|";
      echo 'Skipped...';
      continue;
    fi
    for _base in "${_base_h_str}" "${_base_v_str}"; do
      for _suffix in png jpg svg; do
        _file="${_base}.${_suffix}";
        rm -f "${_file}";
      done
      if [ "${_base}" = "${_base_h_str}" ]; then
        ln -s "${_hfile}" "${_base}.svg";
      else
        ln -s "${_vfile}" "${_base}.svg";
      fi
    done
  done
}

_mainFn;

