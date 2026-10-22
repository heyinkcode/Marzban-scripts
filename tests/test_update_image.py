"""Offline update guards; Linux also exercises real Bash and Compose rendering."""
import os
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = (("marzban-node.sh", "marzban-node", "update_marzban_node_script"),
           ("marzban.sh", "marzban", "update_marzban_script"))
HELPERS = ("configured_service_image", "image_from_repository", "require_fork_update_image")


def function(text, name):
    match = re.search(r"(?ms)^" + re.escape(name) + r"\(\) \{\n.*?^\}", text)
    if not match:
        raise AssertionError("Missing function " + name)
    return match.group()


class SourceContractTests(unittest.TestCase):
    def test_both_commands_use_identical_recognition(self):
        texts = [(ROOT / name).read_text(encoding="utf-8") for name, _, _ in SCRIPTS]
        for helper in HELPERS:
            self.assertEqual(function(texts[0], helper), function(texts[1], helper))

    def test_update_does_not_require_yq_or_suppress_failure(self):
        for name, service, updater in SCRIPTS:
            body = function((ROOT / name).read_text(encoding="utf-8"), "update_command")
            self.assertNotIn("yq", body)
            self.assertIn('require_fork_update_image "' + service + '"', body)
            for call in ("backup_before_fork_update", "pull_fork_image", updater):
                self.assertIn(call + " || return 1", body)

    def test_no_running_container_or_raw_file_fallback(self):
        for name, _, _ in SCRIPTS:
            helper = function((ROOT / name).read_text(encoding="utf-8"), HELPERS[0])
            self.assertIn('config 2>/dev/null', helper)
            self.assertNotIn("inspect", helper)
            self.assertNotIn("yq", helper)
            self.assertNotIn('cat "$COMPOSE_FILE"', helper)

    def test_existing_adopt_retains_explicit_yq_requirement(self):
        for name, _, _ in SCRIPTS:
            body = function((ROOT / name).read_text(encoding="utf-8"), "adopt_command")
            self.assertIn("yq is required", body)
            self.assertIn("backup_before_fork_update", body)

    def test_namespace_helpers_are_identical(self):
        texts = [(ROOT / name).read_text(encoding="utf-8") for name, _, _ in SCRIPTS]
        for helper in ("rewrite_service_image", "migrate_fork_namespace"):
            self.assertEqual(function(texts[0], helper), function(texts[1], helper))

    def test_active_downloads_and_images_use_current_owner(self):
        for name, service, _ in SCRIPTS:
            text = (ROOT / name).read_text(encoding="utf-8")
            self.assertIn('FETCH_REPO="heyinkcode/Marzban-scripts"', text)
            self.assertNotIn('github.com/kissow', text)
            self.assertIn('ghcr.io/heyinkcode/' + service, text)
            self.assertIn('"ghcr.io/kissow/' + service + '" || return 1', text)


@unittest.skipUnless(sys.platform.startswith("linux"), "Real Bash/Compose runs in Linux CI")
class BashUpdateTests(unittest.TestCase):
    def run_update(self, image=None, *, service_missing=False, duplicate=False,
                   config_failure=False, fail_stage="", yq_present=False,
                   image_line=None, custom_name=True):
        for name, service, updater in SCRIPTS:
            with self.subTest(script=name), tempfile.TemporaryDirectory() as tmp:
                text = (ROOT / name).read_text(encoding="utf-8")
                selected = "unrelated" if service_missing else service
                value = (image if image is not None else "ghcr.io/heyinkcode/{service}:latest").replace("{service}", service)
                rendered = ("name: fixture\nservices:\n  decoy:\n    image: ghcr.io/heyinkcode/" + service +
                            ":latest\n  " + selected + ":\n    image: " + value + "\n")
                if image_line is not None:
                    rendered = rendered.replace("    image: " + value, image_line.replace("{service}", service))
                if duplicate:
                    rendered += "    image: " + value + "\n"
                rendered += ("    environment:\n      PRIVATE: synthetic-do-not-print\n"
                             "      image: ghcr.io/gozargah/" + service + ":latest\n"
                             "  database:\n    image: postgres:16\nnetworks:\n  default: {}\n")
                bin_path = Path(tmp) / "bin"
                bin_path.mkdir()
                awk = shutil.which("awk")
                self.assertIsNotNone(awk)
                (bin_path / "awk").symlink_to(awk)
                log = Path(tmp) / "events"
                program = "set -e\n" + "\n".join(function(text, f) for f in (*HELPERS, "update_command"))
                program += r'''
colorized_echo() { printf '%s\n' "$2"; }
check_running_as_root() { :; }
is_marzban_node_installed() { return 0; }
is_marzban_installed() { return 0; }
detect_compose() { :; }
compose_fixture() {
    [[ "$#" == 5 && "$1" == -f && "$2" == "$COMPOSE_FILE" && "$3" == -p && "$4" == "$APP_NAME" && "$5" == config ]] || return 90
    printf 'CONFIG\n' >> "$EVENT_LOG"
    if [[ "$CONFIG_FAILURE" == 1 ]]; then
        printf 'synthetic-do-not-print\n' >&2
        return 1
    fi
    printf '%s\n' "$FIXTURE_MODEL"
}
backup_before_fork_update() { printf 'BACKUP\n' >> "$EVENT_LOG"; [[ "$FAIL_STAGE" != BACKUP ]]; }
pull_fork_image() { printf 'PULL\n' >> "$EVENT_LOG"; [[ "$FAIL_STAGE" != PULL ]]; }
migrate_fork_namespace() { printf 'NAMESPACE\n' >> "$EVENT_LOG"; [[ "$FAIL_STAGE" != NAMESPACE ]] && pull_fork_image; }
update_marzban_node_script() { printf 'SCRIPT\n' >> "$EVENT_LOG"; [[ "$FAIL_STAGE" != SCRIPT ]]; }
update_marzban_script() { printf 'SCRIPT\n' >> "$EVENT_LOG"; [[ "$FAIL_STAGE" != SCRIPT ]]; }
'''
                if yq_present:
                    program += "yq() { printf 'YQ\n' >> \"$EVENT_LOG\"; return 127; }\n"
                # Deliberately call in an if: set -e alone must not hide stage failures.
                program += "if update_command; then exit 0; else exit $?; fi\n"
                env = os.environ.copy()
                env.update(PATH=str(bin_path), COMPOSE="compose_fixture", EVENT_LOG=str(log),
                           COMPOSE_FILE=str(Path(tmp) / "node config with spaces.yml"),
                           APP_NAME=service + "2" if custom_name else service,
                           FIXTURE_MODEL=rendered, CONFIG_FAILURE="1" if config_failure else "0",
                           FAIL_STAGE=fail_stage)
                result = subprocess.run([shutil.which("bash"), "--noprofile", "--norc", "-c", program],
                                        env=env, capture_output=True, text=True, timeout=10)
                events = log.read_text().splitlines() if log.exists() else []
                self.assertNotIn("synthetic-do-not-print", result.stdout + result.stderr)
                self.assertNotIn("YQ", events)
                yield result, events

    def assert_success(self, **kwargs):
        for result, events in self.run_update(**kwargs):
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertEqual(events, ["CONFIG", "BACKUP", "PULL", "SCRIPT"])

    def assert_rejected(self, *, official=False, **kwargs):
        for result, events in self.run_update(**kwargs):
            self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertEqual(events, ["CONFIG"])
            self.assertEqual(" adopt'" in result.stdout, official)

    def test_fork_without_yq(self):
        self.assert_success()

    def test_legacy_latest_enters_migration_before_pull(self):
        for result, events in self.run_update(image="ghcr.io/kissow/{service}:latest"):
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertEqual(events, ["CONFIG", "BACKUP", "NAMESPACE", "PULL", "SCRIPT"])

    def test_legacy_implicit_latest_enters_migration(self):
        for result, events in self.run_update(image="ghcr.io/kissow/{service}"):
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn("NAMESPACE", events)

    def test_legacy_pins_are_not_silently_changed(self):
        for suffix in (":stable-1", "@sha256:" + "a" * 64, ":latest@sha256:" + "b" * 64):
            self.assert_rejected(image="ghcr.io/kissow/{service}" + suffix)

    def test_legacy_prefix_lookalike_is_rejected(self):
        self.assert_rejected(image="ghcr.io/kissow/{service}-evil:latest")

    def test_namespace_failure_prevents_script_success(self):
        for result, events in self.run_update(image="ghcr.io/kissow/{service}:latest", fail_stage="NAMESPACE"):
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(events, ["CONFIG", "BACKUP", "NAMESPACE"])
            self.assertNotIn("updated successfully", result.stdout)

    def test_incompatible_yq_is_ignored(self):
        self.assert_success(yq_present=True)

    def test_default_command_name(self):
        self.assert_success(custom_name=False)

    def test_custom_tag(self):
        self.assert_success(image="ghcr.io/heyinkcode/{service}:stable-1")

    def test_implicit_latest(self):
        self.check_suffix("")

    def test_pinned_digest(self):
        self.check_suffix("@sha256:" + "a" * 64)

    def test_tag_and_digest(self):
        self.check_suffix(":stable-1@sha256:" + "b" * 64)

    def check_suffix(self, suffix):
        for quote in ("", "'", '"'):
            self.assert_success(image_line="    image: " + quote + "ghcr.io/heyinkcode/{service}" + suffix + quote)

    def test_official_not_silently_adopted(self):
        self.assert_rejected(official=True, image="ghcr.io/gozargah/{service}:latest")

    def test_other_repository_not_mislabeled_official(self):
        self.assert_rejected(image="ghcr.io/example/custom:latest")

    def test_prefix_lookalike_is_rejected(self):
        self.assert_rejected(image="ghcr.io/heyinkcode/{service}-evil:latest")

    def test_missing_target_does_not_match_other_service(self):
        self.assert_rejected(service_missing=True)

    def test_duplicate_image_fails_closed(self):
        self.assert_rejected(duplicate=True)

    def test_compose_failure_is_not_official_image(self):
        self.assert_rejected(config_failure=True)

    def test_missing_image_is_not_official_image(self):
        self.assert_rejected(image_line="    ports: []")

    def test_malformed_reference_is_rejected(self):
        self.assert_rejected(image="ghcr.io/heyinkcode/{service}:bad tag")

    def test_failed_backup_stops_pull(self):
        for result, events in self.run_update(fail_stage="BACKUP"):
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(events, ["CONFIG", "BACKUP"])

    def test_failed_pull_stops_script_refresh(self):
        for result, events in self.run_update(fail_stage="PULL"):
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(events, ["CONFIG", "BACKUP", "PULL"])

    def test_failed_script_refresh_does_not_report_success(self):
        for result, events in self.run_update(fail_stage="SCRIPT"):
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(events, ["CONFIG", "BACKUP", "PULL", "SCRIPT"])
            self.assertNotIn("updated successfully", result.stdout)

    def test_real_compose_resolves_env_and_yaml_anchors(self):
        self.assertIsNotNone(shutil.which("docker"))
        for name, service, _ in SCRIPTS:
            with self.subTest(script=name), tempfile.TemporaryDirectory() as tmp:
                path = Path(tmp) / "compose.yml"
                path.write_text('x-base: &base\n  image: ${TEST_IMAGE}\nservices:\n  ' + service +
                                ':\n    <<: *base\n    depends_on: [database]\n  database:\n    image: postgres:16\n')
                (Path(tmp) / ".env").write_text("TEST_IMAGE=ghcr.io/heyinkcode/" + service + ":stable-1\n")
                text = (ROOT / name).read_text()
                program = "set -e\n" + "\n".join(function(text, f) for f in HELPERS)
                program += '\ncolorized_echo() { printf "%s\\n" "$2"; }\n'
                program += 'configured_service_image "' + service + '"\n'
                env = os.environ.copy()
                env.pop("TEST_IMAGE", None)
                env.update(COMPOSE="docker compose", COMPOSE_FILE=str(path), APP_NAME="recognition-test")
                result = subprocess.run([shutil.which("bash"), "-c", program], env=env,
                                        capture_output=True, text=True, timeout=20)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stdout.strip(), "ghcr.io/heyinkcode/" + service + ":stable-1")


@unittest.skipUnless(sys.platform.startswith("linux"), "Real Bash backup flow runs in Linux CI")
class BashBackupTests(unittest.TestCase):
    def exercise_backup(self, failure=""):
        for name, service, _ in SCRIPTS:
            with self.subTest(script=name), tempfile.TemporaryDirectory() as tmp:
                app = Path(tmp) / "app"
                data = Path(tmp) / "data"
                app.mkdir()
                data.mkdir()
                (app / "docker-compose.yml").write_text("services: {}\n")
                (app / ".env").write_text("# local SQLite fixture\n")
                (data / "cert.pem").write_text("synthetic fixture\n")
                log = Path(tmp) / "events"
                text = (ROOT / name).read_text()
                program = "set -e\n" + function(text, "backup_before_fork_update") + r'''
colorized_echo() { printf '%s\n' "$2"; }
compose_fixture() {
    case "${*: -1}" in
        --quiet) step=VALIDATE ;;
        stop) step=STOP ;;
        -d) step=RESUME ;;
        *) return 90 ;;
    esac
    printf '%s\n' "$step" >> "$EVENT_LOG"
    [[ "$FAILURE" != "$step" ]]
}
mkdir() { [[ "$FAILURE" != MKDIR ]] && command mkdir "$@"; }
mktemp() { [[ "$FAILURE" != MKTEMP ]] && command mktemp "$@"; }
tar() {
    if [[ "$1" == -czf ]]; then step=ARCHIVE; else step=VERIFY; fi
    printf '%s\n' "$step" >> "$EVENT_LOG"
    [[ "$FAILURE" != "$step" ]] && command tar "$@"
}
if backup_before_fork_update; then exit 0; else exit $?; fi
'''
                env = os.environ.copy()
                env.update(APP_DIR=str(app), DATA_DIR=str(data), ENV_FILE=str(app / ".env"),
                           COMPOSE_FILE=str(app / "docker-compose.yml"), APP_NAME=service,
                           COMPOSE="compose_fixture", EVENT_LOG=str(log), FAILURE=failure)
                result = subprocess.run([shutil.which("bash"), "-c", program], env=env,
                                        capture_output=True, text=True, timeout=10)
                events = log.read_text().splitlines() if log.exists() else []
                if failure:
                    self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
                    self.assertNotIn("Pre-update", result.stdout)
                else:
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertEqual(events, ["VALIDATE", "STOP", "ARCHIVE", "VERIFY", "RESUME"])
                    self.assertEqual(len(list((app / "backup").glob("upgrade-*.tar.gz"))), 1)
                return_events = events
                if failure in ("VALIDATE", "MKDIR", "MKTEMP"):
                    self.assertNotIn("STOP", events)
                if failure == "STOP":
                    self.assertNotIn("ARCHIVE", events)
                if failure in ("ARCHIVE", "VERIFY"):
                    self.assertEqual(return_events[-1], "RESUME")
                self.assertEqual((data / "cert.pem").read_text(), "synthetic fixture\n")

    def test_real_archive_and_resume(self):
        self.exercise_backup()

    def test_invalid_config_stops_before_stop(self):
        self.exercise_backup("VALIDATE")

    def test_backup_directory_failure_stops(self):
        self.exercise_backup("MKDIR")

    def test_backup_file_failure_stops(self):
        self.exercise_backup("MKTEMP")

    def test_stop_failure_does_not_archive(self):
        self.exercise_backup("STOP")

    def test_archive_failure_resumes_without_success(self):
        self.exercise_backup("ARCHIVE")

    def test_verify_failure_resumes_without_success(self):
        self.exercise_backup("VERIFY")

    def test_resume_failure_is_not_success(self):
        self.exercise_backup("RESUME")


if __name__ == "__main__":
    unittest.main()
