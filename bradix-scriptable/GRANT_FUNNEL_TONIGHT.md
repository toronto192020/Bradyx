# BRADIX Grant Funnel — Tonight's Execution Plan

## EXEC VIEW
- **Radium Capital R&D Advance**: Apply NOW — get your R&D tax refund early (before EOFY June 30)
- **QLD Innovation Economy Fund**: Applications close 25 June 2026 — apply this week
- **R&D Tax Incentive**: 2026 Budget increased offset by 4.5% — Bruder Technologies qualifies
- **Corporate Card**: Airwallex (AU-native) or Weel — API-connected, spending controls, $0 to start
- **GrantConnect.gov.au**: Live list of all open federal grants — filter tonight

---

## GRANT 1: Radium Capital R&D Advance (PRIORITY — DO TONIGHT)

**What**: Get your expected R&D Tax Incentive refund EARLY — before EOFY.  
**Who**: Radium Capital (Australian fintech, purpose-built for this)  
**How much**: Up to 80% of your expected R&DTI refund, advanced now  
**Eligibility**: You've done R&D (AI automation, BRADIX, home automation, aging-in-place tech)  
**Timeline**: Apply now → funds in 2-4 weeks  
**Cost**: Fee deducted from the advance (typically 10-15%)  

### Action Steps:
1. Go to: https://www.radiumcapital.com.au
2. Click "Apply" or "Get a Quote"
3. You need:
   - ABN: Bruder Technologies And Solutions Pty Ltd
   - Description of R&D activities (AI agents, home automation, voice control, care tech)
   - Estimated R&D spend for FY25/26
   - Your accountant's details (or self-lodge)
4. They'll assess and offer an advance amount

### R&D Activities That Qualify (your stack):
- BRADIX AI automation system (novel software development)
- Voice-controlled care monitoring (experimental development)
- Aging-in-place technology integration (Home Assistant + AI)
- OBD vehicle diagnostics automation (experimental)
- Multi-agent orchestration system (novel architecture)
- Edge AI deployment on Jetson (experimental hardware/software)

---

## GRANT 2: QLD Innovation Economy Fund

**What**: Funding for innovation support hubs  
**Closes**: 25 June 2026  
**URL**: https://advance.qld.gov.au/grants-and-programs/innovation-economy-fund  
**Relevance**: BRADIX as an innovation platform for aging-in-place / smart home / AI  

---

## GRANT 3: QLD Export Ready Grants

**What**: Up to $25,000 for export-ready Queensland businesses  
**Status**: Open — closing soon  
**URL**: Check business.qld.gov.au/running-business/support-services/financial/grants/schedule  
**Relevance**: BRADIX as exportable SaaS/consulting for smart home + aged care  

---

## GRANT 4: R&D Tax Incentive (Annual — Lodge by Oct 2026)

**What**: Refundable tax offset — 43.5 cents per dollar of eligible R&D spend  
**Who**: Companies under $20M turnover (you qualify easily)  
**2026 Budget Change**: +4.5% offset for core R&D activities (from July 2028, but current rates still excellent)  
**Current Rate**: 18.5% refundable offset above company tax rate = 43.5% total  
**Deadline**: Register activities with AusIndustry within 10 months of EOFY  

### Your Eligible R&D Spend:
- Hardware (Jetson, NUC, Pi, sensors): claim as R&D assets
- Software development time: your hours on BRADIX
- Cloud services used for R&D: any subscriptions
- Contractor costs: if you paid anyone to help

---

## GRANT 5: GrantConnect — Full Federal List

**URL**: https://www.grants.gov.au/go/list  
**Action**: Filter by: Technology, Innovation, Small Business, Queensland  
**Check tonight**: Sort by closing date, grab anything closing in next 30 days  

---

## CORPORATE CARD SETUP — MONEY IN, CONTROLLED OUT

### Recommended: Airwallex (AU-native, API, corporate cards)

**Why Airwallex**:
- Australian company, AU bank account
- Virtual + physical corporate cards
- Set spending limits per card
- Multi-currency (good for any international grants/payments)
- Full REST API — connects to BRADIX/n8n
- Xero integration for bookkeeping
- No personal credit check required

**Sign up**: https://www.airwallex.com/au  
**What you need**: ABN, director ID, business details  

### Alternative: Weel (formerly DiviPay)

**Why Weel**:
- Australian-built, 4000+ AU businesses
- AI-powered expense management
- Open API (RESTful — budgets, users, transactions)
- iPhone app for instant card management
- Smart receipt matching

**Sign up**: https://letsweel.com  
**App**: Already on App Store  

### The Flow:
```
Grant money arrives → Airwallex/Weel account
                    → Issue cards with limits
                    → R&D spend tracked automatically
                    → Remaining balance protected
                    → API feeds into BRADIX dashboard
                    → End of year: R&D claim is pre-documented
```

---

## TONIGHT'S 30-MINUTE SPRINT

| # | Action | Time | Link |
|---|--------|------|------|
| 1 | Radium Capital — start R&D advance application | 10 min | radiumcapital.com.au |
| 2 | GrantConnect — filter and bookmark open grants | 10 min | grants.gov.au/go/list |
| 3 | Airwallex OR Weel — sign up for corporate card | 10 min | airwallex.com/au or letsweel.com |

---

## SCRIPTABLE MODULE — FINANCIAL TRACKING

Add this to your BRADIX_Master_Automation.js CONFIG:

```javascript
// 8. Financial / Corporate Card
financial: {
  airwallex: {
    baseUrl: "https://api.airwallex.com/api/v1",
    apiKey: "YOUR_AIRWALLEX_API_KEY",
    clientId: "YOUR_CLIENT_ID"
  },
  // OR
  weel: {
    baseUrl: "https://api.letsweel.com/v1",
    apiKey: "YOUR_WEEL_API_KEY"
  }
}
```

New functions to add:
```javascript
async function checkBalance() {
  // Airwallex
  const url = `${CONFIG.financial.airwallex.baseUrl}/balances/current`;
  const result = await sendRequest(url, "GET", {
    "Authorization": `Bearer ${CONFIG.financial.airwallex.apiKey}`
  });
  if (result) {
    await notifyTelegram(`💰 *Balance:* $${result.available_amount} AUD`);
  }
  return result;
}

async function getRecentTransactions() {
  const url = `${CONFIG.financial.airwallex.baseUrl}/transactions?page_size=5`;
  const result = await sendRequest(url, "GET", {
    "Authorization": `Bearer ${CONFIG.financial.airwallex.apiKey}`
  });
  if (result && result.items) {
    let msg = "📊 *Recent Transactions:*\n";
    result.items.forEach(t => {
      msg += `• ${t.description}: $${t.amount}\n`;
    });
    await notifyTelegram(msg);
  }
  return result;
}
```

---

## TOTAL POTENTIAL INCOMING

| Source | Amount | Timeline |
|--------|--------|----------|
| Radium R&D Advance | $5,000-$20,000+ | 2-4 weeks |
| QLD Innovation Fund | Up to $50,000 | Application-dependent |
| QLD Export Grant | Up to $25,000 | Application-dependent |
| R&D Tax Incentive (annual) | 43.5% of eligible spend | After EOFY lodge |
| BlueCare surplus (Mum's care) | $18,000 | Sign agreement |
| SPER recovery (over-seizure) | $15,000+ | After nominations |
| AFCA/Hollard | $5,000+ | 30-90 days |
| **TOTAL POTENTIAL** | **$100,000+** | **Next 3-6 months** |

---

## KEY DEADLINES

| What | When |
|------|------|
| EOFY (R&D spend must be this FY) | 30 June 2026 |
| QLD Innovation Economy Fund | 25 June 2026 |
| Radium Capital advance (before EOFY) | Apply NOW |
| AusIndustry R&D registration | Within 10 months of EOFY |
| SPER nominations (stop warrant growth) | ASAP |

---

*Generated by BRADIX Systems — June 12, 2026*
