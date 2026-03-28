#!/usr/bin/env python3
"""
BRADIX OBD AUTO-SOLVE AGENT
============================
Connects to your AIOBD Bluetooth adapter, reads all fault codes and live sensor data,
interprets them using a local knowledge base, and generates a plain-English fix report.

SETUP:
  pip3 install obd openai requests
  
USAGE:
  python3 OBD_AUTO_SOLVE.py                    # Auto-connect via Bluetooth
  python3 OBD_AUTO_SOLVE.py --port /dev/rfcomm0  # Specify port manually
  python3 OBD_AUTO_SOLVE.py --demo              # Run with demo codes (no car needed)

OUTPUT:
  - Prints plain-English diagnosis to terminal
  - Saves report to ~/bradix_documents/OBD_REPORT_<timestamp>.md
  - Optionally pushes to BRADIX dashboard at bradix.systems
"""

import obd
import json
import os
import sys
import argparse
from datetime import datetime
from openai import OpenAI

# ─── CONFIG ────────────────────────────────────────────────────────────────────
VEHICLE = "Hyundai ix35"
REPORT_DIR = os.path.expanduser("~/bradix_documents")
DASHBOARD_URL = "http://localhost:8080/api/obd-report"  # BRADIX API endpoint

# ─── LOCAL OBD CODE DATABASE ───────────────────────────────────────────────────
# Covers the most common codes for Hyundai ix35 and general vehicles
OBD_CODE_DB = {
    "P0420": {
        "name": "Catalytic Converter Efficiency Below Threshold (Bank 1)",
        "severity": "HIGH",
        "symptom": "Muffled exhaust sound, loss of power, poor acceleration",
        "cause": "Blocked or failed catalytic converter. Very common on ix35.",
        "fix": "1. Check exhaust flow at tailpipe (should feel strong). 2. Replace catalytic converter. 3. Check for oil burning first (blue smoke) as this kills cats.",
        "cost_est": "$400-$900 AUS (aftermarket cat)",
        "parts": "Search Supercheap Auto or Repco for 'Hyundai ix35 catalytic converter'"
    },
    "P0300": {
        "name": "Random/Multiple Cylinder Misfire Detected",
        "severity": "HIGH",
        "symptom": "Rough idle, shaking, loss of power, bad fuel feeling",
        "cause": "Multiple cylinders misfiring. Could be plugs, coils, fuel, or compression.",
        "fix": "1. Replace all spark plugs (NGK recommended for ix35). 2. Check ignition coils with multimeter. 3. Check fuel pressure.",
        "cost_est": "$80-$200 AUS (plugs + coils)",
        "parts": "NGK BKR6E-11 spark plugs for ix35 2.0L"
    },
    "P0301": {"name": "Cylinder 1 Misfire", "severity": "HIGH", "symptom": "Rough idle, shaking", "cause": "Cylinder 1 specific misfire — plug, coil, or injector", "fix": "Swap coil from cylinder 1 to another. If misfire moves, replace coil. If not, replace plug then check injector.", "cost_est": "$50-$150 AUS", "parts": "Ignition coil for Hyundai ix35"},
    "P0302": {"name": "Cylinder 2 Misfire", "severity": "HIGH", "symptom": "Rough idle", "cause": "Cylinder 2 specific misfire", "fix": "Same as P0301 but cylinder 2", "cost_est": "$50-$150 AUS", "parts": "Ignition coil for Hyundai ix35"},
    "P0303": {"name": "Cylinder 3 Misfire", "severity": "HIGH", "symptom": "Rough idle", "cause": "Cylinder 3 specific misfire", "fix": "Same as P0301 but cylinder 3", "cost_est": "$50-$150 AUS", "parts": "Ignition coil for Hyundai ix35"},
    "P0304": {"name": "Cylinder 4 Misfire", "severity": "HIGH", "symptom": "Rough idle", "cause": "Cylinder 4 specific misfire", "fix": "Same as P0301 but cylinder 4", "cost_est": "$50-$150 AUS", "parts": "Ignition coil for Hyundai ix35"},
    "P0171": {
        "name": "System Too Lean (Bank 1)",
        "severity": "MEDIUM",
        "symptom": "Hesitation, poor fuel economy, rough idle",
        "cause": "Too much air or not enough fuel. Common causes: vacuum leak, dirty MAF sensor, weak fuel pump.",
        "fix": "1. Clean MAF sensor with MAF cleaner spray ($15). 2. Check all vacuum hoses for cracks. 3. Check fuel pressure.",
        "cost_est": "$15-$300 AUS depending on cause",
        "parts": "CRC MAF sensor cleaner from Supercheap"
    },
    "P0172": {
        "name": "System Too Rich (Bank 1)",
        "severity": "MEDIUM",
        "symptom": "Black smoke, poor fuel economy, strong fuel smell",
        "cause": "Too much fuel. Leaking injector, faulty O2 sensor, or coolant temp sensor.",
        "fix": "1. Check for fuel smell in oil (dipstick). 2. Inspect injectors. 3. Replace O2 sensor if old.",
        "cost_est": "$50-$400 AUS",
        "parts": "Bosch O2 sensor for Hyundai ix35"
    },
    "P0130": {"name": "O2 Sensor Circuit Malfunction (Bank 1, Sensor 1)", "severity": "MEDIUM", "symptom": "Poor fuel economy, rough running", "cause": "Upstream O2 sensor failing or wiring issue", "fix": "Replace upstream O2 sensor. Check wiring harness for damage.", "cost_est": "$80-$200 AUS", "parts": "Bosch upstream O2 sensor ix35"},
    "P0340": {"name": "Camshaft Position Sensor Circuit Malfunction", "severity": "HIGH", "symptom": "Engine won't start or stalls, rough running", "cause": "Camshaft position sensor failing — common on ix35 2.0L", "fix": "Replace camshaft position sensor. Located on top of engine near cam.", "cost_est": "$50-$150 AUS", "parts": "Hyundai ix35 camshaft position sensor"},
    "P0011": {"name": "Camshaft Position Timing Over-Advanced (Bank 1)", "severity": "HIGH", "symptom": "Rough idle, poor performance, rattling", "cause": "VVT (variable valve timing) issue. Often low oil or dirty oil.", "fix": "1. Change oil immediately (use 5W-30 full synthetic). 2. If persists, check VVT solenoid.", "cost_est": "$50-$300 AUS", "parts": "VVT solenoid Hyundai ix35"},
    "P0455": {"name": "EVAP System Large Leak", "severity": "LOW", "symptom": "Fuel smell, check engine light", "cause": "Loose or cracked fuel cap most common cause", "fix": "1. Tighten or replace fuel cap first ($15). 2. If persists, check EVAP hoses.", "cost_est": "$15-$200 AUS", "parts": "Hyundai ix35 fuel cap"},
    "P0505": {"name": "Idle Control System Malfunction", "severity": "MEDIUM", "symptom": "Rough or unstable idle, stalling", "cause": "Dirty or failed idle air control valve or throttle body", "fix": "1. Clean throttle body with throttle body cleaner spray. 2. Replace IAC valve if cleaning doesn't help.", "cost_est": "$20-$200 AUS", "parts": "Throttle body cleaner + Hyundai ix35 IAC valve"},
}

# ─── LIVE DATA COMMANDS TO READ ────────────────────────────────────────────────
LIVE_DATA_COMMANDS = [
    obd.commands.RPM,
    obd.commands.SPEED,
    obd.commands.COOLANT_TEMP,
    obd.commands.FUEL_PRESSURE,
    obd.commands.SHORT_TERM_FUEL_TRIM_1,
    obd.commands.LONG_TERM_FUEL_TRIM_1,
    obd.commands.INTAKE_TEMP,
    obd.commands.MAF,
    obd.commands.THROTTLE_POS,
    obd.commands.O2_B1S1,
    obd.commands.O2_B1S2,
    obd.commands.ENGINE_LOAD,
]

# ─── DEMO CODES (for testing without a car) ───────────────────────────────────
DEMO_CODES = ["P0420", "P0300", "P0171"]
DEMO_LIVE_DATA = {
    "RPM": "850 rpm (low — should be ~750-900 at idle)",
    "COOLANT_TEMP": "88°C (normal)",
    "LONG_TERM_FUEL_TRIM_1": "+22% (HIGH — engine compensating for lean condition)",
    "SHORT_TERM_FUEL_TRIM_1": "+15% (elevated)",
    "ENGINE_LOAD": "45% at idle (HIGH — should be ~20-25%)",
    "THROTTLE_POS": "12% (normal at idle)",
}


def connect_obd(port=None):
    """Connect to OBD adapter"""
    print("🔌 Connecting to AIOBD adapter...")
    if port:
        connection = obd.OBD(port)
    else:
        connection = obd.OBD()  # Auto-detect
    
    if connection.is_connected():
        print(f"✅ Connected via {connection.port_name()}")
        return connection
    else:
        print("❌ Could not connect. Try: python3 OBD_AUTO_SOLVE.py --port /dev/rfcomm0")
        print("   Or pair AIOBD via Bluetooth first: bluetoothctl -> pair -> connect")
        return None


def read_fault_codes(connection):
    """Read all diagnostic trouble codes"""
    print("\n🔍 Reading fault codes...")
    response = connection.query(obd.commands.GET_DTC)
    if response.is_null():
        print("   No codes found or command not supported")
        return []
    codes = [str(code[0]) for code in response.value]
    print(f"   Found {len(codes)} code(s): {', '.join(codes) if codes else 'NONE'}")
    return codes


def read_live_data(connection):
    """Read live sensor data"""
    print("\n📊 Reading live sensor data...")
    live = {}
    for cmd in LIVE_DATA_COMMANDS:
        try:
            response = connection.query(cmd)
            if not response.is_null():
                live[cmd.name] = str(response.value)
                print(f"   {cmd.name}: {response.value}")
        except Exception:
            pass
    return live


def interpret_codes_local(codes):
    """Interpret codes using local database"""
    results = []
    for code in codes:
        if code in OBD_CODE_DB:
            results.append({"code": code, **OBD_CODE_DB[code]})
        else:
            results.append({
                "code": code,
                "name": "Unknown code",
                "severity": "UNKNOWN",
                "symptom": "Unknown",
                "cause": "Not in local database — search: https://www.obd-codes.com/" + code,
                "fix": "Run a Google search for: " + code + " Hyundai ix35",
                "cost_est": "Unknown",
                "parts": "Unknown"
            })
    return results


def interpret_with_ai(codes, live_data, vehicle):
    """Use AI to generate enhanced diagnosis"""
    try:
        client = OpenAI()
        
        codes_str = json.dumps(codes, indent=2)
        live_str = json.dumps(live_data, indent=2)
        
        prompt = f"""You are an expert automotive diagnostic AI specialising in Hyundai vehicles in Australia.

Vehicle: {vehicle}
Fault Codes Found: {codes_str}
Live Sensor Data: {live_str}

The owner describes symptoms: engine sounds "underwater" (muffled/gurgling), behaves like "bad fuel" (misfiring, loss of power, poor acceleration).

Please provide:
1. MOST LIKELY ROOT CAUSE (single primary diagnosis)
2. PRIORITY ORDER for fixes (what to do first)
3. IMMEDIATE SAFETY ASSESSMENT (is it safe to drive?)
4. ESTIMATED TOTAL REPAIR COST in Australian dollars
5. DIY vs MECHANIC recommendation for each fix
6. Any patterns in the codes that point to a single underlying cause

Be direct, practical, and specific to Australian conditions and parts availability."""

        response = client.chat.completions.create(
            model="gpt-4.1-mini",
            messages=[{"role": "user", "content": prompt}],
            max_tokens=1000
        )
        return response.choices[0].message.content
    except Exception as e:
        return f"AI analysis unavailable: {e}\nUsing local database only."


def generate_report(codes, interpreted, live_data, ai_analysis, vehicle):
    """Generate the full diagnostic report"""
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M")
    filename = f"OBD_REPORT_{datetime.now().strftime('%Y%m%d_%H%M%S')}.md"
    filepath = os.path.join(REPORT_DIR, filename)
    
    # Determine overall severity
    severities = [r.get("severity", "UNKNOWN") for r in interpreted]
    if "HIGH" in severities:
        overall = "🔴 HIGH — Do not drive until inspected"
    elif "MEDIUM" in severities:
        overall = "🟡 MEDIUM — Drive with caution, fix soon"
    else:
        overall = "🟢 LOW — Monitor, fix when convenient"
    
    report = f"""# BRADIX OBD DIAGNOSTIC REPORT
**Vehicle:** {vehicle}  
**Date:** {timestamp}  
**Overall Status:** {overall}

---

## FAULT CODES FOUND: {len(codes)}

"""
    for r in interpreted:
        severity_icon = {"HIGH": "🔴", "MEDIUM": "🟡", "LOW": "🟢"}.get(r.get("severity"), "⚪")
        report += f"""### {severity_icon} {r['code']} — {r['name']}
- **Severity:** {r.get('severity', 'UNKNOWN')}
- **Symptom:** {r.get('symptom', 'N/A')}
- **Likely Cause:** {r.get('cause', 'N/A')}
- **Fix:** {r.get('fix', 'N/A')}
- **Estimated Cost:** {r.get('cost_est', 'N/A')}
- **Parts to Search:** {r.get('parts', 'N/A')}

"""
    
    report += f"""---

## LIVE SENSOR DATA

"""
    for key, val in live_data.items():
        report += f"- **{key}:** {val}\n"
    
    report += f"""
---

## AI ANALYSIS

{ai_analysis}

---

## IMMEDIATE ACTIONS

1. **Do NOT drive** if P0420 (catalytic converter) or P030X (misfires) are present until inspected
2. **Scan with AIOBD** before each drive to monitor if codes return after clearing
3. **Clear codes** after fixing each issue and retest: `python3 OBD_AUTO_SOLVE.py --clear`
4. **Call Supercheap Auto** (13 11 14) or Repco (13 13 32) for parts

---

## RESOURCES

- OBD Code Lookup: https://www.obd-codes.com/
- Hyundai ix35 Forum: https://www.hyundaiforums.com/
- Supercheap Auto: https://www.supercheapauto.com.au/
- Repco: https://www.repco.com.au/

*Generated by BRADIX OBD Auto-Solve Agent*
"""
    
    os.makedirs(REPORT_DIR, exist_ok=True)
    with open(filepath, "w") as f:
        f.write(report)
    
    return report, filepath


def push_to_dashboard(report_path):
    """Push report to BRADIX dashboard"""
    try:
        import requests
        with open(report_path) as f:
            content = f.read()
        requests.post(DASHBOARD_URL, json={"report": content}, timeout=5)
        print(f"✅ Report pushed to BRADIX dashboard")
    except Exception:
        pass  # Dashboard may not be running yet


def main():
    parser = argparse.ArgumentParser(description="BRADIX OBD Auto-Solve Agent")
    parser.add_argument("--port", help="OBD port (e.g. /dev/rfcomm0)")
    parser.add_argument("--demo", action="store_true", help="Run with demo codes (no car needed)")
    parser.add_argument("--clear", action="store_true", help="Clear all fault codes after reading")
    args = parser.parse_args()
    
    print("=" * 60)
    print("  BRADIX OBD AUTO-SOLVE AGENT")
    print(f"  Vehicle: {VEHICLE}")
    print("=" * 60)
    
    if args.demo:
        print("\n🎮 DEMO MODE — Using sample codes for Hyundai ix35")
        codes = DEMO_CODES
        live_data = DEMO_LIVE_DATA
    else:
        connection = connect_obd(args.port)
        if not connection:
            print("\nTip: To pair AIOBD Bluetooth on Linux:")
            print("  bluetoothctl")
            print("  scan on")
            print("  pair XX:XX:XX:XX:XX:XX")
            print("  connect XX:XX:XX:XX:XX:XX")
            print("  trust XX:XX:XX:XX:XX:XX")
            print("  rfcomm bind /dev/rfcomm0 XX:XX:XX:XX:XX:XX")
            sys.exit(1)
        
        codes = read_fault_codes(connection)
        live_data = read_live_data(connection)
        
        if args.clear and codes:
            print("\n🗑️  Clearing fault codes...")
            connection.query(obd.commands.CLEAR_DTC)
            print("   Codes cleared.")
        
        connection.close()
    
    if not codes:
        print("\n✅ No fault codes found! Vehicle ECU is clean.")
        print("   If symptoms persist, check: fuel quality, air filter, spark plugs")
        return
    
    print(f"\n⚙️  Interpreting {len(codes)} code(s)...")
    interpreted = interpret_codes_local(codes)
    
    print("\n🤖 Running AI analysis...")
    ai_analysis = interpret_with_ai(codes, live_data, VEHICLE)
    
    print("\n📝 Generating report...")
    report, filepath = generate_report(codes, interpreted, live_data, ai_analysis, VEHICLE)
    
    print("\n" + "=" * 60)
    print(report)
    print("=" * 60)
    print(f"\n💾 Report saved to: {filepath}")
    
    push_to_dashboard(filepath)
    
    print("\n✅ Done. Open the report file for full details.")
    print(f"   cat '{filepath}'")


if __name__ == "__main__":
    main()
