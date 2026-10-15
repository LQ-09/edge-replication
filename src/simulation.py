"""Reuse the verified R simulation; do not substitute a new Python DGP."""
import argparse
import subprocess
from .common import ROOT

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--rscript',default='Rscript')
    parser.add_argument('--check-only',action='store_true')
    args=parser.parse_args()
    command=[args.rscript,'run_simulation.R']
    if args.check_only:command.append('--check-only')
    subprocess.run(command,cwd=ROOT,check=True)
