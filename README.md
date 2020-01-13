# Prerequisites
Python, R, Suite Sparse installed.

On a Mac you can install the above using Homebrew:

```
brew install python r suite-sparse
```

# Installation
```
git clone --recurse-submodules https://github.com/andportnoy/mixed
make setup
```

# Tests
Enter a list of columns in `columns.txt` and the desired mixed effects formula
in `formula.txt`, then to compare outputs against lme4 in R run `make`.
