readings = [
    {"date": "2026-08-01", "kvah": 148.40, "kwh": 120.70, "mf": 5},
    {"date": "2026-08-02", "kvah": 148.40, "kwh": 125.00, "mf": 5},
    {"date": "2026-08-03", "kvah": 129.60, "kwh": 152.10, "mf": 5},
    {"date": "2026-08-04", "kvah": 108.40, "kwh": 107.70, "mf": 5},
    {"date": "2026-08-06", "kvah": 167.50, "kwh": 166.50, "mf": 5},
    {"date": "2026-08-07", "kvah": 137.70, "kwh": 137.10, "mf": 5},
    {"date": "2026-08-08", "kvah": 134.40, "kwh": 131.50, "mf": 5},
    {"date": "2026-08-09", "kvah": 127.50, "kwh": 126.30, "mf": 5},
    {"date": "2026-08-10", "kvah": 131.10, "kwh": 130.70, "mf": 5},
    {"date": "2026-08-11", "kvah": 109.70, "kwh": 98.60, "mf": 5},
    {"date": "2026-08-13", "kvah": 188.40, "kwh": 167.00, "mf": 5},
    {"date": "2026-08-14", "kvah": 122.50, "kwh": 142.90, "mf": 5},
    {"date": "2026-08-16", "kvah": 119.60, "kwh": 117.00, "mf": 5},
    {"date": "2026-08-17", "kvah": 95.60, "kwh": 94.60, "mf": 5},
    {"date": "2026-08-18", "kvah": 95.90, "kwh": 95.00, "mf": 5},
    {"date": "2026-08-20", "kvah": 143.20, "kwh": 118.60, "mf": 5},
    {"date": "2026-08-21", "kvah": 139.20, "kwh": 162.50, "mf": 5},
]

# Single-reading zone profile (GKH June bill derived)
zone_profile = {"A": 0.0847, "B": 0.0423, "C": 0.7072, "D": 0.1655}

# ACTUAL preset: HT-I FY26-27 defaults
# todZoneShares = {'A': 0.0, 'B': 0.0, 'C': -0.15, 'D': 0.25}
# These are ADJUSTMENTS to the base rate, not multipliers
zone_shares = {"A": 0.0, "B": 0.0, "C": -0.15, "D": 0.25}
rate = 8.68  # HT-I FY26-27 energy rate

shift_zones = [
    [("B", 1.0), ("C", 5/8)],
    [("C", 3/8), ("D", 5/7)],
    [("D", 2/7), ("A", 1.0)],
]
shift_names = ["Day   (06-14)", "Evening (14-22)", "Night (22-06)"]

print("=" * 80)
print("  GKH AUGUST 2026 - Net ToD vs Total ToD (CORRECT rates)")
print("  HT-I FY26-27: energy_rate=8.68, shares: A=0, B=0, C=-0.15, D=+0.25")
print("=" * 80)
print()
print(f"  {'Date':<12} {'kVAh':>6} {'MF':>3} {'Units':>6}  {'Net ToD':>10}  {'Shift ToD':>10}  {'diff':>8}")
print("  " + "-" * 70)

grand_zone_units = {"A": 0.0, "B": 0.0, "C": 0.0, "D": 0.0}
grand_net_tod = 0.0
grand_shift_tod = 0.0

for r in readings:
    units = r["kvah"] * r["mf"]

    zu = {z: units * zone_profile[z] for z in "ABCD"}
    for z in "ABCD":
        grand_zone_units[z] += zu[z]

    net_tod = sum(zu[z] * zone_shares[z] * rate for z in "ABCD")
    grand_net_tod += net_tod

    shift_tod = 0.0
    for shift_idx, zones in enumerate(shift_zones):
        for z_name, frac in zones:
            shift_tod += zu[z_name] * frac * zone_shares[z_name] * rate
    grand_shift_tod += shift_tod

    diff = abs(net_tod - shift_tod)
    print(f"  {r['date']:<12} {r['kvah']:>6.1f} {r['mf']:>3} {int(units):>6}  {net_tod:>10.2f}  {shift_tod:>10.2f}  {diff:>8.6f}")

print()
print("=" * 80)
print("  GRAND TOTALS")
print("=" * 80)
print()
total_units = sum(r["kvah"] * r["mf"] for r in readings)
print(f"  Total billing units: {total_units:.0f} kVAh")
print(f"  Days: {len(readings)}")
print()
print("  Accumulated Zone Units:")
for z in "ABCD":
    contrib = grand_zone_units[z] * zone_shares[z] * rate
    print(f"    Zone {z}: {grand_zone_units[z]:>8.2f} units  share={zone_shares[z]:>+.2f}  "
          f"charge = {contrib:>10.2f}")
print()
print("  METHOD 1 -- Net ToD (Zone Table):")
net_sum = 0
for z in "ABCD":
    c = grand_zone_units[z] * zone_shares[z] * rate
    net_sum += c
    print(f"    {grand_zone_units[z]:>8.2f} x ({zone_shares[z]:>+.2f}) x {rate} = {c:>10.2f}")
print(f"    {'='*40}")
print(f"    Net ToD = {grand_net_tod:>10.2f}")
print()
print("  METHOD 2 -- Total ToD (Shift Summary):")
for si, (name, zones) in enumerate(zip(shift_names, shift_zones)):
    amt = 0.0
    parts = []
    for z_name, frac in zones:
        contrib = grand_zone_units[z_name] * frac * zone_shares[z_name] * rate
        amt += contrib
        parts.append(f"{z_name}*{frac:.4f}")
    print(f"    {name}: {', '.join(parts)} = {amt:>10.2f}")
print(f"    {'='*40}")
print(f"    Total ToD = {grand_shift_tod:>10.2f}")
print()
diff = abs(grand_net_tod - grand_shift_tod)
print(f"  DIFFERENCE = {diff:.6f}")
print()

if diff < 0.01:
    print("  [PROVED] Net ToD == Total ToD  (difference = 0)")
else:
    print(f"  [BUG] Net ToD != Total ToD  (diff = {diff})")

print()
print("  WHY (math proof):")
print("    Day shift:   B * 1.0 + C * 5/8")
print("    Eve shift:   C * 3/8 + D * 5/7")
print("    Night shift: D * 2/7 + A * 1.0")
print("    -------------------------------------------")
print("    Total = A*1.0 + B*1.0 + C*(5/8+3/8) + D*(5/7+2/7)")
print("          = A*1.0 + B*1.0 + C*1.0 + D*1.0  = Net ToD")
print("=" * 80)
