"""remembr: record values while an analysis runs, read them back when the
paper builds.

Python steps record the quantities a paper cites the same way the R
steps do::

    from remembr import Remember

    remember = Remember()
    remember.to("paper/knitr_rdata")
    remember(len(panel), "n.articles")
    remember(panel["date"].min(), "wv.first.edit")

remembR.R reads the result back and merges it with whatever the R
scripts recorded.

Two output targets are supported, chosen by the store's extension:

``.json``
    A typed JSON envelope, read by ``load.remembered()`` in
    remembR.R. Needs nothing but the standard library, so a Python
    step can record values on a machine with no R installed at all.

``.RDS``
    The R object file the upstream package writes, via rpy2. Kept for
    projects that want one store shared by both languages. rpy2 is
    imported only when this target is used.

Derived from pyRemembeR by Nathan TeBlunthuis <nathante@uw.edu>,
GPL-3. See README.md for the JSON schema and for how this fork differs.
"""

import datetime
import json
import math
import os
import sys

import pandas as pd

__all__ = ["Remember", "script_stem"]


def script_stem():
    """Name of the running script, without directory or extension.

    Used to name a store after the script that writes it, so the name
    lives in one place.
    """
    return os.path.splitext(os.path.basename(sys.argv[0]))[0]


class Remember(object):
    def __init__(self, f="remembr.json"):
        self.namespace = None
        self.remember_file = f
        self.r = {}

    # -- recording ------------------------------------------------

    def __call__(self, x, name, save=True):
        self.__setitem__(name, x, save)

    def __setitem__(self, name, x, save=True):
        if self.namespace is None or self.namespace == "":
            self.r[name] = x
        else:
            self.r.setdefault(self.namespace, {})[name] = x

        if save:
            self.save()

    def forget(self):
        """Drop everything recorded so far without writing it."""
        self.r = {}

    def set_namespace(self, namespace=""):
        """File values under ``r[namespace][name]`` rather than ``r[name]``.

        Lets one script record the same quantities for several inputs
        without their names colliding.
        """
        self.namespace = namespace

    def set_file(self, f):
        self.remember_file = f

    def to(self, directory=".", suffix=None, stem=None, ext=".json"):
        """Point the store at ``<directory>/<script><-suffix><ext>``.

        A suffix distinguishes runs of one script over several inputs,
        as in ``remember.to("paper/knitr_rdata", "WV")``.
        """
        stem = stem or script_stem()
        if suffix:
            stem = "{0}-{1}".format(stem, suffix)
        os.makedirs(directory, exist_ok=True)
        self.remember_file = os.path.join(directory, stem + ext)
        return self.remember_file

    # -- writing --------------------------------------------------

    def save(self):
        """Write the store, choosing the target from its extension."""
        if self.remember_file.lower().endswith(".json"):
            self._save_json()
        else:
            self._save_rds()
        return self.remember_file

    def _save_json(self):
        encoded = {name: _encode(value) for name, value in self.r.items()}
        with open(self.remember_file, "w") as fh:
            # Sorted and indented so a store diffs readably: a review
            # of the commit shows which numbers moved.
            json.dump(encoded, fh, indent=2, sort_keys=True)
            fh.write("\n")

    def _save_rds(self, update=True):
        # rpy2 and filelock are imported here rather than at the top so
        # that the JSON target works without either installed.
        from pathlib import Path

        import rpy2.robjects as ro

        robj = None
        if update and Path(self.remember_file).exists():
            import filelock

            with filelock.FileLock("{0}.lock".format(self.remember_file)):
                robj = ro.r("readRDS")(self.remember_file)

        robj = _to_r_list(self.r, robj)
        ro.r("saveRDS")(robj, self.remember_file, version=2)

    # Upstream's name for save(), kept so existing scripts still run.
    save_to_r = save


# ---------------------------------------------------------------
# JSON encoding.
#
# Each value is wrapped in a type so that R gets back the object that
# was meant rather than whatever JSON happens to imply: a date as a
# Date, a table as a data frame with its columns in order, a missing
# value as NA. remembR.R decodes these; keep the two in step.
# ---------------------------------------------------------------


def _encode(value):
    if isinstance(value, pd.DataFrame):
        return _encode_frame(value)

    if isinstance(value, pd.Series):
        return _encode_sequence(value.tolist(), [str(i) for i in value.index])

    if isinstance(value, dict):
        # A dict of values is a nested store; a dict of plain scalars
        # would also encode as a named vector, but nesting keeps
        # namespaces and grouped results readable on the R side.
        return {"type": "list",
                "value": {str(k): _encode(v) for k, v in value.items()}}

    if isinstance(value, (list, tuple)) or _is_array(value):
        return _encode_sequence(list(value), None)

    if _is_date(value):
        return {"type": "date", "value": _iso(value)}

    return {"type": "scalar", "value": _scalar(value)}


def _encode_sequence(values, names):
    envelope = {"type": "vector", "value": [_scalar(v) for v in values]}
    if values and all(_is_date(v) or _missing(v) for v in values):
        envelope = {"type": "date",
                    "value": [None if _missing(v) else _iso(v) for v in values]}
    if names is not None:
        envelope["names"] = names
    return envelope


def _encode_frame(df):
    # Column order is carried explicitly because JSON objects have no
    # order a reader can rely on.
    columns = [str(c) for c in df.columns]
    dates = [c for c in columns if _is_date_column(df[c])]
    return {"type": "data.frame",
            "columns": columns,
            "date.columns": dates,
            "value": {c: [None if _missing(v) else
                          (_iso(v) if c in dates else _scalar(v))
                          for v in df[c].tolist()]
                      for c in columns}}


def _is_array(x):
    # numpy arrives with pandas but is not imported here directly.
    return hasattr(x, "dtype") and hasattr(x, "tolist") and hasattr(x, "shape")


def _is_date(x):
    return isinstance(x, (datetime.date, datetime.datetime, pd.Timestamp))


def _is_date_column(series):
    return pd.api.types.is_datetime64_any_dtype(series) or (
        series.dtype == object and len(series) and
        all(_is_date(v) or _missing(v) for v in series))


def _missing(x):
    return x is None or (isinstance(x, float) and math.isnan(x)) or x is pd.NaT


def _iso(x):
    x = pd.Timestamp(x)
    if x.hour or x.minute or x.second or x.microsecond:
        return x.strftime("%Y-%m-%dT%H:%M:%S")
    return x.strftime("%Y-%m-%d")


def _scalar(x):
    """Reduce one value to something JSON can hold and R can read back."""
    if _missing(x):
        return None

    if _is_date(x):
        return _iso(x)

    # numpy scalars carry an item() that yields the plain Python value.
    if hasattr(x, "item") and not isinstance(x, (str, bytes)):
        x = x.item()

    if isinstance(x, float) and math.isinf(x):
        raise ValueError("cannot record an infinite value: JSON has no "
                         "spelling for it")

    if isinstance(x, (bool, int, float, str)):
        return x

    raise TypeError("cannot record a {0}: record numbers, strings, dates, "
                    "sequences, and data frames".format(type(x).__name__))


# ---------------------------------------------------------------
# The RDS target, unchanged in behaviour from upstream.
# ---------------------------------------------------------------


def _to_r_list(values, robj=None):
    import rpy2.robjects as ro

    new = ro.ListVector({name: _to_r_item(x) for name, x in values.items()})
    if robj is None:
        return new
    return ro.ListVector({**dict(robj.items()), **dict(new.items())})


def _to_r_item(x):
    import rpy2.robjects as ro
    from rpy2.robjects import pandas2ri
    from rpy2.robjects.conversion import localconverter

    if isinstance(x, pd.DataFrame):
        with localconverter(ro.default_converter + pandas2ri.converter):
            return ro.conversion.get_conversion().py2rpy(x)

    if isinstance(x, dict):
        return _to_r_list(x)

    if _is_date(x):
        return _iso(x)

    return x
