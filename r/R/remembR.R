## remembR: record values while an analysis runs, read them back when
## the paper builds.
##
## Analytic scripts record the quantities a paper cites with
## remember(); each script writes its own store under a directory the
## project picks. The paper calls load.remembered() on that directory,
## merges every store into the list `r`, and cites values with
## \Sexpr{}. Nothing is typed into the TeX by hand and nothing is
## recomputed at build time, which matters when the document is built
## somewhere with little computing power and no access to the data.
##
## Python steps record the same way through remembr.py. They write
## JSON rather than RDS, and load.remembered() reads both, so a project
## can mix the two languages without either needing an interpreter for
## the other. See README.md for why this fork works that way.
##
## Derived from RemembR and pyRemembeR by Nathan TeBlunthuis
## <nathante@uw.edu>, GPL-3. Divergences are described in README.md.

## The store this session writes to. remember.to() sets it from the
## running script's name, which is the usual way to name it.
remember.file <- "remembr.RDS"

## An optional namespace. When set, values are filed under
## r[[prefix]][[name]] rather than r[[name]], which lets one script
## record the same quantities for several inputs without collisions.
remember.prefix <- ""

## Values recorded so far this session.
if (!exists("r")) { r <- list() }

## Name of the running script, without directory or extension. Used to
## name its store, so the name lives in one place.
script.stem <- function () {
    args <- commandArgs(trailingOnly = FALSE)
    file <- sub("^--file=", "", args[grep("^--file=", args)])
    if (length(file) != 1) {
        stop("cannot tell which script is running: name the store with change.remember.file()")
    }
    sub("\\.[Rr]$", "", basename(file))
}

## Point this session's store at <dir>/<script>.RDS, creating the
## directory if needed. A suffix distinguishes runs of one script over
## several inputs, as in remember.to("paper/knitr_rdata", "WV").
remember.to <- function (dir = ".", suffix, stem = script.stem()) {
    if (!missing(suffix)) {
        stem <- paste(stem, suffix, sep = "-")
    }
    dir.create(dir, showWarnings = FALSE, recursive = TRUE)
    change.remember.file(file.path(dir, paste0(stem, ".RDS")))
    invisible(remember.file)
}

## Record one value. Called without a name it uses the expression
## itself, so remember(n.articles) files the value under
## "n.articles". The value is printed unless silenced, which keeps the
## recorded numbers visible in the pipeline's logs. Every call writes
## the store, so a crash partway through still leaves what ran.
remember <- function (var, name, save = TRUE, silent = FALSE) {
    if (missing(name)) {
        name <- deparse(substitute(var))
    }

    if (remember.prefix == "") {
        r[[name]] <<- var
    } else {
        if (is.null(r[[remember.prefix]])) {
            r[[remember.prefix]] <<- list()
        }
        r[[remember.prefix]][[name]] <<- var
    }

    if (!silent) {
        print(var)
        flush.console()
    }
    if (save) {
        save.remember()
    }

    invisible(var)
}

save.remember <- function () {
    saveRDS(r, file = remember.file)
    invisible(remember.file)
}

## Drop everything recorded so far. Passing clear=FALSE to
## change.remember.file() keeps the current values and writes them to
## the new location instead.
forget <- function () {
    r <<- list()
    invisible(NULL)
}

change.remember.file <- function (file, clear = TRUE) {
    remember.file <<- file
    if (clear) {
        forget()
    } else {
        save.remember()
    }
    invisible(file)
}

set.remember.prefix <- function (prefix = "") {
    remember.prefix <<- prefix
    invisible(prefix)
}

## ---------------------------------------------------------------
## Reading stores back: the half the paper uses.
## ---------------------------------------------------------------

## Merge every store in a directory into one list. Stores written by R
## (.RDS, or .RData holding a list named r) and by Python (.json) are
## both read; only the JSON path needs jsonlite, so a project that
## records nothing from Python needs no packages at all to read its
## numbers back.
##
## Two stores defining the same name is an error rather than a silent
## overwrite: with several scripts and two languages feeding one flat
## namespace, a quietly masked value is a wrong number in the paper.
## The names each file contributed are kept on the result as the
## "source" attribute, which is what makes that error nameable and is
## worth having when tracking down where a value came from.
load.remembered <- function (dir = ".", quiet = FALSE) {
    files <- sort(list.files(dir, pattern = "\\.(RDS|RData|json)$",
                             full.names = TRUE, ignore.case = TRUE))
    if (!length(files)) {
        stop("no stores found in ", dir)
    }

    r <- list()
    origin <- character(0)
    for (file in files) {
        one <- if (grepl("\\.json$", file, ignore.case = TRUE)) {
            read.remembered.json(file)
        } else {
            read.remembered.rdata(file)
        }

        dup <- intersect(names(one), names(r))
        if (length(dup)) {
            stop("two stores define ", paste(dQuote(dup), collapse = ", "),
                 ": ", basename(file), " and ",
                 paste(unique(origin[dup]), collapse = ", "))
        }

        r[names(one)] <- one
        origin[names(one)] <- basename(file)
    }

    if (!quiet) {
        cat(sprintf("== loaded %d value%s from %d store%s in %s\n",
                    length(r), if (length(r) == 1) "" else "s",
                    length(files), if (length(files) == 1) "" else "s", dir))
    }

    attr(r, "source") <- origin
    r
}

read.remembered.rdata <- function (file) {
    if (grepl("\\.RDS$", file, ignore.case = TRUE)) {
        return(readRDS(file))
    }
    ## .RData is supported for stores written before RDS, which name
    ## the list they hold rather than saving it anonymously.
    env <- new.env()
    load(file, envir = env)
    if (!exists("r", envir = env, inherits = FALSE)) {
        stop(basename(file), " holds no list named r")
    }
    get("r", envir = env)
}

## ---------------------------------------------------------------
## Decoding what Python wrote.
##
## remembr.py wraps each value in a type so it comes back as the R
## object it was meant to be rather than as whatever JSON happens to
## imply: a date as a Date, a table as a data frame with its columns in
## order, a JSON null as NA. The schema is documented in README.md.
## ---------------------------------------------------------------

read.remembered.json <- function (file) {
    if (!requireNamespace("jsonlite", quietly = TRUE)) {
        stop("reading ", basename(file), " needs the jsonlite package")
    }
    parsed <- jsonlite::fromJSON(file, simplifyVector = FALSE)
    lapply(parsed, decode.remembered)
}

decode.remembered <- function (x) {
    if (!is.list(x) || is.null(x$type)) {
        stop("value is not a remembr envelope: expected a type")
    }

    switch(x$type,
           scalar = if (is.null(x$value)) NA else x$value,
           vector = set.names(remembered.vector(x$value), x$names),
           date   = set.names(remembered.dates(x$value), x$names),
           list   = lapply(x$value, decode.remembered),
           data.frame = remembered.frame(x),
           stop("unknown remembr type: ", x$type))
}

## JSON arrays arrive as lists so that nulls survive the trip; flatten
## them to an atomic vector with nulls as NA.
remembered.vector <- function (x) {
    if (!length(x)) {
        return(logical(0))
    }
    x[vapply(x, is.null, logical(1))] <- NA
    unlist(x, use.names = FALSE)
}

## Dates are written as ISO 8601. Whole days come back as Date;
## anything carrying a time comes back as POSIXct in UTC.
remembered.dates <- function (x) {
    x <- as.character(remembered.vector(x))
    if (all(is.na(x) | grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", x))) {
        as.Date(x)
    } else {
        as.POSIXct(x, format = "%Y-%m-%dT%H:%M:%S", tz = "UTC")
    }
}

set.names <- function (x, names) {
    if (!is.null(names)) {
        names(x) <- remembered.vector(names)
    }
    x
}

remembered.frame <- function (x) {
    columns <- remembered.vector(x$columns)
    dates <- remembered.vector(x$date.columns)

    cols <- lapply(columns, function (column) {
        if (column %in% dates) {
            remembered.dates(x$value[[column]])
        } else {
            remembered.vector(x$value[[column]])
        }
    })

    names(cols) <- columns
    as.data.frame(cols, stringsAsFactors = FALSE)
}
