"""Installer boundary checks using a fake sf executable; no org is changed."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


INSTALLER = Path(__file__).resolve().parents[1] / "install.sh"


class InstallerTest(unittest.TestCase):
    def run_installer(self, *args, deploy_status=0, smoke_status=0):
        with tempfile.TemporaryDirectory(prefix="value mapper ") as folder:
            root = Path(folder)
            fake_sf = root / "sf"
            fake_sf.write_text(
                "#!/usr/bin/env python3\n"
                "import json, os, sys\n"
                "with open(os.environ['MAPPER_CALL_LOG'], 'a') as log:\n"
                "    log.write(json.dumps({'args': sys.argv[1:], 'cwd': os.getcwd()}) + '\\n')\n"
                "status = 'MAPPER_DEPLOY_STATUS' if sys.argv[1] == 'project' else 'MAPPER_SMOKE_STATUS'\n"
                "sys.exit(int(os.environ[status]))\n"
            )
            fake_sf.chmod(0o755)
            call_log = root / "calls.jsonl"
            result = subprocess.run(
                ["bash", str(INSTALLER), *args], cwd=root,
                env={**os.environ, "PATH": str(root) + os.pathsep + os.environ["PATH"],
                     "MAPPER_CALL_LOG": str(call_log),
                     "MAPPER_DEPLOY_STATUS": str(deploy_status),
                     "MAPPER_SMOKE_STATUS": str(smoke_status)},
                capture_output=True, text=True,
            )
            calls = [json.loads(line) for line in call_log.read_text().splitlines()] if call_log.exists() else []
            return result, calls

    def test_requires_explicit_org_before_calling_sf(self):
        for args in [(), ("--target-org",), ("--target-org", "--dry-run"),
                     ("--target-org", "org", "--wait", "0"),
                     ("--target-org", "org", "--test-level", "NoTestRun"),
                     ("--unknown",)]:
            with self.subTest(args=args):
                result, calls = self.run_installer(*args)
                self.assertNotEqual(0, result.returncode)
                self.assertEqual([], calls)

    def test_core_only_and_explicit_org_on_every_command(self):
        result, calls = self.run_installer("--target-org", "my chosen org")
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertEqual(2, len(calls))
        self.assertNotIn("examples", calls[0]["args"])
        self.assertIn("MappingResolverTest", calls[0]["args"])
        self.assertIn("MappingFlowActionTest", calls[0]["args"])
        for call in calls:
            args = call["args"]
            self.assertEqual("my chosen org", args[args.index("--target-org") + 1])
            self.assertEqual(str(INSTALLER.parents[1]), call["cwd"])
        self.assertIn("scripts/apex/value-mapper-smoke.apex", calls[1]["args"])

    def test_examples_are_opt_in(self):
        result, calls = self.run_installer("--target-org", "demo", "--with-examples")
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertEqual(3, len(calls))
        self.assertIn("examples", calls[0]["args"])
        self.assertIn("scripts/apex/value-mapper-demo.apex", calls[2]["args"])

    def test_dry_run_never_executes_smoke(self):
        result, calls = self.run_installer("--target-org", "demo", "--dry-run")
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertEqual(1, len(calls))
        self.assertIn("--dry-run", calls[0]["args"])

    def test_failed_or_pending_deploy_never_executes_smoke(self):
        for status in [1, 68, 69]:
            with self.subTest(status=status):
                result, calls = self.run_installer("--target-org", "demo", deploy_status=status)
                self.assertEqual(status, result.returncode)
                self.assertEqual(1, len(calls))

    def test_smoke_failure_is_not_reported_as_success(self):
        result, calls = self.run_installer("--target-org", "demo", "--with-examples", smoke_status=1)
        self.assertEqual(1, result.returncode)
        self.assertEqual(2, len(calls))
        self.assertNotIn("installation and smoke checks passed", result.stdout)

    def test_local_tests_omit_specified_test_flag(self):
        result, calls = self.run_installer("--target-org", "demo", "--test-level", "RunLocalTests", "--wait", "12")
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertIn("RunLocalTests", calls[0]["args"])
        self.assertNotIn("--tests", calls[0]["args"])
        self.assertIn("12", calls[0]["args"])


if __name__ == "__main__":
    unittest.main()
