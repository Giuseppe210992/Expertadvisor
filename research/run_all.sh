#!/bin/sh
# Riesegue l'intera ricerca (dati gia' scaricati in research/data). ~35 minuti su 4 core.
set -e
cd "$(dirname "$0")"
python3 math_checks.py            > results/math_checks.txt
python3 exp1_decomposition.py     > results/exp1_decomposition.txt
python3 exp2_overlay_search.py    > results/exp2_overlay_search.txt
python3 exp3_asymmetry.py         > results/exp3_asymmetry.txt
python3 exp4_candidates.py        > results/exp4_candidates.txt
python3 exp5_final.py             > results/exp5_final.txt
python3 exp6_risk_sizing.py       > results/exp6_risk_sizing.txt
python3 exp7_futures_costs.py     > results/exp7_futures_costs.txt
python3 exp8_daily_target_check.py > results/exp8_daily_target_check.txt
python3 exp9_short_hold.py        > results/exp9_short_hold.txt
python3 exp10_harvest.py          > results/exp10_harvest.txt
python3 exp11_harvest_stress.py   > results/exp11_harvest_stress.txt
python3 exp12_double_50.py        > results/exp12_double_50.txt
python3 instrument_profile.py     > /dev/null
python3 make_charts.py
python3 cost_table.py             > /dev/null
python3 cost_table2.py            > /dev/null
echo "OK"
