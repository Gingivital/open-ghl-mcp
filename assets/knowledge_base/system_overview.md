# Multi Ultimate GHL Agent System — Knowledge Base
**Binary Frame: UP = Profits / DOWN = Loss**

---

## The Straight Path

```
LEAD IN
  ↓
[SCOUT]      Blue/Orange — First contact, binary ask, route or disqualify
  ↓ YES
[QUALIFIER]  Red/Green   — Score 3 criteria, UP = hot handoff, DOWN = nurture
  ↓ QUALIFIED
[CLOSER]     Blue/Orange — Book, confirm, close. No-show recovery built in.
  ↓ WON
[FULFILLMENT] Red/Green  — Auto-deliver, milestone tracking, referral ask
  ↓ ACTIVE
[OPTIMIZER]  Black/White — Daily metric scan, auto-rewrite, win-back sequences
  ↓
REPEAT (referral loop feeds back to Scout)
```

---

## Binary Rules — Always Active

| Signal | UP Action | DOWN Action |
|--------|-----------|-------------|
| Replied YES/READY | Advance pipeline stage | — |
| Replied NO/STOP | Close file respectfully | Tag: disqualified |
| No reply after 5 steps | Tag: cold_archive | Stop sequences |
| Qualified (3/3) | Transfer to Closer | — |
| Not qualified (0-1/3) | — | Long nurture |
| Booked | Pre-call sequence | — |
| No-show | Recovery sequence (3 attempts) | Close file after 3 |
| Closed Won | Fulfillment kickoff | — |
| Closed Lost | 90-day re-entry | — |
| Milestone 1 hit | Advance + referral ask | — |
| 7 days no activity | Win-back trigger | Archive after 5 days |

---

## Sequence Files
| File | Agent | Channel | Trigger |
|------|-------|---------|---------|
| `01_lead_scout_sms.json` | Scout | SMS | New lead |
| `02_lead_scout_email.json` | Scout | Email | New lead |
| `03_qualifier_sequence.json` | Qualifier | SMS + Email | Tag: awaiting_qualification |
| `04_closer_sequence.json` | Closer | SMS + Email | Tag: qualified_hot |
| `05_fulfillment_sequence.json` | Fulfillment | SMS + Email | Tag: closed_won |
| `06_optimizer_sequence.json` | Optimizer | SMS + Email + Internal | Daily + thresholds |

---

## Agent Prompt Files
| File | Contents |
|------|----------|
| `master_claude_coworker_prompt.md` | Master orchestrator system prompt |
| `all_five_agent_prompts.md` | All 5 agent prompts ready to paste into Agent Studio |

---

## Workflow Map
`workflow_map.json` — 6 core workflows + pipeline stages + master tag list

---

## Customization Variables (Replace Before Deploy)
| Placeholder | Replace With |
|-------------|-------------|
| `[OUTCOME]` | Your service outcome (e.g. "book more clients") |
| `[CORE PAIN POINT]` | Your market's #1 pain |
| `[BUDGET QUALIFIER]` | Your price point |
| `[TESTIMONIAL]` | Real client result |
| `[CLOSER NAME]` | Your closer's name |
| `[CALENDAR LINK]` | Your Calendly/GHL booking link |
| `[ZOOM LINK]` | Your meeting link |
| `[SNAPSHOT LINK]` | Your GHL snapshot URL |
| `[REFERRAL INCENTIVE]` | What you give for referrals |
| `[LOOM LINK]` | Your demo video link |
| `[TARGET CUSTOMER TYPE]` | Who you serve |
| `[DESIRED RESULT]` | What they want |
| `[PRICE POINT]` | Your offer price |

---

## MCP Integration — Live Control via Claude Code

With PIT token configured in `.env`, Claude Code can:
- Search and update contacts in real time
- Apply tags to trigger workflows programmatically
- Create opportunities and move pipeline stages
- Send messages directly from the MCP server
- Pull analytics to feed the Optimizer

**Run the system check:**
```bash
uv run pytest tests/test_pit_config.py -v
```

**Start MCP server:**
```bash
python -m src.main
```
