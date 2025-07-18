#!/usr/bin/env python3
# This script will set the LANforge to a BLANK database then it will load the specified database
# and start a graphical report
import sys
import os
import importlib
import argparse
from pprint import pprint
from time import sleep

if sys.version_info[0] != 3:
    print("This script requires Python 3")
    exit(1)

sys.path.append(os.path.join(os.path.abspath(__file__ + "../../../")))

LFUtils = importlib.import_module("py-json.LANforge.LFUtils")
lfcli_base = importlib.import_module("py-json.LANforge.lfcli_base")
LFCliBase = lfcli_base.LFCliBase
realm = importlib.import_module("py-json.realm")
Realm = realm.Realm

"""
    cvScenario.lanforge_db = args.lanforge_db
    if args.cv_test is not None:
        cvScenario.cv_test = args.cv_test
    if args.test_scenario is not None:
        cvScenario.test_scenario = args.test_scenario
"""


class RunCvScenario(LFCliBase):
    def __init__(self, lfhost="localhost", lfport=8080, debug_=False, lanforge_db_=None, cv_scenario_=None,
                 cv_test_=None, test_scenario_=None):
        super().__init__(_lfjson_host=lfhost, _lfjson_port=lfport, _debug=debug_, _exit_on_error=True,
                         _exit_on_fail=True)
        self.lanforge_db = lanforge_db_
        self.cv_scenario = cv_scenario_
        self.cv_test = cv_test_
        self.test_profile = test_scenario_
        self.localrealm = Realm(lfclient_host=lfhost, lfclient_port=lfport, debug_=debug_)
        self.report_name = None

    def get_report_file_name(self):
        return self.report_name

    def build(self):
        data = {
            "name": "BLANK",
            "action": "overwrite",
            "clean_dut": "yes",
            "clean_chambers": "yes"
        }
        self.json_post("/cli-json/load", data)
        sleep(1)
        port_counter = 0
        attempts = 6
        while (attempts > 0) and (port_counter > 0):
            sleep(1)
            attempts -= 1
            print("looking for ports like vap+")
            port_list = self.localrealm.find_ports_like("vap+")
            alias_map = LFUtils.portListToAliasMap(port_list)
            port_counter = len(alias_map)

            port_list = self.localrealm.find_ports_like("sta+")
            alias_map = LFUtils.portListToAliasMap(port_list)
            port_counter += len(alias_map)
            if port_counter == 0:
                break

        if (port_counter != 0) and (attempts == 0):
            print("There appears to be a vAP in this database, quitting.")
            pprint(alias_map)
            exit(1)

        data = {
            "name": self.lanforge_db,
            "action": "overwrite",
            "clean_dut": "yes",
            "clean_chambers": "yes"
        }
        self.json_post("/cli-json/load", data)
        sleep(5)
        self._pass("Loaded scenario %s" % self.lanforge_db, True)
        return True

    def start(self, debug_=False):
        # /gui_cli takes commands keyed on 'cmd', so we create an array of commands
        commands = [
            # "cv apply '%s'" % self.cv_scenario,
            "sleep 5",
            "cv build",
            "sleep 5",
            "cv is_built",
            "sleep 2",
            "cv sync",
            "sleep 1",
            "cv create '%s' test_ref 'true'" % self.cv_test,
            "sleep 5",
            "cv load test_ref '%s'" % self.test_profile,
            "sleep 2",
            "cv set test_ref 'Auto Save Report' true",
            "sleep 4",
            "cv click test_ref Start",
            "sleep 2",
            "cv click test_ref 'Another Iteration'",
            "sleep 240",
            # sleep for (test duration for 1 time test takes  x num iterations requested) - this example is 2 iterations
            "cv click test_ref 'Another Iteration'",  # unselect Another Iteration before test ends
            "sleep 50"  # finish test
            "cv get test_ref 'Report Location:'",
            "sleep 5",
            "cv click test_ref 'Save HTML'",
            "cv click test_ref 'Close'",
            "sleep 1",
            "cv click test_ref Cancel",
            "sleep 1",
            "exit"
        ]
        for command in commands:
            data = {
                "cmd": command
            }
            try:
                debug_par = ""
                if debug_:
                    debug_par = "?_debug=1"
                if command.endswith("is_built"):
                    print("Waiting for scenario to build...", end='')
                    self.localrealm.wait_while_building(debug_=False)
                    print("...proceeding")
                elif command.startswith("sleep "):
                    nap = int(command.split(" ")[1])
                    print("sleeping %d..." % nap)
                    sleep(nap)
                    print("...proceeding")
                else:
                    response_json = []
                    print("running %s..." % command, end='')
                    self.json_post("/gui-json/cmd%s" % debug_par, data, debug_=False, response_json_list_=response_json)
                    if debug_:
                        LFUtils.debug_printer.pprint(response_json)
                    print("...proceeding")

            except Exception as x:
                print(x)

        self._pass("report finished", print_=True)

    def stop(self):
        pass

    def cleanup(self):
        pass


def main():
    lfjson_host = "localhost"
    lfjson_port = 8080
    parser = argparse.ArgumentParser(
        prog="rvr_scenario.py",
        formatter_class=argparse.RawTextHelpFormatter,
        description="""LANforge Reporting Script:  Load a scenario and run a RvR report
Example:
./rvr_scenario.py --lfmgr 127.0.0.1 --lanforge_db 'handsets' --cv_test  --test_scenario 'test-20'
""")
    parser.add_argument("-m", "--lfmgr", type=str,
                        help="address of the LANforge GUI machine (localhost is default)")
    parser.add_argument("-o", "--port", type=int,
                        help="IP Port the LANforge GUI is listening on (8080 is default)")
    parser.add_argument("--lanforge_db", "--db", "--lanforge_scenario", type=str,
                        help="Name of test scenario database (see Status Tab)")
    parser.add_argument("-c", "--cv_scenario", type=str,
                        help="Name of Chamber View test scenario (see CV Manage Scenarios)")
    parser.add_argument("-n", "--cv_test", type=str,
                        help="Chamber View test")
    parser.add_argument("-s", "--test_profile", "--test_settings", type=str,
                        help="Name of the saved CV test settings")
    parser.add_argument('--help_summary', action="store_true",
                        help='Show summary of what this script does')

    args = parser.parse_args()

    help_summary = '''\
LANforge Reporting Script:  Load a scenario and run a RvR report.
'''
    if args.help_summary:
        print(help_summary)
        exit(0)

    if not args.cv_scenario or not args.cv_test or not args.test_profile:
        print("Warning: --cv_scenario , --cv_test and --test_settings required ")
        exit(1)

    if args.lfmgr is not None:
        lfjson_host = args.lfmgr
    if args.port is not None:
        lfjson_port = args.port

    run_cv_scenario = RunCvScenario(lfjson_host, lfjson_port)

    if args.lanforge_db is not None:
        run_cv_scenario.lanforge_db = args.lanforge_db
    if args.cv_scenario is not None:
        run_cv_scenario.cv_scenario = args.cv_scenario
    if args.cv_test is not None:
        run_cv_scenario.cv_test = args.cv_test
    if args.test_profile is not None:
        run_cv_scenario.test_profile = args.test_profile

    if (run_cv_scenario.lanforge_db is None) or (run_cv_scenario.lanforge_db == ""):
        run_cv_scenario.lanforge_db = "DFLT"
        # raise ValueError("Please specificy scenario database name with --lanforge_db")

    if not (run_cv_scenario.build() and run_cv_scenario.passes()):
        print("scenario failed to build.")
        print(run_cv_scenario.get_fail_message())
        exit(1)

    if not (run_cv_scenario.start() and run_cv_scenario.passes()):
        print("scenario failed to start.")
        print(run_cv_scenario.get_fail_message())
        exit(1)

    if not (run_cv_scenario.stop() and run_cv_scenario.passes()):
        print("scenario failed to stop:")
        print(run_cv_scenario.get_fail_message())
        exit(1)

    if not (run_cv_scenario.cleanup() and run_cv_scenario.passes()):
        print("scenario failed to clean up:")
        print(run_cv_scenario.get_fail_message())
        exit(1)

    report_file = run_cv_scenario.get_report_file_name()
    print("Report file saved to " + report_file)


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -


if __name__ == "__main__":
    main()
