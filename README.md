# You never fail until you stop trying.

In the middle of difficulty lies opportunity.

## My dotfiles M2 from 2023

My dotfiles are based on [shiwano](https://github.com/shiwano/dotfiles).

## Install

Clone first, then run the script.

```
git clone https://github.com/thanks2music/dotfiles-rere.git ~/dotfiles
bash ~/dotfiles/setup.sh
```

Piping through `curl` is intentionally not documented here. You cannot inspect the
script before it runs, and `setup.sh` clones this repository anyway — so cloning
first is strictly better. See the note at the top of `setup.sh`.

`setup.sh` is idempotent: phases that already completed report `ok`. It exits
non-zero if any phase failed **or was skipped**, so read the summary rather than
treating a non-zero exit as a failure on its own.
