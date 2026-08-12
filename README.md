# remembR

Record values while an analysis runs; read them back when the paper
builds.

The problem this solves is the number typed into a manuscript by hand.
Once a statistic is transcribed into TeX it stops tracking the code
that produced it, and every later change to the pipeline silently
leaves it wrong. Instead, analytic scripts record the quantities the
paper cites as they compute them, and the paper cites those recordings
rather than literals. A number can then only be wrong the way the
analysis is wrong.

This is a fork of [RemembR][] and [pyRemembeR][] by Nathan
TeBlunthuis, GPL-3, and keeps their API. Both upstream histories are
here in full, rewritten into the subdirectories their packages now
occupy, so `git log --follow` reaches every earlier revision of these
files.

[RemembR]: https://github.com/groceryheist/RemembR
[pyRemembeR]: https://github.com/groceryheist/pyRembr

## Layout

    r/        the R package, remembR
    python/   the Python package, pyremembr

The two are kept together because they implement one contract: the
schema below says how a recorded value is written and read back, and
both sides have to agree on it. In separate repositories a change to
that agreement ships from two places at two times, and a mismatch
shows up as a wrong number in somebody's paper rather than as a failed
test.

The Python distribution is `pyremembr` rather than `remembr` because
that name is taken on PyPI by an unrelated project. Its import name
matches, so installing both is harmless.

## Recording from R

```r
source("r/R/remembR.R")
remember.to("paper/knitr_rdata")     # store is named after the script

remember(nrow(final.df), "n.article.weeks")
remember(divergence.slope)           # filed under "divergence.slope"
```

`remember()` files a value in the list `r` and writes the store on
every call, so a run that dies partway through still leaves what it
got to. Called without a name it uses the expression itself, which
keeps the name in the paper and the name in the code identical.

`remember.to(dir, suffix)` points the store at
`<dir>/<script><-suffix>.RDS`. The suffix distinguishes runs of one
script over several inputs—one per community, say. Use
`change.remember.file()` to name a store directly, `forget()` to drop
what has been recorded without writing it, and
`set.remember.prefix()` to nest values under a namespace when one
script records the same quantities for several inputs.

## Recording from Python

```python
from pyremembr import Remember

remember = Remember()
remember.to("paper/knitr_rdata")

remember(len(panel), "n.articles")
remember(panel["date"].min(), "wv.first.edit")
```

The interface mirrors the R side: the object is callable, `set_file()`
and `set_namespace()` behave as they do upstream, and `forget()` drops
what has been recorded. Names are given explicitly, since Python
cannot recover the expression that produced a value.

Numbers, strings, dates, sequences, dicts, `Series`, and `DataFrame`
are recordable. Anything else raises rather than being written in some
shape R will misread.

## Reading it back

```r
source("r/R/remembR.R")
r <- load.remembered("knitr_rdata")
attach(r)
```

`load.remembered()` merges every store in a directory, whichever
language wrote it, and returns one list. Two stores defining the same
name is an error rather than a silent overwrite: with several scripts
and two languages feeding one flat namespace, a masked value is a
wrong number in the paper and nothing about the output would show it.
The error names both files. Which file each name came from is kept on
the result as the `source` attribute.

In a knitr document, this belongs in the preamble chunk, after which
values are cited with `\Sexpr{}`.

Until the R half is installable from CRAN, a document that has to
build somewhere the rest of the project is not present—an Overleaf
project holding only the paper, say—needs its own copy of
`remembR.R` beside it. Generating that copy from a make rule, rather
than copying it by hand, is what keeps the two from drifting, and a
preamble that prefers the project's own copy when it is present falls
back to the vendored one only where it has to.

## Output targets

The store's extension chooses the format.

`.RDS` is the R object file, and the target upstream uses for both
languages. Python writes it through rpy2, which means an R
installation behind the Python interpreter.

`.json` is a typed envelope read by `load.remembered()`. Writing it
from Python needs nothing but the standard library and pandas, and
reading it needs `jsonlite`. This is the target that lets a project
mix the two languages without either needing an interpreter for the
other, and it is what `remember.to()` selects by default on the Python
side. It also gives a store that diffs readably, so a commit shows
which numbers moved.

The R side writes `.RDS`, since it loses nothing on the round trip and
the paper's reader handles both.

### The JSON schema

Each value is wrapped in a type, because JSON alone does not say
whether `"2013-04-01"` is a string or a date, or which order a table's
columns go in.

```json
{
  "n.articles":  {"type": "scalar", "value": 22617},
  "split.date":  {"type": "date",   "value": "2013-04-01"},
  "pct.edited":  {"type": "vector", "value": [3.5, 4.8],
                  "names": ["WT", "WV"]},
  "thresholds":  {"type": "list",
                  "value": {"core": {"type": "scalar", "value": 100}}},
  "grid":        {"type": "data.frame",
                  "columns": ["week", "length"],
                  "date.columns": ["week"],
                  "value": {"week": ["2013-01-07"], "length": [7.1]}}
}
```

Dates are ISO 8601 and come back as `Date` when they are whole days
and `POSIXct` in UTC when they carry a time. `null` comes back as
`NA`. Column order is carried explicitly because JSON objects have
none a reader can rely on. Infinities are refused, since JSON has no
spelling for them.
