"""Grafici del report (PNG statici, palette di riferimento dataviz: slot 1-3)."""
import json, pandas as pd, numpy as np, matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

C = {"CORE_ONLY": "#2a78d6", "ORIGINALE": "#eb6834", "PROPOSTA": "#1baf7a", "HARVEST": "#4a3aa7"}
NAME = {"CORE_ONLY": "Solo principale", "ORIGINALE": "Idea originale (overlay H4, hedge)",
        "PROPOSTA": "Variante B (overlay D1, netting)", "HARVEST": "Variante C (B + TP giornaliero 0,5 ATR)"}
INK, INK2, GRID, SURF = "#0b0b0b", "#52514e", "#e6e5e0", "#fcfcfb"
plt.rcParams.update({"font.size": 10, "axes.edgecolor": GRID, "axes.labelcolor": INK2, "xtick.color": INK2, "ytick.color": INK2,
                     "axes.grid": True, "grid.color": GRID, "grid.linewidth": 0.8, "axes.spines.top": False, "axes.spines.right": False,
                     "figure.facecolor": SURF, "axes.facecolor": SURF, "savefig.facecolor": SURF})
OUT = "../docs/img/"

# 1. curve di equity
fig, ax = plt.subplots(figsize=(10, 5.0))
for k in ["CORE_ONLY", "ORIGINALE", "PROPOSTA", "HARVEST"]:
    e = pd.read_csv(f"results/equity_{k}.csv", index_col=0, parse_dates=True).iloc[:, 0]
    r = (e / e.iloc[0] - 1) * 100
    ax.plot(r.index, r.values, color=C[k], lw=2, label=NAME[k])
    ax.annotate(f"{NAME[k]}  {r.iloc[-1]:+.1f}%", (r.index[-1], r.iloc[-1]), xytext=(6, 0), textcoords="offset points",
                va="center", fontsize=9, color=INK)
ax.axhline(0, color=INK2, lw=0.8)
ax.set_ylabel("Rendimento cumulato netto (%)")
ax.set_title("Portafoglio 12 strumenti, 2005-2020, rischio 1% per sleeve, tutti i costi inclusi", loc="left", color=INK, fontsize=11)
ax.legend(loc="upper center", bbox_to_anchor=(0.45, -0.1), ncol=2, frameon=False, fontsize=9)
ax.set_xlim(right=ax.get_xlim()[1] + 2600)
fig.tight_layout(); fig.savefig(OUT + "equity_varianti.png", dpi=130); plt.close(fig)

# 2. scomposizione lordo / costi / netto
s = json.load(open("results/summary.json"))
s["HARVEST"] = json.load(open("results/summary_harvest.json"))
cats = ["Lordo principale", "Lordo overlay", "Costi esecuzione", "Swap", "Netto totale"]
fig, ax = plt.subplots(figsize=(9, 5.0))
y = np.arange(len(cats)); h = 0.27
for j, k in enumerate(["ORIGINALE", "PROPOSTA", "HARVEST"]):
    d = s[k]
    vals = [d["gross_core"], d["gross_ov"], -(d["exec_core"] + d["exec_ov"]), d["swap_core"] + d["swap_ov"],
            d["net_core"] + d["net_ov"]]
    yy = y + (j - 1) * h
    ax.barh(yy, vals, height=h - 0.04, color=C[k], label=NAME[k])
    for yi, v in zip(yy, vals):
        ax.annotate(f"{v/1000:+.1f}k", (v, yi), xytext=(4 if v >= 0 else -4, 0), textcoords="offset points",
                    ha="left" if v >= 0 else "right", va="center", fontsize=8.5, color=INK)
ax.set_yticks(y); ax.set_yticklabels(cats); ax.invert_yaxis()
ax.axvline(0, color=INK2, lw=0.8)
ax.set_xlabel("USD su capitale 1,2M (15 anni)")
ax.set_title("Da dove viene (e dove va) il profitto", loc="left", color=INK, fontsize=11)
ax.legend(loc="upper center", bbox_to_anchor=(0.45, -0.13), ncol=2, frameon=False, fontsize=9)
ax.set_xlim(-34000, 60000)
fig.tight_layout(); fig.savefig(OUT + "scomposizione_pnl.png", dpi=130); plt.close(fig)

# 3. rischio vs rendimento
fig, ax = plt.subplots(figsize=(8.5, 4.4))
rk = pd.read_csv("results/risk_levels.csv", index_col=0)
rh = pd.read_csv("results/risk_levels_harvest.csv").set_index("risk_sleeve")
for df_, k in [(rk, "PROPOSTA"), (rh, "HARVEST")]:
    ax.plot(df_["max_dd"] * 100, df_["cagr"] * 100, color=C[k], lw=2, marker="o", ms=8, markeredgecolor=SURF,
            markeredgewidth=2, label=NAME[k])
    for r_, row in df_.iterrows():
        off, ha = ((-9, 3), "right") if k == "HARVEST" else ((0, -16), "center")
        ax.annotate(f"{r_:.0%}", (row.max_dd * 100, row.cagr * 100), xytext=off, ha=ha,
                    textcoords="offset points", fontsize=8.5, color=INK)
ax.text(0.99, 0.98, "etichette = rischio per trade per sleeve\n(1/12 sul capitale totale)", transform=ax.transAxes,
        ha="right", va="top", fontsize=8.5, color=INK2)
ax.axhline(0, color=INK2, lw=0.8)
ax.set_xlabel("Drawdown massimo (%)"); ax.set_ylabel("CAGR netto (%)"); ax.set_ylim(-8, 11)
ax.set_title("Rischio e rendimento: il 10% al giorno non e' nemmeno nel grafico", loc="left", color=INK, fontsize=11)
ax.legend(loc="center right", bbox_to_anchor=(1.0, 0.62), frameon=False, fontsize=9)
fig.tight_layout(); fig.savefig(OUT + "rischio_rendimento.png", dpi=130); plt.close(fig)

# 4. stress costi
sd = pd.read_csv("results/stress_costs.csv", header=[0, 1], index_col=0)
net = sd["net_pct"] * 100
order = ["zero costi (solo lordo)", "base", "commissioni x2", "slippage x3", "spread x2", "spread x3", "swap x2",
         "carry avverso +2%", "tutto peggiorato"]
net = net.loc[order]
net["HARVEST"] = pd.read_csv("results/stress_costs_harvest.csv", index_col=0)["net_pct"].reindex(order).values * 100
fig, ax = plt.subplots(figsize=(9, 5.4))
y = np.arange(len(order)); h = 0.2
for j, k in enumerate(["CORE_ONLY", "ORIGINALE", "PROPOSTA", "HARVEST"]):
    ax.barh(y + (j - 1.5) * h, net[k].values, height=h - 0.03, color=C[k], label=NAME[k])
ax.set_yticks(y); ax.set_yticklabels(order); ax.invert_yaxis()
ax.axvline(0, color=INK2, lw=0.8)
ax.set_xlabel("Rendimento netto cumulato 2005-2020 (%)")
ax.set_title("Sensibilita' ai costi: il segno del risultato dipende dai costi", loc="left", color=INK, fontsize=11)
ax.legend(loc="upper center", bbox_to_anchor=(0.4, -0.1), ncol=2, frameon=False, fontsize=9)
fig.tight_layout(); fig.savefig(OUT + "stress_costi.png", dpi=130); plt.close(fig)
print("ok")
