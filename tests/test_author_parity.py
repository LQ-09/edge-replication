"""Signed author Python estimates must agree with frozen author R reference values."""
import unittest
from pathlib import Path
import pandas as pd
from vendor.python_bidask.edge import edge

class AuthorParity(unittest.TestCase):
    def test_positive_and_negative_signed_estimates(self):
        root=Path(__file__).parent/'fixtures/parity'
        references=pd.read_csv(root/'r_results.csv')
        self.assertTrue((references.signed>0).any() and (references.signed<0).any())
        for row in references.itertuples():
            x=pd.read_csv(root/row.file)
            self.assertAlmostEqual(edge(x.open,x.high,x.low,x.close,sign=True),row.signed,places=12)
