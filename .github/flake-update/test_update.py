"""tests of update.py's pure core, against trimmed real locks and real nix errors.

fixtures/*.lock.json are flake.lock trimmed to ten root inputs: `old` from
before a nixpkgs bump, `main`, and `candidate`, main with every passenger
updated as `nix flake update <name>` did it. fixtures/*.err are nix's stderr:
oracle-2 evaluated with a broken, an unsupported and a removed package added,
desktop-nixos with a renamed one, and `nix flake update copyparty` failing on
copyparty's registry lookup. coeus-summary.md has the shape coeus' step
summary table takes. build-hash-mismatch.log is the end of a darwin machine's
coeus job log, failing on a wheel whose hash nixpkgs got wrong, and
build-builder-failed.err is nix's stderr for a builder that exits 2. the
release tests rewrite the committed flake.nix.
"""

import copy
import dataclasses
import json
import re
import unittest
from pathlib import Path

import update as u

HERE = Path(__file__).parent
FIXTURES = HERE / "fixtures"
REPO = HERE.parents[1]

# the nixpkgs the eval fixtures came from
NIXPKGS = u.Nixpkgs(
    "04906337b6d53e8bb0eaf0470ae9f070a4d4eb55", "/nix/store/64d7bdawbnr6pwp2sgjm83jl6r95gimc-source"
)
CONFIG = u.Config(
    triggers=("nixpkgs",),
    passengers=("arion", "coeus", "copyparty", "crane", "determinate", "nixos-mailserver"),
)
MAIN_SHA = "1" * 40


def text(name: str) -> str:
    return (FIXTURES / name).read_text()


def lock(name: str) -> dict:
    return json.loads(text(f"{name}.lock.json"))


def candidate(base: str, new: str, stuck: tuple[u.Stuck, ...] = ()) -> u.Candidate:
    return u.Candidate(text(f"{new}.lock.json"), "", u.diff(CONFIG, lock(base), lock(new)), stuck)


def open_pr(
    pr_lock: str, base_sha: str = MAIN_SHA, foreign: tuple[str, ...] = (), checked: bool = True
) -> u.OpenPr:
    return u.OpenPr(
        number=7, head_sha="2" * 40, base_sha=base_sha, lock=lock(pr_lock), foreign=foreign, checked=checked
    )


TRIGGER_MOVED = candidate("old", "main")
PASSENGERS_MOVED = candidate("main", "candidate")
NOTHING_MOVED = candidate("main", "main")


class Decide(unittest.TestCase):
    def decide(self, cand, pr=None, parked=None, force_open=False) -> u.Plan:
        return u.decide(CONFIG, MAIN_SHA, cand, pr, parked, force_open)

    def test_nothing_moved_is_idle(self):
        self.assertIsInstance(self.decide(NOTHING_MOVED), u.Idle)

    def test_only_passengers_moved_is_idle(self):
        plan = self.decide(PASSENGERS_MOVED)
        self.assertIsInstance(plan, u.Idle)
        self.assertIn("only passengers", plan.reason)

    def test_open_by_hand_takes_passengers_alone(self):
        self.assertEqual(
            self.decide(PASSENGERS_MOVED, force_open=True), u.Open(PASSENGERS_MOVED, by_hand=True)
        )

    def test_open_by_hand_with_nothing_moved_stays_idle(self):
        self.assertIsInstance(self.decide(NOTHING_MOVED, force_open=True), u.Idle)

    def test_a_trigger_moving_opens(self):
        self.assertEqual(self.decide(TRIGGER_MOVED), u.Open(TRIGGER_MOVED, by_hand=False))

    def test_a_parked_pr_with_the_same_triggers_holds_it_back(self):
        plan = self.decide(TRIGGER_MOVED, parked=u.Parked(5, lock("main")))
        self.assertIsInstance(plan, u.Idle)
        self.assertIn("#5", plan.reason)

    def test_a_trigger_moving_past_the_parked_pr_opens(self):
        plan = self.decide(TRIGGER_MOVED, parked=u.Parked(5, lock("old")))
        self.assertEqual(plan, u.Open(TRIGGER_MOVED, by_hand=False))

    def test_open_by_hand_overrides_a_parked_pr(self):
        plan = self.decide(TRIGGER_MOVED, parked=u.Parked(5, lock("main")), force_open=True)
        self.assertIsInstance(plan, u.Open)

    def test_an_open_pr_with_nothing_left_to_carry_closes(self):
        pr = open_pr("candidate")
        plan = self.decide(NOTHING_MOVED, pr=pr)
        self.assertIsInstance(plan, u.Close)
        self.assertEqual(plan.pr, pr)

    def test_an_open_pr_with_its_own_commits_stays_with_nothing_moved(self):
        foreign = ("3" * 40,)
        self.assertIsInstance(self.decide(NOTHING_MOVED, pr=open_pr("main", foreign=foreign)), u.Idle)
        plan = self.decide(NOTHING_MOVED, pr=open_pr("main", base_sha="0" * 40, foreign=foreign))
        self.assertIsInstance(plan, u.Refresh)
        self.assertTrue(plan.rebased)

    def test_an_open_pr_already_current_is_idle(self):
        plan = self.decide(PASSENGERS_MOVED, pr=open_pr("candidate"))
        self.assertIsInstance(plan, u.Idle)
        self.assertIn("#7", plan.reason)

    def test_a_push_the_bot_has_not_checked_gets_checked_as_it_is(self):
        pr = open_pr("candidate", foreign=("3" * 40,), checked=False)
        self.assertEqual(self.decide(PASSENGERS_MOVED, pr=pr), u.Recheck(pr, PASSENGERS_MOVED))

    def test_an_unchecked_head_that_main_moved_under_is_rebuilt_instead(self):
        pr = open_pr("candidate", base_sha="0" * 40, checked=False)
        self.assertIsInstance(self.decide(PASSENGERS_MOVED, pr=pr), u.Refresh)

    def test_main_moving_under_an_open_pr_refreshes_it(self):
        plan = self.decide(PASSENGERS_MOVED, pr=open_pr("candidate", base_sha="0" * 40))
        self.assertEqual(
            plan, u.Refresh(open_pr("candidate", base_sha="0" * 40), PASSENGERS_MOVED, since=(), rebased=True)
        )

    def test_passengers_ride_along_while_a_pr_is_open(self):
        plan = self.decide(PASSENGERS_MOVED, pr=open_pr("main"))
        self.assertIsInstance(plan, u.Refresh)
        self.assertFalse(plan.rebased)
        self.assertEqual([bump.name for bump in plan.since], ["arion", "crane", "determinate"])


class Lock(unittest.TestCase):
    def test_bumps_list_triggers_first_then_passengers_alphabetically(self):
        bumps = u.diff(CONFIG, lock("old"), lock("candidate"))
        self.assertEqual(
            [(bump.name, bump.policy) for bump in bumps],
            [
                ("nixpkgs", u.Policy.TRIGGER),
                ("arion", u.Policy.PASSENGER),
                ("coeus", u.Policy.PASSENGER),
                ("crane", u.Policy.PASSENGER),
                ("determinate", u.Policy.PASSENGER),
            ],
        )

    def test_manual_inputs_never_bump(self):
        moved = lock("main")
        thoth = moved["nodes"]["thoth"]["locked"]
        thoth["rev"], thoth["lastModified"] = "f" * 40, thoth["lastModified"] + 1
        self.assertEqual(u.diff(CONFIG, lock("main"), moved), ())

    def test_compare_links_per_kind(self):
        pins = u.root_pins(lock("main"))
        new = u.root_pins(lock("candidate"))
        self.assertEqual(
            u.compare_link(pins["arion"], new["arion"]),
            "https://github.com/hercules-ci/arion/compare/c320d2d666a4a38e52447213fbc70b0b5ebcaad1...a7c8163c7fb739e224d66380a677912de7cb15a7",
        )
        self.assertEqual(
            u.compare_link(pins["determinate"], new["determinate"]),
            "https://github.com/DeterminateSystems/determinate/compare/558e026d9d3c78351170d8f8a797fa0fac541ccf...49968eb8f0f1a3c9c8790e9ead7ce7b5196f6c0f",
        )
        mailserver = pins["nixos-mailserver"]
        self.assertEqual(
            u.compare_link(mailserver, dataclasses.replace(mailserver, rev="abc")),
            "https://gitlab.com/simple-nixos-mailserver/nixos-mailserver/-/compare/9004c7d9b0986719a76ca6945a718434508d7b2e...abc",
        )
        thoth = pins["thoth"]
        self.assertEqual(
            u.compare_link(thoth, dataclasses.replace(thoth, rev="abc")),
            "https://github.com/GustavoWidman/thoth/compare/1395acfa5aa9c06739cf7e371d0e6e064369fcf2...abc",
        )
        self.assertIsNone(u.compare_link(pins["arion"], pins["crane"]))
        elsewhere = u.Pin(kind="tarball", last_modified=0, rev="a", url="https://example.com/x.tar.gz")
        self.assertIsNone(u.compare_link(elsewhere, dataclasses.replace(elsewhere, rev="b")))


class Render(unittest.TestCase):
    bumps = u.diff(CONFIG, lock("old"), lock("candidate"))

    def test_commit_subjects(self):
        self.assertEqual(u.commit_subject(self.bumps[:1]), "chore(flake): bump nixpkgs")
        self.assertEqual(u.commit_subject(self.bumps[:2]), "chore(flake): bump nixpkgs and arion")
        self.assertEqual(u.commit_subject(self.bumps[:3]), "chore(flake): bump nixpkgs, arion and coeus")
        self.assertEqual(u.commit_subject(self.bumps), "chore(flake): bump nixpkgs and 4 other inputs")

    def test_commit_body_has_a_line_per_bump(self):
        lines = u.commit_message(self.bumps).splitlines()
        self.assertEqual(lines[2], "nixpkgs: d4f25a3 (2026-11-11) to 0490633 (2026-11-17).")
        self.assertIn("determinate: 3.24.2 (2026-11-05) to 3.24.3 (2026-11-19).", lines)
        self.assertEqual(len(lines), 2 + len(self.bumps))

    def body(
        self, cand=TRIGGER_MOVED, evals=(), fleet=u.NotBuilt("Not built on a dry run."), by_hand=False
    ) -> str:
        return u.render_body(cand, CONFIG, by_hand, evals, fleet)

    def test_body_tables_what_changed(self):
        body = self.body()
        self.assertTrue(body.startswith(u.MARKER))
        self.assertIn("`nixpkgs` moved, and 1 passenger rides along.", body)
        rows = [line for line in body.splitlines() if line.startswith("| `")]
        self.assertEqual(
            rows[0],
            "| `nixpkgs` | trigger | `d4f25a3` (2026-11-11) | `0490633` (2026-11-17) "
            "| [compare](https://github.com/NixOS/nixpkgs/compare/d4f25a3e562008648d45bcf2d70bcc7422cad84e...04906337b6d53e8bb0eaf0470ae9f070a4d4eb55) |",
        )
        self.assertTrue(rows[1].startswith("| `coeus` | passenger |"))
        self.assertIn("Manual, so never touched here: `rift`, `taproot` and `thoth`.", body)

    def test_body_says_who_opened_it(self):
        self.assertIn("Opened by hand", self.body(PASSENGERS_MOVED, by_hand=True))

    def test_body_spells_out_stuck_inputs(self):
        stuck = u.Stuck("copyparty", u.Policy.PASSENGER, u.error_block(text("update-copyparty.err")))
        body = self.body(candidate("old", "main", (stuck,)))
        self.assertIn("Stuck, so main's pin stays: `copyparty`.", body)
        self.assertIn(
            "**`copyparty`**: cannot find flake 'flake:nixpkgs/nixos-26.05' in the flake registries", body
        )

    def test_body_names_refused_packages_with_links(self):
        evals = (
            u.HostEval("lab", "x86_64-linux", "/nix/store/x.drv", None, ()),
            u.HostEval(
                "oracle-2", "aarch64-linux", None, u.classify(text("eval-broken.err"), NIXPKGS), (), "trace"
            ),
            u.HostEval(
                "oracle-1", "aarch64-linux", None, u.classify(text("eval-broken.err"), NIXPKGS), (), "trace"
            ),
        )
        body = self.body(evals=evals)
        self.assertIn("1 of 3 hosts evaluate", body)
        self.assertIn("| `oracle-2` | aarch64-linux | ❌ nixpkgs refuses `seadrive-fuse-3.0.26` |", body)
        self.assertIn(
            "- nixpkgs refuses [`seadrive-fuse-3.0.26`](https://github.com/NixOS/nixpkgs/blob/"
            "04906337b6d53e8bb0eaf0470ae9f070a4d4eb55/pkgs/by-name/se/seadrive-fuse/package.nix#L54) "
            "on `oracle-2` and `oracle-1`: it has problems: broken: This package is broken.",
            body,
        )

    def test_body_shows_the_fleet_build(self):
        table, machines = u.parse_coeus_summary(text("coeus-summary.md"))
        built = u.Built(False, table, machines, (("oracle-1", "building thoth\nerror: thoth failed"),))
        body = self.body(fleet=built)
        self.assertIn("1 of 4 machines built, 1 failed, 1 unreachable.", body)
        self.assertIn("| lab | ✅ succeeded |", body)
        self.assertIn("error: thoth failed", body)

    def test_body_names_what_broke_a_machine_build(self):
        table, machines = u.parse_coeus_summary(text("coeus-summary.md"))
        built = u.Built(False, table, machines, (("oracle-1", text("build-hash-mismatch.log")),))
        body = self.body(fleet=built)
        self.assertIn("- `oracle-1` could not build `mitmproxy_macos-0.12.16-py3-none-any.whl`.", body)
        self.assertIn("<summary>oracle-1: what broke</summary>", body)
        self.assertIn("got:    sha256-ruw6Tl0NG8XJiyltwszNaXAxiOWUYlDU9n8eaxSYI+A=", body)
        self.assertNotIn("dependency failed", body)

    def test_body_falls_back_to_the_end_of_a_log_without_an_error(self):
        table, machines = u.parse_coeus_summary(text("coeus-summary.md"))
        built = u.Built(False, table, machines, (("oracle-1", "building thoth\nkilled"),))
        body = self.body(fleet=built)
        self.assertIn("<summary>oracle-1: the end of its log</summary>", body)
        self.assertIn("killed", body)
        self.assertNotIn("could not build", body)

    def test_refresh_comment_says_what_moved_and_where_main_went(self):
        plan = u.Refresh(
            open_pr("main", base_sha="0" * 40), PASSENGERS_MOVED, since=PASSENGERS_MOVED.bumps, rebased=True
        )
        evals = (u.HostEval("lab", "x86_64-linux", "/nix/store/x.drv", None, ()),)
        comment = u.refresh_comment(plan, MAIN_SHA, evals, u.NotBuilt("Skipped for this run."))
        self.assertIn("`arion` c320d2d to a7c8163", comment)
        self.assertIn("starts from 1111111", comment)
        self.assertTrue(comment.endswith("Checks: 1 of 1 hosts evaluate; Skipped for this run.\n"))


    def test_recheck_comment_names_the_commit_and_its_checks(self):
        evals = (u.HostEval("lab", "x86_64-linux", "/nix/store/x.drv", None, ()),)
        comment = u.recheck_comment("4" * 40, evals, u.NotBuilt("Skipped for this run."))
        self.assertEqual(comment, "Checked 4444444: 1 of 1 hosts evaluate; Skipped for this run.\n")


    def test_a_stuck_update_keeps_what_git_said(self):
        stderr = (
            "warning: ignoring untrusted flake configuration setting 'fallback'.\n"
            "Pass '--accept-flake-config' to trust it\n"
            "fatal: could not read Username for 'https://github.com': terminal prompts disabled\n"
            "error:\n"
            "       … while fetching the input 'git+ssh://git@github.com/GustavoWidman/thoth'\n\n"
            "       error: Failed to fetch git repository 'ssh://git@github.com/GustavoWidman/thoth'\n"
        )
        error = u.update_error(stderr)
        self.assertTrue(error.startswith("fatal: could not read Username"))
        self.assertNotIn("untrusted", error)
        stuck = u.Stuck("thoth", u.Policy.PASSENGER, error)
        self.assertEqual(stuck.summary, "Failed to fetch git repository 'ssh://git@github.com/GustavoWidman/thoth'")


class Classify(unittest.TestCase):
    def test_broken_package(self):
        error = u.classify(text("eval-broken.err"), NIXPKGS)
        self.assertEqual(
            error,
            u.Refusal(
                package="seadrive-fuse-3.0.26",
                reason="has problems: broken: This package is broken.",
                position=f"{NIXPKGS.path}/pkgs/by-name/se/seadrive-fuse/package.nix:54",
                link=f"https://github.com/NixOS/nixpkgs/blob/{NIXPKGS.rev}/pkgs/by-name/se/seadrive-fuse/package.nix#L54",
            ),
        )

    def test_unsupported_package(self):
        error = u.classify(text("eval-unsupported.err"), NIXPKGS)
        self.assertIsInstance(error, u.Refusal)
        self.assertEqual(error.package, "spacedrive-0.4.3")
        self.assertEqual(error.reason, "is not available on the requested hostPlatform")

    def test_a_position_outside_that_nixpkgs_gets_no_link(self):
        other = u.Nixpkgs(NIXPKGS.rev, "/nix/store/00000000000000000000000000000000-source")
        self.assertIsNone(u.classify(text("eval-broken.err"), other).link)
        self.assertIsNone(u.classify(text("eval-broken.err"), None).link)

    def test_removed_package(self):
        self.assertEqual(
            u.classify(text("eval-removed.err"), NIXPKGS),
            u.Removed("_0verkill", "'_0verkill' has been removed due to lack of maintenance"),
        )

    def test_anything_else_keeps_its_message(self):
        error = u.classify(text("update-copyparty.err"), NIXPKGS)
        self.assertEqual(
            error, u.Failure("cannot find flake 'flake:nixpkgs/nixos-26.05' in the flake registries")
        )

    def test_warnings(self):
        self.assertEqual(
            u.eval_warnings(text("eval-warning.err")), ("'_86Box' has been renamed to '_86box'",)
        )
        self.assertEqual(u.eval_warnings(text("eval-broken.err")), ())


class Coeus(unittest.TestCase):
    def test_summary_table(self):
        table, machines = u.parse_coeus_summary(text("coeus-summary.md"))
        self.assertTrue(table.startswith("| Host | Outcome |"))
        self.assertEqual(
            [(machine.host, machine.ok, machine.job) for machine in machines],
            [
                ("lab", True, "#118"),
                ("oracle-1", False, "#57"),
                ("laptop-mac", False, None),
                ("oracle-2", None, "#61"),
            ],
        )
        self.assertIn("failed | exit 1", machines[1].outcome)
        self.assertTrue(machines[2].unreachable)


    def test_a_build_failure_is_the_error_under_its_dependents(self):
        causes = u.build_failures(text("build-hash-mismatch.log"))
        self.assertEqual(len(causes), 1)
        self.assertTrue(causes[0].startswith("error: hash mismatch in fixed-output derivation"))
        self.assertIn("specified: sha256-7VaT+JsMvR0qjFoxuu0r16dLCq1oZy4IREwYaMOPSfg=", causes[0])
        self.assertEqual(u.failed_derivation(causes[0]), "mitmproxy_macos-0.12.16-py3-none-any.whl")

    def test_a_failed_builder_keeps_its_last_lines(self):
        (cause,) = u.build_failures(text("build-builder-failed.err"))
        self.assertIn("Reason: builder failed with exit code 2.", cause)
        self.assertIn("> main.c:3: error: expected expression", cause)
        self.assertEqual(u.failed_derivation(cause), "flake-update-fixture-1.0")

    def test_a_log_without_errors_has_no_build_failure(self):
        self.assertEqual(u.build_failures("building thoth\nkilled"), ())
        self.assertIsNone(u.failed_derivation("error: out of disk space"))


class Config(unittest.TestCase):
    tracked = 'triggers = ["nixpkgs"]\npassengers = ["coeus", "taproot", "thoth"]\n'

    def parse(self, toml: str) -> u.Config:
        return u.parse_config(toml, lock("main"))

    def test_the_committed_config_fits_the_committed_lock(self):
        # which input goes in which list is the config's to say; only that it parses is checked
        flake_lock = json.loads((REPO / "flake.lock").read_text())
        u.parse_config((HERE / "inputs.toml").read_text(), flake_lock)

    def test_releases_take_a_bare_name_or_a_tag_regex(self):
        config = self.parse(self.tracked + 'releases = ["taproot"]')
        self.assertEqual(config.releases, {"taproot": u.Latest()})
        config = self.parse(self.tracked + "releases = [{ input = \"taproot\", tag = 'taproot-v\\d+' }]")
        self.assertEqual(config.releases, {"taproot": u.TagPattern(re.compile(r"taproot-v\d+"))})
        self.assertEqual(self.parse(self.tracked).releases, {})

    def test_rejects(self):
        for toml in (
            "triggers = [",
            'triggers = ["nixpkgs"]\nmanual = ["thoth"]',
            'triggers = ["nixpkgs", "zed"]',
            'triggers = ["nixpkgs"]\npassengers = ["nixpkgs"]',
            'passengers = ["coeus", "coeus"]',
            'triggers = "nixpkgs"',
            # a release input in neither list
            'triggers = ["nixpkgs"]\nreleases = ["taproot"]',
            # thoth's url names no ref, so it has no tag to move
            self.tracked + 'releases = ["thoth"]',
            self.tracked + 'releases = ["taproot", { input = "taproot", tag = "v.*" }]',
            self.tracked + 'releases = [{ input = "taproot", tag = "v(" }]',
            self.tracked + 'releases = [{ input = "taproot", tag = "v.*", prerelease = true }]',
            self.tracked + 'releases = [{ input = "taproot" }]',
            self.tracked + "releases = [3]",
            self.tracked + 'releases = "taproot"',
        ):
            with self.subTest(toml=toml), self.assertRaises(u.ConfigError):
                self.parse(toml)


TAPROOT = re.compile(r"taproot-v\d+\.\d+\.\d+")


class Releases(unittest.TestCase):
    def test_version_order_compares_numbers(self):
        self.assertEqual(u.newest_tag(["v0.9.0", "v0.10.0", "v0.2.0"], re.compile(r"v[\d.]+")), "v0.10.0")

    def test_the_anchored_regex_leaves_out_release_candidates(self):
        tags = ["taproot-v0.5.0", "taproot-v0.6.0", "taproot-v0.7.0"]
        tags += [f"taproot-v0.8.0-rc.{n}" for n in range(1, 6)]
        self.assertEqual(u.newest_tag(tags, TAPROOT), "taproot-v0.7.0")

    def test_a_backport_cut_after_a_newer_release_loses(self):
        self.assertEqual(u.newest_tag(["taproot-v0.7.1", "taproot-v0.6.3"], TAPROOT), "taproot-v0.7.1")

    def test_no_match_is_none(self):
        self.assertIsNone(u.newest_tag(["v1.0.0"], TAPROOT))

    def test_tags_from_ls_remote(self):
        listed = "aaa\trefs/tags/taproot-v0.7.0\nbbb\trefs/tags/taproot-v0.7.1\nccc\trefs/heads/main\n"
        self.assertEqual(u.tags_from_ls_remote(listed), ("taproot-v0.7.0", "taproot-v0.7.1"))

    flake = (REPO / "flake.nix").read_text()
    taproot = u.Origin.from_original(
        u.root_originals(json.loads((REPO / "flake.lock").read_text()))["taproot"]
    )

    def test_rewrites_the_committed_url_and_nothing_else(self):
        new = u.rewrite_url(self.flake, "taproot", self.taproot, "taproot-v9.9.9")
        changed = [(a, b) for a, b in zip(self.flake.splitlines(), new.splitlines()) if a != b]
        self.assertEqual(len(changed), 1)
        before, after = changed[0]
        self.assertIn(f'"github:265866/taproot/{self.taproot.ref}"', before)
        self.assertEqual(after, before.replace(self.taproot.ref, "taproot-v9.9.9"))

    def test_the_ref_query_spelling(self):
        origin = u.Origin("github", "v1.0.0", "o", "r")
        self.assertEqual(
            u.rewrite_url('x.url = "github:o/r?ref=v1.0.0";', "x", origin, "v1.1.0"),
            'x.url = "github:o/r?ref=v1.1.0";',
        )
        thoth = u.Origin("git", "v1.0.0", url="ssh://git@github.com/GustavoWidman/thoth")
        old = 'url = "git+ssh://git@github.com/GustavoWidman/thoth?ref=v1.0.0&shallow=1";'
        self.assertEqual(
            u.rewrite_url(old, "thoth", thoth, "v2"),
            'url = "git+ssh://git@github.com/GustavoWidman/thoth?ref=v2&shallow=1";',
        )

    def test_a_longer_url_is_not_the_old_one(self):
        origin = u.Origin("github", "v1.0.0", "o", "r")
        with self.assertRaisesRegex(u.ReleaseError, "can't find x's url"):
            u.rewrite_url('x.url = "github:o/r/v1.0.0-rc.1";', "x", origin, "v1.1.0")

    def test_refuses_a_missing_url(self):
        gone = dataclasses.replace(self.taproot, ref="taproot-v0.0.1")
        with self.assertRaisesRegex(u.ReleaseError, "can't find taproot's url in flake.nix"):
            u.rewrite_url(self.flake, "taproot", gone, "taproot-v9.9.9")

    def test_refuses_a_url_written_twice(self):
        # a commented-out copy is as good as a live one to a text match
        commented = f'inputs = {{\n    # url = "github:265866/taproot/{self.taproot.ref}";'
        twice = self.flake.replace("inputs = {", commented, 1)
        with self.assertRaisesRegex(u.ReleaseError, "2 times"):
            u.rewrite_url(twice, "taproot", self.taproot, "taproot-v9.9.9")


class RefChange(unittest.TestCase):
    """taproot's url moved from one release tag to the next"""

    config = dataclasses.replace(CONFIG, passengers=(*CONFIG.passengers, "taproot"))
    new = copy.deepcopy(lock("main"))
    new["nodes"]["taproot"]["original"]["ref"] = "taproot-v0.7.1"
    new["nodes"]["taproot"]["locked"] |= {"rev": "9" * 40, "lastModified": 1794920400}
    bumps = u.diff(config, lock("main"), new)

    def test_the_bump_names_the_tags(self):
        self.assertEqual(
            [bump.line for bump in self.bumps],
            ["taproot: taproot-v0.7.0 (2026-11-13) to taproot-v0.7.1 (2026-11-17)."],
        )

    def test_the_table_row_names_the_tags_and_links_the_revs(self):
        cand = u.Candidate(json.dumps(self.new), "", self.bumps, ())
        body = u.render_body(cand, self.config, False, (), u.NotBuilt("Not built on a dry run."))
        old_rev = lock("main")["nodes"]["taproot"]["locked"]["rev"]
        self.assertIn(
            "| `taproot` | passenger | `taproot-v0.7.0` (2026-11-13) | `taproot-v0.7.1` (2026-11-17) "
            f"| [compare](https://github.com/265866/taproot/compare/{old_rev}...{'9' * 40}) |",
            body,
        )


if __name__ == "__main__":
    unittest.main()
