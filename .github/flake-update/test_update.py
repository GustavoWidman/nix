"""tests of update.py's pure core, against trimmed real locks and real nix errors.

fixtures/*.lock.json are flake.lock trimmed to ten root inputs: `old` from
before a nixpkgs bump, `main`, and `candidate`, main with every passenger
updated as `nix flake update <name>` did it. fixtures/*.err are nix's stderr:
oracle-2 evaluated with a broken, an unsupported and a removed package added,
desktop-nixos with a renamed one, and `nix flake update copyparty` failing on
copyparty's registry lookup. coeus-summary.md has the shape coeus' step
summary table takes.
"""

import dataclasses
import json
import unittest
from pathlib import Path

import update as u

HERE = Path(__file__).parent
FIXTURES = HERE / "fixtures"

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
    return u.Candidate(text(f"{new}.lock.json"), u.diff(CONFIG, lock(base), lock(new)), stuck)


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


class Config(unittest.TestCase):
    roots = ("nixpkgs", "coeus", "thoth")

    def test_the_committed_config_fits_the_committed_lock(self):
        # which input goes in which list is the config's to say; only that it parses is checked
        flake_lock = json.loads((HERE.parents[1] / "flake.lock").read_text())
        u.parse_config((HERE / "inputs.toml").read_text(), u.root_inputs(flake_lock))

    def test_rejects(self):
        for toml in (
            "triggers = [",
            'triggers = ["nixpkgs"]\nmanual = ["thoth"]',
            'triggers = ["nixpkgs", "zed"]',
            'triggers = ["nixpkgs"]\npassengers = ["nixpkgs"]',
            'passengers = ["coeus", "coeus"]',
            'triggers = "nixpkgs"',
        ):
            with self.subTest(toml=toml), self.assertRaises(u.ConfigError):
                u.parse_config(toml, self.roots)


if __name__ == "__main__":
    unittest.main()
