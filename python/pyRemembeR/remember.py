import rpy2
import filelock
import rpy2.robjects as ro
from os import path
from rpy2.robjects import pandas2ri, numpy2ri
from rpy2.robjects.packages import importr
from rpy2.robjects.conversion import localconverter
import pandas as pd
pandas2ri.activate()
numpy2ri.activate()

class Remember(object):
    def __init__(self, f="remember.RDS"):
    
        self.namespace = None
        self.remember_file = f
        self.r = {}

    def _remember_dict(r, robj=None):
        return ro.ListVector{name:Remember._remember_item(x) for name, x in r.items()}

    @staticmethod
    def _remember_item(x):
        if type(x) == pd.DataFrame:
            with localconverter(ro.default_converter + pandas2ri.converter):
                rx = ro.conversion.py2rpy(x)

        elif type(x) == dict:
            rx = Remember._remember_dict(x)

        else:
            rx = x

        return rx
    
    def __call__(self, x, name, save=True):
        self.__setitem__(name, x, save)

    def __setitem__(self, name, x, save=False):
        if self.namespace is None or self.namespace == "":
            self.r[name] = x
        elif self.namespace not in self.r:
            self.r[self.namespace] = {}
            self.r[self.namespace][name] = x
        else:
            self.r[self.namespace][name] = x

        if save is True:
            self.save_to_r(update=True)

    ## save the r function to rdata file
    def save_to_r(self, update=True):
        
        robj = None
        if path.exists(self.remember_file):

            lock = filelock.FileLock("{0}.lock".format(self.remember_file))
            with lock:
                if update == True:
                    readRDS = ro.r("readRDS")
                    robj = readRDS(self.remember_file)

        robj = Remember._remember_dict(self.r, robj)
        saveRDS = ro.r("saveRDS")
        saveRDS(robj, self.remember_file)

    def set_namespace(self, namespace=""):
        self.namespace = namespace

    def set_file(self, f):
        self.remember_file = f
