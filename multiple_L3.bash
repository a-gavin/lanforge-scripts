#!/bin/bash
set -veux
# Create multiple L3 cross-connects, monitor them for a while and exit
KBPS=1000
MBPS=1000000
GBPS=1000000000
# DBG="--debug"
DBG=''
# test prefix must be a single word, no punctuation or spaces
TEST_PREFIX="spiderman"
GUI="localhost"
if [[ ! -z "${1:-}" ]]; then
    GUI="$1"
fi
NUM_CX=${NUM_CX:-3}
UPSTREAM_PORT=${UPSTREAM:-"1.1.eth1"}
RADIOS=(
    1.1.wiphy0
    1.1.wiphy1
    1.2.wiphy0
    1.2.wiphy1
)
STATIONS=(
    1.1.sta0000
    1.1.sta0001
    1.2.sta0000
    1.2.sta0001
)
SSID="jedway-r7800-5G"
PASSWD="jedway-r7800-5G"
SEC="wpa2"
UPLOAD_BPS=(
    $((  2 * $MBPS))
    $((  1 * $MBPS))
    $((750 * $KBPS))
    $((750 * $KBPS))
)
DOWNLOAD_BPS=(
    $((  1 * $MBPS))
    $((  2 * $MBPS))
    $((250 * $KBPS))
    $((250 * $KBPS))
)
cd ./py-scripts
LAST_STA_IDX=$(( ${#STATIONS[@]}- 1))
EXISTING_STATIONS=( $(./modify_station.py --mgr "$GUI" --list_stations) )
# check for connection group name
EXISTING_GROUPS=( $(./testgroup.py --mgr "$GUI" --list_groups) )
ADD_GROUP=0
if echo "${EXISTING_GROUPS[@]}" | grep -q 'No test groups found'; then
    ADD_GROUP=1
elif ! echo "${EXISTING_GROUPS[@]}" | grep -q "$TEST_PREFIX"; then
    ADD_GROUP=1
fi
if (( ADD_GROUP > 0 )); then
    ./testgroup.py --mgr "$GUI" --add_group --group_name "$TEST_PREFIX"
    ./raw_cli.py --mgr "$GUI" --cmd show_group --param "group $TEST_PREFIX"
fi

for i in $(seq 0 $LAST_STA_IDX); do
    if echo "${EXISTING_STATIONS[@]}" | grep -q "${STATIONS[$i]}" ; then
        echo "station ${STATIONS[$i]} exists"
    else
        ./create_station.py --mgr "$GUI" $DBG \
            --radio         "${RADIOS[$i]}" \
            --security      "$SEC" \
            --ssid          "$SSID" \
            --passwd        "$PASSWD" \
            --mode          anAC \
            --radio_channel 153 \
            --country_code  840 \
            --no_pre_cleanup \
            --no_cleanup \
         || echo "problem creating station ${STATIONS[$i]}] "
    fi
    ./create_l3.py --mgr "$GUI" $DBG \
        --cx_type       "${TYPE:-lf_udp}" \
        --cx_prefix     "${TEST_PREFIX}_$i-" \
        --endp_a        "${STATIONS[$i]}" \
        --endp_b        "${UPSTREAM_PORT}" \
        --min_rate_a    "${UPLOAD_BPS[$i]}" \
        --min_rate_b    "${DOWNLOAD_BPS[$i]}" \
        --no_pre_cleanup --no_cleanup
    ./raw_cli.py --mgr "$GUI" --cmd nc_show_endpoints --arg "endpoint all"
done
for i in $(seq 0 $LAST_STA_IDX); do
    short_sta="${STATIONS[$i]}"
    short_sta="${short_sta##*.}-0" # need to turn 1.1.sta0000 to sta0000-0
    ./testgroup.py --mgr "$GUI" $DBG \
        --group_name    "$TEST_PREFIX" \
        --add_cx        "${TEST_PREFIX}_${i}-${short_sta}" \
        --use_existing
done
./raw_cli.py --mgr "$GUI" --cmd show_group --arg "group $TEST_PREFIX"
sleep 1
./testgroup.py --mgr "$GUI" $DBG \
    --use_existing \
    --group_name $TEST_PREFIX \
    --start_group $TEST_PREFIX
sleep 10
./testgroup.py --mgr "$GUI" \
    --use_existing \
    --group_name $TEST_PREFIX \
    --quiesce_group $TEST_PREFIX