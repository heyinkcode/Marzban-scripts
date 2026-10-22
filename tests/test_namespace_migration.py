"""Real Compose model equivalence and image-only owner migration; no daemon writes."""
import os
import re
import shutil
import stat
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from test_update_image import ROOT, SCRIPTS, function


@unittest.skipUnless(sys.platform.startswith("linux"), "Real Bash/Compose migration runs in Linux CI")
class NamespaceMigrationTests(unittest.TestCase):
    def exercise(self, layout="plain", failure="", expected_success=True):
        for name, service, _ in SCRIPTS:
            with self.subTest(script=name, layout=layout, failure=failure), tempfile.TemporaryDirectory() as tmp:
                app = Path(tmp) / "app with spaces"
                app.mkdir()
                (app / "backup").mkdir(mode=0o700)
                (app / "data").mkdir()
                original_image = "ghcr.io/kissow/" + service + ":latest"
                new_image = "ghcr.io/heyinkcode/" + service + ":latest"
                raw = ("services:\n  " + service + ":\n    image: " + original_image +
                       "\n    environment:\n      PRIVATE: ${PRIVATE}\n    ports: ['8443:8443']\n"
                       "    volumes: ['./data:/var/lib/app']\n  database:\n    image: postgres:16\n")
                if layout == "env":
                    raw = raw.replace(original_image, "${LEGACY_IMAGE}")
                elif layout == "anchor":
                    raw = "x-base: &base\n  image: " + original_image + "\n" + raw.replace("    image: " + original_image, "    <<: *base")
                elif layout == "quotes":
                    raw = raw.replace("  " + service + ":", '  "' + service + '":').replace(original_image, "'" + original_image + "'")
                elif layout == "unsupported":
                    raw = "services: {" + service + ": {image: '" + original_image + "'}}\n"
                path = app / "docker-compose.yml"
                path.write_text(raw)
                path.chmod(0o640)
                env_path = app / ".env"
                env_text = "PRIVATE=synthetic-do-not-print\nLEGACY_IMAGE=" + original_image + "\n"
                env_path.write_text(env_text)
                log = app / "events"
                source = (ROOT / name).read_text()
                program = "set -e\n" + "\n".join(function(source, item) for item in
                    ("configured_service_image", "rewrite_service_image", "migrate_fork_namespace", "pull_fork_image"))
                program += r'''
colorized_echo() { printf '%s\n' "$2"; }
compose_fixture() {
    local file="$2"
    case "$5" in
        config) command docker compose "$@" ;;
        pull)
            if [[ "$file" == "$COMPOSE_FILE" ]]; then
                printf 'ACTIVE_PULL\n' >> "$EVENT_LOG"
                [[ "$FAILURE" != ACTIVE_PULL ]]
            else
                printf 'PRE_PULL\n' >> "$EVENT_LOG"
                [[ "$FAILURE" != PRE_PULL ]]
            fi ;;
        up)
            if grep -q 'ghcr.io/heyinkcode/' "$file"; then
                printf 'NEW_UP\n' >> "$EVENT_LOG"
                [[ "$FAILURE" != NEW_UP && "$FAILURE" != RECOVERY ]]
            else
                printf 'OLD_UP\n' >> "$EVENT_LOG"
                [[ "$FAILURE" != RECOVERY ]]
            fi ;;
        *) return 90 ;;
    esac
}
if migrate_fork_namespace "$SERVICE" "$NEW_IMAGE"; then exit 0; else exit $?; fi
'''
                env = os.environ.copy()
                env.update(APP_DIR=str(app), COMPOSE_FILE=str(path), APP_NAME=service + "2", SERVICE=service,
                           COMPOSE="compose_fixture", EVENT_LOG=str(log), FAILURE=failure, NEW_IMAGE=new_image)
                result = subprocess.run([shutil.which("bash"), "--noprofile", "--norc", "-c", program],
                                        env=env, capture_output=True, text=True, timeout=40)
                self.assertNotIn("synthetic-do-not-print", result.stdout + result.stderr)
                self.assertEqual(env_path.read_text(), env_text)
                self.assertEqual(stat.S_IMODE(path.stat().st_mode), 0o640)
                self.assertFalse(list(app.glob(".owner-*")))
                events = log.read_text().splitlines() if log.exists() else []
                if expected_success:
                    self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                    self.assertIn(new_image, path.read_text())
                    self.assertEqual(events, ["PRE_PULL", "ACTIVE_PULL", "NEW_UP"])
                    backup = list((app / "backup").glob("namespace-compose-*.yml"))
                    self.assertEqual(len(backup), 1)
                    self.assertEqual(backup[0].read_text(), raw)
                else:
                    self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
                    self.assertEqual(path.read_text(), raw)
                    self.assertNotIn("Image namespace migrated", result.stdout)
                    if layout == "unsupported":
                        self.assertEqual(events, [])
                    if failure in ("NEW_UP", "RECOVERY", "ACTIVE_PULL"):
                        self.assertEqual(events[-1], "OLD_UP")

    def test_plain_preserves_ports_volumes_env_and_other_services(self):
        self.exercise()

    def test_environment_image(self):
        self.exercise("env")

    def test_inherited_anchor_image(self):
        self.exercise("anchor")

    def test_quoted_service_and_image(self):
        self.exercise("quotes")

    def test_unsupported_yaml_is_unchanged(self):
        self.exercise("unsupported", expected_success=False)

    def test_registry_failure_before_write(self):
        self.exercise(failure="PRE_PULL", expected_success=False)

    def test_pull_failure_restores_original(self):
        self.exercise(failure="ACTIVE_PULL", expected_success=False)

    def test_start_failure_restores_original(self):
        self.exercise(failure="NEW_UP", expected_success=False)

    def test_failed_recovery_never_reports_success(self):
        self.exercise(failure="RECOVERY", expected_success=False)


@unittest.skipUnless(sys.platform.startswith("linux"), "Documented bootstrap runs in Linux CI")
class BootstrapCommandTests(unittest.TestCase):
    def exercise(self, failure=""):
        guide = (ROOT / "docs/GITHUB_NAMESPACE_MIGRATION.md").read_text()
        commands = re.findall(r"```sh\n(sudo bash -c [^\n]+)\n```", guide)
        self.assertEqual(len(commands), 2)
        for command in commands:
            with self.subTest(command=command, failure=failure), tempfile.TemporaryDirectory() as tmp:
                base = Path(tmp)
                bin_path = base / "bin"
                bin_path.mkdir()
                log = base / "events"
                fixtures = {
                    "sudo": '#!/bin/bash\nexec "$@"\n',
                    "curl": r'''#!/bin/bash
[[ "$FAILURE" != DOWNLOAD ]] || exit 22
while [[ $# -gt 0 ]]; do
    if [[ "$1" == -o ]]; then destination="$2"; break; fi
    shift
done
printf '%s\n' '[[ "$1" == install-script ]] || exit 90' 'printf "INSTALL\\n" >> "$EVENT_LOG"' '[[ "$FAILURE" != INSTALL ]] || exit 1' > "$destination"
''',
                    "marzban": '#!/bin/bash\nprintf "UPDATE\\n" >> "$EVENT_LOG"\n',
                    "marzban-node": '#!/bin/bash\nprintf "UPDATE\\n" >> "$EVENT_LOG"\n',
                }
                for name, body in fixtures.items():
                    path = bin_path / name
                    path.write_text(body)
                    path.chmod(0o755)
                env = os.environ.copy()
                env.update(PATH=str(bin_path) + os.pathsep + env["PATH"], EVENT_LOG=str(log), FAILURE=failure, TMPDIR=tmp)
                result = subprocess.run([shutil.which("bash"), "--noprofile", "--norc", "-c", command],
                                        env=env, capture_output=True, text=True, timeout=10)
                events = log.read_text().splitlines() if log.exists() else []
                if failure:
                    self.assertNotEqual(result.returncode, 0, result.stderr)
                    self.assertNotIn("UPDATE", events)
                else:
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertEqual(events, ["INSTALL", "UPDATE"])
                self.assertFalse(list(base.glob("tmp.*")))

    def test_exact_documented_commands_refresh_before_update(self):
        self.exercise()

    def test_download_failure_never_runs_old_cli(self):
        self.exercise("DOWNLOAD")

    def test_install_failure_never_updates(self):
        self.exercise("INSTALL")
