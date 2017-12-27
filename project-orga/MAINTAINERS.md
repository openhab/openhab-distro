# The openHAB Maintainer manual

## Introduction

Dear maintainer. Thank you for investing the time and energy to help
make openHAB as useful as possible. Maintaining a project is difficult,
sometimes unrewarding work. Sure, you will get to contribute cool
features to the project. But most of your time will be spent reviewing,
cleaning up, documenting, answering questions, and justifying design
decisions - while everyone has all the fun! But remember - the quality
of the maintainers' work is what distinguishes the good projects from
the great. So please be proud of your work, even the unglamourous parts,
and encourage a culture of appreciation and respect for *every* aspect
of improving the project - not just the hot new features.

This document is a manual for maintainers old and new. It explains what
is expected of maintainers, how they should work, and what tools are
available to them.

This is a living document - if you see something out of date or missing,
speak up!

## What is a maintainer's responsibility?

It is every maintainer's responsibility to:

1. Expose a clear road map for improving their component.
2. Deliver prompt feedback and decisions on pull requests.
3. Be available to anyone with questions, bug reports, criticism etc.
  on their component. This includes GitHub requests and the
  [community forum](https://community.openhab.org).
4. Make sure their component respects the philosophy, design and
  road map of the project.

## How are decisions made?

Short answer: with pull requests to the openHAB repository.

openHAB is an open-source project with an open design philosophy. This
means that the repository is the source of truth for EVERY aspect of the
project, including its philosophy, design, road map, and APIs. *If it's
part of the project, it's in the repo. If it's in the repo, it's part of
the project.*

As a result, all decisions can be expressed as changes to the
repository. An implementation change is a change to the source code. An
API change is a change to the API specification. A philosophy change is
a change to the philosophy manifesto, and so on.

All decisions affecting openHAB, big and small, follow the same 3 steps:

* Step 1: Open a pull request. Anyone can do this.

* Step 2: Discuss the pull request. Anyone can do this.

* Step 3: Accept (`LGTM`) or refuse a pull request. The relevant maintainers do 
this (see below "Who decides what?")
   + Accepting pull requests
      - If the pull request appears to be ready to merge, give it a `LGTM`, which
    stands for "Looks Good To Me".
      - If the pull request has some small problems that need to be changed, make
    a comment adressing the issues.
      - If the changes needed to a PR are small, you can add a "LGTM once the
    following comments are adressed..." this will reduce needless back and
    forth.
      - If the PR only needs a few changes before being merged, any MAINTAINER can
    make a replacement PR that incorporates the existing commits and fixes the
    problems before a fast track merge.
   + Closing pull requests
      - If a PR appears to be abandoned, after having attempted to contact the
    original contributor, then a replacement PR may be made.  Once the
    replacement PR is made, any contributor may close the original one.
      - If you are not sure if the pull request implements a good feature or you
    do not understand the purpose of the PR, ask the contributor to provide
    more documentation.  If the contributor is not able to adequately explain
    the purpose of the PR, the PR may be closed by any MAINTAINER.
      - If a MAINTAINER feels that the pull request is sufficiently architecturally
    flawed, or if the pull request needs significantly more design discussion
    before being considered, the MAINTAINER should close the pull request with
    a short explanation of what discussion still needs to be had.  It is
    important not to leave such pull requests open, as this will waste both the
    MAINTAINER's time and the contributor's time.  It is not good to string a
    contributor on for weeks or months, having them make many changes to a PR
    that will eventually be rejected.

## Who decides what?

All decisions are pull requests, and the relevant maintainers make
decisions by accepting or refusing pull requests. Review and acceptance
by anyone is denoted by adding a comment in the pull request: `LGTM`.
However, only currently listed `MAINTAINERS` are counted towards the
required majority.

openHAB follows the timeless, highly efficient and totally unfair system
known as [Benevolent dictator for
life](http://en.wikipedia.org/wiki/Benevolent_Dictator_for_Life), with
yours truly, Kai Kreuzer, in the role of BDFL. This means that all
decisions are made, by default, by Kai. Since making every decision
myself would be highly un-scalable, in practice decisions are spread
across multiple maintainers.

The relevant maintainers for a pull request can be worked out in 2 steps:

* Step 1: Determine the subdirectories affected by the pull request. This
  might be `distribution/openhab-offline`, 
  `docs/source/installation`, or any other part of the repo.

* Step 2: Find the `MAINTAINERS` file which affects this directory. If the
  directory itself does not have a `MAINTAINERS` file, work your way up
  the repo hierarchy until you find one.

There is also a `project-orga/getmaintainers.sh` script that will print out the 
maintainers for a specified directory.

### I'm a maintainer, and I'm going on holiday

Please let your co-maintainers and other contributors know by raising a pull
request that comments out your `MAINTAINERS` file entry using a `#`.

### I'm a maintainer. Should I make pull requests too?

Yes. Nobody should ever push to master directly. All changes should be
made through a pull request.

### Helping contributors with the DCO

The [DCO or `Sign your work`](
https://github.com/openhab/openhab2/blob/master/CONTRIBUTING.md#sign-your-work)
requirement is not intended as a roadblock or speed bump.

Some openHAB contributors are not as familiar with `git`, or have used a web based
editor, and thus asking them to `git commit --amend -s` is not the best way forward.

In this case, maintainers can update the commits based on clause (c) of the DCO. The
most trivial way for a contributor to allow the maintainer to do this, is to add
a DCO signature in a Pull Requests's comment, or a maintainer can simply note that
the change is sufficiently trivial that it does not substantivly change the existing
contribution - i.e., a spelling change.

When you add someone's DCO, please also add your own to keep a log.

### Who assigns maintainers?

Kai has final `LGTM` approval for all pull requests to `MAINTAINERS` files.

### How is this process changed?

Just like everything else: by making a pull request :)
