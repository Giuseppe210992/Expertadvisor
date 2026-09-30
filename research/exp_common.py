import os, sys, numpy as np, pandas as pd
from multiprocessing import Pool
from dataclasses import replace
from engine import run, stats, P
from instruments import INSTR

SYMS = list(INSTR.keys())

def _job(args):
    sym, p, label = args
    r = run(sym, p, keep_trades=True)
    s = stats(r, label)
    s["sym"] = sym
    return s

def batch(jobs, procs=None):
    with Pool(procs or os.cpu_count()) as pool:
        return pd.DataFrame(pool.map(_job, jobs))

def fmt(df, cols):
    return df[cols].to_string(float_format=lambda x: f"{x:,.4f}")
