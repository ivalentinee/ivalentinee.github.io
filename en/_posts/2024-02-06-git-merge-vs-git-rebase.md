---
layout: post
title:  "What's the difference between git merge and git rebase?"
date:   2024-02-06
categories: programming
uid: git-merge-vs-git-rebase
---

## Introduction
Let me first give an answer to "Why?"

Well, I'm interviewing *Señor NodeJS developers* for about 1.5 years (about half a year after I started using NodeJS myself, *oh, the irony*). And the only (well, not the only, but the only one technical) git-related question I ask is this one.

Why this question? Because the answer tells me exactly how deep a candidate went into a rabbit hole of "git". And there's more than one possible answer from "I don't know" to "Actually git makes diffs dynamically".

So, to provide some feedback on this topic to candidates I need to have some prepared text, but I ~~failed to~~ [I managed in a half an hour of googling!](https://www.edwardthomson.com/blog/merge_vs_rebase.html) to find a proper article. Thus I think I should ~~fix~~ elaborate on this topic a bit.

Let's go through some possible answers and get to the ultimate one.

## Weak answers

### "I don't know"
"Move along, there's nothing to see here". If you don't know – you should go and find out. Maybe read this article (yeah, I'm hilarious, I know).

### "Merge combines the code while rebase applies it on top"
Well, yep, that's technically correct since `merge` tries to, well, *merge* (do you still remember I'm hilarious?) two branches into one, while `rebase` **applies** (not *re-bases*, got ya!) commits on top of another branch. Still not enough of an explanation.

### "Rebase changes history"
If only it could undo *that particular embarassing moment you think everyone still remembers*.\\
Jokes aside this answer is, again, technically correct, but if you care about non-changing commit history just go use [Mercurial](https://en.wikipedia.org/wiki/Mercurial). Still not enough of an explanation.

### "Merge combines the code once while rebase applies commits one-by-one"
That one is way more interesting but still does not point to, *ahem*, pain points *pointed* by the question (I'm still funny, a'right?).

But that is waaaay closer to the real problem. Indeed, git does calculate diff **only once** for `merge` by comparing **the latest state** for both branches, while `rebase` does this **for every commit** of a branch you're rebasing.

## "Diff is calculated differently for `merge` and `rebase`: `merge` resolves conflicts in a merge-commit, while rebase resolves 'em for every commit [one-by-one](https://youtu.be/gUaFD4JFU8c)"
Well, we're miles closer to [*the truth*](https://en.wikipedia.org/wiki/The_X-Files). But there's a nuance, which makes me to ask the next question: "What does that lead to?"

### "What does that lead to?"

#### "Different git blame"
So, the first answer to "What does that lead to?".

Explanation is pretty simple here (but not like evebody knows that): if there're any conflicts, resolved code (**even an automatically calculated one**) would be placed into a merge commit for `merge`, but will stay in related commits for `rebase`.

To demonstrate this fact on a 2-hour workshop I made [a small repo with examples](https://github.com/ivalentinee/git-workshop/blob/master/manual/INDEX.md). Go take a look if you have some time.

And (if you don't know that fact) I'm a huge advocate for **git-blame-driven** approach, so I'd like to see some questionable line git blame to trace to an actual commit it relates to instead of some meaningless `Merge branch 'feature/fix-some-bug' into 'master'`.

This makes me an advocate for *another questionable approach*: devs should `rebase` their branch *onto* `master` right before merging that branch *into* master to both have proper history **and** a merge-commit to denote the fact of merging a branch.

#### "Different code"
This one is mindblowing. Other "reasons" have nothing to do with an actual code, just git history. This one is really dangerous (no joke, but remember, I'm still funny).

Let's take a look.\\
I'll provide a full listing so you can go and find out what's going on yourself:
```bash
# Initialize a git repo
git init .

# Make the first commit with a single file
echo "some string" > file.txt
git add file.txt
git commit -m "Initial commit"

# Create two branches to play with
git branch branch-1
git branch branch-2

# Change that one line in "branch-1"
git checkout branch-1
echo "some string // changed" > file.txt
git add file.txt
git commit -m "Changed line 2 on branch 1"

# Change that one line in "branch-2"
git checkout branch-2
echo "some string // changed" > file.txt
git add file.txt
git commit -m "Changed line 2 on branch 2"

# Rewind that one line in "branch-2"
echo "some string" > file.txt
git add file.txt
git commit -m "Reverted line 2 on branch 2"

# Copy "branch-2" to try both merge and rebase
git branch branch-2-non-modified

# Try "git merge"
git merge --no-edit branch-1
cat file.txt
# Getting "some string // changed"

# Reset "branch-2" to non-merged state
git reset --hard branch-2-non-modified

# Try "git rebase"
git rebase branch-1
cat file.txt
# Getting "some string"
```

Exciting? It is! Especially so if told by a candidate.

Why that happens? Well, go think, google – I'm too lazy (but still hilarious!) to write an explanation. Especially considering that I do not ask for an explanation on an interview – if a candidate knows the fact then I know for a fact (yep, I'm still funny! ~~Double~~ Triple fact!) they got deep enough digging git.
