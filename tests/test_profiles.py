"""Offline profile checks. All linking and adoption use a temporary checkout."""

import os
import pty
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
GHOSTTY = shutil.which("ghostty")
if (
    GHOSTTY is None
    and Path("/Applications/Ghostty.app/Contents/MacOS/ghostty").exists()
):
    GHOSTTY = "/Applications/Ghostty.app/Contents/MacOS/ghostty"


@unittest.skipUnless(
    shutil.which("stow") and shutil.which("zsh"), "Requires GNU Stow and Zsh"
)
class ProfilesTest(unittest.TestCase):
    def setUp(self):
        self.work = tempfile.TemporaryDirectory(prefix="dotfiles-check-")
        self.addCleanup(self.work.cleanup)
        self.root = Path(self.work.name)
        self.checkout = self.root / "repo"
        shutil.copytree(
            REPO,
            self.checkout,
            symlinks=True,
            ignore=shutil.ignore_patterns(".git", ".ruff_cache", "__pycache__"),
        )
        self.home = self.root / "home"
        self.home.mkdir()
        self.env = dict(
            os.environ,
            HOME=str(self.home),
            XDG_STATE_HOME=str(self.home / ".local/state"),
            XDG_CONFIG_HOME=str(self.home / ".config"),
        )
        self.env.pop("ZDOTDIR", None)

    def bash(self, code, *, check=True):
        result = subprocess.run(
            ["bash", "-ec", code],
            cwd=self.checkout,
            env=self.env,
            capture_output=True,
            text=True,
            check=False,
        )
        if check:
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        return result

    def cli(self, profile="linux-server", action="stow", backend="apt", flags=""):
        platform = "macos" if profile == "macos" else "linux"
        return self.bash(
            "source scripts/lib/common.sh; "
            f"detect_platform() {{ PLATFORM={platform}; BACKEND={backend}; ID=ubuntu; }}; "
            f"main {action} --profile {profile} {flags}"
        )

    def test_fresh_repeat_and_profile_switch(self):
        for profile, backend in [
            ("macos", "brew"),
            ("linux-server", "apt"),
            ("linux-desktop", "apt"),
            ("linux-server", "apt"),
        ]:
            with self.subTest(profile=profile):
                self.cli(profile, backend=backend)
                self.cli(profile, backend=backend)
                self.assertTrue((self.home / ".zshrc").is_symlink())
                self.assertTrue((self.home / ".config/nvim/init.lua").is_symlink())
                for config in [
                    "ghostty/config.ghostty",
                    "zed/keymap.json",
                    "zed/settings.json",
                ]:
                    self.assertEqual(
                        (self.home / ".config" / config).exists(),
                        profile != "linux-server",
                    )
                self.assertEqual((self.home / ".macos").exists(), profile == "macos")
                self.assertFalse((self.home / "scripts").exists())
                self.assertFalse((self.home / "settings").exists())
                self.assertFalse(
                    (self.home / ".config/cmux/cmux.json.cmux-write.lock").exists()
                )
                self.assertIn(
                    f"profile={profile}",
                    (self.home / ".local/state/dotfiles/machine").read_text(),
                )

    def test_previous_layout_links_are_migrated(self):
        old_repo = self.home / ".dotfiles"
        old_repo.symlink_to(self.checkout, target_is_directory=True)
        (self.home / ".zshrc").symlink_to(".dotfiles/.zshrc")
        config = self.home / ".config"
        config.mkdir()
        (config / "nvim").symlink_to("../.dotfiles/.config/nvim")
        (config / "zed").mkdir()
        (config / "zed/keymap.json").symlink_to(old_repo / ".config/zed/keymap.json")
        self.cli("macos", backend="brew")
        self.assertEqual(
            (self.home / ".zshrc").resolve(),
            (self.checkout / "packages/terminal/.zshrc").resolve(),
        )
        self.assertTrue((config / "nvim/init.lua").is_file())
        self.assertTrue((config / "zed/keymap.json").is_file())

    def test_unrelated_dangling_symlink_is_preserved(self):
        link = self.home / ".zshrc"
        foreign = self.root / "other/packages/terminal/.zshrc"
        link.symlink_to(foreign)
        result = self.bash(
            "source scripts/lib/common.sh; PROFILE=linux-server; "
            "PLATFORM=linux; choose_profile; link_configs",
            check=False,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(link.readlink(), foreign)

    def test_adoption_preserves_local_contents(self):
        local = self.home / ".config/nvim/init.lua"
        local.parent.mkdir(parents=True)
        local.write_text("-- existing local config\n")
        self.cli(flags="--adopt")
        self.assertTrue(local.is_symlink())
        self.assertEqual(
            (self.checkout / "packages/terminal/.config/nvim/init.lua").read_text(),
            "-- existing local config\n",
        )
        backups = list((self.home / ".local/state/dotfiles/backups").glob("stow.*"))
        self.assertEqual(len(backups), 1)
        self.assertIn(str(local), (backups[0] / "paths.tsv").read_text())
        originals = [p.read_text() for p in (backups[0] / "sources").iterdir()]
        self.assertIn(
            (REPO / "packages/terminal/.config/nvim/init.lua").read_text(), originals
        )
        locals_saved = [
            p.read_text()
            for p in (backups[0] / "targets").iterdir()
            if not p.is_symlink()
        ]
        self.assertIn("-- existing local config\n", locals_saved)
        self.cli(flags="--adopt")
        self.assertTrue(local.is_symlink())
        self.assertEqual(local.read_text(), "-- existing local config\n")

    def test_conflicts_require_explicit_adoption(self):
        local = self.home / ".zshrc"
        local.write_text("# existing shell config\n")
        source = self.checkout / "packages/terminal/.zshrc"
        original = source.read_text()
        for flags in ["", "--dry-run"]:
            result = self.bash(
                "source scripts/lib/common.sh; "
                "detect_platform() { PLATFORM=linux; BACKEND=apt; }; "
                f"main stow --profile linux-server {flags}",
                check=False,
            )
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("Conflict:", result.stderr)
            self.assertEqual(local.read_text(), "# existing shell config\n")
            self.assertEqual(source.read_text(), original)
            self.assertFalse((self.home / ".local/state").exists())

    def test_switch_conflict_preserves_previous_profile(self):
        self.cli()
        local = self.home / ".config/zed/settings.json"
        local.parent.mkdir(parents=True)
        local.write_text("{}\n")
        state = self.home / ".local/state/dotfiles/machine"
        original = state.read_bytes()
        result = self.bash(
            "source scripts/lib/common.sh; "
            "detect_platform() { PLATFORM=linux; BACKEND=apt; }; "
            "main stow --profile linux-desktop",
            check=False,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertTrue((self.home / ".zshrc").is_symlink())
        self.assertTrue((self.home / ".local/bin/bat").is_symlink())
        self.assertEqual(state.read_bytes(), original)
        self.assertFalse((self.home / ".config/ghostty/config.ghostty").exists())

    def test_failed_switch_restores_links_and_adopted_sources(self):
        self.cli()
        local = self.home / ".config/zed/settings.json"
        local.parent.mkdir(parents=True)
        local.write_text("{}\n")
        source = self.checkout / "packages/desktop/.config/zed/settings.json"
        original_source = source.read_bytes()
        state = self.home / ".local/state/dotfiles/machine"
        original_state = state.read_bytes()
        # Fail after Stow has adopted files and installed the new config links.
        result = self.bash(
            "source scripts/lib/common.sh; "
            "detect_platform() { PLATFORM=linux; BACKEND=apt; }; "
            'stow() { command stow "$@" || return; '
            "case $* in *packages/linux-desktop*) return 1;; esac; }; "
            "main stow --profile linux-desktop --adopt",
            check=False,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("restoring previous", result.stderr)
        self.assertEqual(source.read_bytes(), original_source)
        self.assertEqual(local.read_text(), "{}\n")
        self.assertFalse(local.is_symlink())
        self.assertEqual(state.read_bytes(), original_state)
        self.assertTrue((self.home / ".zshrc").is_symlink())
        self.assertTrue((self.home / ".local/bin/bat").is_symlink())
        self.assertFalse((self.home / ".config/ghostty/config.ghostty").exists())

    def test_migration_dry_run_does_not_remove_legacy_links(self):
        (self.home / ".dotfiles").symlink_to(self.checkout, target_is_directory=True)
        config = self.home / ".config"
        config.mkdir()
        legacy = config / "nvim"
        legacy.symlink_to("../.dotfiles/.config/nvim")
        self.cli(flags="--dry-run")
        self.assertEqual(legacy.readlink(), Path("../.dotfiles/.config/nvim"))
        self.assertFalse((self.home / ".local/state").exists())

    def test_entrypoints_from_another_directory_with_spaces_in_checkout_path(self):
        checkout = self.root / "source trees" / "my shell config"
        checkout.parent.mkdir()
        self.checkout.rename(checkout)
        self.checkout = checkout
        profile = "macos" if sys.platform == "darwin" else "linux-server"
        for script, flags in [("setup", ["--dry-run"]), ("stow", [])]:
            result = subprocess.run(
                [
                    "bash",
                    str(checkout / "scripts" / f"{script}.sh"),
                    "--profile",
                    profile,
                    *flags,
                ],
                cwd=self.root,
                env=self.env,
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(
            (self.home / ".zshrc").resolve(),
            (checkout / "packages/terminal/.zshrc").resolve(),
        )
        result = subprocess.run(
            [
                "zsh",
                "-fc",
                'source "$HOME/.zprofile"; source "$HOME/.zshrc"; [[ -d "$DOTFILES_ZSH_DIR" ]] && print READY',
            ],
            cwd=self.root,
            env=self.env,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), "READY")
        self.assertFalse(result.stderr)
        if GHOSTTY and profile == "macos":
            result = subprocess.run(
                [
                    GHOSTTY,
                    "+validate-config",
                    "--config-file="
                    + str(self.home / ".config/ghostty/config.ghostty"),
                ],
                env=self.env,
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_custom_config_directory_and_profile_switch(self):
        config = self.root / "app config"
        self.env["XDG_CONFIG_HOME"] = str(config)
        self.cli("linux-desktop")
        self.assertTrue((config / "nvim/init.lua").is_symlink())
        self.assertTrue((config / "ghostty/common.ghostty").is_symlink())
        self.assertTrue((config / "ghostty/config.ghostty").is_symlink())
        self.assertFalse((self.home / ".config").exists())
        self.assertTrue((self.home / ".zshrc").is_symlink())
        self.assertTrue((self.home / ".local/bin/bat").is_symlink())
        self.cli("linux-server")
        self.assertTrue((config / "nvim/init.lua").is_symlink())
        self.assertFalse((config / "ghostty/config.ghostty").exists())
        result = subprocess.run(
            [
                "zsh",
                "-f",
                "-c",
                'source "$HOME/.zprofile"; source "$HOME/.zshrc"; print READY',
            ],
            env=self.env,
            text=True,
            capture_output=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), "READY")
        self.assertFalse(result.stderr)

    def test_changing_config_directory_removes_only_managed_links(self):
        self.cli("linux-desktop")
        previous = self.home / ".config"
        local = previous / "dotfiles/local.zsh"
        local.write_text("# local settings\n")
        config = self.root / "new config"
        self.env["XDG_CONFIG_HOME"] = str(config)
        self.cli("linux-desktop")
        self.assertFalse((previous / "nvim/init.lua").exists())
        self.assertFalse((previous / "ghostty/config.ghostty").exists())
        self.assertEqual(local.read_text(), "# local settings\n")
        self.assertTrue((config / "nvim/init.lua").is_symlink())
        self.assertIn(
            "config_home=" + str(config),
            (self.home / ".local/state/dotfiles/machine").read_text(),
        )

    @unittest.skipUnless(GHOSTTY, "Requires Ghostty")
    def test_ghostty_include_with_custom_config_directory(self):
        config = self.root / "app config"
        self.env["XDG_CONFIG_HOME"] = str(config)
        self.cli("linux-desktop")
        result = subprocess.run(
            [
                str(GHOSTTY),
                "+validate-config",
                "--config-file=" + str(config / "ghostty/config.ghostty"),
            ],
            env=self.env,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_relative_config_directory_is_rejected(self):
        self.env["XDG_CONFIG_HOME"] = "relative-config"
        result = self.bash(
            "source scripts/lib/common.sh; PLATFORM=linux; PROFILE=linux-server; "
            "choose_profile; link_configs",
            check=False,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(list(self.home.iterdir()))

    def test_shared_homebrew_initialization_in_bash_and_zsh(self):
        code = (
            "unset HOMEBREW_PREFIX DOTFILES_TEST_BREW_CALLS; "
            "brew() { printf '%s\\n' 'export HOMEBREW_PREFIX=/test-brew; "
            "DOTFILES_TEST_BREW_CALLS=$(( ${DOTFILES_TEST_BREW_CALLS:-0} + 1 ))'; }; "
            "source packages/terminal/.config/dotfiles/zsh/lib/homebrew.sh; "
            "dotfiles_homebrew_init; dotfiles_homebrew_init; "
            "[[ $HOMEBREW_PREFIX == /test-brew && $DOTFILES_TEST_BREW_CALLS == 1 ]]"
        )
        for shell in ["bash", "zsh"]:
            result = subprocess.run(
                [shell, "-fc", code],
                cwd=self.checkout,
                env=self.env,
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_dry_run_all_linux_backends(self):
        for backend in ["apt", "dnf", "pacman"]:
            for profile in ["linux-server", "linux-desktop"]:
                result = self.cli(
                    profile,
                    "setup",
                    backend,
                    "--extras development,utilities --dry-run",
                )
                self.assertIn("Would select uv:", result.stdout)
                self.assertEqual(
                    "Would select ghostty:" in result.stdout, profile == "linux-desktop"
                )
                self.assertFalse(list(self.home.iterdir()))

    def test_saved_selection_and_invalid_options(self):
        self.cli(flags="--extras development")
        result = self.bash(
            'source scripts/lib/common.sh; read_state; printf \'%s:%s\' "$PROFILE" "$EXTRAS"'
        )
        self.assertEqual(result.stdout, "linux-server:development")
        for flags in ["--profile", "--extras invalid", "--unknown"]:
            result = self.bash(f"bash scripts/stow.sh {flags}", check=False)
            self.assertNotEqual(result.returncode, 0)

    def test_package_failures_and_arch_full_upgrade(self):
        for backend in ["apt", "dnf", "pacman"]:
            result = self.bash(
                "source scripts/lib/common.sh; "
                f"PROFILE=linux-server; BACKEND={backend}; SUDO=(); "
                "source scripts/lib/linux.sh; "
                "selected_rows() { printf 'git|git|-\\nbad|bad|-\\nmissing|missing|-\\n'; }; "
                "package_available() { [[ $1 != missing ]]; }; "
                "package_installed() { return 1; }; "
                "native_install() { note INSTALL:$1; [[ $1 != bad ]]; }; "
                "apt-get() { note APT:$*; }; dnf() { note DNF:$*; }; pacman() { note PACMAN:$*; }; "
                "manage_packages update"
            )
            self.assertIn("INSTALL:git", result.stdout)
            self.assertIn("native package install/upgrade failed", result.stderr)
            self.assertIn("unavailable in configured repositories", result.stderr)
            if backend == "pacman":
                self.assertIn("PACMAN:-Syu --noconfirm", result.stdout)

    @unittest.skipIf(os.geteuid() == 0, "Root already has package installation access")
    def test_no_sudo_falls_back_to_config_only(self):
        result = self.bash(
            "source scripts/lib/common.sh; BACKEND=apt; sudo() { return 1; }; "
            "obtain_privilege; [[ $CONFIG_ONLY == 1 ]]"
        )
        self.assertIn("No sudo access; using config-only setup", result.stderr)

    def test_foreign_symlink_is_preserved_on_conflict(self):
        foreign = self.root / "user-zshrc"
        foreign.write_text("# outside the checkout\n")
        (self.home / ".zshrc").symlink_to(foreign)
        result = self.bash(
            "source scripts/lib/common.sh; PLATFORM=linux; PROFILE=linux-server; "
            "choose_profile; link_configs; save_state",
            check=False,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(foreign.read_text(), "# outside the checkout\n")
        self.assertEqual((self.home / ".zshrc").resolve(), foreign.resolve())
        self.assertFalse((self.home / ".local/state/dotfiles/machine").exists())

    def test_foreign_directory_link_does_not_change_checkout_links(self):
        config = self.home / ".config"
        config.mkdir()
        intermediate = self.root / "other-ghostty"
        intermediate.symlink_to(self.checkout / "packages/macos/.config/ghostty")
        (config / "ghostty").symlink_to(intermediate)
        source = self.checkout / "packages/macos/.config/ghostty/config.ghostty"
        contents = source.read_text()
        self.bash(
            "source scripts/lib/common.sh; PLATFORM=linux; PROFILE=linux-desktop; "
            "choose_profile; link_configs",
            check=False,
        )
        self.assertEqual(source.read_text(), contents)
        self.assertTrue((config / "ghostty").is_symlink())

    def test_linux_shell_without_tools(self):
        self.cli()
        for agent in [False, True]:
            env = dict(self.env, PATH="/usr/bin:/bin", TERM="xterm-256color")
            for key in [
                "CODEX_CLI",
                "CLAUDE_CLI",
                "GEMINI_CLI",
                "OPENCODE_CLI",
                "PI_CLI",
                "GITHUB_COPILOT_CLI",
                "VSCODE_INJECTION",
                "TERM_PROGRAM",
                "HOMEBREW_PREFIX",
            ]:
                env.pop(key, None)
            if agent:
                env["CODEX_CLI"] = "1"
            result = subprocess.run(
                [
                    "zsh",
                    "-f",
                    "-ic",
                    'OSTYPE=linux-gnu; source "$HOME/.zshrc"; print READY',
                ],
                env=env,
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout.strip(), "READY")
            self.assertFalse(result.stderr)

    def test_ssh_copy_uses_osc52(self):
        master, slave = pty.openpty()
        try:
            result = subprocess.run(
                [
                    "zsh",
                    "-fc",
                    "source packages/terminal/.config/dotfiles/zsh/functions/clipboard.zsh; printf hello | c",
                ],
                cwd=self.checkout,
                env=dict(
                    self.env, SSH_CONNECTION="test", TERM="xterm-256color", TMUX=""
                ),
                stdout=slave,
                stderr=subprocess.PIPE,
                check=False,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn(b"\x1b]52;c;aGVsbG8=\x07", os.read(master, 4096))
        finally:
            os.close(master)
            os.close(slave)

    @unittest.skipUnless(shutil.which("nvim"), "Requires Neovim")
    def test_old_neovim_does_not_bootstrap_incompatible_plugins(self):
        result = subprocess.run(
            [
                "nvim",
                "--headless",
                "-u",
                "NONE",
                "-i",
                "NONE",
                "-c",
                (
                    "lua vim.fn.has = function() return 0 end; "
                    "require = function() error('Plugin bootstrap must not run') end; "
                    "dofile('packages/terminal/.config/nvim/init.lua')"
                ),
                "-c",
                "qa",
            ],
            cwd=self.checkout,
            env=self.env,
            capture_output=True,
            text=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn("Plugin bootstrap must not run", result.stderr)


if __name__ == "__main__":
    unittest.main()
