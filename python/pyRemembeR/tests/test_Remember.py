import unittest
import rpy2
import rpy2.robjects as ro
import pandas as pd
from pyRemembeR import Remember

class TestRemember(unittest.TestCase):
    def test_pd(self):

        df = pd.DataFrame({"a":range(1,100),"b":range(101,200)})
        
        remember = Remember()
        obj = remember._remember_item(df)

        obj.rownames = ro.NULL

        check = ro.DataFrame({'a':ro.IntVector(range(1,100)), 'b':ro.IntVector(range(101,200))})
        
        self.assertEqual(check.r_repr(), obj.r_repr())
