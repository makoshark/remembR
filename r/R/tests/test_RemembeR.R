library(testthat)
library(data.table)
source("../RemembeR.R")
test_that("single numbers",{
    remember(1,"one")
    expect_equal(r$one,1)
}
)

test_that("prefixes",{
    set.remember.prefix("prefix")
    remember(2,"two")
    expect_equal(r$prefix$two,2)
    expect_equal(r$one,1)
}
)

test.dt <- as.data.table(data("mtcars"))

test_that("data.tables",{
    set.remember.prefix("")
    remember(test.dt, 'test.dt')
    expect_equal(r$test.dt,test.dt)
}
)
