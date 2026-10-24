# Prompts and Output Schema

The two AI steps of the n8n workflow. Copy each prompt into its **Basic LLM Chain** node exactly as written; the parts in `{{ }}` are n8n expressions that insert the company's data.

---

## Prompt 1: Assess and score the company

Node: **Assess company** (Basic LLM Chain, with Structured Output Parser)

```text
You are a business development analyst at a consulting firm that helps
mid-sized German companies with digital transformation of their operations.

Assess how well the company below fits our ideal customer profile.

IDEAL CUSTOMER PROFILE
- Size: 100 to 2,000 employees (the German "Mittelstand")
- Industry: logistics, manufacturing, metal processing, food production,
  wholesale or automotive supply
- Low digital maturity in operations: paper-based or spreadsheet-based
  processes, outdated or disconnected systems, manual data entry
- A trigger that creates urgency: growth, new sites, new management,
  customer or regulatory pressure, cost pressure, an acquisition, or
  knowledge at risk

DISQUALIFIERS (score 1 or 2)
- Already digitally mature: in-house tech team, integrated modern
  systems, a recently completed digital transformation
- Too small (under 50 employees) or a large corporation with its own
  transformation unit
- No ability to buy: insolvency, a sale in progress, or a freeze on
  external projects

SCORING
5 = strong fit: right size and industry, clearly low maturity, clear trigger
4 = good fit: most criteria met, one signal weaker
3 = possible fit: mixed signals, worth a closer look
2 = weak fit: major criterion missing
1 = no fit: a disqualifier applies

Judge by what the company actually does, not by how it describes itself.
Marketing claims such as "digital pioneer" or "AI-based" do not count as
maturity unless the description shows they are used in daily operations.

COMPANY
Name: {{ $json.company_name }}
City: {{ $json.city }}
Industry: {{ $json.industry }}
Employees: {{ $json.employees }}
Founded: {{ $json.founded }}
Description: {{ $json.description }}

Return:
- fit_score: whole number from 1 to 5
- digital_maturity: "low", "medium" or "high"
- key_signal: the single most important fact behind the score, max 20 words
- reason: one or two sentences explaining the score
```

### Output schema

In the **Structured Output Parser** node, choose **Define using JSON Schema** and paste:

```json
{
  "type": "object",
  "properties": {
    "fit_score": { "type": "integer", "minimum": 1, "maximum": 5 },
    "digital_maturity": { "type": "string", "enum": ["low", "medium", "high"] },
    "key_signal": { "type": "string" },
    "reason": { "type": "string" }
  },
  "required": ["fit_score", "digital_maturity", "key_signal", "reason"]
}
```

The schema forces the AI to answer in a fixed structure, so the result can be saved straight into the SQL table. Without it, the AI might answer in free text that can't be stored reliably.

---

## Prompt 2: Draft the first outreach message

Node: **Draft outreach** (Basic LLM Chain, no output parser). Runs only for companies scored 4 or 5.

```text
You are a business development consultant at a firm that helps mid-sized
German companies digitalise their operations.

Write a short first outreach email to the managing director of the company
below. Requirements:
- Maximum 90 words, plus a subject line
- Refer to one specific, concrete detail about the company
- Name one realistic benefit, without promising numbers or results
- End with a low-pressure question about a short call
- Polite and professional, no buzzwords, no exaggeration
- Write in English

COMPANY
Name: {{ $('Loop Over Items').item.json.company_name }}
Industry: {{ $('Loop Over Items').item.json.industry }}
Description: {{ $('Loop Over Items').item.json.description }}
Key signal from our assessment: {{ $('Assess company').item.json.output.key_signal }}

Return only the subject line and the email text.
```

To write the drafts in German instead, change the last requirement to "Write in German, using the formal Sie form". That's what a real German Mittelstand client would expect, but you need to be able to review the German text yourself.

---

## Why two separate prompts?

- **Each step does one job.** Scoring needs strict rules and a fixed output format; writing needs freedom of style. Mixing both in one prompt makes each worse.
- **Cost and focus.** Drafts are only written for the hot leads, not for all 50 companies.
- **This is the orchestration**: the output of the first AI step decides whether and how the second step runs.
