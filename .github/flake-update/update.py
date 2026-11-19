#!/usr/bin/env python3
"""keeps one pull request, on the `flake-update` branch, open and current.

inputs.toml sorts the flake's root inputs into triggers, which open the pull
request when they move, and passengers, which ride along. the core below
(parse, diff, decide, render) is pure and tested by test_update.py; the shell
after it runs nix, git, gh and coeus.
"""

from __future__ import annotations

import argparse
import datetime
import enum
import hashlib
import json
import os
import re
import subprocess
import sys
import tempfile
import textwrap
import tomllib
from collections.abc import Iterable
from dataclasses import dataclass
from itertools import takewhile
from pathlib import Path

BRANCH = "flake-update"
MARKER = "<!-- flake-update -->"
BOT_EMAIL = "41898282+github-actions[bot]@users.noreply.github.com"
EVAL_STATUS = "flake-update/eval"
BUILD_STATUS = "flake-update/build"

# --- config ------------------------------------------------------------------


class Policy(enum.Enum):
    TRIGGER = "trigger"
    PASSENGER = "passenger"


class ConfigError(ValueError):
    pass


@dataclass(frozen=True)
class Config:
    triggers: tuple[str, ...]
    passengers: tuple[str, ...]

    def policy(self, name: str) -> Policy | None:
        if name in self.triggers:
            return Policy.TRIGGER
        if name in self.passengers:
            return Policy.PASSENGER
        return None

    @property
    def tracked(self) -> tuple[str, ...]:
        """triggers first, then passengers, each alphabetically"""
        return tuple(sorted(self.triggers)) + tuple(sorted(self.passengers))


def parse_config(text: str, root_inputs: Iterable[str]) -> Config:
    try:
        data = tomllib.loads(text)
    except tomllib.TOMLDecodeError as error:
        raise ConfigError(f"inputs.toml is not valid TOML: {error}") from None

    unknown = sorted(set(data) - {"triggers", "passengers"})
    if unknown:
        raise ConfigError(f"inputs.toml has unknown keys: {', '.join(unknown)}")

    known = set(root_inputs)
    lists: dict[str, tuple[str, ...]] = {}
    for key in ("triggers", "passengers"):
        names = data.get(key, [])
        if not isinstance(names, list) or not all(isinstance(name, str) for name in names):
            raise ConfigError(f"`{key}` in inputs.toml must be a list of input names")
        repeated = sorted({name for name in names if names.count(name) > 1})
        if repeated:
            raise ConfigError(f"`{key}` lists these more than once: {', '.join(repeated)}")
        missing = sorted(set(names) - known)
        if missing:
            raise ConfigError(f"`{key}` names inputs flake.nix does not have: {', '.join(missing)}")
        lists[key] = tuple(names)

    both = sorted(set(lists["triggers"]) & set(lists["passengers"]))
    if both:
        raise ConfigError(f"both a trigger and a passenger: {', '.join(both)}")
    return Config(triggers=lists["triggers"], passengers=lists["passengers"])


# --- lock --------------------------------------------------------------------

FLAKEHUB = re.compile(r"/f/pinned/(?P<owner>[^/]+)/(?P<repo>[^/]+)/(?P<version>[^/]+)/")
GITHUB_GIT = re.compile(r"^(?:ssh://git@|https://)github\.com/(?P<owner>[^/]+)/(?P<repo>[^/]+?)(?:\.git)?/?$")


@dataclass(frozen=True)
class Pin:
    """where a lock node's `locked` points"""

    kind: str
    last_modified: int
    rev: str | None = None
    # a flakehub release, which names itself by version
    version: str | None = None
    # the forge that has a compare view of two revs, with the repository on it
    forge: str | None = None
    owner: str | None = None
    repo: str | None = None
    url: str | None = None

    @classmethod
    def from_locked(cls, locked: dict) -> Pin:
        kind = locked["type"]
        url = locked.get("url")
        forge, owner, repo, version = None, locked.get("owner"), locked.get("repo"), None
        if kind in ("github", "gitlab"):
            forge = kind
        elif kind == "tarball" and url and (match := FLAKEHUB.search(url)):
            # flakehub publishes from github, under the same owner and name
            forge, owner, repo, version = "github", match["owner"], match["repo"], match["version"]
        elif kind == "git" and url and (match := GITHUB_GIT.match(url)):
            forge, owner, repo = "github", match["owner"], match["repo"]
        return cls(
            kind=kind,
            last_modified=locked.get("lastModified", 0),
            rev=locked.get("rev"),
            version=version,
            forge=forge,
            owner=owner,
            repo=repo,
            url=url,
        )

    @property
    def date(self) -> str:
        return datetime.datetime.fromtimestamp(self.last_modified, datetime.UTC).strftime("%Y-%m-%d")

    @property
    def name(self) -> str:
        """the version of a release, else the short rev"""
        return self.version or (self.rev or "?")[:7]


def compare_link(old: Pin, new: Pin) -> str | None:
    if not (old.rev and new.rev) or (old.forge, old.owner, old.repo) != (new.forge, new.owner, new.repo):
        return None
    match old.forge:
        case "github":
            return f"https://github.com/{old.owner}/{old.repo}/compare/{old.rev}...{new.rev}"
        case "gitlab":
            return f"https://gitlab.com/{old.owner}/{old.repo}/-/compare/{old.rev}...{new.rev}"
    return None


def root_inputs(lock: dict) -> tuple[str, ...]:
    return tuple(lock["nodes"][lock["root"]]["inputs"])


def root_pins(lock: dict) -> dict[str, Pin]:
    """each root input's pin; an input that follows another has none of its own"""
    nodes = lock["nodes"]
    return {
        name: Pin.from_locked(nodes[key]["locked"])
        for name, key in nodes[lock["root"]]["inputs"].items()
        if isinstance(key, str)
    }


@dataclass(frozen=True)
class Bump:
    name: str
    policy: Policy
    old: Pin
    new: Pin

    @property
    def link(self) -> str | None:
        return compare_link(self.old, self.new)

    @property
    def line(self) -> str:
        return f"{self.name}: {self.old.name} ({self.old.date}) to {self.new.name} ({self.new.date})."


def diff(config: Config, old_lock: dict, new_lock: dict) -> tuple[Bump, ...]:
    """the tracked inputs that moved, triggers first, then alphabetically"""
    old, new = root_pins(old_lock), root_pins(new_lock)
    return tuple(
        Bump(name, config.policy(name), old[name], new[name])
        for name in config.tracked
        if name in old and name in new and old[name] != new[name]
    )


# --- nix errors --------------------------------------------------------------

ANSI = re.compile(r"\x1b\[[0-9;]*[A-Za-z]")
ERROR_LINE = re.compile(r"^\s*error: (?P<message>\S.*)$")
REFUSAL = re.compile(
    r"^\s*error: Refusing to evaluate package '(?P<package>[^']+)' in (?P<position>.+?) because it (?P<reason>.*)$"
)
REMOVED = re.compile(r"^\s*error: '(?P<attr>[^']+)' has been (?:removed|renamed)")


def error_block(stderr: str) -> str:
    """a nix command's error, from its first `error:` on, without the warnings before it"""
    lines = ANSI.sub("", stderr).splitlines()
    start = next((index for index, line in enumerate(lines) if line.startswith("error:")), None)
    return "\n".join(lines[-20:] if start is None else lines[start:]).strip()


def innermost_error(stderr: str) -> str:
    """the last `error:` message, the one that says what went wrong, up to its paragraph's end"""
    lines = ANSI.sub("", stderr).splitlines()
    last = max((index for index, line in enumerate(lines) if ERROR_LINE.match(line)), default=None)
    if last is None:
        return "\n".join(line for line in lines[-5:] if line.strip()).strip()
    paragraph = [ERROR_LINE.match(lines[last])["message"]]
    paragraph += [line.strip() for line in takewhile(str.strip, lines[last + 1 :])]
    return "\n".join(paragraph)


@dataclass(frozen=True)
class Stuck:
    """a tracked input whose `nix flake update` failed; main's pin stays"""

    name: str
    policy: Policy
    error: str

    @property
    def summary(self) -> str:
        return innermost_error(self.error).splitlines()[0]


@dataclass(frozen=True)
class Nixpkgs:
    """the candidate's nixpkgs: its rev, and the store path its files sit under"""

    rev: str
    path: str


@dataclass(frozen=True)
class Refusal:
    """nixpkgs refused a package: broken, insecure, unfree, unsupported here"""

    package: str
    reason: str
    position: str
    link: str | None


@dataclass(frozen=True)
class Removed:
    """an attribute nixpkgs removed or renamed, from pkgs/top-level/aliases.nix"""

    attr: str
    message: str


@dataclass(frozen=True)
class Failure:
    message: str


EvalError = Refusal | Removed | Failure


def position_link(position: str, nixpkgs: Nixpkgs | None) -> str | None:
    path, _, line = position.rpartition(":")
    prefix = nixpkgs.path.rstrip("/") + "/" if nixpkgs else None
    if not prefix or not path.startswith(prefix) or not line.isdigit():
        return None
    return f"https://github.com/NixOS/nixpkgs/blob/{nixpkgs.rev}/{path[len(prefix) :]}#L{line}"


def classify(stderr: str, nixpkgs: Nixpkgs | None) -> EvalError:
    lines = ANSI.sub("", stderr).splitlines()
    last = max((index for index, line in enumerate(lines) if ERROR_LINE.match(line)), default=None)
    if last is not None and (match := REFUSAL.match(lines[last])):
        reason = match["reason"].rstrip(":")
        problems = [
            line.strip()[2:]
            for line in takewhile(lambda line: line.strip().startswith("- "), lines[last + 1 :])
        ]
        if problems:
            reason += ": " + "; ".join(problems)
        return Refusal(match["package"], reason, match["position"], position_link(match["position"], nixpkgs))
    if last is not None and (match := REMOVED.match(lines[last])):
        return Removed(match["attr"], ERROR_LINE.match(lines[last])["message"])
    return Failure(innermost_error(stderr))


def eval_warnings(stderr: str) -> tuple[str, ...]:
    prefix = "evaluation warning: "
    found = (
        line[len(prefix) :].strip() for line in ANSI.sub("", stderr).splitlines() if line.startswith(prefix)
    )
    return tuple(dict.fromkeys(found))


@dataclass(frozen=True)
class HostEval:
    host: str
    arch: str
    drv: str | None
    error: EvalError | None
    warnings: tuple[str, ...]
    # the end of the error and its trace, for the details
    trace: str = ""


# --- fleet build ---------------------------------------------------------------


@dataclass(frozen=True)
class Machine:
    """one row of the table `coeus deploy` writes to $GITHUB_STEP_SUMMARY"""

    host: str
    # None while coeus could not say
    ok: bool | None
    outcome: str
    job: str | None

    @property
    def unreachable(self) -> bool:
        return self.ok is False and self.outcome.startswith("unreachable")


@dataclass(frozen=True)
class NotBuilt:
    note: str


@dataclass(frozen=True)
class Built:
    passed: bool
    table: str
    machines: tuple[Machine, ...]
    # the end of each failed machine's job log
    logs: tuple[tuple[str, str], ...]


Fleet = NotBuilt | Built

CELL = re.compile(r"(?<!\\)\|")
ATTACH = re.compile(r"coeus attach \S+ (?P<job>[^\s`]+)")
MARKS = {"✅": True, "❌": False, "⏳": None}


def parse_coeus_summary(markdown: str) -> tuple[str, tuple[Machine, ...]]:
    rows = [line for line in markdown.splitlines() if line.startswith("|")]
    machines = []
    for row in rows[2:]:
        cells = [cell.strip() for cell in CELL.split(row.strip())[1:-1]]
        if len(cells) < 5:
            continue
        mark, _, outcome = cells[1].partition(" ")
        job = ATTACH.search(cells[4])
        machines.append(Machine(cells[0], MARKS.get(mark), outcome.replace("\\|", "|"), job and job["job"]))
    return "\n".join(rows), tuple(machines)


# --- plan --------------------------------------------------------------------


@dataclass(frozen=True)
class Candidate:
    """main's lock with every tracked input updated that would update"""

    lock_text: str
    bumps: tuple[Bump, ...]
    stuck: tuple[Stuck, ...]

    @property
    def lock(self) -> dict:
        return json.loads(self.lock_text)


@dataclass(frozen=True)
class OpenPr:
    number: int
    head_sha: str
    # where the branch leaves main
    base_sha: str
    lock: dict
    # commits on the branch the bot did not author, oldest first
    foreign: tuple[str, ...]
    # the head carries the bot's evaluation status; a person's push does not
    checked: bool = True


@dataclass(frozen=True)
class Parked:
    """the newest bot pull request a person closed without merging"""

    number: int
    lock: dict


@dataclass(frozen=True)
class Idle:
    reason: str


@dataclass(frozen=True)
class Open:
    candidate: Candidate
    by_hand: bool


@dataclass(frozen=True)
class Refresh:
    pr: OpenPr
    candidate: Candidate
    since: tuple[Bump, ...]
    rebased: bool


@dataclass(frozen=True)
class Recheck:
    """a person pushed to the branch, which needs checks but no rebuild"""

    pr: OpenPr
    candidate: Candidate


@dataclass(frozen=True)
class Close:
    pr: OpenPr
    reason: str


Plan = Idle | Open | Refresh | Recheck | Close


def trigger_pins(config: Config, lock: dict) -> dict[str, Pin | None]:
    pins = root_pins(lock)
    return {name: pins.get(name) for name in config.triggers}


def decide(
    config: Config,
    main_sha: str,
    candidate: Candidate,
    pr: OpenPr | None,
    parked: Parked | None,
    force_open: bool,
) -> Plan:
    if pr is None:
        if not candidate.bumps:
            return Idle("no tracked input moved")
        moved = any(bump.policy is Policy.TRIGGER for bump in candidate.bumps)
        if not moved and not force_open:
            return Idle("only passengers moved")
        if (
            parked
            and not force_open
            and trigger_pins(config, parked.lock) == trigger_pins(config, candidate.lock)
        ):
            return Idle(f"#{parked.number} was closed with these triggers; waiting for one to move")
        return Open(candidate, by_hand=not moved)

    if not candidate.bumps and not pr.foreign:
        return Close(pr, "main already has every update")
    rebased = pr.base_sha != main_sha
    if candidate.lock == pr.lock and not rebased:
        return Idle(f"#{pr.number} is up to date") if pr.checked else Recheck(pr, candidate)
    return Refresh(pr, candidate, since=diff(config, pr.lock, candidate.lock), rebased=rebased)


# --- render ------------------------------------------------------------------


def names(items: Iterable[str]) -> str:
    items = list(items)
    return items[0] if len(items) == 1 else f"{', '.join(items[:-1])} and {items[-1]}"


def commit_subject(bumps: tuple[Bump, ...]) -> str:
    if not bumps:
        return "chore(flake): no input to bump"
    if len(bumps) <= 3:
        return f"chore(flake): bump {names(bump.name for bump in bumps)}"
    return f"chore(flake): bump {bumps[0].name} and {len(bumps) - 1} other inputs"


def commit_message(bumps: tuple[Bump, ...]) -> str:
    return commit_subject(bumps) + "\n\n" + "\n".join(bump.line for bump in bumps) + "\n"


def code(text: str) -> str:
    return f"`{text}`"


def fenced(text: str, lines: int) -> str:
    kept = text.splitlines()[-lines:]
    return "````text\n" + "\n".join(kept) + "\n````"


def why(candidate: Candidate, by_hand: bool) -> str:
    triggers = [code(bump.name) for bump in candidate.bumps if bump.policy is Policy.TRIGGER]
    riders = sum(bump.policy is Policy.PASSENGER for bump in candidate.bumps)
    ride = {0: "nothing rides along", 1: "1 passenger rides along"}.get(
        riders, f"{riders} passengers ride along"
    )
    if triggers:
        return f"{names(triggers)} moved, and {ride}."
    if by_hand:
        return f"Opened by hand with no trigger moved, and {ride}."
    if riders:
        return f"No trigger is ahead of main, and {ride} while this stays open."
    return "main already has every input update; this carries the branch's own commits."


def eval_cell(result: HostEval) -> str:
    match result.error:
        case None:
            warned = len(result.warnings)
            return "✅" + (f", {warned} warning{'s' * (warned > 1)}" if warned else "")
        case Refusal(package=package):
            return f"❌ nixpkgs refuses {code(package)}"
        case Removed(attr=attr):
            return f"❌ {code(attr)} is gone from nixpkgs"
        case Failure():
            return "❌ error"


def eval_description(evals: tuple[HostEval, ...]) -> str:
    return f"{sum(result.error is None for result in evals)} of {len(evals)} hosts evaluate"


def checks_line(evals: tuple[HostEval, ...], fleet: Fleet) -> str:
    # a skipped build's note is already a sentence
    return f"{eval_description(evals)}; {build_description(fleet).rstrip('.')}."


def build_description(fleet: Fleet) -> str:
    match fleet:
        case NotBuilt(note=note):
            return note
        case Built(machines=()):
            return "coeus reported no machines"
        case Built(machines=machines):
            built = sum(machine.ok is True for machine in machines)
            unreachable = sum(machine.unreachable for machine in machines)
            failed = sum(machine.ok is False for machine in machines) - unreachable
            parts = [f"{built} of {len(machines)} machines built"]
            parts += [f"{failed} failed"] * bool(failed) + [f"{unreachable} unreachable"] * bool(unreachable)
            return ", ".join(parts)


def render_verification(evals: tuple[HostEval, ...], fleet: Fleet) -> list[str]:
    parts = [f"### Evaluation\n\n{eval_description(evals)} on the runner.\n"]
    parts.append("| host | arch | eval |\n| --- | --- | --- |")
    parts += [f"| {code(result.host)} | {result.arch} | {eval_cell(result)} |" for result in evals]
    parts.append("")

    refusals: dict[Refusal, list[str]] = {}
    for result in evals:
        if isinstance(result.error, Refusal):
            refusals.setdefault(result.error, []).append(code(result.host))
    for refusal, hosts in refusals.items():
        package = f"[{code(refusal.package)}]({refusal.link})" if refusal.link else code(refusal.package)
        where = "" if refusal.link else f" ({refusal.position})"
        parts.append(f"- nixpkgs refuses {package}{where} on {names(hosts)}: it {refusal.reason}.")
    for result in evals:
        if isinstance(result.error, Removed):
            parts.append(f"- {code(result.host)}: {result.error.message}")
    if refusals or any(isinstance(result.error, Removed) for result in evals):
        parts.append("")

    noisy = [result for result in evals if result.error or result.warnings]
    if noisy:
        parts.append("<details><summary>errors and warnings</summary>\n")
        for result in noisy:
            parts.append(f"**{code(result.host)}**\n")
            parts += [f"- warning: {warning}" for warning in result.warnings]
            if result.error:
                parts.append("\n" + fenced(result.trace, 30))
            parts.append("")
        parts.append("</details>\n")

    parts.append("### Fleet build\n")
    match fleet:
        case NotBuilt(note=note):
            parts.append(f"{note}\n")
        case Built(table=table, logs=logs):
            parts.append(f"{build_description(fleet)}.\n")
            if table:
                parts.append(table + "\n")
            for host, log in logs:
                parts.append(
                    f"<details><summary>{host}: the end of its log</summary>\n\n{fenced(log, 40)}\n\n</details>\n"
                )
    return parts


def render_body(
    candidate: Candidate,
    config: Config,
    by_hand: bool,
    evals: tuple[HostEval, ...],
    fleet: Fleet,
) -> str:
    parts = [MARKER, "## Why\n", why(candidate, by_hand) + "\n", "## What changed\n"]
    if candidate.bumps:
        parts.append("| input | policy | from | to | link |\n| --- | --- | --- | --- | --- |")
        for bump in candidate.bumps:
            link = f"[compare]({bump.link})" if bump.link else ""
            parts.append(
                f"| {code(bump.name)} | {bump.policy.value} | {code(bump.old.name)} ({bump.old.date}) "
                f"| {code(bump.new.name)} ({bump.new.date}) | {link} |"
            )
        parts.append("")
    else:
        parts.append("No input moved.\n")

    if candidate.stuck:
        parts.append(f"Stuck, so main's pin stays: {names(code(stuck.name) for stuck in candidate.stuck)}.\n")
        parts.append("<details><summary>why they would not update</summary>\n")
        for stuck in candidate.stuck:
            parts.append(f"**{code(stuck.name)}**: {stuck.summary}\n\n{fenced(stuck.error, 20)}\n")
        parts.append("</details>\n")

    manual = sorted(set(root_inputs(candidate.lock)) - set(config.tracked))
    if manual:
        parts.append(f"Manual, so never touched here: {names(code(name) for name in manual)}.\n")

    parts.append("## Verification\n")
    parts += render_verification(evals, fleet)
    return "\n".join(parts).rstrip() + "\n"


def describe_plan(plan: Plan) -> str:
    match plan:
        case Idle(reason=reason):
            return f"idle: {reason}"
        case Open(candidate=candidate):
            return f"open a pull request: {commit_subject(candidate.bumps)}"
        case Refresh(pr=pr, rebased=rebased):
            return f"refresh #{pr.number}" + (", onto main's new tip" if rebased else "")
        case Recheck(pr=pr):
            return f"check #{pr.number}'s new head {pr.head_sha[:7]}"
        case Close(pr=pr, reason=reason):
            return f"close #{pr.number}: {reason}"


def refresh_comment(plan: Refresh, main_sha: str, evals: tuple[HostEval, ...], fleet: Fleet) -> str:
    moved = "; ".join(f"{code(bump.name)} {bump.old.name} to {bump.new.name}" for bump in plan.since)
    lines = [f"Moved since the last push: {moved}." if moved else "No input moved since the last push."]
    if plan.rebased:
        lines.append(f"main moved under it, so the branch now starts from {main_sha[:7]}.")
    lines.append(f"Checks: {checks_line(evals, fleet)}")
    return "\n\n".join(lines) + "\n"


def recheck_comment(head: str, evals: tuple[HostEval, ...], fleet: Fleet) -> str:
    return f"Checked {head[:7]}: {checks_line(evals, fleet)}\n"


def render_summary(
    plan: Plan, candidate: Candidate, evals: tuple[HostEval, ...] | None, fleet: Fleet | None
) -> str:
    parts = ["### flake-update\n", f"Plan: {describe_plan(plan)}.\n"]
    if candidate.bumps:
        parts.append(f"Moved: {names(code(bump.name) for bump in candidate.bumps)}.\n")
    if candidate.stuck:
        parts += [f"- stuck {code(stuck.name)}: {stuck.summary}" for stuck in candidate.stuck] + [""]
    if evals is not None:
        parts.append(f"Eval: {eval_description(evals)}.\n")
    if fleet is not None:
        parts.append(f"Fleet: {build_description(fleet).rstrip('.')}.\n")
    return "\n".join(parts)


def lock_hash(lock_text: str) -> str:
    return hashlib.sha256(lock_text.encode()).hexdigest()[:12]


def conflict_marker(main_sha: str, candidate: Candidate) -> str:
    return f"<!-- flake-update conflict {main_sha} {lock_hash(candidate.lock_text)} -->"


# --- shell -------------------------------------------------------------------


class CommandFailed(RuntimeError):
    def __init__(self, cmd: list[str], proc: subprocess.CompletedProcess):
        tail = "\n".join((proc.stderr or proc.stdout or "").strip().splitlines()[-15:])
        super().__init__(f"`{' '.join(cmd)}` exited {proc.returncode}\n{tail}")


def run(cmd: list[str], *, check: bool = True, stdin: str | None = None) -> subprocess.CompletedProcess:
    proc = subprocess.run(cmd, text=True, input=stdin, capture_output=True)
    if check and proc.returncode != 0:
        raise CommandFailed(cmd, proc)
    return proc


def out(*cmd: str, stdin: str | None = None) -> str:
    return run(list(cmd), stdin=stdin).stdout.strip()


def gh_pr(repo: str, *args: str, stdin: str | None = None) -> str:
    return out("gh", "pr", *args, "--repo", repo, stdin=stdin)


def log(message: str) -> None:
    print(message, file=sys.stderr, flush=True)


NIX = ["nix", "--accept-flake-config"]
# positions in errors name real store paths only without lazy trees, and the
# derivations are the same either way
NIX_EVAL = [*NIX, "eval", "--option", "lazy-trees", "false"]


@dataclass(frozen=True)
class Context:
    root: Path
    config: Config
    main_sha: str
    main_lock_text: str
    repo: str
    # the branch as this run read it, the lease every push holds
    branch_sha: str | None
    run_url: str | None
    no_fleet: bool

    @property
    def lock_path(self) -> Path:
        return self.root / "flake.lock"


def build_candidate(config: Config, lock_path: Path, main_lock_text: str) -> Candidate:
    """updates one tracked input at a time, since one that fails would stop the rest"""
    stuck = []
    try:
        for name in config.tracked:
            before = lock_path.read_text()
            proc = run(["nix", "flake", "update", "--accept-flake-config", name], check=False)
            if proc.returncode != 0:
                lock_path.write_text(before)
                stuck.append(Stuck(name, config.policy(name), error_block(proc.stderr)))
            moved = lock_path.read_text() != before
            log(f"{name}: {'stuck' if proc.returncode else 'moved' if moved else 'current'}")
        lock_text = lock_path.read_text()
    finally:
        lock_path.write_text(main_lock_text)
    bumps = diff(config, json.loads(main_lock_text), json.loads(lock_text))
    return Candidate(lock_text, bumps, tuple(stuck))


def foreign_commits(main_sha: str, head_sha: str) -> tuple[str, ...]:
    """the branch's own commits a person pushed, leaving out any main already has"""
    flags = ["--no-merges", "--reverse", "--right-only", "--cherry-pick", "--format=%H %ae"]
    listed = out("git", "log", *flags, f"{main_sha}...{head_sha}")
    commits = (line.split(" ", 1) for line in listed.splitlines())
    return tuple(sha for sha, email in commits if email != BOT_EMAIL)


def lock_at(rev: str) -> dict:
    return json.loads(out("git", "show", f"{rev}:flake.lock"))


def read_remote(main_sha: str) -> tuple[str, str | None, OpenPr | None, Parked | None]:
    repo = os.environ.get("GITHUB_REPOSITORY") or out(
        "gh", "repo", "view", "--json", "nameWithOwner", "-q", ".nameWithOwner"
    )
    listed = out("git", "ls-remote", "origin", f"refs/heads/{BRANCH}")
    branch_sha = listed.split()[0] if listed else None
    if branch_sha:
        out("git", "fetch", "--no-tags", "--quiet", "origin", f"refs/heads/{BRANCH}")

    fields = "number,state,closedAt,body"
    prs = json.loads(
        gh_pr(repo, "list", "--head", BRANCH, "--state", "all", "--limit", "50", "--json", fields)
    )
    ours = [pr for pr in prs if MARKER in (pr["body"] or "")]

    opened = next((pr for pr in ours if pr["state"] == "OPEN"), None)
    if opened and branch_sha:
        statuses = out("gh", "api", f"repos/{repo}/commits/{branch_sha}/status", "--jq", ".statuses[].context")
        pr = OpenPr(
            number=opened["number"],
            head_sha=branch_sha,
            base_sha=out("git", "merge-base", main_sha, branch_sha),
            lock=lock_at(branch_sha),
            foreign=foreign_commits(main_sha, branch_sha),
            checked=EVAL_STATUS in statuses.splitlines(),
        )
        return repo, branch_sha, pr, None

    closed = [pr for pr in ours if pr["state"] == "CLOSED"]
    if not closed:
        return repo, branch_sha, None, None
    newest = max(closed, key=lambda pr: pr["closedAt"])
    out("git", "fetch", "--no-tags", "--quiet", "origin", f"refs/pull/{newest['number']}/head")
    return repo, branch_sha, None, Parked(newest["number"], lock_at("FETCH_HEAD"))


def nixpkgs_source(lock: dict) -> Nixpkgs | None:
    pin = root_pins(lock).get("nixpkgs")
    expr = "(builtins.getFlake (toString ./.)).inputs.nixpkgs.outPath"
    proc = run([*NIX_EVAL, "--impure", "--raw", "--expr", expr], check=False)
    if not pin or not pin.rev or proc.returncode != 0:
        return None
    return Nixpkgs(pin.rev, proc.stdout.strip())


def eval_hosts(lock: dict) -> tuple[HostEval, ...]:
    """every host's toplevel drvPath, from the tree as it is now"""
    nixpkgs = nixpkgs_source(lock)
    hosts = json.loads(out(*NIX, "eval", "--json", ".#machineMetadata"))
    results = []
    for host, metadata in sorted(hosts.items()):
        proc = run([*NIX_EVAL, "--raw", f".#{host}.system.build.toplevel.drvPath"], check=False)
        warnings = eval_warnings(proc.stderr)
        if proc.returncode == 0:
            results.append(HostEval(host, metadata["architecture"], proc.stdout.strip(), None, warnings))
        else:
            error = classify(proc.stderr, nixpkgs)
            results.append(
                HostEval(host, metadata["architecture"], None, error, warnings, error_block(proc.stderr))
            )
        log(f"eval {host}: {eval_cell(results[-1])}")
    return tuple(results)


# builds without activating; a large --max-failures keeps one failing machine
# from stopping the others, and unreachable ones are skipped
FLEET_BUILD = ["coeus", "deploy", "@all", "--build", "--skip-unreachable", "--max-failures", "1000"]


def build_fleet(sha: str) -> Built:
    with tempfile.TemporaryDirectory() as scratch:
        summary = Path(scratch) / "summary.md"
        # coeus streams its progress into the job log and its table into the summary
        proc = subprocess.run(
            [*FLEET_BUILD, "--rev", sha, "--ref", BRANCH],
            env=os.environ | {"GITHUB_STEP_SUMMARY": str(summary)},
            text=True,
        )
        markdown = summary.read_text() if summary.exists() else ""
    table, machines = parse_coeus_summary(markdown)
    logs = []
    for machine in machines:
        if machine.ok is False and machine.job:
            job = run(["coeus", "logs", machine.host, machine.job], check=False)
            logs.append((machine.host, job.stdout if job.returncode == 0 else job.stderr))
    return Built(proc.returncode == 0, table, machines, tuple(logs))


def build_branch(ctx: Context, candidate: Candidate, foreign: tuple[str, ...]) -> str | None:
    """main's tip, the bot's commit, then the foreign commits; None when one does not apply"""
    out("git", "checkout", "--quiet", "--detach", ctx.main_sha)
    if candidate.bumps:
        ctx.lock_path.write_text(candidate.lock_text)
        out("git", "add", "flake.lock")
        out("git", "commit", "--quiet", "--file", "-", stdin=commit_message(candidate.bumps))
    for sha in foreign:
        if run(["git", "cherry-pick", sha], check=False).returncode != 0:
            run(["git", "cherry-pick", "--abort"], check=False)
            return None
    return out("git", "rev-parse", "HEAD")


def set_status(ctx: Context, sha: str, context: str, state: str, description: str) -> None:
    fields = [f"state={state}", f"context={context}", f"description={description[:140]}"]
    if ctx.run_url:
        fields.append(f"target_url={ctx.run_url}")
    flags = (flag for field in fields for flag in ("-f", field))
    out("gh", "api", "--method", "POST", f"repos/{ctx.repo}/statuses/{sha}", *flags)


def write_summary(text: str) -> None:
    if path := os.environ.get("GITHUB_STEP_SUMMARY"):
        with open(path, "a") as summary:
            summary.write(text + "\n")


def comment_conflict(ctx: Context, pr: OpenPr, candidate: Candidate) -> None:
    marker = conflict_marker(ctx.main_sha, candidate)
    said = out("gh", "api", "--paginate", f"repos/{ctx.repo}/issues/{pr.number}/comments", "--jq", ".[].body")
    if marker in said:
        return
    commits = ", ".join(sha[:7] for sha in pr.foreign)
    body = (
        f"{marker}\nThe bot cannot carry this branch's own commits ({commits}) onto main's tip "
        f"{ctx.main_sha[:7]} with the new lock: one of them no longer applies. It leaves the branch "
        "alone until main or the inputs move; rebase those commits onto main to let it refresh again.\n"
    )
    gh_pr(ctx.repo, "comment", str(pr.number), "--body-file", "-", stdin=body)


def apply(ctx: Context, plan: Plan, candidate: Candidate) -> None:
    match plan:
        case Idle():
            write_summary(render_summary(plan, candidate, None, None))
            return
        case Close(pr=pr, reason=reason):
            gh_pr(ctx.repo, "close", str(pr.number), "--comment", f"Closing: {reason}.", "--delete-branch")
            write_summary(render_summary(plan, candidate, None, None))
            return

    pr = plan.pr if isinstance(plan, (Refresh, Recheck)) else None
    by_hand = isinstance(plan, Open) and plan.by_hand

    if isinstance(plan, Recheck):
        # checks what a person pushed, as it is
        head = plan.pr.head_sha
        out("git", "checkout", "--quiet", "--detach", head)
    else:
        head = build_branch(ctx, candidate, pr.foreign if pr else ())
        if head is None:
            comment_conflict(ctx, pr, candidate)
            print(f"::warning::#{pr.number}'s own commits do not apply onto main; the branch stays as it is")
            write_summary(
                render_summary(
                    plan, candidate, None, NotBuilt("Stopped: the branch's own commits do not apply onto main")
                )
            )
            return
        out(
            "git",
            "push",
            "--quiet",
            f"--force-with-lease=refs/heads/{BRANCH}:{ctx.branch_sha or ''}",
            "origin",
            f"HEAD:refs/heads/{BRANCH}",
        )

    # first what the runner alone can tell, so a run that dies in the fleet
    # build still leaves the pull request with its evaluation
    evals = eval_hosts(candidate.lock)
    title = commit_subject(candidate.bumps)
    pending = NotBuilt("Skipped for this run." if ctx.no_fleet else "Building on every machine that answers.")
    body = render_body(candidate, ctx.config, by_hand, evals, pending)
    if pr:
        number = pr.number
        gh_pr(ctx.repo, "edit", str(number), "--title", title, "--body-file", "-", stdin=body)
    else:
        url = gh_pr(
            ctx.repo,
            "create",
            "--base",
            "main",
            "--head",
            BRANCH,
            "--title",
            title,
            "--body-file",
            "-",
            stdin=body,
        )
        number = int(url.rstrip("/").rsplit("/", 1)[1])
    evaluated = all(result.error is None for result in evals)
    set_status(ctx, head, EVAL_STATUS, "success" if evaluated else "failure", eval_description(evals))

    fleet: Fleet = pending
    if not ctx.no_fleet:
        set_status(ctx, head, BUILD_STATUS, "pending", pending.note)
        fleet = build_fleet(head)
        body = render_body(candidate, ctx.config, by_hand, evals, fleet)
        gh_pr(ctx.repo, "edit", str(number), "--body-file", "-", stdin=body)
        set_status(
            ctx,
            head,
            BUILD_STATUS,
            "success" if fleet.passed else "failure",
            build_description(fleet),
        )

    match plan:
        case Refresh():
            comment = refresh_comment(plan, ctx.main_sha, evals, fleet)
            gh_pr(ctx.repo, "comment", str(number), "--body-file", "-", stdin=comment)
        case Recheck():
            gh_pr(ctx.repo, "comment", str(number), "--body-file", "-", stdin=recheck_comment(head, evals, fleet))
    write_summary(render_summary(plan, candidate, evals, fleet))


def dry_run(ctx: Context, plan: Plan, candidate: Candidate) -> None:
    """everything but the writes: the hosts evaluate on this tree with the candidate's lock"""
    try:
        ctx.lock_path.write_text(candidate.lock_text)
        evals = eval_hosts(candidate.lock)
    finally:
        ctx.lock_path.write_text(ctx.main_lock_text)
    fleet = NotBuilt("Not built on a dry run.")
    by_hand = isinstance(plan, Open) and plan.by_hand
    print(f"plan: {describe_plan(plan)}\n")
    print(f"commit message:\n\n{textwrap.indent(commit_message(candidate.bumps), '    ')}")
    print(f"pull request body:\n\n{render_body(candidate, ctx.config, by_hand, evals, fleet)}")
    write_summary(render_summary(plan, candidate, evals, fleet))


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="compute and print the plan and its checks; write nothing remote",
    )
    parser.add_argument(
        "--open", action="store_true", help="open the pull request even when only passengers moved"
    )
    parser.add_argument("--no-fleet", action="store_true", help="skip the fleet build")
    args = parser.parse_args(argv)

    root = Path(__file__).resolve().parents[2]
    os.chdir(root)
    main_lock_text = (root / "flake.lock").read_text()
    try:
        config = parse_config(
            (Path(__file__).parent / "inputs.toml").read_text(), root_inputs(json.loads(main_lock_text))
        )
    except ConfigError as error:
        print(f"::error::{error}")
        return 2

    main_sha = out("git", "rev-parse", "HEAD")
    candidate = build_candidate(config, root / "flake.lock", main_lock_text)
    for stuck in candidate.stuck:
        print(f"::warning::{stuck.name} would not update: {stuck.summary}")
    if len(candidate.stuck) == len(config.tracked):
        # one input breaks upstream; all of them breaking means nix or the flake is broken here
        print("::error::no tracked input would update, so nothing here can be trusted")
        return 1
    repo, branch_sha, pr, parked = read_remote(main_sha)
    plan = decide(config, main_sha, candidate, pr, parked, force_open=args.open)

    server, run_id = os.environ.get("GITHUB_SERVER_URL"), os.environ.get("GITHUB_RUN_ID")
    ctx = Context(
        root=root,
        config=config,
        main_sha=main_sha,
        main_lock_text=main_lock_text,
        repo=repo,
        branch_sha=branch_sha,
        run_url=f"{server}/{repo}/actions/runs/{run_id}" if server and run_id else None,
        no_fleet=args.no_fleet,
    )
    log(f"plan: {describe_plan(plan)}")
    (dry_run if args.dry_run else apply)(ctx, plan, candidate)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
