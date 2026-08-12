# pyRemembeR
© 2020 Nathan TeBlunthuis

A simple utility for data scientists to save intermediate objects from either R or python. See the [RemembeR](https://github.com/groceryheist/RemembeR) project for the R version.  Useful in reproducible research workflows that require caching intermediate results from expensive computations or robustness checks and loading them in knitr. Interoperable with the pyRemembeR python package to support projects that use both languages. Uses filelocking so that multiple threads or processes can operate on the same cache.
