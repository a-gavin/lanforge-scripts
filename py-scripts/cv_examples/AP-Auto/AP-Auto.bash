#!/bin/bash
#
# NAME:
#   AP-Auto.bash
#
# PURPOSE:
#   Automation script to run the 'AP-Auto' Chamber View test.
#
# USAGE:
#   ./AP-Auto.bash
#
# SUMMARY:
#   This bash script performs the following:
#     - Creates/updates a DUT
#     - Creates/updates a Chamber View scenario
#     - Loads and builds the scenario
#     - Runs the 'AP-Auto' test, saving generated reports
#
#   See the README in the 'cv_examples' directory for more information.
set -x

# 0. TEST CONFIGURATION
#
# NOTE: If you change MGR to a remote IP, ensure that the IP address
#       is the same as the machine running the LANforge GUI.
#
# General configuration
MGR=localhost                               # Substitute for manager LANforge IP if running script remotely
MGR_PORT=8080                               # Unlikely this needs to change
TESTBED=Example-Testbed                     # Name of your testbed as it appears in report

LF_SCRIPTS=/home/lanforge/lanforge-scripts  # Modify this to point at your copy of LANforge scripts.
LF_PY_SCRIPTS=$LF_SCRIPTS/py-scripts        # Directory of LANforge Python scripts.
                                            # Useful if running this script in another directory.

TEST_CFG=AP-Auto.cfg                      # 'AP-Auto' test config file. If not specified in test script
                                            # CLI, then any unspecified options will use default test values.

RPT_DIR=/tmp/AP-Auto_reports              # Output directory for generated reports and associated data

# Chamber View Scenario name
CV_SCENARIO_NAME=AP-Auto_Automated_Test

# Upstream configuration
UPSTREAM_RSRC=1.2                           # In form Shelf.Resource. Shelf is almost always '1'
UPSTREAM_PORT=eth3                          # Name or alias of port. Usually an Ethernet port
UPSTREAM=$UPSTREAM_RSRC.$UPSTREAM_PORT      # Combined to form EID

# DUT configuration
#
# NOTE: Do not put quotes around these values as some of them
#       will be substituted into other strings.
DUT_NAME=AP-Auto_DUT                      # Name of DUT as it appears in report

SSID_2G=test_ssid_2ghz                      # 2.4GHz radio SSID
BSSID_2G=00:00:00:00:00:02                  # 2.4GHz radio BSSID
PASSWD_2G=test_passwd                       # 2.4GHz radio password
AUTH_2G=WPA2\|WPA3                          # 2.4GHz radio authentication type

SSID_5G=test_ssid_5ghz                      # 5GHz radio SSID
BSSID_5G=00:00:00:00:00:05                  # 5GHz radio BSSID
PASSWD_5G=test_passwd                       # 5GHz radio password
AUTH_5G=WPA2\|WPA3                          # 5GHz radio authentication type

SSID_6G=test_ssid_6ghz                      # 6GHz radio SSID
BSSID_6G=00:00:00:00:00:06                  # 6GHz radio BSSID
PASSWD_6G=test_passwd                       # 6GHz radio password
AUTH_6G=WPA3                                # 6GHz radio authentication type

# AP-AUTO-SPECIFIC TEST CONFIGURATION
#
RADIO_2G=1.1.wiphy0
RADIO_5G=1.1.wiphy1

MAX_STATIONS_2G=10
MAX_STATIONS_5G=10
MAX_STATIONS_DUAL=10

# AP-Auto sub-tests. '1' enables the test. '0' disables the test.
TEST_BASIC_CLIENT_CONNECTIVITY=1
TEST_BAND_STEERING=0
TEST_CAPACITY=0
TEST_CHANNEL_SWITCHING=0
TEST_LONG_TERM=0
TEST_STABILITY=0
TEST_SINGLE_STA_THROUGHPUT_VS_PKT_SIZE=0
TEST_MULTI_STA_THROUGHPUT_VS_PKT_SIZE=0
TEST_MULTI_BAND_PERFORMANCE=1
TEST_SKIP_24GHZ=1
TEST_SKIP_5GHZ=0


# Allow sourcing a file to override the configuration values set above.
if [ -f local.cfg ]
then
    . local.cfg
fi


# 1. CREATE/UPDATE NEW DUT
#
# NOTE: Separate SSID option arguments with spaces and ensure the keys are lowercase
echo "Creating/Updating DUT \'$DUT_NAME\'"

$LF_PY_SCRIPTS/create_chamberview_dut.py \
    --lfmgr       $MGR \
    --port        $MGR_PORT \
    --dut_name    $DUT_NAME \
    --ssid        "ssid_idx=0 ssid=$SSID_2G security=$AUTH_2G password=$PASSWD_2G bssid=$BSSID_2G" \
    --ssid        "ssid_idx=1 ssid=$SSID_5G security=$AUTH_5G password=$PASSWD_5G bssid=$BSSID_5G" \
    --ssid        "ssid_idx=2 ssid=$SSID_6G security=$AUTH_6G password=$PASSWD_6G bssid=$BSSID_6G" \
    --sw_version  "beta-beta" \
    --hw_version  "beta-6e" \
    --serial_num  "001" \
    --model_num   "test" \
    --dut_flag    "AP_MODE" \
    --dut_flag    "DHCPD-LAN"


# 2. CREATE/UPDATE AND BUILD CHAMBER VIEW SCENARIO
#
# NOTE: You will need to update this any time you change your Chamber View Scenario.
#
# See README in same directory for instructions on building a
# Chamber View scenario with the `create_chamberview.py` script.
printf "Build Chamber View Scenario with DUT \'$DUT_NAME\' and upstream \'$UPSTREAM_PORT\'"

# This example creates the following:
#   - LAN Ethernet upstream w/ DHCP enabled (the 'DUT $DUT_NAME LAN')
$LF_PY_SCRIPTS/create_chamberview.py \
    --lfmgr $MGR \
    --port $MGR_PORT \
    --delete_scenario \
    --create_scenario $CV_SCENARIO_NAME \
    --raw_line "profile_link 1.1 upstream 1 'DUT: $DUT_NAME LAN'     NA $UPSTREAM_PORT,AUTO -1 NA"


# 3. RUN 'AP-Auto' TEST
#
# See README in same directory for instructions on building a
# Chamber View scenario with the 'lf_ap_auto_test.py' script.
printf "Starting AP-Auto test"

$LF_PY_SCRIPTS/lf_ap_auto_test.py \
    --mgr                   $MGR \
    --port                  $MGR_PORT \
    --lf_user               "lanforge" \
    --lf_password           "lanforge" \
    --instance_name         "ap-auto-instance" \
    --config_name           "test_con" \
    --test_rig              $TESTBED \
    --pull_report           \
    --local_lf_report_dir   $RPT_DIR \
    --raw_lines_file        $TEST_CFG \
    --upstream              $UPSTREAM \
    --dut2_0                "$DUT_NAME $SSID_2G $BSSID_2G (1)" \
    --dut5_0                "$DUT_NAME $SSID_5G $BSSID_5G (2)" \
    --max_stations_2        $MAX_STATIONS_2G \
    --max_stations_5        $MAX_STATIONS_5G \
    --max_stations_dual     $MAX_STATIONS_DUAL \
    --radio2                $RADIO_2G \
    --radio5                $RADIO_5G \
    --set 'basic_cx'        $TEST_BASIC_CLIENT_CONNECTIVITY \
    --set 'band_steering'   $TEST_BAND_STEERING \
    --set 'capacity'        $TEST_CAPACITY \
    --set 'channel_switch'  $TEST_CHANNEL_SWITCHING \
    --set 'long_term'       $TEST_LONG_TERM \
    --set 'mix_stability'   $TEST_STABILITY \
    --set 'tput_single_sta' $TEST_SINGLE_STA_THROUGHPUT_VS_PKT_SIZE \
    --set 'tput_multi_sta'  $TEST_MULTI_STA_THROUGHPUT_VS_PKT_SIZE \
    --set 'tput_multi_band' $TEST_MULTI_BAND_PERFORMANCE \
    --set 'skip_2'          $TEST_SKIP_24GHZ \
    --set 'skip_5'          $TEST_SKIP_5GHZ \

echo "Test is complete. Report can be found in $RPT_DIR"
